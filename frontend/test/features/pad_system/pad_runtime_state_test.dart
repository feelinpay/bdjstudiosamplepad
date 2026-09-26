import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/domain/entities/pad_entity.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/presentation/providers/pad_providers.dart';

import '../../helpers/mock_audio_engine.dart';
import '../../helpers/pad_test_harness.dart';

void main() {
  const pad1 = PadEntity(
    id: 'pad_1',
    index: 0,
    label: 'Pad 1',
    sampleId: 'sample1.wav',
  );
  const pad2 = PadEntity(
    id: 'pad_2',
    index: 1,
    label: 'Pad 2',
    sampleId: 'sample2.wav',
  );

  test('pad state changes only update padRuntimeStateProvider, not padPageProvider list', () async {
    final engine = MockAudioEngine();
    final container = buildPadContainer(engine: engine, pads: [pad1, pad2]);
    final notifier = container.read(padPageProvider(0).notifier);
    final initialList = await container.read(padPageProvider(0).future);

    int padPageNotificationCount = 0;
    container.listen<AsyncValue<List<PadEntity>>>(
      padPageProvider(0),
      (_, __) => padPageNotificationCount++,
    );

    // Initial state is idle
    expect(container.read(padRuntimeStateProvider('pad_1')), equals(PadState.idle));
    expect(container.read(padRuntimeStateProvider('pad_2')), equals(PadState.idle));

    // Tap pad 1: triggers playing state
    await notifier.onPadDown('pad_1');

    // Only pad_1 state changed to playing
    expect(container.read(padRuntimeStateProvider('pad_1')), equals(PadState.playing));
    expect(container.read(padRuntimeStateProvider('pad_2')), equals(PadState.idle));

    // padPageProvider MUST NOT have emitted a new list!
    expect(padPageNotificationCount, equals(0));
    expect(identical(container.read(padPageProvider(0)).value, initialList), isTrue);

    // Force stop pad 1
    await notifier.forceStop('pad_1');
    expect(container.read(padRuntimeStateProvider('pad_1')), equals(PadState.idle));

    // Still no emissions on padPageProvider
    expect(padPageNotificationCount, equals(0));
  });
}
