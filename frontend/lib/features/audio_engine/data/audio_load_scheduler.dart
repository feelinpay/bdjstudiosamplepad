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
    required Future<void> Function(AudioLoadRequest request) load,
    this.canDispatchIdle,
  }) : _load = ((request) => Future.sync(() => load(request)));

  final int maxConcurrent;
  final Future<void> Function(AudioLoadRequest request) _load;
  final bool Function()? canDispatchIdle;
  final _pending = LinkedHashMap<String, AudioLoadRequest>(); // id -> request, en orden
  final _idlePending = LinkedHashMap<String, AudioLoadRequest>();
  int _running = 0;
  Completer<void>? _primaryCompleter;

  @visibleForTesting
  int get runningCount => _running;

  @visibleForTesting
  int get pendingCount => _pending.length;

  @visibleForTesting
  int get idlePendingCount => _idlePending.length;

  @visibleForTesting
  bool get isIdle => _running == 0 && _pending.isEmpty && _idlePending.isEmpty;

  /// Descarta lo pendiente (primario e idle) y encola [queue]. El Future se
  /// completa cuando la cola primaria se vacía o cuando otra llamada la reemplaza.
  Future<void> replaceQueue(Iterable<AudioLoadRequest> queue) {
    _pending.clear();
    _idlePending.clear();
    if (_primaryCompleter != null && !_primaryCompleter!.isCompleted) {
      _primaryCompleter!.complete();
    }
    _primaryCompleter = Completer<void>();

    for (final req in queue) {
      _pending[req.id] = req;
    }

    if (_pending.isEmpty && _running == 0) {
      _primaryCompleter!.complete();
    } else {
      _pump();
    }

    return _primaryCompleter!.future;
  }

  /// Encola [queue] en baja prioridad, ignorando ids ya presentes en cualquiera
  /// de las dos colas.
  void enqueueIdle(Iterable<AudioLoadRequest> queue) {
    for (final req in queue) {
      if (!_pending.containsKey(req.id) && !_idlePending.containsKey(req.id)) {
        _idlePending[req.id] = req;
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
      _dispatch(_pending.remove(id)!, idle: false);
    }

    _checkPrimaryCompletion();

    // Cola ociosa: solo ejecuta cuando la cola primaria está vacía y la concurrencia activa es 0.
    if (_pending.isEmpty && _running == 0 && _idlePending.isNotEmpty) {
      if (canDispatchIdle != null && !canDispatchIdle!()) {
        _idlePending.clear();
        return;
      }
      final id = _idlePending.keys.first;
      _dispatch(_idlePending.remove(id)!, idle: true);
    }
  }

  /// Lanza una carga. `_load` envuelve la función del motor en `Future.sync`,
  /// así que un error síncrono llega como Future fallido: nunca lanza aquí ni
  /// se ejecuta dos veces.
  void _dispatch(AudioLoadRequest request, {required bool idle}) {
    _running++;
    _load(request).catchError((Object error, StackTrace stack) {
      debugPrint(
        '[AudioLoadScheduler] Error al precargar audio${idle ? ' ocioso' : ''} '
        '(${request.id}, ${request.path}): $error',
      );
    }).whenComplete(() {
      _running--;
      _pump();
    });
  }
}
