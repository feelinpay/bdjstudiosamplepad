import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

import '../../../core/audio/audio_load_request.dart';

export '../../../core/audio/audio_load_request.dart';

/// Carga audios en segundo plano sin saturar CPU/RAM.
/// - [maxConcurrent] cargas simultáneas como máximo.
/// - `replaceQueue` descarta lo PENDIENTE (no lo que ya corre) y encola lo nuevo:
///   la última página abierta gana.
class AudioLoadScheduler {
  AudioLoadScheduler({
    required this.maxConcurrent,
    required dynamic load,
  }) : _load = _wrapLoad(load);

  final int maxConcurrent;
  final Future<void> Function(AudioLoadRequest request) _load;
  final _pending = LinkedHashMap<String, AudioLoadRequest>(); // id -> request, en orden
  int _running = 0;

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
  bool get isIdle => _running == 0 && _pending.isEmpty;

  void replaceQueue(dynamic queue) {
    _pending.clear();
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
    _pump();
  }

  void clear() {
    _pending.clear();
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
          _pump();
        });
      } catch (_) {
        _running--;
      }
    }
  }
}
