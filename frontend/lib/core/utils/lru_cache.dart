import 'dart:collection';

class LruCache<K, V> {
  int capacity;
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();
  final void Function(K key, V value)? onEvict;

  LruCache(this.capacity, {this.onEvict});

  V? get(K key) {
    if (!_map.containsKey(key)) return null;
    // Accessing item, move it to end (most recently used)
    var value = _map.remove(key) as V;
    _map[key] = value;
    return value;
  }

  void put(K key, V value) {
    if (_map.containsKey(key)) {
      var oldValue = _map.remove(key) as V;
      if (onEvict != null) {
        onEvict!(key, oldValue);
      }
    }
    _map[key] = value;

    _evictToCapacity();
  }

  void resize(int newCapacity) {
    if (newCapacity < 1) {
      throw ArgumentError.value(
        newCapacity,
        'newCapacity',
        'Debe ser mayor que cero',
      );
    }
    capacity = newCapacity;
    _evictToCapacity();
  }

  void _evictToCapacity() {
    while (_map.length > capacity) {
      var oldestKey = _map.keys.first;
      var oldestValue = _map.remove(oldestKey) as V;
      if (onEvict != null) {
        onEvict!(oldestKey, oldestValue);
      }
    }
  }

  /// Quita [key] liberando su valor.
  ///
  /// `onEvict` es quien libera el recurso asociado (en el motor de audio, la
  /// `AudioSource` nativa). Omitirlo aquí convertía cada `remove` en una fuga.
  void remove(K key) {
    if (!_map.containsKey(key)) return;
    final value = _map.remove(key) as V;
    onEvict?.call(key, value);
  }

  bool containsKey(K key) => _map.containsKey(key);

  void clear() {
    if (onEvict != null) {
      for (var entry in _map.entries) {
        onEvict!(entry.key, entry.value);
      }
    }
    _map.clear();
  }

  Iterable<K> get keys => _map.keys;
  int get length => _map.length;
}
