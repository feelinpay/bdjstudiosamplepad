import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/core/providers/core_providers.dart';
import 'package:bdj_studio_sample_pad/features/midi/presentation/providers/midi_providers.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/domain/entities/pad_entity.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/presentation/providers/pad_providers.dart';

import 'mock_audio_engine.dart';
import 'mock_midi.dart';

/// Crea un contenedor con el `PadPageNotifier` real cuyo `build()` se sustituye
/// por una lista fija de pads (sin tocar Isar) pero REPRODUCIENDO la suscripción
/// al stream `onSoundFinished` que hace el build de producción: cuando el motor
/// notifica un pad, el notifier lo apaga. Sin esto, `overrideWithBuild`
/// dejaría al notifier sin enterarse de los finish — y tanto el PANIC (2.1)
/// como el audio ausente (2.2) dependen de ese stream.
ProviderContainer buildPadContainer({
  required MockAudioEngine engine,
  required List<PadEntity> pads,
}) {
  final container = ProviderContainer(
    overrides: [
      audioEngineProvider.overrideWithValue(engine),
      midiEngineProvider.overrideWithValue(FakeMidiEngine()),
      midiControllerProvider.overrideWith((ref) => FakeMidiController(ref)),
      padPageProvider.overrideWithBuild((ref, notifier) async {
        final audio = ref.read(audioEngineProvider);
        final sub = audio.onSoundFinished.listen((padId) {
          final current = notifier.state.value;
          if (current == null) return;
          final idx = current.indexWhere((p) => p.id == padId);
          if (idx != -1 && current[idx].state != PadState.idle) {
            final list = [...current];
            list[idx] = current[idx].copyWith(state: PadState.idle);
            notifier.state = AsyncData(list);
          }
        });
        ref.onDispose(sub.cancel);
        return pads;
      }),
    ],
  );
  addTearDown(container.dispose);
  return container;
}
