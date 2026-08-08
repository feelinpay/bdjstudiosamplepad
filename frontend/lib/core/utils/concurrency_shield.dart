import 'dart:async';
import 'package:flutter/material.dart';

/// Control de concurrencia e idempotencia para la interfaz de usuario.
///
/// Previene condiciones de carrera, navegaciones duplicadas y ejecuciones
/// concurrentes ante ráfagas de clics rápidas y repetitivas (spam de clics).
///
/// Diseñado para operaciones que deben ser **mutex** (una a la vez) y
/// **idempotentes** (una sola ejecución válida aunque el usuario haga clic
/// repetidamente mientras la operación está en curso.
class ConcurrencyShield {
  // ── Mutex (bloqueo real, no solo flag) ────────────────────────────────
  /// Completers activos indexados por tag. Mientras el Completer está en la
  /// tabla, la operación está en curso y nuevas invocaciones son rechazadas.
  static final Map<String, Completer<void>> _activeMutexes = {};

  // ── Flags operacionales para UI ───────────────────────────────────────
  static final Map<String, bool> _processingFlags = {};

  // ── Throttle (time-based, para UI visual) ─────────────────────────────
  static final Map<String, int> _lastThrottledTimes = {};
  static const Duration _defaultThrottleCooldown = Duration(milliseconds: 300);

  // ── Navegación global ─────────────────────────────────────────────────
  static bool _isNavigatingGlobal = false;

  // ── Contador incremental para request-id ──────────────────────────────
  static int _globalRequestId = 0;

  /// Genera un identificador incremental único para una solicitud asíncrona.
  /// Útil para descartar resultados antiguos cuando se cancela o reemplaza
  /// una operación (p.ej. cambio rápido de workspace mientras la carga
  /// anterior aún no terminó).
  static int nextRequestId() => ++_globalRequestId;

  // ══════════════════════════════════════════════════════════════════════
  //  MÉTRIX REAL (mutex)
  // ══════════════════════════════════════════════════════════════════════

  /// Verifica si una operación identificada por [tag] está actualmente en
  /// ejecución (mutex activo).
  static bool isProcessing(String tag) => _processingFlags[tag] ?? false;

  /// Verifica si hay un mutex activo para [tag].
  static bool isMutexLocked(String tag) => _activeMutexes.containsKey(tag);

  /// Ejecuta [action] bajo un mutex identificado por [tag].
  ///
  /// - Si la operación ya está en curso, retorna `null` inmediatamente
  ///   (la nueva invocación es rechazada — idempotente).
  /// - El mutex se libera en el bloque `finally`, garantizando que nunca
  ///   quede un lock permanente aunque falle la operación.
  /// - Si [trackFlag] es `true` (por defecto), también actualiza
  ///   [_processingFlags] para que la UI pueda consultar el estado.
  static Future<T?> run<T>(
    String tag,
    Future<T> Function() action, {
    bool trackFlag = true,
  }) async {
    if (_activeMutexes.containsKey(tag)) {
      debugPrint(
        '🛑 [ConcurrencyShield] Operación ignorada (mutex activo): $tag',
      );
      return null;
    }

    final completer = Completer<void>();
    _activeMutexes[tag] = completer;
    if (trackFlag) {
      _processingFlags[tag] = true;
    }

    try {
      return await action();
    } catch (e, st) {
      debugPrint('❌ [ConcurrencyShield] Error en operación $tag: $e\n$st');
      rethrow;
    } finally {
      _activeMutexes.remove(tag);
      if (trackFlag) {
        _processingFlags[tag] = false;
      }
      completer.complete();
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  THROTTLE (time-based, para UI visual)
  // ══════════════════════════════════════════════════════════════════════

  /// Bloqueo temporal (Throttle): permite una única ejecución por cada
  /// intervalo de [cooldown]. Ideal para botones de interfaz y eventos
  /// de toque rápido en presentaciones en vivo.
  ///
  /// **No** usar como única protección para operaciones críticas. Siempre
  /// combinar con [run] cuando la operación tenga efectos secundarios.
  static bool throttle(
    String tag, {
    Duration cooldown = _defaultThrottleCooldown,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastThrottledTimes[tag] ?? 0;
    if (now - last < cooldown.inMilliseconds) {
      debugPrint(
        '🛑 [ConcurrencyShield] Evento throttled (spam de clic rechazado): $tag',
      );
      return false;
    }
    _lastThrottledTimes[tag] = now;
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  NAVEGACIÓN
  // ══════════════════════════════════════════════════════════════════════

  /// Verifica si hay una transición de navegación en curso.
  static bool get isNavigating => _isNavigatingGlobal;

  /// Bloqueo atómico de navegación para transiciones entre carpetas o
  /// workspaces. Previene que ráfagas de clic destruyan el árbol de widgets.
  static Future<T?> runNavigation<T>(
    Future<T?> Function() navigationAction,
  ) async {
    if (_isNavigatingGlobal) {
      debugPrint('🛑 [ConcurrencyShield] Navegación duplicada bloqueada.');
      return null;
    }
    _isNavigatingGlobal = true;
    try {
      return await navigationAction();
    } finally {
      _isNavigatingGlobal = false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  CIERRE SEGURO DE MODALES
  // ══════════════════════════════════════════════════════════════════════

  /// Cierra modales/diálogos con protección contra doble cierre.
  static void safePop(BuildContext context, [Object? result]) {
    if (throttle(
      'nav_pop_${context.hashCode}',
      cooldown: const Duration(milliseconds: 450),
    )) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context, result);
      } else {
        debugPrint(
          '⚠️ [ConcurrencyShield] Intento de pop ignorado: no dismissible.',
        );
      }
    }
  }

  /// Cierra modales en el navegador raíz con protección contra doble cierre.
  static void safeRootPop(BuildContext context) {
    if (throttle(
      'root_nav_pop_${context.hashCode}',
      cooldown: const Duration(milliseconds: 450),
    )) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
