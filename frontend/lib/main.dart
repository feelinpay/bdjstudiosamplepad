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
import 'core/services/filesystem_sync_service.dart';
import 'core/services/app_storage_service.dart';
import 'core/platform/device_tier.dart';
import 'core/platform/storage_permission_gate.dart';
import 'features/audio_engine/data/soloud_audio_engine.dart';
import 'core/audio/audio_initialization_result.dart';
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
import 'core/security/keychain_ci_smoke.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('BDJ_KEYCHAIN_CI_SMOKE', defaultValue: false)) {
    runKeychainCiSmokeTest();
    return;
  }
  runApp(const _BootstrapApp());
}

/// Servicios ya inicializados que se inyectan en los providers.
class _AppServices {
  final SettingsService settings;
  final SoLoudAudioEngine audio;
  final KeyBindingService keyBindings;
  final AudioInitializationResult audioInitResult;
  const _AppServices(
    this.settings,
    this.audio,
    this.keyBindings,
    this.audioInitResult,
  );
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

  /// Inicializa el motor de audio con timeout de protección.
  ///
  /// El presupuesto externo (30 s) cubre el peor caso de las estrategias
  /// progresivas internas del motor (3 intentos × watchdog nativo de 5 s +
  /// limpiezas), de modo que el motor siempre alcanza un estado terminal
  /// (`noDevice`/`error`) y la UI muestra su overlay con botón de reintento en
  /// vez de quedarse en "Inicializando..." sin salida.
  Future<AudioInitializationResult> _initAudioSafe(
    SoLoudAudioEngine audioEngine,
    int? savedDeviceId,
  ) async {
    try {
      return await audioEngine
          .initializeAndRestoreDevice(savedDeviceId)
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('[Bootstrap] Audio init timeout after 30 s');
          return const AudioInitializationResult.noDevice(
            userMessage:
                'El motor de audio tardó demasiado en responder. '
                'Los pads funcionarán cuando el audio esté disponible.',
          );
        },
      );
    } catch (e, st) {
      debugPrint('Error inicializando motor de audio: $e\n$st');
      return const AudioInitializationResult.error(
        userMessage: 'Error al inicializar el motor de audio',
      );
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
    await openAppDatabase().timeout(
      const Duration(seconds: 40),
      onTimeout: () => throw TimeoutException(
        'La biblioteca local tardo demasiado en abrir.',
      ),
    );
    debugPrint('[Bootstrap] Base de datos lista');

    // ── Fase 3: Motor de audio ───────────────────────────────────────────
    _updateStatus('Iniciando motor de audio...');
    final audioEngine = SoLoudAudioEngine();
    final settingsService = SettingsService.withPrefs(prefs);
    audioEngine.setSoundCacheCapacity(settingsService.soundCacheCapacity);

    final savedDeviceId = settingsService.audioOutputDeviceId;
    final audioInitResult = await _initAudioSafe(audioEngine, savedDeviceId);

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
      settingsService,
      audioEngine,
      KeyBindingService(prefs),
      audioInitResult,
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
            audioInitializationCacheProvider.overrideWith(
              (ref) => services.audioInitResult,
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
    backgroundColor: const Color(0xFF0D0D0D),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: error == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.deepPurpleAccent),
                  const SizedBox(height: 16),
                  Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.audiotrack,
                    color: Colors.deepPurpleAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
      ),
    ),
  );
}

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
  }

  @override
  void dispose() {
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

  /// Portón OBLIGATORIO de permisos de almacenamiento (solo Android): se
  /// muestra antes que cualquier otra pantalla y bloquea la app hasta
  /// conceder el acceso. En escritorio/iOS entrega el flujo normal.
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
    }
  }
}
