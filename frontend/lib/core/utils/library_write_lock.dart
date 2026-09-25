import 'dart:async';

/// Candado asíncrono para serializar todas las escrituras a la biblioteca
/// (sincronización con disco, creación de pads, importación, reordenación/swap, duplicación).
/// Evita que concurrencia entre background sync y acciones de UI provoque colisiones de `padId`.
class LibraryWriteLock {
  LibraryWriteLock._();

  static Future<void> _last = Future.value();
  static final _zoneKey = Object();

  /// Ejecuta [action] de forma serializada y con reentrada transparente.
  static Future<T> run<T>(Future<T> Function() action) {
    if (Zone.current[_zoneKey] == true) {
      return action();
    }
    final completer = Completer<T>();
    _last = _last.then((_) async {
      try {
        final result = await runZoned(
          action,
          zoneValues: {_zoneKey: true},
        );
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}
