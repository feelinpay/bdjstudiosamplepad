import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/core/audio/trigger_mode.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/domain/entities/pad_entity.dart';

void main() {
  group('PadEntity - valores por defecto', () {
    test('empty() genera un pad idle, oneShot y con label legible', () {
      var pad = PadEntity.empty(0);
      expect(pad.id, 'pad_0');
      expect(pad.index, 0);
      expect(pad.label, 'PAD 1');
      expect(pad.state, PadState.idle);
      expect(pad.playMode, TriggerMode.oneShot);
      expect(pad.pitch, 1.0);
      expect(pad.sampleId, isNull);
      expect(pad.chokeGroup, 0);
      expect(pad.isProtected, isFalse);
    });

    test('el índice se refleja en el label (index+1)', () {
      expect(PadEntity.empty(15).label, 'PAD 16');
    });
  });

  group('PadEntity - copyWith', () {
    test('copia con overrides puntuales sin afectar el resto', () {
      var base = PadEntity.empty(3);
      var updated = base.copyWith(
        state: PadState.playing,
        pitch: 0.5,
        chokeGroup: 2,
      );

      expect(updated.state, PadState.playing);
      expect(updated.pitch, 0.5);
      expect(updated.chokeGroup, 2);
      // Campos no tocados se conservan.
      expect(updated.id, base.id);
      expect(updated.index, base.index);
      expect(updated.label, base.label);
      expect(updated.playMode, base.playMode);
    });

    test('copyWith sin argumentos es igual al original', () {
      var base = PadEntity.empty(1).copyWith(sampleId: 'kick.wav');
      expect(base.copyWith(), equals(base));
    });
  });

  group('PadEntity - igualdad', () {
    test('dos pads con los mismos campos son iguales y comparten hashCode', () {
      var a = PadEntity.empty(2).copyWith(sampleId: 'clap.wav', pitch: 1.2);
      var b = PadEntity.empty(2).copyWith(sampleId: 'clap.wav', pitch: 1.2);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('un cambio de estado rompe la igualdad', () {
      var a = PadEntity.empty(2);
      var b = a.copyWith(state: PadState.playing);
      expect(a == b, isFalse);
    });
  });
}
