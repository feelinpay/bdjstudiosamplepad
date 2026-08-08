import 'dart:typed_data';
import 'trigger_mode.dart';
import 'audio_output_device.dart';
import 'audio_engine_state.dart';
import 'audio_initialization_result.dart';

abstract class AudioEnginePort {
  /// Inicializa el motor de audio y restaura el dispositivo guardado.
  ///
  /// Este método es seguro de llamar múltiples veces (idempotente para
  /// la inicialización) y permite reintentos controlados después de
  /// un fallo.
  ///
  /// - [savedDeviceId]: ID del dispositivo guardado en preferencias.
  ///   Puede ser `null` (predeterminada del sistema).
  ///
  /// Devuelve un [AudioInitializationResult] con el estado del motor,
  /// la lista de dispositivos disponibles y información sobre si el
  /// dispositivo guardado fue reemplazado.
  Future<AudioInitializationResult> initializeAndRestoreDevice(
    int? savedDeviceId,
  );

  /// Reintenta la inicialización del motor de audio después de un fallo.
  /// Es seguro de llamar incluso si el motor ya está listo.
  Future<AudioInitializationResult> retryAudioInitialization(int? savedDeviceId);

  /// Fuerza un nuevo escaneo de dispositivos de salida sin reiniciar el motor.
  /// Útil para detectar dispositivos conectados/desconectados en caliente.
  Future<List<AudioOutputDevice>> refreshPlaybackDevices();

  Future<void> initialize();
  Future<List<AudioOutputDevice>> listOutputDevices();
  Future<void> selectOutputDevice(int? deviceId);

  /// Estado actual del motor de audio para que la UI reaccione
  /// sin depender de un único bool isLoading.
  AudioEngineState get engineState;

  void setSoundCacheCapacity(int capacity);
  bool isLoaded(String id);
  Future<void> loadAudio(String id, String assetPath);
  Future<void> preloadAll(Map<String, String> idToPath);
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
  });
  void stop(String id, {bool notify = true});

  /// Detiene TODAS las voces activas (boton STOP-ALL en vivo).
  void stopAll();

  /// Devuelve la posición actual de reproducción del sonido con el id dado,
  /// o null si no está activo. Usado por la preescucha del waveform editor
  /// para que el puntero visual siga la posición REAL del motor de audio.
  Duration? getPosition(String id);

  /// Reproduce un tono sintetizado (WAV en memoria) sin usar samples.
  /// Usado por el onboarding (Fase 12).
  Future<void> playSynthTone(Uint8List wavBytes);

  // Controles por pad
  void setVolume(String id, double volume);
  void setPan(String id, double pan);
  void setPitch(String id, double pitch);
  void setPadMute(String id, bool muted);
  void setPadSolo(String id, bool soloed);

  // Controles Globales
  void setGlobalVolume(double volume);
  void setMasterReverb(double amount);
  void setMasterEQ({
    double lowGain = 0.0,
    double midGain = 0.0,
    double highGain = 0.0,
  });
  void setMasterDelay(double amount);
  void setMasterCompressor(double amount);
  void setMasterLimiter(double amount);
  void setMasterFlanger(double amount);
  void setMasterDistortion(double amount);

  Float32List? getAudioWave();
  void dispose();

  Stream<String> get onSoundFinished;
}
