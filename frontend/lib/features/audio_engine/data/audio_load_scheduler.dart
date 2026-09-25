import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Carga audios en segundo plano sin saturar CPU/RAM.
/// - [maxConcurrent] cargas simultáneas como máximo.
/// - `replaceQueue` descarta lo PENDIENTE (no lo que ya corre) y encola lo nuevo:
///   la última página abierta gana.
class AudioLoadScheduler {
  AudioLoadScheduler({
    required this.maxConcurrent,
    required Future<void> Function(String id, String path) load,
  })  : _load = load;

  final int maxConcurrent;
  final Future<void> Function(String id, String path) _load;
  final _pending = LinkedHashMap<String, String>(); // id -> path, en orden
  int _running = 0;

  @visibleForTesting
  int get runningCount => _running;

  @visibleForTesting
  int get pendingCount => _pending.length;

  @visibleForTesting
  bool get isIdle => _running == 0 && _pending.isEmpty;

  void replaceQueue(Map<String, String> idToPath) {
    _pending
      ..clear()
      ..addAll(idToPath);
    _pump();
  }

  void clear() {
    _pending.clear();
  }

  void _pump() {
    while (_running < maxConcurrent && _pending.isNotEmpty) {
      final id = _pending.keys.first;
      final path = _pending.remove(id)!;
      _running++;
      try {
        _load(id, path).catchError((Object error, StackTrace stack) {
          debugPrint('[AudioLoadScheduler] Error al precargar audio ($id, $path): $error');
        }).whenComplete(() {
          _running--;
          _pump();
        });
      } catch (_) {
        _running--;
      }
    }
  }
}
