import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/core/audio/synth_tone.dart';

void main() {
  group('SynthTone.sineWav', () {
    test('genera un WAV con cabecera RIFF/WAVE válida', () {
      var bytes = SynthTone.sineWav(frequency: 440, durationMs: 100);
      var ascii = String.fromCharCodes(bytes.sublist(0, 4));
      expect(ascii, 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');
      expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
    });

    test('el tamaño coincide con 44 (cabecera) + PCM 16-bit mono', () {
      const sr = 44100;
      const ms = 100;
      var bytes = SynthTone.sineWav(
        frequency: 440,
        durationMs: ms,
        sampleRate: sr,
      );
      var expectedSamples = (sr * ms / 1000).round();
      expect(bytes.length, 44 + expectedSamples * 2);
    });

    test('declara PCM mono 16-bit en el chunk fmt', () {
      var b = SynthTone.sineWav(frequency: 440, durationMs: 50);
      var bd = ByteData.sublistView(Uint8List.fromList(b));
      expect(bd.getUint16(20, Endian.little), 1); // audioFormat = PCM
      expect(bd.getUint16(22, Endian.little), 1); // canales = 1
      expect(bd.getUint16(34, Endian.little), 16); // bits por sample
    });

    test('frequencyForPad envuelve la escala pentatónica', () {
      expect(SynthTone.frequencyForPad(0), SynthTone.pentatonic[0]);
      expect(
        SynthTone.frequencyForPad(SynthTone.pentatonic.length),
        SynthTone.pentatonic[0],
      );
    });

    test('no genera bytes vacíos para duraciones normales', () {
      var b = SynthTone.sineWav(frequency: 330, durationMs: 220);
      expect(b.length, greaterThan(44));
    });
  });
}
