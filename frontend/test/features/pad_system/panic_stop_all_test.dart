import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/features/midi/presentation/providers/midi_providers.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/domain/entities/pad_entity.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/presentation/providers/pad_providers.dart';

import '../../helpers/mock_audio_engine.dart';
import '../../helpers/mock_midi.dart';
import '../../helpers/pad_test_harness.dart';

/// Regresión para 2.1 (tu reporte): presionar ESC / botón PANIC mientras un pad
/// está sonando debe apagarlo en la UI. `stopAll()` ya emite `onSoundFinished`
/// por cada id activo (contrato cubierto en audio_engine_port_test); aquí se
/// prueba que `forceStopAll()` del notifier apaga los pads, limpia el feedback
/// MIDI y la brillantez por velocity.
void main() {
  const pad = PadEntity(
    id: 'pad_0',
    index: 0,
    label: 'Kick',
    sampleId: 'kick.wav',
  );

  FakeMidiController buildMidi(ProviderContainer container) =>
      container.read(midiControllerProvider) as FakeMidiController;

  test('PANIC: pad en playing vuelve a idle, apaga el MIDI y limpia el velocity',
      () async {
    final engine = MockAudioEngine();
    final container = buildPadContainer(engine: engine, pads: [pad]);
    final notifier = container.read(padPageProvider(0).notifier);
    await container.read(padPageProvider(0).future);

    // Un golpe normal: el pad se enciende.
    await notifier.onPadDown('pad_0');
    expect(container.read(padPageProvider(0)).value!.single.state,
        PadState.playing);

    // Golpe con velocity y feedback MIDI activos.
    container.read(padVelocityProvider.notifier).state = {'pad_0': 0.8};
    final midi = buildMidi(container);
    midi.feedbackCalls.clear();

    // PANIC / ESC.
    await notifier.forceStopAll();

    expect(engine.stopAllCalled, isTrue);
    expect(container.read(padPageProvider(0)).value!.single.state,
        PadState.idle);
    expect(container.read(padVelocityProvider), isEmpty);
    expect(
      midi.feedbackCalls.any((call) => call.$1 == 'pad_0' && !call.$2),
      isTrue,
    );
  });

  test('PANIC con varios pads: todos vuelven a idle y reciben MIDI off',
      () async {
    final engine = MockAudioEngine();
    final container = buildPadContainer(engine: engine, pads: [
      pad,
      const PadEntity(
        id: 'pad_1',
        index: 1,
        label: 'Snare',
        sampleId: 'snare.wav',
      ),
    ]);
    final notifier = container.read(padPageProvider(0).notifier);
    await container.read(padPageProvider(0).future);

    // Dos pads sonando a la vez.
    await notifier.onPadDown('pad_0');
    await notifier.onPadDown('pad_1');
    expect(container.read(padPageProvider(0)).value!.where(
          (p) => p.state == PadState.playing,
        ).length,
        2);

    final midi = buildMidi(container);
    midi.feedbackCalls.clear();

    await notifier.forceStopAll();

    final after = container.read(padPageProvider(0)).value!;
    expect(after.where((p) => p.state == PadState.playing), isEmpty);
    expect(
      midi.feedbackCalls
          .where((call) => !call.$2)
          .map((call) => call.$1)
          .toSet(),
      {'pad_0', 'pad_1'},
    );
  });

  test('ESC sin nada sonando no lanza ni toca el velocity', () async {
    final engine = MockAudioEngine();
    final container = buildPadContainer(engine: engine, pads: [pad]);
    final notifier = container.read(padPageProvider(0).notifier);
    await container.read(padPageProvider(0).future);

    container.read(padVelocityProvider.notifier).state = {'pad_0': 0.5};

    await notifier.forceStopAll();

    expect(engine.stopAllCalled, isTrue);
    expect(container.read(padPageProvider(0)).value!.single.state,
        PadState.idle);
    // Ningún pad estaba encendido: el velocity no se toca.
    expect(container.read(padVelocityProvider), {'pad_0': 0.5});
  });
}
