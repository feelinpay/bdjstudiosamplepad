import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/core/audio/pad_trigger_resolver.dart';
import 'package:bdj_studio_sample_pad/core/audio/trigger_mode.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/domain/entities/pad_entity.dart';

import '../helpers/mock_audio_engine.dart';

/// Reproduce la decisión del notifier (onPadDown/onPadUp) contra el puerto,
/// sin depender de Riverpod/Isar. Verifica que el contrato del AudioEnginePort
/// recibe exactamente los parámetros del pad (choke group, protección, etc).
void _pressDown(MockAudioEngine engine, PadEntity pad) {
  var action = PadTriggerResolver.onDown(pad.playMode, pad.state);
  if (action == PadAction.stop) {
    engine.stop(pad.id);
  } else {
    engine.play(
      pad.id,
      pad.playMode,
      chokeGroup: pad.chokeGroup,
      pan: pad.pan,
      pitch: pad.pitch,
      isProtected: pad.isProtected,
      reverse: pad.reverse,
    );
  }
}

void _releaseUp(MockAudioEngine engine, PadEntity pad) {
  if (PadTriggerResolver.onUp(pad.playMode) == PadAction.stop) {
    engine.stop(pad.id);
  }
}

void main() {
  late MockAudioEngine engine;

  setUp(() => engine = MockAudioEngine());
  tearDown(() => engine.dispose());

  group('AudioEnginePort - contrato básico', () {
    test('initialize marca el motor como inicializado', () async {
      await engine.initialize();
      expect(engine.initialized, isTrue);
    });

    test('onSoundFinished emite el id del pad terminado', () async {
      var ids = <String>[];
      var sub = engine.onSoundFinished.listen(ids.add);
      engine.emitSoundFinished('pad_0');
      await Future<void>.delayed(Duration.zero);
      expect(ids, contains('pad_0'));
      await sub.cancel();
    });

    test('stop(notify: true) emite onSoundFinished y notify: false no (2.1)', () async {
      var ids = <String>[];
      var sub = engine.onSoundFinished.listen(ids.add);

      // Preescucha / retrigger de oneShot: silencioso a propósito.
      engine.stop('pad_a', notify: false);
      await Future<void>.delayed(Duration.zero);
      expect(ids, isNot(contains('pad_a')));

      // ESC / pánico: notificado para que el pad vuelva a `idle`.
      engine.stop('pad_b', notify: true);
      await Future<void>.delayed(Duration.zero);
      expect(ids, contains('pad_b'));

      await sub.cancel();
    });
  });

  group('Dispatch de trigger modes hacia el puerto', () {
    test('One Shot dispara play una sola vez y no para al soltar', () {
      var pad = PadEntity.empty(
        0,
      ).copyWith(sampleId: 'kick.wav', playMode: TriggerMode.oneShot);
      _pressDown(engine, pad);
      _releaseUp(engine, pad);
      expect(engine.playCalls, hasLength(1));
      expect(engine.stopCalls, isEmpty);
    });

    test('Gate para al soltar', () {
      var pad = PadEntity.empty(1).copyWith(playMode: TriggerMode.gate);
      _pressDown(engine, pad);
      _releaseUp(engine, pad);
      expect(engine.playCalls, hasLength(1));
      expect(engine.stopCalls, contains(pad.id));
    });

    test('Toggle: segundo down detiene', () {
      var pad = PadEntity.empty(2).copyWith(playMode: TriggerMode.toggle);
      _pressDown(engine, pad); // arranca
      pad = pad.copyWith(state: PadState.playing);
      _pressDown(engine, pad); // detiene
      expect(engine.playCalls, hasLength(1));
      expect(engine.stopCalls, contains(pad.id));
    });
  });

  group('Choke groups y voz protegida', () {
    test('el choke group del pad se propaga al motor', () {
      var pad = PadEntity.empty(
        3,
      ).copyWith(sampleId: 'openhat.wav', chokeGroup: 1);
      _pressDown(engine, pad);
      expect(engine.playCalls.single.chokeGroup, 1);
    });

    test('dos pads del mismo choke group comparten grupo (corte mutuo)', () {
      var closed = PadEntity.empty(4).copyWith(chokeGroup: 1);
      var open = PadEntity.empty(5).copyWith(chokeGroup: 1);
      _pressDown(engine, closed);
      _pressDown(engine, open);
      expect(engine.playCalls.map((c) => c.chokeGroup), everyElement(1));
    });

    test('pad protegido (ej. Airhorn) viaja con isProtected=true', () {
      var airhorn = PadEntity.empty(
        6,
      ).copyWith(sampleId: 'airhorn.wav', isProtected: true);
      _pressDown(engine, airhorn);
      expect(engine.playCalls.single.isProtected, isTrue);
    });

    test('pan y pitch personalizados se transmiten intactos', () {
      var pad = PadEntity.empty(7).copyWith(pan: -0.5, pitch: 1.5);
      _pressDown(engine, pad);
      expect(engine.playCalls.single.pan, -0.5);
      expect(engine.playCalls.single.pitch, 1.5);
    });
  });
}
