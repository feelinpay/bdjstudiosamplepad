import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/core/widgets/blocking_progress_dialog.dart';
import 'package:bdj_studio_sample_pad/core/utils/concurrency_shield.dart';

void main() {
  group('BlockingProgressController Tests', () {
    test('actualiza mensajes y contadores fielmente', () {
      final controller = BlockingProgressController(
        initialMessage: 'Iniciando...',
      );

      expect(controller.message, 'Iniciando...');
      expect(controller.current, isNull);
      expect(controller.total, isNull);
      expect(controller.progressFraction, isNull);

      var notificationCount = 0;
      controller.addListener(() {
        notificationCount++;
      });

      controller.updateProgress(5, 20, 'Copiando audios...');

      expect(controller.current, 5);
      expect(controller.total, 20);
      expect(controller.message, 'Copiando audios...');
      expect(controller.progressFraction, 0.25);
      expect(notificationCount, 1);

      // Sin cambios no debe notificar
      controller.update(current: 5, total: 20, message: 'Copiando audios...');
      expect(notificationCount, 1);

      controller.updateCount(10, 'Avanzando...');
      expect(controller.current, 10);
      expect(controller.total, 20);
      expect(controller.message, 'Avanzando...');
      expect(controller.progressFraction, 0.5);
      expect(notificationCount, 2);

      controller.dispose();
    });
  });

  group('ConcurrencyShield Mutex Protection Tests', () {
    test('rechaza ejecución concurrente mientras una tarea está en curso', () async {
      const tag = 'test_workspace_operation';
      var task1Started = false;
      var task2Started = false;

      final future1 = ConcurrencyShield.run(tag, () async {
        task1Started = true;
        await Future.delayed(const Duration(milliseconds: 100));
        return 'success';
      });

      // Intentar ejecutar concurrentemente con la misma tag
      final future2 = ConcurrencyShield.run(tag, () async {
        task2Started = true;
        return 'duplicate';
      });

      final result1 = await future1;
      final result2 = await future2;

      expect(task1Started, isTrue);
      expect(result1, 'success');
      expect(task2Started, isFalse);
      expect(result2, isNull); // El segundo llamado fue rechazado por el mutex
      expect(ConcurrencyShield.isMutexLocked(tag), isFalse);
    });
  });
}
