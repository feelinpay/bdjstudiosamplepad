/// Reporte de diagnostico del sistema (Fase 14.2). Entidad pura + export a texto.
class DiagnosticReport {
  // Sistema
  final String appVersion;
  final String platform;
  final String osVersion;

  // Audio
  final int audioBufferSamples;
  final int sampleRate;
  final double latencyMs;

  // MIDI
  final int midiDevicesConnected;

  // Licencia
  final String licenseStatus;

  // Rendimiento y Hardware
  final String performanceProfile;
  final String hardwareSignals;

  final DateTime generatedAt;

  const DiagnosticReport({
    required this.appVersion,
    required this.platform,
    required this.osVersion,
    required this.audioBufferSamples,
    required this.sampleRate,
    required this.latencyMs,
    required this.midiDevicesConnected,
    required this.licenseStatus,
    required this.performanceProfile,
    required this.hardwareSignals,
    required this.generatedAt,
  });

  /// Reporte legible/compartible con soporte.
  String toText() {
    var b = StringBuffer();
    b.writeln('=== BDJ Studio Sample Pad - Reporte de diagnostico ===');
    b.writeln('Generado: ${generatedAt.toIso8601String()}');
    b.writeln('');
    b.writeln('[Sistema]');
    b.writeln('Version app: $appVersion');
    b.writeln('Plataforma: $platform');
    b.writeln('OS: $osVersion');
    b.writeln('');
    b.writeln('[Audio]');
    b.writeln('Buffer: $audioBufferSamples samples @ ${sampleRate}Hz');
    b.writeln('Latencia estimada: ${latencyMs.toStringAsFixed(2)} ms');
    b.writeln('');
    b.writeln('[MIDI]');
    b.writeln('Dispositivos conectados: $midiDevicesConnected');
    b.writeln('');
    b.writeln('[Licencia]');
    b.writeln('Estado: $licenseStatus');
    b.writeln('');
    b.writeln('[Rendimiento y Hardware]');
    b.writeln('Perfil: $performanceProfile');
    b.writeln('Señales: $hardwareSignals');
    return b.toString();
  }
}
