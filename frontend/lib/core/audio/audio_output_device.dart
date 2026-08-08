/// Dispositivo de salida expuesto al usuario sin acoplar la UI a SoLoud.
class AudioOutputDevice {
  const AudioOutputDevice({
    required this.id,
    required this.name,
    required this.isDefault,
  });

  final int id;
  final String name;
  final bool isDefault;
}
