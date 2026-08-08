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
import 'core/providers/audio_providers.dart';
import 'core/services/filesystem_sync_service.dart';
import 'core/services/app_storage_service.dart';
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
class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  static const _installationMarker = 'bdj_sample_pad_installation_v1';
  Future<_AppServices>? _bootstrap;

  @override
  void initState() {
    super.initState();
    _bootstrap = _initialize();
  }

  Future<_AppServices> _initialize() async {
    await AppStorageService.initialize();
    // Un respaldo pendiente incompleto nunca debe impedir que la aplicación
    // abra, especialmente tras una actualización o en almacenamiento lento.
    try {
      await ConfigBackupService.applyPendingRestore();
    } catch (e) {
      debugPrint('Error en applyPendingRestore: $e');
    }

    try {
      GestureBinding.instance.resamplingEnabled = false;
    } catch (_) {}

    final audioEngine = SoLoudAudioEngine();

    // Las preferencias son ligeras y necesarias para construir la interfaz.
    // El motor nativo se prepara después, sin retener la primera pantalla.
    final prefs = await SharedPreferences.getInstance();

    // iOS/macOS conserva el Keychain tras desinstalar una app. El marcador vive en
    // el sandbox de la app; si falta, eliminamos cualquier secreto residual.
    if (!prefs.containsKey(_installationMarker)) {
      try {
        const storage = FlutterSecureStorage();
        for (final key in const [
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
        ]) {
          await storage.delete(key: key);
        }
        await prefs.setBool(_installationMarker, true);
      } catch (e) {
        debugPrint('Error en Secure Storage inicial: $e');
      }
    }

    // SettingsService reutiliza la instancia ya cargada (sin doble fetch).
    final settingsService = SettingsService.withPrefs(prefs);
    audioEngine.setSoundCacheCapacity(settingsService.soundCacheCapacity);

    // Inicializar el motor de audio y restaurar el dispositivo guardado.
    // Await bloquea el splash hasta que el motor esté ready (o haya fallado),
    // de modo que la UI observa un estado coherente vía audioInitializationProvider.
    final savedDeviceId = settingsService.audioOutputDeviceId;
    AudioInitializationResult audioInitResult;
    try {
      audioInitResult = await audioEngine.initializeAndRestoreDevice(
        savedDeviceId,
      );
    } catch (e, st) {
      debugPrint('Error inicializando motor de audio: $e\n$st');
      audioInitResult = const AudioInitializationResult.error(
        userMessage: 'Error al inicializar el motor de audio',
      );
    }

    // Rotacion automatica libre: respeta como gira el usuario su dispositivo.
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
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _StartupScreen(),
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
              error:
                  'No se pudo cargar la configuración local.\n\nDetalle: $detail\n\nReinicia la aplicación o presiona reintentar.',
              onRetry: () {
                final future = _initialize();
                setState(() {
                  _bootstrap = future;
                });
              },
            ),
          );
        }
        if (!snapshot.hasData) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: _StartupScreen(),
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
  const _StartupScreen({this.error, this.onRetry});

  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0D0D0D),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: error == null
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.deepPurpleAccent),
                  SizedBox(height: 16),
                  Text(
                    'Verificando recursos...',
                    style: TextStyle(
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
      home: _buildLicenseGate(licenseState),
    );
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
