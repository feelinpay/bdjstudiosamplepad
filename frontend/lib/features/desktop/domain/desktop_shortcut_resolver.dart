import 'package:flutter/services.dart';

/// Acciones de teclado UNIVERSALES (transporte/navegacion maestro).
enum DesktopAction { stopAll, muteAll, nextPage, prevPage, none }

/// Logica pura de mapeo de teclas universales -> accion.
class DesktopShortcutResolver {
  const DesktopShortcutResolver._();

  static const String keyStopAll = 'action_stop_all';
  static const String keyMuteAll = 'action_mute_all';

  static DesktopAction resolve(
    LogicalKeyboardKey key, {
    Map<String, String>? customBindings,
  }) {
    final keyId = key.keyId.toString();

    // 1. Revisar atajos personalizados asignados por el DJ
    if (customBindings != null) {
      final boundAction = customBindings[keyId];
      if (boundAction != null) {
        if (boundAction == keyStopAll) return DesktopAction.stopAll;
        if (boundAction == keyMuteAll) return DesktopAction.muteAll;
        return DesktopAction.none;
      }

      // 1b. Si una accion maestra ya tiene una tecla PERSONALIZADA guardada,
      // su tecla por defecto queda desactivada: solo funcionan los atajos
      // guardados, no el default en paralelo (ej: mute en ESPACIO + M).
      if (customBindings.containsValue(keyStopAll) &&
          key == LogicalKeyboardKey.escape) {
        return DesktopAction.none;
      }
      if (customBindings.containsValue(keyMuteAll) &&
          key == LogicalKeyboardKey.keyM) {
        return DesktopAction.none;
      }
    }

    // 2. Teclas por defecto (solo si la accion no tiene una personalizada)
    if (key == LogicalKeyboardKey.escape) return DesktopAction.stopAll;
    if (key == LogicalKeyboardKey.keyM) return DesktopAction.muteAll;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp) {
      return DesktopAction.prevPage;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageDown) {
      return DesktopAction.nextPage;
    }
    return DesktopAction.none;
  }

  /// Nuevo indice de pagina, acotado a [0, pageCount-1].
  static int computePageIndex(
    DesktopAction action,
    int current,
    int pageCount,
  ) {
    if (pageCount <= 0) return 0;
    var next = current;
    if (action == DesktopAction.nextPage) next = current + 1;
    if (action == DesktopAction.prevPage) next = current - 1;
    return next.clamp(0, pageCount - 1);
  }
}
