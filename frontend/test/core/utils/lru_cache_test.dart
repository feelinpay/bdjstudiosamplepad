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

  group('desalojo por peso (bytes)', () {
    test('totalWeight suma el peso de los elementos insertados', () {
      final cache = LruCache<String, String>(
        10,
        weigh: (s) => s.length,
        maxWeight: 100,
      );
      cache.put('a', 'hello'); // 5
      cache.put('b', 'world!'); // 6
      expect(cache.totalWeight, 11);
    });

    test('reemplazar clave actualiza totalWeight restando el valor viejo', () {
      final cache = LruCache<String, String>(
        10,
        weigh: (s) => s.length,
        maxWeight: 100,
      );
      cache.put('a', 'hello'); // 5
      expect(cache.totalWeight, 5);
      cache.put('a', 'hi'); // 2
      expect(cache.totalWeight, 2);
    });

    test('remove y clear descuentan peso correctamente', () {
      final cache = LruCache<String, String>(
        10,
        weigh: (s) => s.length,
        maxWeight: 100,
      );
      cache.put('a', 'abc'); // 3
      cache.put('b', 'defgh'); // 5
      expect(cache.totalWeight, 8);

      cache.remove('a');
      expect(cache.totalWeight, 5);

      cache.clear();
      expect(cache.totalWeight, 0);
    });

    test('desaloja el mas antiguo cuando supera maxWeight', () {
      final evicted = <String, String>{};
      final cache = LruCache<String, String>(
        10,
        weigh: (s) => s.length,
        maxWeight: 10,
        onEvict: (k, v) => evicted[k] = v,
      );
      cache.put('a', '12345'); // 5 bytes
      cache.put('b', '67890'); // 5 bytes -> total 10
      expect(cache.length, 2);
      expect(cache.totalWeight, 10);

      // Al añadir 'c' con 4 bytes, total sería 14 > 10. Desaloja 'a'
      cache.put('c', 'abcd');
      expect(cache.containsKey('a'), isFalse);
      expect(cache.containsKey('b'), isTrue);
      expect(cache.containsKey('c'), isTrue);
      expect(evicted['a'], '12345');
      expect(cache.totalWeight, 9); // 'b'(5) + 'c'(4)
    });

    test('un unico elemento que pesa mas que maxWeight es admitido sin bucle infinito', () {
      final evicted = <String, String>{};
      final cache = LruCache<String, String>(
        10,
        weigh: (s) => s.length,
        maxWeight: 5,
        onEvict: (k, v) => evicted[k] = v,
      );

      // Elemento de 20 bytes en cache con maxWeight 5
      cache.put('monster', '12345678901234567890');
      expect(cache.length, 1);
      expect(cache.containsKey('monster'), isTrue);
      expect(cache.totalWeight, 20);
      expect(evicted.isEmpty, isTrue);

      // Si entra otro elemento, el monstruo si se desaloja
      cache.put('tiny', 'hi');
      expect(cache.containsKey('monster'), isFalse);
      expect(cache.containsKey('tiny'), isTrue);
      expect(cache.length, 1);
      expect(cache.totalWeight, 2);
      expect(evicted['monster'], '12345678901234567890');
    });

    test('setMaxWeight reduce el limite y desaloja si es necesario', () {
      final evicted = <String, String>{};
      final cache = LruCache<String, String>(
        10,
        weigh: (s) => s.length,
        maxWeight: 20,
        onEvict: (k, v) => evicted[k] = v,
      );
      cache.put('a', '12345'); // 5
      cache.put('b', '12345'); // 5
      cache.put('c', '12345'); // 5 -> total 15

      expect(cache.length, 3);
      cache.setMaxWeight(8); // Debe desalojar 'a' y 'b' para quedar en <= 8
      expect(cache.length, 1);
      expect(cache.containsKey('c'), isTrue);
      expect(cache.totalWeight, 5);
      expect(evicted.keys, containsAll(<String>['a', 'b']));
    });
  });
}
