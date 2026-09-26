import 'dart:collection';

class LruCache<K, V> {
  int capacity;
  final int Function(V value)? weigh;
  int? _maxWeight;
  int _totalWeight = 0;
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();
  final void Function(K key, V value)? onEvict;

  LruCache(
    this.capacity, {
    this.weigh,
    int? maxWeight,
    this.onEvict,
  }) : _maxWeight = maxWeight;

  int? get maxWeight => _maxWeight;
  int get totalWeight => _totalWeight;

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
      if (weigh != null) {
        _totalWeight -= weigh!(oldValue);
      }
      onEvict?.call(key, oldValue);
    }
    _map[key] = value;
    if (weigh != null) {
      _totalWeight += weigh!(value);
    }

    _evictToLimits();
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
    _evictToLimits();
  }

  void setMaxWeight(int? newMaxWeight) {
    if (newMaxWeight != null && newMaxWeight < 0) {
      throw ArgumentError.value(
        newMaxWeight,
        'newMaxWeight',
        'No puede ser negativo',
      );
    }
    _maxWeight = newMaxWeight;
    _evictToLimits();
  }

  void _evictToLimits() {
    // Desaloja mientras supere la capacidad en elementos o el peso máximo por bytes.
    // Si un único elemento supera maxWeight, queda como único residente para evitar bucle infinito.
    while (_map.length > capacity ||
        (_maxWeight != null && _totalWeight > _maxWeight! && _map.length > 1)) {
      var oldestKey = _map.keys.first;
      var oldestValue = _map.remove(oldestKey) as V;
      if (weigh != null) {
        _totalWeight -= weigh!(oldestValue);
        if (_totalWeight < 0) _totalWeight = 0;
      }
      onEvict?.call(oldestKey, oldestValue);
    }
  }

  /// Quita [key] liberando su valor.
  ///
  /// `onEvict` es quien libera el recurso asociado (en el motor de audio, la
  /// `AudioSource` nativa). Omitirlo aquí convertía cada `remove` en una fuga.
  void remove(K key) {
    if (!_map.containsKey(key)) return;
    final value = _map.remove(key) as V;
    if (weigh != null) {
      _totalWeight -= weigh!(value);
      if (_totalWeight < 0) _totalWeight = 0;
    }
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
    _totalWeight = 0;
  }

  Iterable<K> get keys => _map.keys;
  int get length => _map.length;
}
