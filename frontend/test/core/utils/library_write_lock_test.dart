import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/core/utils/library_write_lock.dart';

void main() {
  test('LibraryWriteLock ejecuta acciones de forma estrictamente secuencial', () async {
    final order = <int>[];
    final c1 = Completer<void>();
    final c2 = Completer<void>();

    final f1 = LibraryWriteLock.run(() async {
      await c1.future;
      order.add(1);
    });

    final f2 = LibraryWriteLock.run(() async {
      await c2.future;
      order.add(2);
    });

    final f3 = LibraryWriteLock.run(() async {
      order.add(3);
    });

    expect(order, isEmpty);
    c1.complete();
    await f1;
    expect(order, [1]);

    c2.complete();
    await f2;
    await f3;
    expect(order, [1, 2, 3]);
  });

  test('LibraryWriteLock no se rompe tras una excepción en una acción', () async {
    final order = <String>[];

    final f1 = LibraryWriteLock.run(() async {
      order.add('error');
      throw Exception('fallo simulado');
    });

    final f2 = LibraryWriteLock.run(() async {
      order.add('success');
      return 42;
    });

    expect(f1, throwsException);
    expect(await f2, 42);
    expect(order, ['error', 'success']);
  });

  test('LibraryWriteLock es reentrante en llamadas anidadas (evita deadlock)', () async {
    final result = await LibraryWriteLock.run(() async {
      return await LibraryWriteLock.run(() async {
        return await LibraryWriteLock.run(() async {
          return 'nested success';
        });
      });
    });

    expect(result, 'nested success');
  });
}
