import 'package:flutter/material.dart';

/// Helper centralizado para mostrar notificaciones SnackBar en la aplicación.
///
/// Resuelve el problema de Flutter 3.44+ donde cualquier SnackBar con [action]
/// adopta `persist: true` por defecto y queda congelado indefinidamente en pantalla.
///
/// Garantiza:
/// - [persist: false] para que siempre respete el [duration].
/// - [showCloseIcon: true] para que el usuario pueda cerrarlo inmediatamente a mano.
/// - Limpieza de avisos previos vía [clearSnackBars()] antes de mostrar uno nuevo.
/// - Compatibilidad total recibiendo [BuildContext] o [ScaffoldMessengerState].
abstract final class AppSnack {
  static void show(
    dynamic target,
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
  }) {
    final ScaffoldMessengerState? messenger = switch (target) {
      BuildContext ctx => ctx.mounted ? ScaffoldMessenger.maybeOf(ctx) : null,
      ScaffoldMessengerState m => m,
      _ => null,
    };
    if (messenger == null) return;

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: action,
          duration: duration,
          persist: false,
          showCloseIcon: true,
          backgroundColor: backgroundColor,
        ),
      );
  }

  /// Limpia cualquier aviso SnackBar activo.
  static void clear(dynamic target) {
    final ScaffoldMessengerState? messenger = switch (target) {
      BuildContext ctx => ctx.mounted ? ScaffoldMessenger.maybeOf(ctx) : null,
      ScaffoldMessengerState m => m,
      _ => null,
    };
    messenger?.clearSnackBars();
  }
}

/// Observer de navegación que descarta cualquier SnackBar activo al cambiar de pantalla.
/// Evita que avisos de una pantalla (ej. Configuración) queden superpuestos en otra (ej. Pads),
/// pero ignora diálogos y modales (DialogRoute, PopupRoute, ModalBottomSheetRoute) para no
/// descartar notificaciones de éxito o progreso al cerrar un diálogo.
class SnackBarDismissNavigatorObserver extends NavigatorObserver {
  SnackBarDismissNavigatorObserver({this.scaffoldMessengerKey});

  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  void _dismissSnackBars() {
    scaffoldMessengerKey?.currentState?.clearSnackBars();
  }

  bool _isRealPageTransition(Route<dynamic>? route, Route<dynamic>? otherRoute) {
    if (route is PopupRoute || otherRoute is PopupRoute) {
      return false;
    }
    return route is PageRoute || otherRoute is PageRoute;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (_isRealPageTransition(route, previousRoute)) {
      _dismissSnackBars();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (_isRealPageTransition(route, previousRoute)) {
      _dismissSnackBars();
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (_isRealPageTransition(newRoute, oldRoute)) {
      _dismissSnackBars();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (_isRealPageTransition(route, previousRoute)) {
      _dismissSnackBars();
    }
  }
}
