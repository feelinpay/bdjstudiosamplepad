import 'package:flutter_test/flutter_test.dart';

import 'package:bdj_studio_sample_pad/core/utils/lru_cache.dart';

/// [LruCache] es lo que limita cuántos audios quedan residentes en memoria en
/// el motor de sonido. Su callback `onEvict` es el que libera el `AudioSource`
/// nativo, así que cada camino que saca una entrada del mapa sin avisar es una
/// fuga de memoria nativa durante un set largo.
void main() {
  group('lectura y escritura', () {
    test('get() devuelve null para una clave ausente', () {
      final cache = LruCache<String, int>(2);
      expect(cache.get('nada'), isNull);
    });

    test('put() y get() recuperan el valor', () {
      final cache = LruCache<String, int>(2)..put('a', 1);
      expect(cache.get('a'), 1);
    });

    test('put() sobre una clave existente reemplaza el valor', () {
      final cache = LruCache<String, int>(2)
        ..put('a', 1)
        ..put('a', 2);
      expect(cache.get('a'), 2);
      expect(cache.length, 1);
    });

    test('containsKey() refleja la presencia', () {
      final cache = LruCache<String, int>(2)..put('a', 1);
      expect(cache.containsKey('a'), isTrue);
      expect(cache.containsKey('b'), isFalse);
    });

    test('length y keys reflejan el contenido', () {
      final cache = LruCache<String, int>(3)
        ..put('a', 1)
        ..put('b', 2);
      expect(cache.length, 2);
      expect(cache.keys, containsAll(<String>['a', 'b']));
    });
  });

  group('política de desalojo', () {
    test('al superar la capacidad se desaloja la entrada más antigua', () {
      final cache = LruCache<String, int>(2)
        ..put('a', 1)
        ..put('b', 2)
        ..put('c', 3);

      expect(cache.containsKey('a'), isFalse);
      expect(cache.containsKey('b'), isTrue);
      expect(cache.containsKey('c'), isTrue);
    });

    test('un get() renueva la antigüedad de la entrada', () {
      final cache = LruCache<String, int>(2)
        ..put('a', 1)
        ..put('b', 2);

      cache.get('a'); // 'a' pasa a ser la más reciente
      cache.put('c', 3);

      expect(cache.containsKey('a'), isTrue, reason: 'a fue usada al final');
      expect(cache.containsKey('b'), isFalse);
    });

    test('el desalojo invoca onEvict con la clave y el valor salientes', () {
      final evicted = <String, int>{};
      LruCache<String, int>(1, onEvict: (k, v) => evicted[k] = v)
        ..put('a', 1)
        ..put('b', 2);

      expect(evicted, {'a': 1});
    });

    test('reemplazar una clave libera el valor anterior', () {
      final evicted = <int>[];
      LruCache<String, int>(2, onEvict: (_, v) => evicted.add(v))
        ..put('a', 1)
        ..put('a', 2);

      expect(evicted, [1], reason: 'el AudioSource viejo debe liberarse');
    });
  });

  group('resize', () {
    test('reducir la capacidad desaloja el excedente inmediatamente', () {
      final cache = LruCache<String, int>(3)
        ..put('a', 1)
        ..put('b', 2)
        ..put('c', 3);

      cache.resize(1);

      expect(cache.length, 1);
      expect(cache.containsKey('c'), isTrue);
    });

    test('reducir la capacidad notifica onEvict de lo desalojado', () {
      final evicted = <String>[];
      final cache = LruCache<String, int>(3, onEvict: (k, _) => evicted.add(k))
        ..put('a', 1)
        ..put('b', 2)
        ..put('c', 3);

      cache.resize(1);

      expect(evicted, ['a', 'b']);
    });

    test('ampliar la capacidad conserva todo', () {
      final cache = LruCache<String, int>(2)
        ..put('a', 1)
        ..put('b', 2);

      cache.resize(5);
      cache.put('c', 3);

      expect(cache.length, 3);
    });

    test('una capacidad menor que 1 se rechaza', () {
      final cache = LruCache<String, int>(2);
      expect(() => cache.resize(0), throwsArgumentError);
    });
  });

  group('liberación explícita', () {
    test('clear() vacía la caché', () {
      final cache = LruCache<String, int>(2)
        ..put('a', 1)
        ..put('b', 2);

      cache.clear();

      expect(cache.length, 0);
    });

    test('clear() notifica onEvict de cada entrada', () {
      final evicted = <String>[];
      final cache = LruCache<String, int>(2, onEvict: (k, _) => evicted.add(k))
        ..put('a', 1)
        ..put('b', 2);

      cache.clear();

      expect(evicted, containsAll(<String>['a', 'b']));
    });

    test('remove() saca la entrada', () {
      final cache = LruCache<String, int>(2)..put('a', 1);
      cache.remove('a');
      expect(cache.containsKey('a'), isFalse);
    });

    test('remove() notifica onEvict para liberar el recurso asociado', () {
      // Sin esta notificación, quitar un pad de la caché deja vivo su
      // AudioSource nativo: el motor pierde memoria en cada reasignación.
      final evicted = <String>[];
      final cache = LruCache<String, int>(2, onEvict: (k, _) => evicted.add(k))
        ..put('a', 1);

      cache.remove('a');

      expect(evicted, ['a']);
    });

    test('remove() de una clave ausente no lanza', () {
      final cache = LruCache<String, int>(2);
      expect(() => cache.remove('nada'), returnsNormally);
    });
  });
}
