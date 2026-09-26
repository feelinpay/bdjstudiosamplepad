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

  /// Normaliza el nombre del dispositivo para mitigar variaciones como el prefijo
  /// de número de puerto USB que Windows antepone, p. ej. "Línea (2- DDJ-FLX4)" vs "Línea (3- DDJ-FLX4)".
  static String normalizeName(String raw) {
    return raw
        .replaceAll(RegExp(r'\(\d+-\s*'), '(')
        .replaceAll(RegExp(r'^\d+-\s*'), '')
        .replaceAll(RegExp(r'[()]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  /// Busca un dispositivo coincidiendo primero por nombre exacto,
  /// o secundariamente por nombre normalizado (ignorando variaciones de puerto USB de Windows).
  static T? findByName<T>(
    Iterable<T> devices,
    String? targetName,
    String Function(T) nameExtractor, {
    void Function(String message)? onLog,
  }) {
    if (targetName == null || targetName.isEmpty) return null;

    // 1. Coincidencia exacta
    final exactMatches = <T>[];
    for (final dev in devices) {
      if (nameExtractor(dev) == targetName) {
        exactMatches.add(dev);
      }
    }
    if (exactMatches.isNotEmpty) {
      final chosen = exactMatches.first;
      if (exactMatches.length > 1) {
        onLog?.call(
          '[AudioEngine] Múltiples dispositivos coinciden exactamente con "$targetName" '
          '(${exactMatches.length} encontrados). Se eligió el primero: "${nameExtractor(chosen)}"',
        );
      }
      return chosen;
    }

    // 2. Coincidencia normalizada
    final targetNorm = normalizeName(targetName);
    if (targetNorm.isEmpty) return null;

    final candidates = <T>[];
    for (final dev in devices) {
      if (normalizeName(nameExtractor(dev)) == targetNorm) {
        candidates.add(dev);
      }
    }

    if (candidates.isNotEmpty) {
      final chosen = candidates.first;
      if (candidates.length > 1) {
        onLog?.call(
          '[AudioEngine] Múltiples dispositivos coinciden por nombre normalizado con "$targetName" '
          '(${candidates.length} encontrados). Se eligió el primero: "${nameExtractor(chosen)}"',
        );
      } else {
        onLog?.call(
          '[AudioEngine] Dispositivo "$targetName" encontrado por nombre normalizado: "${nameExtractor(chosen)}"',
        );
      }
      return chosen;
    }

    return null;
  }
}
