import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/core/audio/pad_trigger_resolver.dart';
import 'package:bdj_studio_sample_pad/core/audio/trigger_mode.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/domain/entities/pad_entity.dart';

import '../helpers/mock_audio_engine.dart';

/// Fase 11.3 - MIDI stress test (versión pura, ejecutable en CI).
/// Requisito: 10.000 eventos en 10 segundos. Aquí medimos el costo de la
/// capa de decisión + dispatch (sin audio nativo) para asegurar que el
/// cuello de botella NO es la lógica de la app.
void main() {
  test('procesa 10.000 disparos MIDI muy por debajo del presupuesto', () {
    var engine = MockAudioEngine();
    var pads = List.generate(
      16,
      (i) => PadEntity.empty(i).copyWith(
        sampleId: 'sample_$i.wav',
        playMode: TriggerMode.values[i % TriggerMode.values.length],
        chokeGroup: i % 4,
      ),
    );

    const eventCount = 10000;
    var sw = Stopwatch()..start();

    for (var n = 0; n < eventCount; n++) {
      var pad = pads[n % pads.length];
      var action = PadTriggerResolver.onDown(pad.playMode, pad.state);
      if (action == PadAction.stop) {
        engine.stop(pad.id);
      } else {
        engine.play(pad.id, pad.playMode, chokeGroup: pad.chokeGroup);
      }
    }

    sw.stop();

    // Presupuesto de la spec: 10s. La lógica pura debe consumir < 1s,
    // dejando >90% del presupuesto al driver MIDI/audio nativo.
    expect(
      sw.elapsedMilliseconds,
      lessThan(1000),
      reason: 'Lógica MIDI demasiado lenta: ${sw.elapsedMilliseconds}ms',
    );
    expect(engine.playCalls.length + engine.stopCalls.length, eventCount);

    engine.dispose();
  });

  test('la resolución touch->decisión es O(1) por evento', () {
    const iterations = 100000;
    var sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      PadTriggerResolver.onDown(TriggerMode.toggle, PadState.playing);
    }
    sw.stop();
    // 100k decisiones deben ser prácticamente instantáneas.
    expect(sw.elapsedMilliseconds, lessThan(200));
  });
}
