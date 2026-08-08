import 'trigger_mode.dart';
import '../../features/pad_system/domain/entities/pad_entity.dart';

/// Acción resuelta por la máquina de estados del pad ante un evento de entrada.
enum PadAction { play, stop, none }

/// Lógica pura (sin dependencias de Riverpod/Isar/Audio nativo) que decide
/// qué debe ocurrir cuando un pad recibe un evento touch-down o touch-up,
/// en función de su [TriggerMode] y su [PadState] actual.
///
/// Centralizar esta decisión permite:
/// - Testear la máquina de estados de forma determinista (Fase 11.1).
/// - Evitar duplicar los "magic booleans" en los notifiers.
class PadTriggerResolver {
  const PadTriggerResolver._();

  /// Decide la acción al presionar el pad (touch-down).
  ///
  /// - Toggle en estado playing -> detiene (segundo toque).
  /// - Cualquier otro caso -> reproduce.
  static PadAction onDown(TriggerMode mode, PadState currentState) {
    if ((mode == TriggerMode.toggle || mode == TriggerMode.loop) &&
        currentState == PadState.playing) {
      return PadAction.stop;
    }
    return PadAction.play;
  }

  /// Decide la acción al soltar el pad (touch-up).
  ///
  /// - Gate y Hold -> detienen al soltar.
  /// - One Shot, Loop y Toggle -> ignoran el touch-up.
  static PadAction onUp(TriggerMode mode) {
    if (mode == TriggerMode.gate || mode == TriggerMode.hold) {
      return PadAction.stop;
    }
    return PadAction.none;
  }

  /// Estado resultante tras aplicar [action] (útil para el notifier).
  static PadState resolveState(PadAction action, PadState fallback) {
    switch (action) {
      case PadAction.play:
        return PadState.playing;
      case PadAction.stop:
        return PadState.idle;
      case PadAction.none:
        return fallback;
    }
  }
}
