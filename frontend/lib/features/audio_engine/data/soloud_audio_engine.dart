import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../../../core/audio/audio_engine_port.dart';
import '../../../core/audio/audio_output_device.dart';
import '../../../core/audio/audio_initialization_result.dart';
import '../../../core/audio/trigger_mode.dart';
import '../../../core/audio/audio_engine_state.dart';
import '../../../core/platform/device_tier.dart';
import '../../../core/services/local_audio_storage_service.dart';
import '../../../core/utils/lru_cache.dart';
import '../../../core/utils/audio_log.dart';
import '../../../core/audio/audio_duration_estimator.dart';
import '../../../core/audio/audio_load_request.dart';
import '../../../core/diagnostics/startup_timeline.dart';
import 'audio_load_scheduler.dart';

/// Configuration for one progressive SoLoud init strategy.
class _InitAttempt {
  final bool lowLatency;
  final int sampleRate;
  final int bufferSize;
  const _InitAttempt({
    required this.lowLatency,
    this.sampleRate = 44100,
    this.bufferSize = 2048,
  });
}

class SoLoudAudioEngine implements AudioEnginePort {
  SoLoud? _soloud;
  bool _audioDisabled = false;
  Completer<void>? _initCompleter;
  bool _isInitialized = false;
  int? _pendingCacheCapacity;
  int? _pendingCacheBudget;
  int _maxAudioCacheBytes = DeviceTierDetector.profile.cacheBudgetBytes;
  int _deferredBytes = 0;
  late LruCache<String, AudioSource> _loadedSounds;
  static final Expando<int> _sourceBytesExpando = Expando<int>('sourceBytes');
  final Map<String, LoadMode> _loadedModes = {};

  /// `_loadedSounds` es `late` y solo existe tras `_doInitialize`. Un golpe de
  /// pad o una nota MIDI pueden llegar antes de que termine el arranque, así
  /// que todo acceso se guarda con este flag para no lanzar
  /// `LateInitializationError`.
  bool _cacheReady = false;
  final Map<String, List<SoundHandle>> _activeHandles = {};
  final Map<String, AudioSource> _deferredDisposeSources = {};
  final Map<int, List<SoundHandle>> _chokeGroupHandles = {};
  final Map<SoundHandle, Timer> _fadeTimers = {};
  final StreamController<String> _soundFinishedController =
      StreamController<String>.broadcast();

  final Map<String, double> _padVolumes = {};
  final Map<String, double> _baseVolumes = {};
  final Set<String> _mutedPads = {};
  final Set<String> _soloedPads = {};

  Timer? _pollingTimer;
  final List<AudioSource> _pendingDisposals = [];
  Timer? _disposalTimer;

  AudioEngineState _engineState = AudioEngineState.uninitialized;
  bool _isChangingDevice = false;
  int _initAttempt = 0;
  List<PlaybackDevice>? _deviceSnapshot; // enumeración del arranque actual
  int? _preferredDeviceId;               // pedido por initializeAndRestoreDevice
  int? _openedDeviceId;                  // con qué dispositivo se abrió realmente

  late final AudioLoadScheduler _preloadScheduler = AudioLoadScheduler(
    maxConcurrent: _calculateMaxConcurrentLoads(),
    load: (AudioLoadRequest req) => loadAudio(
      req.id,
      req.path,
      needsRandomAccess: req.needsRandomAccess,
    ),
  );

  static int _calculateMaxConcurrentLoads() {
    return switch (DeviceTierDetector.current) {
      DeviceTier.low => 1,
      DeviceTier.mid => 2,
      DeviceTier.high => (Platform.numberOfProcessors ~/ 2).clamp(2, 4),
    };
  }

  @override
  AudioEngineState get engineState => _engineState;

  @override
  void setSoundCacheCapacity(int capacity) {
    _pendingCacheCapacity = capacity;
    if (_cacheReady) {
      _loadedSounds.resize(capacity);
    }
  }

  @override
  void setSoundCacheBudget(int bytes) {
    _pendingCacheBudget = bytes;
    _maxAudioCacheBytes = bytes;
    _updateCacheWeightBudget();
  }

  int _effectiveCacheBudget() {
    final eff = _maxAudioCacheBytes - _deferredBytes;
    return eff > 0 ? eff : 0;
  }

  void _updateCacheWeightBudget() {
    if (_cacheReady) {
      _loadedSounds.setMaxWeight(_effectiveCacheBudget());
    }
  }

  SoLoudAudioEngine() {
    try {
      _soloud = SoLoud.instance;
    } catch (e, st) {
      _audioDisabled = true;
      debugPrint(
        'SoLoud library not available on this platform/device: $e\n$st',
      );
    }
  }

  @override
  Stream<String> get onSoundFinished => _soundFinishedController.stream;

  /// Anuncia que [id] dejó de sonar para que la UI apague el pad.
  ///
  /// Se ignora si el motor ya fue liberado: `dispose()` cierra el controller y
  /// un `add` posterior lanzaría.
  void _notifyFinished(String id) {
    if (_soundFinishedController.isClosed) return;
    _soundFinishedController.add(id);
  }

  @override
  bool isLoaded(String id) {
    var inCache =
        _isInitialized && _cacheReady && _loadedSounds.containsKey(id);
    var loaded = inCache && !_audioDisabled;
    AudioLog.log(
      '[SoLoud] isLoaded: id=$id result=$loaded initialized=$_isInitialized disabled=$_audioDisabled inCache=$inCache',
    );
    return loaded;
  }

  @override
  Future<void> initialize() {
    return _ensureInitialized();
  }

  Future<void> _ensureInitialized() {
    if (_engineState == AudioEngineState.disposed) {
      return Future.value();
    }
    if (_isInitialized && _engineState == AudioEngineState.ready) {
      return Future.value();
    }
    // Si ya hay una inicialización EN VUELO, todos los llamadores esperan ese
    // mismo future. La condición estaba invertida (reutilizaba el completer solo
    // cuando ya había terminado): el segundo llamador creaba un completer nuevo,
    // pisaba `_initCompleter`, y al acabar `_doInitialize` se completaba el
    // nuevo — dejando el primero sin completar nunca y la app en la pantalla de
    // carga para siempre.
    final pending = _initCompleter;
    if (pending != null && !pending.isCompleted) {
      return pending.future;
    }
    _initCompleter = Completer<void>();
    _initAttempt++;
    _doInitialize().then(
      (_) {
        if (!_initCompleter!.isCompleted) {
          _initCompleter!.complete();
        }
      },
      onError: (e, st) {
        if (!_initCompleter!.isCompleted) {
          _initCompleter!.completeError(e, st);
        }
      },
    );
    return _initCompleter!.future;
  }

  Future<void> _doInitialize() async {
    if (_engineState == AudioEngineState.initializing) {
      return;
    }
    _engineState = AudioEngineState.initializing;
    debugPrint(
      '[AudioEngine] initAttempt=$_initAttempt platform=${Platform.operatingSystem} '
      'engineState=$_engineState',
    );

    // Un reintento (p.ej. tras reconectar la interfaz de audio) volvía a crear
    // la caché dejando huérfanas las AudioSource nativas de la anterior.
    if (_cacheReady) {
      _loadedSounds.clear();
    }
    _maxAudioCacheBytes =
        _pendingCacheBudget ?? DeviceTierDetector.profile.cacheBudgetBytes;
    _deferredBytes = 0;
    _loadedSounds = LruCache<String, AudioSource>(
      _pendingCacheCapacity ?? DeviceTierDetector.soundCacheCapacity,
      weigh: (source) => _sourceBytesExpando[source] ?? (256 * 1024),
      maxWeight: _effectiveCacheBudget(),
      onEvict: (id, source) {
        _deferDisposeSource(id, source);
      },
    );
    _cacheReady = true;

    if (_audioDisabled || _soloud == null) {
      _isInitialized = true;
      _engineState = AudioEngineState.noDevice;
      debugPrint('[AudioEngine] No SoLoud instance; state=noDevice');
      return;
    }

    StartupTimeline.mark('audio_list_devices_start');
    final devices = _deviceSnapshot = _safeListDevices();
    StartupTimeline.mark('audio_list_devices_end');
    if (devices.isEmpty) {
      _isInitialized = true;
      _engineState = AudioEngineState.noDevice;
      debugPrint(
        '[AudioEngine] No playback devices enumerated; state=noDevice',
      );
      return;
    }

    final preferred =
        devices.where((d) => d.id == _preferredDeviceId).firstOrNull;
    final target = preferred ??
        devices.firstWhere((d) => d.isDefault, orElse: () => devices.first);

    try {
      // Progressive init strategies. The native layer bounds each device open
      // with its own watchdog (5 s), so these timeouts can actually fire even
      // if a low-end audio HAL misbehaves. Cheapest/best-latency first,
      // most-compatible last.
      final attempts = <_InitAttempt>[
        const _InitAttempt(lowLatency: true),
        // Conservative profile avoids the AAudio MMAP path and prefers
        // OpenSL ES — the most compatible configuration on budget hardware.
        const _InitAttempt(lowLatency: false),
        // Some cheap HALs also choke resampling 44.1 kHz: try the native
        // 48 kHz rate with a larger buffer as a last resort.
        const _InitAttempt(
          lowLatency: false,
          sampleRate: 48000,
          bufferSize: 4096,
        ),
      ];
      final List<_InitAttempt> plan =
          Platform.isAndroid ? attempts : attempts.sublist(0, 1);

      Object? lastError;
      bool opened = false;
      StartupTimeline.mark('audio_device_open_start');
      for (final attempt in plan) {
        try {
          await _soloud!
              .init(
                device: (Platform.isAndroid || Platform.isIOS) ? null : target,
                sampleRate: attempt.sampleRate,
                bufferSize: attempt.bufferSize,
                channels: Channels.stereo,
                lowLatency: attempt.lowLatency,
              )
              .timeout(
                const Duration(seconds: 6),
                onTimeout: () => throw TimeoutException(
                  'SoLoud.init() exceeded 6 s '
                  '(lowLatency=${attempt.lowLatency}, '
                  'sr=${attempt.sampleRate}, buf=${attempt.bufferSize})',
                ),
              );
          opened = true;
          _openedDeviceId = target.id;
          break;
        } catch (e) {
          lastError = e;
          debugPrint('[AudioEngine] init attempt failed '
              '(lowLatency=${attempt.lowLatency}, sr=${attempt.sampleRate}, '
              'buf=${attempt.bufferSize}): $e');
          // Reset any half-open native state before the next strategy.
          try {
            if (_soloud!.isInitialized) _soloud!.deinit();
          } catch (_) {}
          if (Platform.isAndroid && _soloud != null) {
            final drainSw = Stopwatch()..start();
            while (_soloud!.initEngineStatus() == -1 &&
                drainSw.elapsedMilliseconds < 1500) {
              await Future<void>.delayed(const Duration(milliseconds: 50));
            }
          }
        }
      }
      StartupTimeline.mark('audio_device_open_end');
      if (!opened) {
        throw (lastError is Exception)
            ? lastError
            : Exception(lastError?.toString() ?? 'audio init failed');
      }
      // Visualización bajo demanda (T20): solo se activa si hay consumidores registrados
      // (ej. el MasterMixerPanel está abierto durante un reinicio/cambio de dispositivo).
      _soloud!.setVisualizationEnabled(_visualizationRefs > 0);
      _isInitialized = true;
      _engineState = AudioEngineState.ready;
      debugPrint(
        '[AudioEngine] Engine ready. availableDevices=${devices.length} '
        'tier=${DeviceTierDetector.current}',
      );
      _startPolling();
    } catch (e, st) {
      final msg = e.toString();
      debugPrint('[AudioEngine] init() failed: $msg\n$st');
      _isInitialized = true;
      if (msg.contains('No playback devices were found') ||
          e is TimeoutException) {
        _engineState = AudioEngineState.noDevice;
      } else {
        _engineState = AudioEngineState.error;
      }
      if (_engineState == AudioEngineState.noDevice) {
        _initCompleter = null;
      }
    }
  }

  void _startPolling() {
    if (_pollingTimer != null) return;
    // Adaptive polling: low-end devices use a longer interval to save CPU.
    final intervalMs = DeviceTierDetector.audioPollingIntervalMs;
    _pollingTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (_audioDisabled || _soloud == null || _activeHandles.isEmpty) return;

      var idsToCheck = _activeHandles.keys.toList();
      for (var id in idsToCheck) {
        var handles = _activeHandles[id];
        if (handles == null || handles.isEmpty) continue;

        bool changed = false;
        handles.removeWhere((handle) {
          try {
            var isValid = _soloud!.getIsValidVoiceHandle(handle);
            if (!isValid) {
              changed = true;
              _fadeTimers.remove(handle)?.cancel();
            }
            return !isValid;
          } catch (_) {
            return true;
          }
        });

        if (changed && handles.isEmpty) {
          AudioLog.log('[SoLoud] polling: soundFinished id=$id handles=0');
          _notifyFinished(id);
          _activeHandles.remove(id);
          _disposeDeferredSource(id);
        }
      }

      var chokeGroupsToCheck = _chokeGroupHandles.keys.toList();
      for (var groupId in chokeGroupsToCheck) {
        var handles = _chokeGroupHandles[groupId];
        if (handles == null || handles.isEmpty) continue;
        handles.removeWhere((handle) {
          try {
            return !_soloud!.getIsValidVoiceHandle(handle);
          } catch (_) {
            return true;
          }
        });
      }
    });
  }

  @override
  Future<List<AudioOutputDevice>> listOutputDevices() async {
    return _mapPlaybackDevices(_safeListDevices());
  }

  List<AudioOutputDevice> _mapPlaybackDevices(List<PlaybackDevice> devices) {
    return devices
        .map(
          (device) => AudioOutputDevice(
            id: device.id,
            name: device.name,
            isDefault: device.isDefault,
          ),
        )
        .toList(growable: false);
  }

  List<PlaybackDevice> _safeListDevices() {
    if (_soloud == null) return const [];
    try {
      return _soloud!.listPlaybackDevices();
    } catch (e, st) {
      debugPrint('[AudioEngine] listPlaybackDevices failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<AudioInitializationResult> initializeAndRestoreDevice(
    int? savedDeviceId,
  ) async {
    debugPrint(
      '[AudioEngine] initializeAndRestoreDevice: savedDeviceId=$savedDeviceId',
    );

    _preferredDeviceId = savedDeviceId;
    await _ensureInitialized();

    if (_audioDisabled || _soloud == null) {
      _engineState = AudioEngineState.noDevice;
      return const AudioInitializationResult.noDevice(
        userMessage:
            'No se encontró una salida de audio disponible. '
            'Conecta parlantes, auriculares o una interfaz de audio.',
      );
    }

    final devices = _deviceSnapshot ?? _safeListDevices();
    if (devices.isEmpty) {
      _engineState = AudioEngineState.noDevice;
      return const AudioInitializationResult.noDevice(
        userMessage:
            'No se encontró una salida de audio disponible. '
            'Conecta parlantes, auriculares o una interfaz de audio.',
      );
    }

    final mappedDevices = _mapPlaybackDevices(devices);
    final defaultDevice = devices.firstWhere(
      (d) => d.isDefault,
      orElse: () => devices.first,
    );
    bool savedDeviceInvalid = false;
    int targetDeviceId = savedDeviceId ?? defaultDevice.id;
    String? warningMessage;

    if (savedDeviceId != null && savedDeviceId != -1) {
      final savedExists = devices.any((d) => d.id == savedDeviceId);
      if (!savedExists) {
        savedDeviceInvalid = true;
        targetDeviceId = defaultDevice.id;
        warningMessage =
            'El dispositivo de audio anterior ya no está disponible. '
            'Se utilizará la salida predeterminada.';
        debugPrint(
          '[AudioEngine] saved device $savedDeviceId not found; '
          'falling back to default ${defaultDevice.id}',
        );
      }
    }

    if (!_isInitialized || _engineState != AudioEngineState.ready) {
      _engineState = AudioEngineState.error;
      return AudioInitializationResult.error(
        userMessage:
            warningMessage ?? 'No se pudo inicializar el motor de audio.',
      );
    }

    final needsDeviceSwitch = targetDeviceId != _openedDeviceId;
    if (needsDeviceSwitch) {
      final selectResult = await _changeDevice(targetDeviceId, devices: devices);
      if (selectResult != null) {
        _engineState = AudioEngineState.error;
        return AudioInitializationResult.error(userMessage: selectResult);
      }
    }

    return AudioInitializationResult(
      state: _engineState,
      devices: mappedDevices,
      appliedDeviceId: targetDeviceId,
      savedDeviceInvalid: savedDeviceInvalid,
      userMessage: warningMessage,
    );
  }

  @override
  Future<AudioInitializationResult> retryAudioInitialization(
    int? savedDeviceId,
  ) async {
    debugPrint(
      '[AudioEngine] retryAudioInitialization: savedDeviceId=$savedDeviceId',
    );

    _deviceSnapshot = null;
    _openedDeviceId = null;
    _initCompleter = null;
    _isInitialized = false;

    if (_soloud != null && _engineState != AudioEngineState.noDevice) {
      try {
        _soloud!.deinit();
      } catch (e, st) {
        debugPrint('[AudioEngine] deinit during retry failed: $e\n$st');
      }
    }

    if (Platform.isAndroid && _soloud != null) {
      final drainSw = Stopwatch()..start();
      while (_soloud!.initEngineStatus() == -1 &&
          drainSw.elapsedMilliseconds < 1500) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    _isChangingDevice = false;
    return initializeAndRestoreDevice(savedDeviceId);
  }

  @override
  Future<List<AudioOutputDevice>> refreshPlaybackDevices() async {
    final devices = _safeListDevices();
    return _mapPlaybackDevices(devices);
  }

  @override
  Future<void> selectOutputDevice(int? deviceId) async {
    if (_isChangingDevice) {
      throw StateError('Cambio de dispositivo en curso.');
    }
    _isChangingDevice = true;
    _engineState = AudioEngineState.changingDevice;

    try {
      await _ensureInitialized();

      if (_audioDisabled || _soloud == null) {
        _engineState = AudioEngineState.noDevice;
        return;
      }

      final devices = _safeListDevices();
      if (devices.isEmpty) {
        _engineState = AudioEngineState.noDevice;
        return;
      }

      final targetId = deviceId == null || deviceId == -1
          ? null
          : devices
                .firstWhere(
                  (d) => d.id == deviceId,
                  orElse: () => devices.firstWhere(
                    (d) => d.isDefault,
                    orElse: () => devices.first,
                  ),
                )
                .id;
      final safeDeviceId =
          targetId ??
          devices
              .firstWhere((d) => d.isDefault, orElse: () => devices.first)
              .id;

      final defaultDevice = devices.firstWhere(
        (d) => d.isDefault,
        orElse: () => devices.first,
      );
      final isMobileSingleOutput =
          Platform.isAndroid || Platform.isIOS;
      if (isMobileSingleOutput && safeDeviceId == defaultDevice.id) {
        // Already on the only OS-managed output; reopening it would just
        // restart the stream.
        _engineState = AudioEngineState.ready;
        return;
      }

      final errorMsg = _changeDevice(safeDeviceId);
      if (errorMsg != null) {
        if (errorMsg.contains('No playback devices were found')) {
          _engineState = AudioEngineState.noDevice;
        } else {
          _engineState = AudioEngineState.error;
          debugPrint('[AudioEngine] selectOutputDevice failed: $errorMsg');
        }
        return;
      }

      _engineState = AudioEngineState.ready;
    } finally {
      _isChangingDevice = false;
    }
  }

  String? _changeDevice(int deviceId, {List<PlaybackDevice>? devices}) {
    if (_audioDisabled || _soloud == null) {
      return 'No se encontró una salida de audio disponible.';
    }
    try {
      final devList = devices ?? _soloud!.listPlaybackDevices();
      final targetDevice = devList.firstWhere(
        (d) => d.id == deviceId,
        orElse: () =>
            devList.firstWhere((d) => d.isDefault, orElse: () => devList.first),
      );
      _soloud!.changeDevice(newDevice: targetDevice);
      _openedDeviceId = targetDevice.id;
      _engineState = AudioEngineState.ready;
      return null;
    } catch (e, st) {
      final msg = e.toString();
      debugPrint('[AudioEngine] changeDevice($deviceId) failed: $msg\n$st');
      if (msg.contains('No playback devices were found')) {
        _engineState = AudioEngineState.noDevice;
        return 'No se encontró una salida de audio disponible. '
            'Conecta parlantes, auriculares o una interfaz de audio.';
      }
      _engineState = AudioEngineState.error;
      return 'No se pudo cambiar la salida de audio. Inténtalo de nuevo.';
    }
  }

  final Map<String, String> _loadedPaths = {};
  final Set<String> _loadingIds = {};

  void _deferDisposeSource(String id, AudioSource source) {
    final bytes = _sourceBytesExpando[source] ?? (256 * 1024);
    if (_activeHandles.containsKey(id) && _activeHandles[id]!.isNotEmpty) {
      _deferredDisposeSources[id] = source;
      _loadedPaths.remove(id);
      _loadedModes.remove(id);
      _deferredBytes += bytes;
      _updateCacheWeightBudget();
      AudioLog.log(
        '[SoLoud] onEvict: DEFERRED id=$id (playback still active, handles=${_activeHandles[id]!.length}, deferredBytes=$_deferredBytes)',
      );
      return;
    }

    if (_activeHandles.containsKey(id)) {
      _activeHandles.remove(id);
    }
    _loadedPaths.remove(id);
    _loadedModes.remove(id);
    AudioLog.log(
      '[SoLoud] onEvict: DISPOSING id=$id immediately (no active handles)',
    );
    _scheduleDisposeSource(source);
  }

  void _disposeDeferredSource(String id) {
    final source = _deferredDisposeSources.remove(id);
    if (source == null) return;
    final bytes = _sourceBytesExpando[source] ?? (256 * 1024);
    _deferredBytes -= bytes;
    if (_deferredBytes < 0) _deferredBytes = 0;
    _updateCacheWeightBudget();
    AudioLog.log(
      '[SoLoud] _disposeDeferredSource: disposing deferred source for id=$id, deferredBytes=$_deferredBytes',
    );
    _scheduleDisposeSource(source);
  }

  void _scheduleDisposeSource(AudioSource source) {
    if (_audioDisabled || _soloud == null) return;
    if (_engineState == AudioEngineState.disposed) {
      try {
        _soloud!.disposeSource(source);
      } catch (_) {}
      return;
    }
    if (_pendingDisposals.contains(source)) return;
    _pendingDisposals.add(source);
    _disposalTimer ??= Timer(
      const Duration(milliseconds: 100),
      _drainPendingDisposals,
    );
  }

  void _drainPendingDisposals() {
    _disposalTimer = null;
    if (_audioDisabled || _soloud == null) return;
    var batch = List<AudioSource>.of(_pendingDisposals);
    _pendingDisposals.clear();
    for (var source in batch) {
      try {
        _soloud!.disposeSource(source);
      } catch (_) {}
    }
  }

  @override
  Future<void> loadAudio(
    String id,
    String assetPath, {
    bool needsRandomAccess = false,
  }) async {
    if (AudioLog.verbose) {
      final inCache = _cacheReady && _loadedSounds.containsKey(id);
      AudioLog.log(
        '[SoLoud] loadAudio: id=$id path=$assetPath needsRandomAccess=$needsRandomAccess inCache=$inCache inFlight=${_loadingIds.contains(id)}',
      );
    }
    if (_loadingIds.contains(id)) return;
    _loadingIds.add(id);
    try {
      await _loadAudioInternal(
        id,
        assetPath,
        needsRandomAccess: needsRandomAccess,
      );
    } finally {
      _loadingIds.remove(id);
    }
  }

  Future<void> _loadAudioInternal(
    String id,
    String assetPath, {
    bool needsRandomAccess = false,
  }) async {
    await _ensureInitialized();
    if (_audioDisabled || _soloud == null) {
      AudioLog.log('[SoLoud] loadAudio: SKIPPED id=$id (disabled or null)');
      return;
    }
    var resolvedPath = LocalAudioStorageService.resolvePathSync(assetPath);
    AudioLog.log('[SoLoud] loadAudio: resolvedPath=$resolvedPath');

    if (_loadedSounds.containsKey(id) && _loadedPaths[id] == resolvedPath) {
      if (!needsRandomAccess || _loadedModes[id] == LoadMode.memory) {
        _loadedSounds.get(id);
        AudioLog.log(
          '[SoLoud] loadAudio: CACHE HIT id=$id (same path, mode=${_loadedModes[id]})',
        );
        return;
      }
      AudioLog.log(
        '[SoLoud] loadAudio: PROMOTING TO MEMORY id=$id (was disk, now needsRandomAccess)',
      );
    }

    if (_loadedSounds.containsKey(id)) {
      AudioLog.log(
        '[SoLoud] loadAudio: CACHE COLLISION id=$id (different path or mode), stopping old',
      );
      stop(id, notify: false);
      // `remove` ya dispara onEvict, que libera la fuente anterior.
      _loadedSounds.remove(id);
      _loadedPaths.remove(id);
      _loadedModes.remove(id);
      _activeHandles.remove(id);
    }

    if (_deferredDisposeSources.containsKey(id) ||
        (_activeHandles.containsKey(id) && _activeHandles[id]!.isNotEmpty)) {
      AudioLog.log(
        '[SoLoud] loadAudio: stopping deferred/active handles for id=$id',
      );
      // Silencioso: es limpieza interna de la carga. Notificar aquí apagaría el
      // pad justo después de que onPadDown lo encendiera, porque la entrega del
      // stream es asíncrona y llegaría tarde.
      stop(id, notify: false);
    }

    try {
      AudioSource source;
      LoadMode mode = LoadMode.memory;
      Duration? estimatedDuration;

      if (_isAbsolutePath(resolvedPath)) {
        final file = File(resolvedPath);
        if (!await file.exists()) {
          AudioLog.log(
            '[SoLoud] loadAudio: FILE NOT FOUND id=$id at $resolvedPath',
          );
          return;
        }

        // Si no requiere acceso aleatorio (reverse/cue), evaluamos duración para streaming desde disco
        if (!needsRandomAccess) {
          estimatedDuration =
              await AudioDurationEstimator.estimateDecodedDuration(file);
          final thresholdSec = DeviceTierDetector.profile.diskThresholdSeconds;
          if (estimatedDuration != null &&
              estimatedDuration.inSeconds > thresholdSec) {
            mode = LoadMode.disk;
          }
        }

        AudioLog.log(
          '[SoLoud] loadAudio: LOADING id=$id mode=$mode dur=${estimatedDuration?.inSeconds}s (threshold=${DeviceTierDetector.profile.diskThresholdSeconds}s)',
        );
        source = await _soloud!.loadFile(resolvedPath, mode: mode);
      } else {
        source = await _soloud!.loadAsset(resolvedPath);
        mode = LoadMode.memory;
      }

      Duration? actualDuration;
      if (mode == LoadMode.memory && _soloud != null) {
        try {
          actualDuration = _soloud!.getLength(source);
        } catch (_) {}
      }
      final soundBytes = AudioDurationEstimator.estimateSoundMemoryBytes(
        actualDuration ?? estimatedDuration,
        mode,
      );
      _sourceBytesExpando[source] = soundBytes;

      _loadedModes[id] = mode;
      _loadedSounds.put(id, source);
      _loadedPaths[id] = resolvedPath;
      _activeHandles[id] = [];
      AudioLog.log(
        '[SoLoud] loadAudio: SUCCESS id=$id mode=$mode bytes=$soundBytes cacheSize=${_loadedSounds.length} totalWeight=${_loadedSounds.totalWeight}',
      );
    } catch (e) {
      debugPrint('[SoLoud] loadAudio: ERROR id=$id: $e');
    }
  }

  bool _isAbsolutePath(String path) {
    if (path.length >= 2 && path[1] == ':') return true;
    if (path.startsWith('/')) return true;
    return false;
  }

  @override
  Future<void> preloadAll(dynamic requests) {
    return _preloadScheduler.replaceQueue(requests);
  }

  @override
  void preloadIdle(dynamic requests) {
    _preloadScheduler.enqueueIdle(requests);
  }

  @override
  double get cacheUsageRatio {
    if (!_cacheReady) return 0.0;
    final budget = _effectiveCacheBudget();
    if (budget <= 0) return 0.0;
    return _loadedSounds.totalWeight / budget;
  }

  @override
  void play(
    String id,
    TriggerMode mode, {
    int chokeGroup = 0,
    double pan = 0.0,
    double pitch = 1.0,
    double volume = 1.0,
    bool isProtected = false,
    bool reverse = false,
    Duration fadeIn = Duration.zero,
    Duration fadeOut = Duration.zero,
    Duration startPoint = Duration.zero,
    Duration? endPoint,
    Duration loopPoint = Duration.zero,
  }) {
    if (_audioDisabled || _soloud == null || !_cacheReady) {
      AudioLog.log(
        '[SoLoud] play: audioDisabled=$_audioDisabled soloud=$_soloud cacheReady=$_cacheReady for id=$id mode=$mode',
      );
      _notifyFinished(id);
      return;
    }
    var source = _loadedSounds.get(id);
    AudioLog.log(
      '[SoLoud] play: id=$id mode=$mode startPoint=$startPoint endPoint=$endPoint loopPoint=$loopPoint source=${source != null} handles=${_activeHandles[id]?.length}',
    );
    if (source == null) {
      AudioLog.log(
        '[SoLoud] play: SOURCE NOT FOUND in cache for id=$id — loadAudio may not have been called',
      );
      // Sin este aviso el pad se queda encendido para siempre: onPadDown ya lo
      // puso en `playing` y solo onSoundFinished lo devuelve a `idle`.
      _notifyFinished(id);
      return;
    }

    if (chokeGroup > 0) {
      var groupHandles = _chokeGroupHandles[chokeGroup];
      if (groupHandles != null) {
        for (var handle in groupHandles) {
          _soloud!.fadeVolume(handle, 0.0, const Duration(milliseconds: 50));
          _soloud!.scheduleStop(handle, const Duration(milliseconds: 50));
        }
        groupHandles.clear();
      }
    }

    if (mode == TriggerMode.toggle) {
      if ((_activeHandles[id]?.isNotEmpty ?? false)) {
        stop(id);
        return;
      }
    }

    try {
      _baseVolumes[id] = volume;
      double targetVolume = (_padVolumes[id] ?? 1.0) * volume;
      if (_mutedPads.contains(id)) targetVolume = 0.0;
      if (_soloedPads.isNotEmpty && !_soloedPads.contains(id)) {
        targetVolume = 0.0;
      }

      // El loop se configura antes de crear la voz. Configurarlo después de
      // iniciar (o con un Timer y seek) deja un hueco audible al reiniciar.
      final nativeLoopPoint = loopPoint > Duration.zero
          ? loopPoint
          : startPoint;
      // Para un inicio recortado no dejamos que se emita ni un frame desde
      // 0 ms: primero posicionamos la voz y luego la liberamos.
      final startPaused = startPoint > Duration.zero;
      var handle = _soloud!.play(
        source,
        volume: fadeIn.inMilliseconds > 0 ? 0.0 : targetVolume,
        pan: pan,
        paused: startPaused,
        looping: mode == TriggerMode.loop,
        loopingStartAt: nativeLoopPoint,
      );

      if (!_soloud!.getIsValidVoiceHandle(handle)) {
        AudioLog.log(
          '[SoLoud] play: HANDLE INVALID immediately after play for id=$id mode=$mode',
        );
        _notifyFinished(id);
        return;
      }
      AudioLog.log(
        '[SoLoud] play: started handle for id=$id mode=$mode pos=${_soloud!.getPosition(handle)}',
      );

      double finalPitch = reverse ? -pitch : pitch;
      _soloud!.setRelativePlaySpeed(handle, finalPitch);

      if (fadeIn.inMilliseconds > 0) {
        _soloud!.fadeVolume(handle, targetVolume, fadeIn);
      }

      if (startPoint.inMilliseconds > 0) {
        _soloud!.seek(handle, startPoint);
      }
      if (startPaused) {
        _soloud!.setPause(handle, false);
      }

      if (endPoint != null && mode != TriggerMode.loop) {
        var durationToPlay = endPoint - startPoint;
        if (durationToPlay.inMilliseconds > 0) {
          if (fadeOut.inMilliseconds > 0) {
            var timer = Timer(durationToPlay - fadeOut, () {
              _fadeTimers.remove(handle)?.cancel();
              if (_soloud != null && _soloud!.getIsValidVoiceHandle(handle)) {
                _soloud!.fadeVolume(handle, 0.0, fadeOut);
              }
            });
            _fadeTimers[handle] = timer;
          }
          _soloud!.scheduleStop(handle, durationToPlay);
        }
      }

      if (isProtected) {
        _soloud!.setProtectVoice(handle, true);
      }

      if (mode == TriggerMode.loop) {
        if (endPoint != null && endPoint > nativeLoopPoint) {
          _soloud!.setLoopEndPoint(handle, endPoint);
        }
        AudioLog.log(
          '[SoLoud] play: seamless native loop id=$id '
          'loopPoint=$nativeLoopPoint endPoint=$endPoint startPoint=$startPoint',
        );
      }

      _activeHandles.putIfAbsent(id, () => []).add(handle);
      AudioLog.log(
        '[SoLoud] play: handle registered for id=$id, total handles=${_activeHandles[id]!.length}',
      );

      if (chokeGroup > 0) {
        _chokeGroupHandles.putIfAbsent(chokeGroup, () => []).add(handle);
      }
    } catch (e) {
      debugPrint('Error playing audio $id: $e');
      _notifyFinished(id);
    }
  }

  @override
  void stopAll() {
    // Es el PANIC / ESC: además de callar el audio debe apagar todos los pads,
    // así que cada id se notifica para que la UI vuelva a `idle`.
    final activeIds = _activeHandles.keys.toSet();
    final knownIds = <String>{
      ...activeIds,
      if (_cacheReady) ..._loadedSounds.keys,
    };
    for (final id in activeIds) {
      stop(id);
    }
    // Un pad puede seguir iluminado aunque su voz haya terminado justo antes
    // del PANIC. También se reinician las páginas/workspaces no visibles.
    for (final id in knownIds.difference(activeIds)) {
      _notifyFinished(id);
    }
    _chokeGroupHandles.clear();
  }

  @override
  Duration? getPosition(String id) {
    if (_soloud == null) return null;
    var handles = _activeHandles[id];
    if (handles == null || handles.isEmpty) return null;
    for (var handle in handles) {
      try {
        if (_soloud!.getIsValidVoiceHandle(handle)) {
          return _soloud!.getPosition(handle);
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  @override
  void stop(String id, {bool notify = true}) {
    AudioLog.log(
      '[SoLoud] stop: id=$id notify=$notify handles=${_activeHandles[id]?.length} deferred=${_deferredDisposeSources.containsKey(id)}',
    );
    if (_soloud == null) {
      // Sin motor nativo no hay nada que callar, pero el pad sí debe apagarse:
      // si no, arrancar sin tarjeta de sonido deja los pads encendidos.
      if (notify) _notifyFinished(id);
      return;
    }
    var handles = _activeHandles.remove(id);
    if (handles != null) {
      AudioLog.log(
        '[SoLoud] stop: removing ${handles.length} handles for id=$id',
      );
      for (var handle in handles) {
        _fadeTimers.remove(handle)?.cancel();
        try {
          _soloud!.stop(handle);
        } catch (_) {}
      }
      handles.clear();
    }
    _disposeDeferredSource(id);

    // `notify` estaba declarado pero el cuerpo nunca lo usaba: ningún stop
    // manual (PANIC/ESC, botón de stop del pad, borrado) emitía onSoundFinished,
    // que es lo único que devuelve el pad a `idle`. Por eso quedaba encendido.
    // Los llamadores que pasan `notify: false` (preescucha del editor, retrigger
    // de oneShot) siguen en silencio a propósito.
    if (notify) {
      _notifyFinished(id);
    }
  }

  @override
  void setVolume(String id, double volume) {
    _padVolumes[id] = volume;
    _updateAllVolumes();
  }

  void _updateAllVolumes() {
    if (_soloud == null) return;
    for (var id in _activeHandles.keys) {
      var handles = _activeHandles[id];
      if (handles == null) continue;

      double targetVolume = (_padVolumes[id] ?? 1.0) * (_baseVolumes[id] ?? 1.0);
      if (_mutedPads.contains(id)) targetVolume = 0.0;
      if (_soloedPads.isNotEmpty && !_soloedPads.contains(id)) {
        targetVolume = 0.0;
      }

      for (var handle in handles) {
        try {
          _soloud!.setVolume(handle, targetVolume);
        } catch (_) {}
      }
    }
  }

  @override
  void setPadMute(String id, bool muted) {
    if (muted) {
      _mutedPads.add(id);
    } else {
      _mutedPads.remove(id);
    }
    _updateAllVolumes();
  }

  @override
  void setPadSolo(String id, bool soloed) {
    if (soloed) {
      _soloedPads.add(id);
    } else {
      _soloedPads.remove(id);
    }
    _updateAllVolumes();
  }

  @override
  void setPan(String id, double pan) {
    if (_soloud == null) return;
    var handles = _activeHandles[id];
    if (handles != null) {
      for (var handle in handles) {
        try {
          _soloud!.setPan(handle, pan);
        } catch (_) {}
      }
    }
  }

  @override
  void setPitch(String id, double pitch) {
    if (_soloud == null) return;
    var handles = _activeHandles[id];
    if (handles != null) {
      for (var handle in handles) {
        try {
          _soloud!.setRelativePlaySpeed(handle, pitch);
        } catch (_) {}
      }
    }
  }

  @override
  void setGlobalVolume(double volume) {
    if (_soloud == null) return;
    try {
      _soloud!.setGlobalVolume(volume);
    } catch (_) {}
  }

  @override
  void setMasterReverb(double amount) {
    if (_soloud == null) return;
    try {
      if (amount > 0) {
        if (!_soloud!.filters.freeverbFilter.isActive) {
          _soloud!.filters.freeverbFilter.activate();
        }
        _soloud!.filters.freeverbFilter.roomSize.value = amount;
        _soloud!.filters.freeverbFilter.wet.value = amount;
      } else {
        if (_soloud!.filters.freeverbFilter.isActive) {
          _soloud!.filters.freeverbFilter.deactivate();
        }
      }
    } catch (_) {}
  }

  @override
  void setMasterEQ({
    double lowGain = 0.0,
    double midGain = 0.0,
    double highGain = 0.0,
  }) {
    if (_soloud == null) return;
    try {
      if (lowGain > 0 || highGain > 0) {
        if (!_soloud!.filters.biquadResonantFilter.isActive) {
          _soloud!.filters.biquadResonantFilter.activate();
        }
        if (highGain > lowGain) {
          _soloud!.filters.biquadResonantFilter.type.value = 1.0;
          _soloud!.filters.biquadResonantFilter.frequency.value =
              1000 + (highGain * 4000);
        } else {
          _soloud!.filters.biquadResonantFilter.type.value = 0.0;
          _soloud!.filters.biquadResonantFilter.frequency.value =
              5000 - (lowGain * 4000);
        }
        _soloud!.filters.biquadResonantFilter.wet.value = 1.0;
      } else {
        if (_soloud!.filters.biquadResonantFilter.isActive) {
          _soloud!.filters.biquadResonantFilter.deactivate();
        }
      }
    } catch (_) {}
  }

  @override
  void setMasterDelay(double amount) {
    if (_soloud == null) return;
    try {
      if (amount > 0) {
        if (!_soloud!.filters.echoFilter.isActive) {
          _soloud!.filters.echoFilter.activate();
        }
        _soloud!.filters.echoFilter.delay.value = amount * 0.5;
        _soloud!.filters.echoFilter.decay.value = amount;
      } else {
        if (_soloud!.filters.echoFilter.isActive) {
          _soloud!.filters.echoFilter.deactivate();
        }
      }
    } catch (_) {}
  }

  @override
  void setMasterCompressor(double amount) {
    if (_soloud == null) return;
    try {
      if (amount > 0) {
        if (!_soloud!.filters.compressorFilter.isActive) {
          _soloud!.filters.compressorFilter.activate();
        }
      } else {
        if (_soloud!.filters.compressorFilter.isActive) {
          _soloud!.filters.compressorFilter.deactivate();
        }
      }
    } catch (_) {}
  }

  @override
  void setMasterLimiter(double amount) {
    if (_soloud == null) return;
    try {
      if (amount > 0) {
        if (!_soloud!.filters.limiterFilter.isActive) {
          _soloud!.filters.limiterFilter.activate();
        }
      } else {
        if (_soloud!.filters.limiterFilter.isActive) {
          _soloud!.filters.limiterFilter.deactivate();
        }
      }
    } catch (_) {}
  }

  @override
  void setMasterFlanger(double amount) {
    if (_soloud == null) return;
    try {
      if (amount > 0) {
        if (!_soloud!.filters.flangerFilter.isActive) {
          _soloud!.filters.flangerFilter.activate();
        }
        _soloud!.filters.flangerFilter.delay.value = amount * 0.05;
        _soloud!.filters.flangerFilter.freq.value = amount * 10;
      } else {
        if (_soloud!.filters.flangerFilter.isActive) {
          _soloud!.filters.flangerFilter.deactivate();
        }
      }
    } catch (_) {}
  }

  @override
  void setMasterDistortion(double amount) {
    if (_soloud == null) return;
    try {
      if (amount > 0) {
        if (!_soloud!.filters.lofiFilter.isActive) {
          _soloud!.filters.lofiFilter.activate();
        }
        _soloud!.filters.lofiFilter.bitdepth.value = 16.0 - (amount * 14.0);
        _soloud!.filters.lofiFilter.samplerate.value =
            44100.0 - (amount * 40000.0);
      } else {
        if (_soloud!.filters.lofiFilter.isActive) {
          _soloud!.filters.lofiFilter.deactivate();
        }
      }
    } catch (_) {}
  }

  @override
  int _visualizationRefs = 0;

  @visibleForTesting
  int get visualizationRefs => _visualizationRefs;

  @override
  void acquireVisualization() {
    _visualizationRefs++;
    if (_visualizationRefs == 1) {
      setVisualizationEnabled(true);
    }
  }

  @override
  void releaseVisualization() {
    if (_visualizationRefs > 0) {
      _visualizationRefs--;
      if (_visualizationRefs == 0) {
        setVisualizationEnabled(false);
      }
    }
  }

  @override
  void setVisualizationEnabled(bool enabled) {
    if (_audioDisabled || _soloud == null) return;
    try {
      _soloud!.setVisualizationEnabled(enabled);
    } catch (_) {}
  }

  AudioData? _audioData;

  @override
  Float32List? getAudioWave() {
    if (!_isInitialized || _audioDisabled || _soloud == null || _visualizationRefs == 0) {
      return null;
    }
    try {
      _audioData ??= AudioData(GetSamplesKind.wave);
      _audioData!.updateSamples();
      return _audioData!.getAudioData();
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> playSynthTone(Uint8List wavBytes) async {
    try {
      await _ensureInitialized();
      if (_audioDisabled || _soloud == null) return;
      var name = 'synth_tone_${DateTime.now().microsecondsSinceEpoch}';
      var source = await _soloud!.loadMem(name, wavBytes);
      var handle = _soloud!.play(source);
      Timer(const Duration(milliseconds: 600), () {
        if (_soloud != null && _soloud!.getIsValidVoiceHandle(handle)) {
          _soloud!.stop(handle);
        }
        if (_soloud != null) {
          _soloud!.disposeSource(source);
        }
      });
    } catch (e) {
      debugPrint('Error reproduciendo tono sintetizado: $e');
    }
  }

  @override
  void dispose() {
    _engineState = AudioEngineState.disposed;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _disposalTimer?.cancel();
    _disposalTimer = null;
    _pendingDisposals.clear();
    _loadingIds.clear();
    for (var timer in _fadeTimers.values) {
      timer.cancel();
    }
    _fadeTimers.clear();
    _activeHandles.clear();
    _chokeGroupHandles.clear();
    _audioData?.dispose();
    _audioData = null;
    _visualizationRefs = 0;
    _soundFinishedController.close();
    _loadedPaths.clear();
    _loadedModes.clear();
    _deferredDisposeSources.clear();
    _deferredBytes = 0;
    _mutedPads.clear();
    _soloedPads.clear();
    _padVolumes.clear();
    _initCompleter = null;
    if (!_isInitialized || _soloud == null) return;
    if (_cacheReady) {
      // Liberar las fuentes AHORA: `clear()` dispara onEvict, que encolaría una
      // disposición diferida con un Timer que correría 100 ms después de
      // `deinit()`, sobre un motor ya cerrado.
      _loadedSounds.clear();
      _drainPendingDisposals();
      _disposalTimer?.cancel();
      _disposalTimer = null;
      _cacheReady = false;
    }
    try {
      _soloud!.deinit();
    } catch (_) {}
  }
}
