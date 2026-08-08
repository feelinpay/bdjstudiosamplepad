import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/features/support/domain/diagnostic_report.dart';

void main() {
  test('DiagnosticReport.toText incluye todas las secciones', () {
    var r = DiagnosticReport(
      appVersion: '1.0.0',
      platform: 'android',
      osVersion: 'Android 14',
      audioBufferSamples: 128,
      sampleRate: 48000,
      latencyMs: 2.67,
      midiDevicesConnected: 1,
      licenseStatus: 'Licencia activa',
      generatedAt: DateTime.parse('2026-07-21T10:00:00.000'),
    );
    var text = r.toText();
    expect(text, contains('[Sistema]'));
    expect(text, contains('[Audio]'));
    expect(text, contains('[MIDI]'));
    expect(text, contains('[Licencia]'));
    expect(text, contains('128 samples @ 48000Hz'));
    expect(text, contains('Estado: Licencia activa'));
  });
}
