import 'dart:async';
import 'dart:typed_data';

import 'package:bdj_studio_sample_pad/core/audio/audio_engine_port.dart';
import 'package:bdj_studio_sample_pad/core/audio/audio_engine_state.dart';
import 'package:bdj_studio_sample_pad/core/audio/audio_output_device.dart';
import 'package:bdj_studio_sample_pad/core/audio/audio_initialization_result.dart';
import 'package:bdj_studio_sample_pad/core/audio/trigger_mode.dart';

/// Registro de una invocación a [play] para poder hacer aserciones en tests.
class PlayCall {
  final String id;
  final TriggerMode mode;
  final int chokeGroup;
  final double pan;
  final double pitch;
  final bool isProtected;
  final bool reverse;

  PlayCall({
    required this.id,
    required this.mode,
    required this.chokeGroup,
    required this.pan,
    required this.pitch,
    required this.isProtected,
    required this.reverse,
  });
}

/// Implementación falsa de [AudioEnginePort] que no toca audio nativo.
/// Registra todas las interacciones para verificar el contrato del puerto
/// y la lógica que lo consume (Fase 11.1 - Tests de Audio Engine port).
class MockAudioEngine implements AudioEnginePort {
  final List<PlayCall> playCalls = [];
  final List<String> stopCalls = [];
  final Map<String, double> volumes = {};
  bool initialized = false;
  bool disposed = false;
  double globalVolume = 1.0;
  AudioEngineState mockState = AudioEngineState.uninitialized;

  /// Dispositivos simulados para devolver por [listOutputDevices].
  List<AudioOutputDevice> mockDevices = const [
    AudioOutputDevice(id: -1, name: 'Default', isDefault: true),
  ];

  /// Si true, [initializeAndRestoreDevice] devolverá noDevice.
  bool simulateNoDevices = false;

  /// Si true, [selectOutputDevice] lanzará una excepción genérica.
  bool simulateSelectionError = false;

  /// Simula el audio ausente (2.2): `play` no encuentra la fuente y emite
  /// `onSoundFinished` para que el pad no se quede encendido.
  bool simulateMissingSource = false;

  /// Ids que están sonando (play sin stop). Lo usa [stopAll] para notificar
  /// como el motor real: cada id activo vuelve a `idle` vía onSoundFinished.
  final Set<String> _activeIds = {};

  /// Último [savedDeviceId] recibido por [initializeAndRestoreDevice].
  int? lastSavedDeviceId;

  /// Último deviceId aplicado por [selectOutputDevice] o [initializeAndRestoreDevice].
  int? mockCurrentDeviceId;

  /// Si la última restauración usó fallback al predeterminado.
  bool lastSavedDeviceFallback = false;

  final StreamController<String> _finishedController =
      StreamController<String>.broadcast();

  /// Simula que un sample terminó (para probar el retorno a idle).
  void emitSoundFinished(String id) => _finishedController.add(id);

  @override
  Future<void> initialize() async {
    initialized = true;
    mockState = AudioEngineState.ready;
  }

  @override
  Future<AudioInitializationResult> initializeAndRestoreDevice(
    int? savedDeviceId,
  ) async {
     lastSavedDeviceId = savedDeviceId;
    if (simulateNoDevices) {
      mockState = AudioEngineState.noDevice;
      return const AudioInitializationResult.noDevice(
        userMessage: 'No se encontró una salida de audio disponible.',
      );
    }
    initialized = true;
    mockState = AudioEngineState.ready;
    lastSavedDeviceFallback = false;
    int resolvedDeviceId = mockDevices.firstWhere((d) => d.isDefault).id;
    if (savedDeviceId != null && savedDeviceId != -1) {
      final found = mockDevices.any((d) => d.id == savedDeviceId);
      if (!found) {
        lastSavedDeviceFallback = true;
      } else {
        resolvedDeviceId = savedDeviceId;
      }
    }
    mockCurrentDeviceId = resolvedDeviceId;
    return AudioInitializationResult(
      state: mockState,
      devices: mockDevices,
      appliedDeviceId: resolvedDeviceId,
      savedDeviceInvalid: lastSavedDeviceFallback,
    );
  }

  @override
  Future<AudioInitializationResult> retryAudioInitialization(
    int? savedDeviceId,
  ) async {
    initialized = false;
    if (simulateSelectionError) {
      mockState = AudioEngineState.error;
      return AudioInitializationResult.error(
        userMessage: 'No se pudo cambiar la salida de audio.',
      );
    }
    return initializeAndRestoreDevice(savedDeviceId);
  }

  @override
  Future<List<AudioOutputDevice>> refreshPlaybackDevices() async {
    return mockDevices;
  }

  @override
  Future<List<AudioOutputDevice>> listOutputDevices() async {
    if (disposed) return const [];
    return mockDevices;
  }

  @override
  Future<void> selectOutputDevice(int? deviceId) async {
    if (simulateNoDevices) {
      mockState = AudioEngineState.noDevice;
      return;
    }
    if (simulateSelectionError) {
      throw StateError('Simulated device selection error');
    }
    if (mockDevices.isEmpty) {
      mockState = AudioEngineState.noDevice;
      return;
    }
       final target = deviceId == null || deviceId == -1
           ? mockDevices.firstWhere((d) => d.isDefault)
           : mockDevices.firstWhere((d) => d.id == deviceId, orElse: () => mockDevices.firstWhere((d) => d.isDefault));
     mockCurrentDeviceId = target.id;
     mockState = AudioEngineState.ready;
  }

  @override
  AudioEngineState get engineState => mockState;

  @override
  void setSoundCacheCapacity(int capacity) {}

  @override
  bool isLoaded(String id) => true;

  @override
  Future<void> loadAudio(String id, String assetPath) async {}

  @override
  Future<void> preloadAll(Map<String, String> idToPath) async {}

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
    if (simulateMissingSource) {
      // Igual que el motor real: sin fuente, emite finish para no encender el pad.
      emitSoundFinished(id);
      return;
    }
    _activeIds.add(id);
    playCalls.add(
      PlayCall(
        id: id,
        mode: mode,
        chokeGroup: chokeGroup,
        pan: pan,
        pitch: pitch,
        isProtected: isProtected,
        reverse: reverse,
      ),
    );
  }

  @override
  void stop(String id, {bool notify = true}) {
    stopCalls.add(id);
    _activeIds.remove(id);
    // Igual que el motor real: un stop notificado devuelve el pad a `idle`.
    if (notify && !_finishedController.isClosed) {
      _finishedController.add(id);
    }
  }

  bool stopAllCalled = false;
  @override
  void stopAll() {
    stopAllCalled = true;
    // Igual que el motor real (PANIC/ESC): cada id sonando se notifica para
    // que su notifier vuelva a `idle` y apague el feedback MIDI.
    for (var id in _activeIds.toList()) {
      _activeIds.remove(id);
      if (!_finishedController.isClosed) {
        _finishedController.add(id);
      }
    }
  }

  /// Simulación de posición de reproducción para tests de waveform editor.
  Duration? mockPosition;
  final Map<String, Duration> positions = {};

  void setPosition(String id, Duration position) => positions[id] = position;
  void clearPosition(String id) => positions.remove(id);
  void clearAllPositions() => positions.clear();

  @override
  Duration? getPosition(String id) => positions[id] ?? mockPosition;

  final List<int> synthToneByteLengths = [];
  @override
  Future<void> playSynthTone(Uint8List wavBytes) async {
    synthToneByteLengths.add(wavBytes.length);
  }

  @override
  void setVolume(String id, double volume) => volumes[id] = volume;

  @override
  void setPan(String id, double pan) {}

  @override
  void setPitch(String id, double pitch) {}

  @override
  void setPadMute(String id, bool muted) {}

  @override
  void setPadSolo(String id, bool soloed) {}

  @override
  void setGlobalVolume(double volume) => globalVolume = volume;

  @override
  void setMasterReverb(double amount) {}

  @override
  void setMasterEQ({
    double lowGain = 0.0,
    double midGain = 0.0,
    double highGain = 0.0,
  }) {}

  @override
  void setMasterDelay(double amount) {}

  @override
  void setMasterCompressor(double amount) {}

  @override
  void setMasterLimiter(double amount) {}

  @override
  void setMasterFlanger(double amount) {}

  @override
  void setMasterDistortion(double amount) {}

  @override
  Float32List? getAudioWave() => null;

  @override
  void dispose() {
    disposed = true;
    mockState = AudioEngineState.uninitialized;
    initialized = false;
    _finishedController.close();
  }

  @override
  Stream<String> get onSoundFinished => _finishedController.stream;
}
