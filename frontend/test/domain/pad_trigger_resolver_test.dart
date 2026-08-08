import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/core/audio/pad_trigger_resolver.dart';
import 'package:bdj_studio_sample_pad/core/audio/trigger_mode.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/domain/entities/pad_entity.dart';

void main() {
  // Máquina de estados del Pad Engine (Fase 11.1).
  group('PadTriggerResolver.onDown', () {
    test('One Shot en idle -> play', () {
      expect(
        PadTriggerResolver.onDown(TriggerMode.oneShot, PadState.idle),
        PadAction.play,
      );
    });

    test('Loop en idle -> play', () {
      expect(
        PadTriggerResolver.onDown(TriggerMode.loop, PadState.idle),
        PadAction.play,
      );
    });

    test('Gate en idle -> play', () {
      expect(
        PadTriggerResolver.onDown(TriggerMode.gate, PadState.idle),
        PadAction.play,
      );
    });

    test('Toggle en idle -> play (primer toque)', () {
      expect(
        PadTriggerResolver.onDown(TriggerMode.toggle, PadState.idle),
        PadAction.play,
      );
    });

    test('Loop en playing -> stop (segundo toque, spec de audio)', () {
      expect(
        PadTriggerResolver.onDown(TriggerMode.loop, PadState.playing),
        PadAction.stop,
      );
    });

    test('Toggle en playing -> stop (segundo toque)', () {
      expect(
        PadTriggerResolver.onDown(TriggerMode.toggle, PadState.playing),
        PadAction.stop,
      );
    });

    test('One Shot en playing -> play (re-trigger, no toggle)', () {
      expect(
        PadTriggerResolver.onDown(TriggerMode.oneShot, PadState.playing),
        PadAction.play,
      );
    });
  });

  group('PadTriggerResolver.onUp', () {
    test('Gate al soltar -> stop', () {
      expect(PadTriggerResolver.onUp(TriggerMode.gate), PadAction.stop);
    });

    test('Hold al soltar -> stop', () {
      expect(PadTriggerResolver.onUp(TriggerMode.hold), PadAction.stop);
    });

    test('One Shot al soltar -> none (sigue sonando)', () {
      expect(PadTriggerResolver.onUp(TriggerMode.oneShot), PadAction.none);
    });

    test('Loop al soltar -> none', () {
      expect(PadTriggerResolver.onUp(TriggerMode.loop), PadAction.none);
    });

    test('Toggle al soltar -> none', () {
      expect(PadTriggerResolver.onUp(TriggerMode.toggle), PadAction.none);
    });
  });

  group('PadTriggerResolver.resolveState', () {
    test('play -> playing', () {
      expect(
        PadTriggerResolver.resolveState(PadAction.play, PadState.idle),
        PadState.playing,
      );
    });

    test('stop -> idle', () {
      expect(
        PadTriggerResolver.resolveState(PadAction.stop, PadState.playing),
        PadState.idle,
      );
    });

    test('none -> conserva el estado previo', () {
      expect(
        PadTriggerResolver.resolveState(PadAction.none, PadState.playing),
        PadState.playing,
      );
    });
  });
}
