import 'audio_engine_state.dart';
import 'audio_output_device.dart';

/// Resultado de la inicialización y restauración del dispositivo de audio.
/// Permite a la UI reaccionar según el estado del motor sin exponer
/// excepciones C++ al usuario.
class AudioInitializationResult {
  final AudioEngineState state;
  final List<AudioOutputDevice> devices;
  final int? appliedDeviceId;
  final bool savedDeviceInvalid;
  final String? userMessage;

  const AudioInitializationResult({
    required this.state,
    required this.devices,
    this.appliedDeviceId,
    this.savedDeviceInvalid = false,
    this.userMessage,
  });

  const AudioInitializationResult.ready({
    required List<AudioOutputDevice> devices,
    int? appliedDeviceId,
    bool savedDeviceInvalid = false,
    String? userMessage,
  }) : this(
          state: AudioEngineState.ready,
          devices: devices,
          appliedDeviceId: appliedDeviceId,
          savedDeviceInvalid: savedDeviceInvalid,
          userMessage: userMessage,
        );

  const AudioInitializationResult.noDevice({
    String? userMessage,
  }) : this(
          state: AudioEngineState.noDevice,
          devices: const [],
          userMessage: userMessage,
        );

  const AudioInitializationResult.error({
    String? userMessage,
  }) : this(
          state: AudioEngineState.error,
          devices: const [],
          userMessage: userMessage,
        );
}
