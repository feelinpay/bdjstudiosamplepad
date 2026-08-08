import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/features/metronome/domain/tap_tempo.dart';

void main() {
  group('TapTempo', () {
    test('un solo golpe no da BPM', () {
      var t = TapTempo();
      expect(t.tap(DateTime(2026, 1, 1, 0, 0, 0)), isNull);
    });

    test('golpes cada 500ms => 120 BPM', () {
      var t = TapTempo();
      var base = DateTime(2026, 1, 1, 0, 0, 0);
      t.tap(base);
      t.tap(base.add(const Duration(milliseconds: 500)));
      var bpm = t.tap(base.add(const Duration(milliseconds: 1000)));
      expect(bpm, 120);
    });

    test('golpes cada 1000ms => 60 BPM', () {
      var t = TapTempo();
      var base = DateTime(2026, 1, 1);
      t.tap(base);
      var bpm = t.tap(base.add(const Duration(seconds: 1)));
      expect(bpm, 60);
    });

    test('una pausa larga reinicia la medicion', () {
      var t = TapTempo();
      var base = DateTime(2026, 1, 1);
      t.tap(base);
      t.tap(base.add(const Duration(milliseconds: 500)));
      // gap > 2s reinicia
      expect(t.tap(base.add(const Duration(seconds: 5))), isNull);
    });

    test('BPM se acota al rango valido', () {
      var t = TapTempo();
      var base = DateTime(2026, 1, 1);
      t.tap(base);
      var bpm = t.tap(
        base.add(const Duration(milliseconds: 10)),
      ); // 6000bpm -> clamp
      expect(bpm, TapTempo.maxBpm);
    });
  });
}
