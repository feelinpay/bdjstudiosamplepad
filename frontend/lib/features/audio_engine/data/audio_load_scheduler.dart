import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

import '../../../core/audio/audio_load_request.dart';

export '../../../core/audio/audio_load_request.dart';

/// Carga audios en segundo plano sin saturar CPU/RAM.
/// - [maxConcurrent] cargas simultáneas como máximo en cola primaria.
/// - `replaceQueue` descarta lo PENDIENTE (primario e idle) y encola lo nuevo:
///   la última página abierta gana.
/// - `enqueueIdle` encola tareas en una cola de baja prioridad que solo se
///   despachan cuando la cola primaria está vacía y la concurrencia activa es 0.
class AudioLoadScheduler {
  AudioLoadScheduler({
    required this.maxConcurrent,
    required dynamic load,
  }) : _load = _wrapLoad(load);

  final int maxConcurrent;
  final Future<void> Function(AudioLoadRequest request) _load;
  final _pending = LinkedHashMap<String, AudioLoadRequest>(); // id -> request, en orden
  final _idlePending = LinkedHashMap<String, AudioLoadRequest>();
  int _running = 0;
  Completer<void>? _primaryCompleter;

  static Future<void> Function(AudioLoadRequest) _wrapLoad(dynamic fn) {
    if (fn is Future<void> Function(AudioLoadRequest)) {
      return fn;
    }
    return (AudioLoadRequest req) {
      if (fn is Future<void> Function(String, String, bool)) {
        return fn(req.id, req.path, req.needsRandomAccess);
      }
      try {
        final res = (fn as Function)(req.id, req.path, needsRandomAccess: req.needsRandomAccess);
        if (res is Future<void>) return res;
      } catch (_) {
        final res = (fn as Function)(req.id, req.path);
        if (res is Future<void>) return res;
      }
      return Future.value();
    };
  }

  @visibleForTesting
  int get runningCount => _running;

  @visibleForTesting
  int get pendingCount => _pending.length;

  @visibleForTesting
  int get idlePendingCount => _idlePending.length;

  @visibleForTesting
  bool get isIdle => _running == 0 && _pending.isEmpty && _idlePending.isEmpty;

  Future<void> replaceQueue(dynamic queue) {
    _pending.clear();
    _idlePending.clear();
    if (_primaryCompleter != null && !_primaryCompleter!.isCompleted) {
      _primaryCompleter!.complete();
    }
    _primaryCompleter = Completer<void>();

    if (queue is Map<String, String>) {
      for (final entry in queue.entries) {
        _pending[entry.key] = AudioLoadRequest(id: entry.key, path: entry.value);
      }
    } else if (queue is Iterable<AudioLoadRequest>) {
      for (final req in queue) {
        _pending[req.id] = req;
      }
    } else if (queue is Map<String, AudioLoadRequest>) {
      _pending.addAll(queue);
    }

    if (_pending.isEmpty && _running == 0) {
      _primaryCompleter!.complete();
    } else {
      _pump();
    }

    return _primaryCompleter!.future;
  }

  void enqueueIdle(dynamic queue) {
    if (queue is Iterable<AudioLoadRequest>) {
      for (final req in queue) {
        if (!_pending.containsKey(req.id) && !_idlePending.containsKey(req.id)) {
          _idlePending[req.id] = req;
        }
      }
    } else if (queue is Map<String, AudioLoadRequest>) {
      for (final entry in queue.entries) {
        if (!_pending.containsKey(entry.key) && !_idlePending.containsKey(entry.key)) {
          _idlePending[entry.key] = entry.value;
        }
      }
    } else if (queue is Map<String, String>) {
      for (final entry in queue.entries) {
        if (!_pending.containsKey(entry.key) && !_idlePending.containsKey(entry.key)) {
          _idlePending[entry.key] = AudioLoadRequest(id: entry.key, path: entry.value);
        }
      }
    }
    _pump();
  }

  void clear() {
    _pending.clear();
    _idlePending.clear();
    if (_primaryCompleter != null && !_primaryCompleter!.isCompleted) {
      _primaryCompleter!.complete();
    }
  }

  void _checkPrimaryCompletion() {
    if (_pending.isEmpty && _running == 0) {
      if (_primaryCompleter != null && !_primaryCompleter!.isCompleted) {
        _primaryCompleter!.complete();
      }
    }
  }

  void _pump() {
    while (_running < maxConcurrent && _pending.isNotEmpty) {
      final id = _pending.keys.first;
      final request = _pending.remove(id)!;
      _running++;
      try {
        _load(request).catchError((Object error, StackTrace stack) {
          debugPrint('[AudioLoadScheduler] Error al precargar audio ($id, ${request.path}): $error');
        }).whenComplete(() {
          _running--;
          _checkPrimaryCompletion();
          _pump();
        });
      } catch (_) {
        _running--;
        _checkPrimaryCompletion();
      }
    }

    _checkPrimaryCompletion();

    // Cola ociosa: solo ejecuta cuando la cola primaria está vacía y la concurrencia activa es 0.
    if (_pending.isEmpty && _running == 0 && _idlePending.isNotEmpty) {
      final id = _idlePending.keys.first;
      final request = _idlePending.remove(id)!;
      _running++;
      try {
        _load(request).catchError((Object error, StackTrace stack) {
          debugPrint('[AudioLoadScheduler] Error al precargar audio ocioso ($id, ${request.path}): $error');
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
