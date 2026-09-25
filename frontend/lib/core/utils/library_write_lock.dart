import 'dart:async';

/// Candado asíncrono para serializar todas las escrituras a la biblioteca
/// (sincronización con disco, creación de pads, importación, reordenación/swap, duplicación).
/// Evita que concurrencia entre background sync y acciones de UI provoque colisiones de `padId`.
class LibraryWriteLock {
  LibraryWriteLock._();

  static Future<void> _last = Future.value();

  /// Ejecuta [action] de forma serializada.
  static Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _last = _last.then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}
