import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/domain/entities/pad_entity.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/presentation/providers/pad_providers.dart';

import '../../helpers/mock_audio_engine.dart';
import '../../helpers/pad_test_harness.dart';

/// Regresión para 2.2: un pad cuyo sample no existe (o nunca se asignó) no debe
/// quedarse encendido después de golpearlo. `play()` sin fuente emite
/// `onSoundFinished` (igual que los caminos de error) y `onPadDown` ni siquiera
/// toca el motor cuando el pad está vacío.
void main() {
  const emptyPad = PadEntity(id: 'pad_empty', index: 0, label: 'Empty');
  const missingPad = PadEntity(
    id: 'pad_missing',
    index: 0,
    label: 'Missing',
    sampleId: 'gone.wav',
  );

  test('pad sin sample: onPadDown no lo enciende ni toca el motor', () async {
    final engine = MockAudioEngine();
    final container = buildPadContainer(engine: engine, pads: [emptyPad]);
    final notifier = container.read(padPageProvider(0).notifier);
    await container.read(padPageProvider(0).future);

    await notifier.onPadDown('pad_empty');

    expect(container.read(padPageProvider(0)).value!.single.state,
        PadState.idle);
    expect(engine.playCalls, isEmpty);
    expect(container.read(padVelocityProvider), isEmpty);
  });

  test('sample inexistente: el pad se enciende y vuelve a idle al fallar play',
      () async {
    final engine = MockAudioEngine()..simulateMissingSource = true;
    final container = buildPadContainer(engine: engine, pads: [missingPad]);
    final notifier = container.read(padPageProvider(0).notifier);
    await container.read(padPageProvider(0).future);

    await notifier.onPadDown('pad_missing');

    // Regresión: antes se quedaba encendido para siempre.
    expect(container.read(padPageProvider(0)).value!.single.state,
        PadState.idle);
    expect(container.read(padVelocityProvider), isEmpty);
  });
}
