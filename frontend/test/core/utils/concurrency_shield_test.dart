import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:bdj_studio_sample_pad/core/utils/concurrency_shield.dart';

/// [ConcurrencyShield] es la barrera contra el spam de clics en vivo: evita
/// que una ráfaga sobre el mismo botón dispare dos importaciones, dos borrados
/// o dos navegaciones simultáneas. Sus garantías (mutex real, liberación aun
/// ante excepción, throttle temporal) son las que sostienen la app durante un
/// set, así que conviene fijarlas.
void main() {
  group('run() — mutex', () {
    test('ejecuta la acción y devuelve su resultado', () async {
      final result = await ConcurrencyShield.run('tag-ok', () async => 42);
      expect(result, 42);
    });

    test('rechaza una segunda invocación mientras la primera está en curso',
        () async {
      final gate = Completer<void>();
      var ejecuciones = 0;

      final first = ConcurrencyShield.run('tag-mutex', () async {
        ejecuciones++;
        await gate.future;
        return 'primera';
      });
      final second = await ConcurrencyShield.run(
        'tag-mutex',
        () async {
          ejecuciones++;
          return 'segunda';
        },
      );

      expect(second, isNull, reason: 'la invocación duplicada se descarta');
      expect(ejecuciones, 1);

      gate.complete();
      expect(await first, 'primera');
    });

    test('libera el mutex al terminar, permitiendo una nueva ejecución',
        () async {
      await ConcurrencyShield.run('tag-libre', () async => 1);
      final second = await ConcurrencyShield.run('tag-libre', () async => 2);
      expect(second, 2);
    });

    test('libera el mutex aunque la acción lance', () async {
      await expectLater(
        ConcurrencyShield.run('tag-error', () async => throw StateError('boom')),
        throwsStateError,
      );

      final after = await ConcurrencyShield.run('tag-error', () async => 'ok');
      expect(after, 'ok', reason: 'un fallo no debe dejar el lock tomado');
    });

    test('tags distintos no se bloquean entre sí', () async {
      final gate = Completer<void>();
      final first = ConcurrencyShield.run('tag-a', () async {
        await gate.future;
        return 'a';
      });
      final second = await ConcurrencyShield.run('tag-b', () async => 'b');

      expect(second, 'b');
      gate.complete();
      await first;
    });

    test('isMutexLocked refleja el estado durante y después', () async {
      final gate = Completer<void>();
      final running = ConcurrencyShield.run('tag-estado', () async {
        await gate.future;
        return null;
      });

      await Future<void>.delayed(Duration.zero);
      expect(ConcurrencyShield.isMutexLocked('tag-estado'), isTrue);

      gate.complete();
      await running;
      expect(ConcurrencyShield.isMutexLocked('tag-estado'), isFalse);
    });

    test('isProcessing sigue el flag de UI y se apaga al final', () async {
      final gate = Completer<void>();
      final running = ConcurrencyShield.run('tag-flag', () async {
        await gate.future;
        return null;
      });

      await Future<void>.delayed(Duration.zero);
      expect(ConcurrencyShield.isProcessing('tag-flag'), isTrue);

      gate.complete();
      await running;
      expect(ConcurrencyShield.isProcessing('tag-flag'), isFalse);
    });

    test('trackFlag:false no marca la operación como en proceso', () async {
      final gate = Completer<void>();
      final running = ConcurrencyShield.run(
        'tag-sin-flag',
        () async {
          await gate.future;
          return null;
        },
        trackFlag: false,
      );

      await Future<void>.delayed(Duration.zero);
      expect(ConcurrencyShield.isProcessing('tag-sin-flag'), isFalse);
      expect(ConcurrencyShield.isMutexLocked('tag-sin-flag'), isTrue);

      gate.complete();
      await running;
    });
  });

  group('throttle()', () {
    test('la primera llamada pasa', () {
      expect(ConcurrencyShield.throttle('th-1'), isTrue);
    });

    test('una segunda llamada inmediata se rechaza', () {
      ConcurrencyShield.throttle('th-2');
      expect(ConcurrencyShield.throttle('th-2'), isFalse);
    });

    test('pasado el cooldown vuelve a pasar', () async {
      const cooldown = Duration(milliseconds: 30);
      expect(ConcurrencyShield.throttle('th-3', cooldown: cooldown), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(ConcurrencyShield.throttle('th-3', cooldown: cooldown), isTrue);
    });

    test('tags distintos se throttlean por separado', () {
      expect(ConcurrencyShield.throttle('th-4a'), isTrue);
      expect(ConcurrencyShield.throttle('th-4b'), isTrue);
    });

    test('una ráfaga de clics deja pasar exactamente uno', () {
      var aceptados = 0;
      for (var i = 0; i < 25; i++) {
        if (ConcurrencyShield.throttle('th-rafaga')) aceptados++;
      }
      expect(aceptados, 1);
    });
  });

  group('runNavigation()', () {
    test('ejecuta la navegación y devuelve su resultado', () async {
      final result = await ConcurrencyShield.runNavigation(() async => 'listo');
      expect(result, 'listo');
    });

    test('bloquea una navegación concurrente', () async {
      final gate = Completer<void>();
      final first = ConcurrencyShield.runNavigation(() async {
        await gate.future;
        return 'primera';
      });
      final second = await ConcurrencyShield.runNavigation(() async => 'segunda');

      expect(second, isNull);
      expect(ConcurrencyShield.isNavigating, isTrue);

      gate.complete();
      await first;
      expect(ConcurrencyShield.isNavigating, isFalse);
    });

    test('libera el candado aunque la navegación lance', () async {
      await expectLater(
        ConcurrencyShield.runNavigation(() async => throw StateError('boom')),
        throwsStateError,
      );
      expect(ConcurrencyShield.isNavigating, isFalse);
    });
  });

  group('nextRequestId()', () {
    test('es estrictamente incremental', () {
      final a = ConcurrencyShield.nextRequestId();
      final b = ConcurrencyShield.nextRequestId();
      expect(b, greaterThan(a));
    });

    test('no repite valores en una ráfaga', () {
      final ids = List.generate(50, (_) => ConcurrencyShield.nextRequestId());
      expect(ids.toSet().length, 50);
    });
  });
}
