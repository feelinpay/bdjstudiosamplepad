import 'package:flutter/material.dart';
import '../utils/concurrency_shield.dart';

/// Controlador reactivo para actualizar el progreso y mensajes del modal bloqueante.
class BlockingProgressController extends ChangeNotifier {
  String _message;
  int? _current;
  int? _total;

  BlockingProgressController({
    String initialMessage = '',
    int? current,
    int? total,
  })  : _message = initialMessage,
        _current = current,
        _total = total;

  String get message => _message;
  int? get current => _current;
  int? get total => _total;

  double? get progressFraction {
    if (_total != null && _total! > 0 && _current != null) {
      return (_current! / _total!).clamp(0.0, 1.0);
    }
    return null;
  }

  void update({
    String? message,
    int? current,
    int? total,
  }) {
    var changed = false;
    if (message != null && message != _message) {
      _message = message;
      changed = true;
    }
    if (current != null && current != _current) {
      _current = current;
      changed = true;
    }
    if (total != null && total != _total) {
      _total = total;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  void updateProgress(int current, int total, [String? message]) {
    update(current: current, total: total, message: message);
  }

  void updateCount(int current, [String? message]) {
    update(current: current, message: message);
  }
}

/// Diálogo modal bloqueante que previene navegación y toques accidentales
/// durante operaciones pesadas en disco o base de datos.
///
/// Implementa `barrierDismissible: false` y `PopScope(canPop: false)`, garantizando
/// que ni el fondo ni el botón/gesto Atrás de Android puedan descartarlo.
class BlockingProgressDialog extends StatelessWidget {
  final String title;
  final BlockingProgressController controller;

  const BlockingProgressDialog({
    super.key,
    required this.title,
    required this.controller,
  });

  /// Ejecuta [task] mostrando el diálogo bloqueante mientras está en curso.
  ///
  /// Garantiza mediante `try / finally` que el diálogo **siempre** se cierra
  /// al terminar o si ocurre un error, sin dejar la app bloqueada.
  static Future<T> run<T>(
    BuildContext context, {
    required String title,
    String? initialMessage,
    required Future<T> Function(BlockingProgressController progress) task,
  }) async {
    final controller = BlockingProgressController(
      initialMessage: initialMessage ?? 'Por favor espere...',
    );

    var dialogOpen = true;

    // Mostrar modal bloqueante
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => BlockingProgressDialog(
        title: title,
        controller: controller,
      ),
    ).then((_) {
      dialogOpen = false;
    });

    try {
      return await task(controller);
    } finally {
      if (dialogOpen && context.mounted) {
        ConcurrencyShield.safeRootPop(context);
      }
      controller.dispose();
    }
  }

  /// Muestra el diálogo manualmente devolviendo una función de cierre.
  /// Preferir [run] siempre que sea posible.
  static void Function() show(
    BuildContext context, {
    required String title,
    required BlockingProgressController controller,
  }) {
    var dialogOpen = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => BlockingProgressDialog(
        title: title,
        controller: controller,
      ),
    ).then((_) {
      dialogOpen = false;
    });

    return () {
      if (dialogOpen && context.mounted) {
        ConcurrencyShield.safeRootPop(context);
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E222D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        content: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final fraction = controller.progressFraction;
            final current = controller.current;
            final total = controller.total;
            final message = controller.message;

            String subtitleText = message;
            if (current != null && total != null && total > 0) {
              final countText = '$current de $total';
              subtitleText = message.isNotEmpty ? '$message ($countText)' : countText;
            } else if (current != null && current > 0) {
              final countText = '$current procesado(s)...';
              subtitleText = message.isNotEmpty ? '$message ($countText)' : countText;
            }

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    value: fraction,
                    strokeWidth: 3,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                    backgroundColor: fraction != null ? Colors.white12 : null,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitleText,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
