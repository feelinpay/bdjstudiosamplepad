/// Resultado de un cambio de dispositivo de salida de audio.
/// Permite a la UI diferenciar entre éxito, fallo recuperable y
/// estado sin dispositivo, sin exponer excepciones C++ al usuario.
class AudioChangeResult {
  final String userMessage;
  final bool isRecoverable;
  final bool isNoDevice;

  const AudioChangeResult({
    this.userMessage = '',
    this.isRecoverable = false,
    this.isNoDevice = false,
  });

  const AudioChangeResult.success(String message)
      : userMessage = message,
        isRecoverable = true,
        isNoDevice = false;

  const AudioChangeResult.failure(String message)
      : userMessage = message,
        isRecoverable = true,
        isNoDevice = false;

  const AudioChangeResult.noDevice(String message)
      : userMessage = message,
        isRecoverable = true,
        isNoDevice = true;
}
