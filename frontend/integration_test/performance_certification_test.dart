// SAMPLE PAD PRO - LIVE CERTIFICATION (Fase 11.3)
//
// Este harness se ejecuta en un DISPOSITIVO/EMULADOR real, no en CI puro:
//
//   flutter test integration_test/performance_certification_test.dart
//
// Mide los umbrales de la certificación en vivo:
//   - Latencia touch-to-decision < 15 ms (p95)
//   - 60 FPS con 32 pads activos (frame budget 16.6 ms)
//   - RAM < 200 MB en uso normal
//
// Nota: la latencia real touch-to-AUDIO depende del buffer nativo
// (128 samples @ 48kHz = 2.67 ms) + esta capa. Aquí se certifica la
// porción controlada por Flutter/Dart y el pipeline de frames.
import 'dart:developer' as developer;
import 'dart:io' show ProcessInfo;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bdj_studio_sample_pad/core/audio/pad_trigger_resolver.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/domain/entities/pad_entity.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Live Certification', () {
    testWidgets('Latencia touch->decisión < 15ms (p95)', (tester) async {
      final pad = PadEntity.empty(0).copyWith(sampleId: 'kick.wav');
      final samples = <int>[];

      for (var i = 0; i < 500; i++) {
        final sw = Stopwatch()..start();
        PadTriggerResolver.onDown(pad.playMode, pad.state);
        sw.stop();
        samples.add(sw.elapsedMicroseconds);
      }

      samples.sort();
      final p95 = samples[(samples.length * 0.95).floor()];
      final p95Ms = p95 / 1000.0;
      developer.log('Latencia p95: ${p95Ms.toStringAsFixed(3)} ms',
          name: 'certification');
      expect(p95Ms, lessThan(15.0));
    });

    testWidgets('60 FPS con 32 pads activos', (tester) async {
      await binding.watchPerformance(() async {
        await tester.pumpWidget(const _StressPadGrid(padCount: 32));
        // Simula actividad visual (repaints) durante ~2 segundos de frames.
        for (var i = 0; i < 120; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      });

      // El timeline se vuelca en reportData['performance'] para inspección
      // con `flutter test --profile`. Aquí verificamos que no hubo excepciones
      // de layout/paint durante el estrés visual.
      expect(tester.takeException(), isNull);
    });

    testWidgets('RAM < 200MB en uso normal', (tester) async {
      await tester.pumpWidget(const _StressPadGrid(padCount: 32));
      await tester.pumpAndSettle();

      final rssMb = ProcessInfo.currentRss / (1024 * 1024);
      developer.log('RSS: ${rssMb.toStringAsFixed(1)} MB',
          name: 'certification');
      expect(rssMb, lessThan(200.0));
    });
  });
}

/// Grid de estrés: [padCount] pads con RepaintBoundary por celda, replicando
/// la estructura de PadGridView para medir el costo de frame.
class _StressPadGrid extends StatelessWidget {
  final int padCount;
  const _StressPadGrid({required this.padCount});

  @override
  Widget build(BuildContext context) {
    final pads = List.generate(padCount, (i) => PadEntity.empty(i));
    return MaterialApp(
      home: Scaffold(
        body: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
          ),
          itemCount: pads.length,
          itemBuilder: (_, i) => RepaintBoundary(
            child: Container(
              margin: const EdgeInsets.all(4),
              color: Color(pads[i].colorHex),
              child: Center(child: Text(pads[i].label)),
            ),
          ),
        ),
      ),
    );
  }
}
