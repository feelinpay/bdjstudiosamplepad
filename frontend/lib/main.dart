import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers/core_providers.dart';
import 'core/providers/database_provider.dart';
import 'core/providers/audio_providers.dart';
import 'core/providers/library_sync_provider.dart';
import 'core/services/filesystem_sync_service.dart';
import 'core/services/app_storage_service.dart';
import 'core/platform/device_tier.dart';
import 'core/platform/storage_permission_gate.dart';
import 'features/audio_engine/data/soloud_audio_engine.dart';
import 'core/theme/app_theme.dart';
import 'features/pad_system/presentation/pages/main_pad_page.dart';
import 'features/licensing/presentation/screens/activation_screen.dart';
import 'features/licensing/presentation/providers/license_providers.dart';
import 'features/settings/data/services/settings_service.dart';
import 'features/settings/data/services/config_backup_service.dart';
import 'features/settings/presentation/providers/settings_provider.dart';
import 'features/desktop/data/key_binding_service.dart';
import 'features/desktop/presentation/providers/desktop_providers.dart';
import 'l10n/app_localizations.dart';
import 'core/errors/failures.dart';
import 'core/licensing/licensing_port.dart';
import 'core/security/secure_storage_impl.dart';
import 'core/licensing/license_manager.dart';
import 'core/security/device_fingerprint.dart';
import 'core/services/crash_log_service.dart';
import 'core/security/keychain_ci_smoke.dart';
import 'core/audio/audio_bootstrapper.dart';
import 'core/diagnostics/startup_timeline.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    StartupTimeline.watchSlowFrames();
    if (const bool.fromEnvironment('BDJ_KEYCHAIN_CI_SMOKE', defaultValue: false)) {
      runKeychainCiSmokeTest();
      return;
    }
    await CrashLogService.initialize();
    StartupTimeline.mark('runApp');
    runApp(const _BootstrapApp());
  }, (error, stack) {

    CrashLogService.recordPlatformError(error, stack);
  });
}

/// Servicios ya inicializados que se inyectan en los providers.
class _AppServices {
  final SettingsService settings;
  final SoLoudAudioEngine audio;
  final KeyBindingService keyBindings;
  final SecureStorageImpl secureStorage;
  final LicenseManager licenseManager;
  final Future<Result<LicenseInfo>> licenseCheck;

  const _AppServices({
    required this.settings,
    required this.audio,
    required this.keyBindings,
    required this.secureStorage,
    required this.licenseManager,
    required this.licenseCheck,
  });
}

/// Muestra la ventana AL INSTANTE con un splash mientras el arranque pesado
/// (audio, settings, prefs) ocurre en segundo plano y EN PARALELO. Evita el
/// "lag" de apertura en equipos de baja gama, sin usar el motor de audio antes
/// de estar listo (los pads solo aparecen cuando todo termino de cargar).
///
/// v2: Inicialización progresiva con feedback visual paso-a-paso, operaciones
/// en paralelo, timeouts de seguridad y detección automática de gama del
/// dispositivo para ajustar presupuestos de recursos.
class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  static const _installationMarker = 'bdj_sample_pad_installation_v1';

  Future<_AppServices>? _bootstrap;
  String _statusText = 'Preparando...';

  @override
  void initState() {
    super.initState();
    _bootstrap = _initialize();
  }

  void _updateStatus(String text) {
    if (mounted) {
      setState(() => _statusText = text);
    }
  }

  /// Limpia secretos residuales del Keychain en la primera instalación.
  /// Las 10 operaciones corren en paralelo en vez de secuencialmente.
  ///
  /// Con presupuesto de tiempo: en equipos de gama baja el Keystore de Android
  /// puede tardar varios segundos en su primer acceso y, si está corrupto,
  /// llegar a bloquearse. El marcador se escribe igual para no repetir el
  /// intento en cada arranque.
  Future<void> _cleanKeychainIfNeeded(SharedPreferences prefs) async {
    if (prefs.containsKey(_installationMarker)) return;
    try {
      const storage = FlutterSecureStorage();
      const keys = [
        'spp_license_key',
        'spp_license_status',
        'spp_access_token',
        'spp_refresh_token',
        'spp_token_expires_at',
        'spp_last_sync_at',
        'spp_device_id',
        'spp_hardware_fingerprint',
        'spp_last_license_check_utc',
        'spp_install_id',
      ];
      await Future.wait(keys.map((k) => storage.delete(key: k))).timeout(
        const Duration(seconds: 6),
        onTimeout: () => const <void>[],
      );
      await prefs.setBool(_installationMarker, true);
    } catch (e) {
      debugPrint('Error en Secure Storage inicial: $e');
    }
  }

  Future<_AppServices> _initialize() async {
    // ── Fase 1: Almacenamiento + Preferencias + Detección de gama ─────────
    // Estas tres operaciones son independientes y corren en paralelo.
    // Cada una con presupuesto propio: en gama baja la E/S flash fría puede
    // tardar; ninguna debe poder colgar el arranque por sí sola.
    _updateStatus('Preparando almacenamiento...');
    final phase1 = await Future.wait([
      AppStorageService.initialize() // [0] void
          .timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('[Bootstrap] storage init timed out — continuing');
      }),
      SharedPreferences.getInstance(), // [1] SharedPreferences
      DeviceTierDetector.detect(), // [2] DeviceTier
    ]);
    final prefs = phase1[1] as SharedPreferences;
    final tier = phase1[2] as DeviceTier;
    debugPrint('[Bootstrap] Phase 1 done — tier=$tier');
    StartupTimeline.mark('phase1');

    // ── Fase 2: Restauración pendiente + Keychain cleanup ────────────────
    // Ambas son operaciones de I/O independientes con timeout de protección.
    _updateStatus('Verificando configuración...');
    await Future.wait([
      ConfigBackupService.applyPendingRestore()
          .timeout(const Duration(seconds: 5), onTimeout: () {
        debugPrint('[Bootstrap] applyPendingRestore timed out — skipping');
      }).catchError((e) {
        debugPrint('Error en applyPendingRestore: $e');
      }),
      _cleanKeychainIfNeeded(prefs),
    ]);
    StartupTimeline.mark('phase2');

    // Tras la Fase 2: validación de licencia en paralelo con la base de datos
    final secureStorage = SecureStorageImpl();
    final licenseManager = LicenseManager(
      secureStorage: secureStorage,
      fingerprint: DeviceFingerprint.withPersistentStorage(secureStorage),
    );
    final licenseCheck = licenseManager.validateLicense(); // sin await aquí

    try {
      GestureBinding.instance.resamplingEnabled = false;
    } catch (_) {}

    // ── Fase 2.5: Biblioteca (base de datos) ─────────────────────────────
    // La base es una dependencia dura: si no abre, no hay nada que mostrar.
    // Se abre aqui, y no de forma perezosa en el primer consumidor, porque los
    // consumidores absorben el error y dejaban la app girando sobre el logo sin
    // salida. Abriendola en el arranque el fallo llega a `_StartupScreen`, con
    // mensaje concreto y boton de reintentar. El presupuesto convierte ademas un
    // cuelgue en un error visible.
    _updateStatus('Abriendo biblioteca...');
    try {
      await openAppDatabase().timeout(
        const Duration(seconds: 40),
        onTimeout: () => throw TimeoutException(
          'La biblioteca local tardo demasiado en abrir.',
        ),
      );
      await ConfigBackupService.cleanupBeforeRestoreBackup();
      debugPrint('[Bootstrap] Base de datos lista');
      StartupTimeline.mark('database');
    } catch (e) {
      debugPrint('[Bootstrap] Error al abrir biblioteca: $e');
      final rolledBack = await ConfigBackupService.rollbackFailedRestore();
      if (rolledBack) {
        debugPrint('[Bootstrap] Rollback ejecutado. Reintentando abrir base de datos original...');
        _updateStatus('Restaurando proyecto anterior...');
        await openAppDatabase().timeout(
          const Duration(seconds: 40),
          onTimeout: () => throw TimeoutException(
            'La biblioteca previa tardo demasiado en abrir.',
          ),
        );
        await ConfigBackupService.cleanupBeforeRestoreBackup();
        debugPrint('[Bootstrap] Base de datos original reabierta con éxito');
        StartupTimeline.mark('database');
      } else {
        rethrow;
      }
    }

    // ── Fase 3: Motor de audio ───────────────────────────────────────────
    final audioEngine = SoLoudAudioEngine();
    final settingsService = SettingsService.withPrefs(prefs);
    audioEngine.setSoundCacheCapacity(settingsService.soundCacheCapacity);

    // ── Fase 4: Configuración de plataforma ──────────────────────────────
    // Rotación libre + barra de estado transparente en móvil.
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.black,
          ),
        );
      } catch (e) {
        debugPrint('Error configurando SystemChrome: $e');
      }
    }

    _updateStatus('¡Listo!');
    return _AppServices(
      settings: settingsService,
      audio: audioEngine,
      keyBindings: KeyBindingService(prefs),
      secureStorage: secureStorage,
      licenseManager: licenseManager,
      licenseCheck: licenseCheck,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrap == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _StartupScreen(statusText: _statusText),
      );
    }

    return FutureBuilder<_AppServices>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final detail = snapshot.error?.toString() ?? 'Error desconocido';
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: _StartupScreen(
              statusText: _statusText,
              error:
                  'No se pudo iniciar la aplicación.\n\nDetalle: $detail\n\nReinicia la aplicación o presiona reintentar.',
              onRetry: () {
                _statusText = 'Reintentando...';
                final future = _initialize();
                setState(() {
                  _bootstrap = future;
                });
              },
            ),
          );
        }
        if (!snapshot.hasData) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: _StartupScreen(statusText: _statusText),
          );
        }
        final services = snapshot.data!;
        return ProviderScope(
          overrides: [
            audioEngineProvider.overrideWithValue(services.audio),
            settingsServiceProvider.overrideWithValue(services.settings),
            settingsProvider.overrideWith(
              (ref) => SettingsNotifier(services.settings),
            ),
            keyBindingServiceProvider.overrideWithValue(services.keyBindings),
            secureStorageProvider.overrideWithValue(services.secureStorage),
            licenseManagerProvider.overrideWithValue(services.licenseManager),
            licenseProvider.overrideWith(
              (ref) => LicenseNotifier(
                ref.read(licenseManagerProvider),
                preloaded: services.licenseCheck,
              ),
            ),
          ],
          child: const SamplePadProApp(),
        );
      },
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen({this.statusText = 'Preparando...', this.error, this.onRetry});

  final String statusText;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF151522),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: error == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        'assets/icon/logo.png',
                        width: 104,
                        height: 104,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.library_music_rounded,
                          color: Colors.deepPurpleAccent,
                          size: 80,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'BDJ STUDIO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const Text(
                      'SAMPLE PAD',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const CircularProgressIndicator(
                      color: Colors.deepPurpleAccent,
                      strokeWidth: 3.5,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      statusText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.redAccent,
                      size: 56,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No se pudo iniciar la aplicación',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reintentar'),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                          ),
                          onPressed: () async {
                            final report = await CrashLogService.generateDiagnosticReport();
                            await Clipboard.setData(ClipboardData(text: report));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Diagnóstico copiado al portapapeles.'),
                                  backgroundColor: Colors.deepPurpleAccent,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copiar diagnóstico'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    ),
  );
}

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class SamplePadProApp extends ConsumerStatefulWidget {
  const SamplePadProApp({super.key});

  @override
  ConsumerState<SamplePadProApp> createState() => _SamplePadProAppState();
}

class _SamplePadProAppState extends ConsumerState<SamplePadProApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    DeviceFingerprint.onFingerprintChanged = () {
      if (mounted) {
        ref.read(licenseProvider.notifier).sync();
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      StartupTimeline.mark('firstAppFrame');
      final engine = ref.read(audioEngineProvider);
      final saved = ref.read(settingsServiceProvider).audioOutputDeviceId;
      AudioBootstrapper.start(engine, saved).then((result) {
        if (mounted) {
          ref.read(audioInitializationCacheProvider.notifier).state = result;
        }
      });
      ref.read(librarySyncProvider.future).then((changed) {
        if (changed > 0 && mounted) {
          refreshLibraryViewsWidget(ref);
        }
      });
      if (ConfigBackupService.lastRestoreRolledBack) {
        ConfigBackupService.lastRestoreRolledBack = false;
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 7),
            backgroundColor: Color(0xFFE65100),
            content: Text(
              'El respaldo no se pudo aplicar. Tu proyecto anterior sigue intacto.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    DeviceFingerprint.onFingerprintChanged = null;
    WidgetsBinding.instance.removeObserver(this);
    ref.read(audioEngineProvider).dispose();
    FilesystemSyncService.stopLiveWatcher();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(licenseProvider.notifier).sync();
    }
  }

  @override
  Widget build(BuildContext context) {
    var licenseState = ref.watch(licenseProvider);
    var settingsState = ref.watch(settingsProvider.select((s) => s.fontScale));

    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'BDJ Studio Sample Pad',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      builder: (context, child) {
        var scale = settingsState;
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('es')],
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      routes: {'/main': (_) => const MainPadPage()},
      home: _buildHome(licenseState),
    );
  }

  /// Portón informativo de permisos de audio (solo Android): solicita
  /// acceso para importar audios del dispositivo, pero no bloquea el uso de la app.
  /// En escritorio/iOS entrega el flujo normal directamente.
  Widget _buildHome(LicenseState licenseState) {
    return StoragePermissionGate(child: _buildLicenseGate(licenseState));
  }

  Widget _buildLicenseGate(LicenseState licenseState) {
    switch (licenseState.loadingState) {
      case LicenseLoadingState.initial:
      case LicenseLoadingState.loading:
        return const Scaffold(
          backgroundColor: Color(0xFF0D0D0D),
          body: Center(
            child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
          ),
        );
      case LicenseLoadingState.licensed:
        return const MainPadPage();
      case LicenseLoadingState.unlicensed:
      case LicenseLoadingState.error:
        {
          return const ActivationScreen();
        }
      case LicenseLoadingState.timeout:
        return Scaffold(
          backgroundColor: const Color(0xFF151522),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_off_rounded,
                    color: Colors.amberAccent,
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No se pudo verificar la licencia',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    licenseState.error ??
                        'La verificación de licencia tardó demasiado tiempo.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => ref.read(licenseProvider.notifier).sync(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }
}
