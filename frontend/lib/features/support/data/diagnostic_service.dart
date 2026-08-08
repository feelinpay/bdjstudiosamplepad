import 'dart:io' show Platform;
import '../domain/diagnostic_report.dart';

/// Recolecta el estado del sistema para el reporte de diagnostico (Fase 14.2).
class DiagnosticService {
  const DiagnosticService._();

  // Configuracion fija del motor de audio (128 samples @ 48kHz = 2.67ms).
  static const int audioBufferSamples = 128;
  static const int sampleRate = 48000;
  static const double latencyMs = 2.67;
  static const String appVersion = '1.0.3';

  static Future<DiagnosticReport> gather({
    required int midiCount,
    required String licenseStatus,
  }) async {
    return DiagnosticReport(
      appVersion: appVersion,
      platform: Platform.operatingSystem,
      osVersion: _osVersion(),
      audioBufferSamples: audioBufferSamples,
      sampleRate: sampleRate,
      latencyMs: latencyMs,
      midiDevicesConnected: midiCount,
      licenseStatus: licenseStatus,
      generatedAt: DateTime.now(),
    );
  }

  /// Windows 11 sigue reportando "Windows 10" en su nombre de producto (Microsoft
  /// nunca lo actualizo). El indicador real es el build: >= 22000 es Windows 11.
  static String _osVersion() {
    var raw = Platform.operatingSystemVersion;
    if (Platform.isWindows) {
      final m = RegExp(r'Build (\d+)').firstMatch(raw);
      final build = m != null ? int.tryParse(m.group(1)!) : null;
      if (build != null && build >= 22000) {
        raw = raw.replaceAll('Windows 10', 'Windows 11');
      }
    }
    return raw;
  }
}
