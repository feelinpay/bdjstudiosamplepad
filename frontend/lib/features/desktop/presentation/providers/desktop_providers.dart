import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/services.dart';
import '../../data/key_binding_service.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';

/// Teclas reservadas que no pueden asignarse a pads (conflicto con navegación/maestros).
final Set<int> _reservedKeyIds = {
  LogicalKeyboardKey.escape.keyId,
  LogicalKeyboardKey.keyM.keyId,
  LogicalKeyboardKey.arrowLeft.keyId,
  LogicalKeyboardKey.arrowRight.keyId,
  LogicalKeyboardKey.arrowUp.keyId,
  LogicalKeyboardKey.arrowDown.keyId,
  LogicalKeyboardKey.pageUp.keyId,
  LogicalKeyboardKey.pageDown.keyId,
  LogicalKeyboardKey.tab.keyId,
};

/// Se sobreescribe en main.dart al arrancar (SharedPreferences).
final keyBindingServiceProvider = Provider<KeyBindingService>((ref) {
  throw UnimplementedError('Must be overridden at startup');
});

/// Pad en espera de asignar tecla (modo "aprender tecla"), o null.
final keyLearnPadProvider = StateProvider<String?>((ref) => null);

/// Mapa reactivo keyId -> padId de los atajos que puso el usuario.
final keyBindingsProvider =
    StateNotifierProvider<KeyBindingsNotifier, Map<String, String>>((ref) {
      return KeyBindingsNotifier(ref.read(keyBindingServiceProvider));
    });

/// Mapa O(1) de padId -> etiqueta de tecla para la vista actual.
///
/// Los pads pertenecen a un workspace y a una vista/carpeta. Mostrar una
/// asignación de otro workspace aquí inducía a error y, peor aún, hacía creer
/// que una tecla estaba ocupada cuando no lo estaba en esta vista.
final padKeyLabelsProvider = Provider<Map<String, String>>((ref) {
  final bindings = ref.watch(keyBindingsProvider);
  final service = ref.read(keyBindingServiceProvider);
  final workspaceId = ref.watch(currentWorkspaceIdProvider);
  final pageIndex = ref.watch(currentPageIndexProvider);
  final map = <String, String>{};
  if (workspaceId == null) return map;

  for (var entry in bindings.entries) {
    final keyId = KeyBindingsNotifier.keyIdForScope(
      entry.key,
      workspaceId: workspaceId,
      pageIndex: pageIndex,
    );
    if (keyId != null && !entry.value.startsWith('action_')) {
      map[entry.value] = service.labelFor(keyId);
    }
  }
  return map;
});

class KeyBindingsNotifier extends StateNotifier<Map<String, String>> {
  final KeyBindingService _service;
  KeyBindingsNotifier(this._service) : super(_service.getAll());

  /// Clave persistida de un pad. No se usa el índice de página por sí solo:
  /// cada workspace tiene su propia raíz (índice 0) y sus propias carpetas.
  static String scopedKey({
    required int workspaceId,
    required int pageIndex,
    required String keyId,
  }) => 'pad:$workspaceId:$pageIndex:$keyId';

  static String? keyIdForScope(
    String storedKey, {
    required int workspaceId,
    required int pageIndex,
  }) {
    final prefix = 'pad:$workspaceId:$pageIndex:';
    return storedKey.startsWith(prefix)
        ? storedKey.substring(prefix.length)
        : null;
  }

  String? padForKey({
    required int workspaceId,
    required int pageIndex,
    required String keyId,
  }) =>
      state[scopedKey(
        workspaceId: workspaceId,
        pageIndex: pageIndex,
        keyId: keyId,
      )];

  /// Asigna una tecla a un pad aislado por página/carpeta, o a una acción maestra
  /// (action_stop_all, action_mute_all). Devuelve false solo si la tecla está reservada
  /// y el objetivo es un pad (no una acción maestra).
  Future<bool> bind(
    String keyId,
    String padId, {
    int workspaceId = 0,
    int pageIndex = 0,
  }) async {
    final isMasterAction = padId.startsWith('action_');

    // Reserved keys blocked only for pad bindings, not master actions
    if (!isMasterAction) {
      var keyIdInt = int.tryParse(keyId);
      if (keyIdInt != null && _reservedKeyIds.contains(keyIdInt)) {
        return false;
      }
    }

    var map = {...state};

    if (isMasterAction) {
      // Master action: remove ALL bindings for this key (scoped + unscoped)
      // so the key is exclusively assigned to the master action.
      map.removeWhere(
        (k, v) =>
            k == keyId ||
            k.endsWith(':$keyId') ||
            k.endsWith('_$keyId'), // formato legado por página
      );
      // Remove any existing binding targeting this master action
      map.removeWhere((k, v) => v == padId);
      // Store unscoped (resolver looks up plain keyId)
      map[keyId] = padId;
    } else {
      // Una acción maestra es global y tiene prioridad sobre las vistas.
      // No se elimina de manera silenciosa desde una asignación de pad.
      if (map[keyId]?.startsWith('action_') ?? false) return false;

      // Pad binding: sustituye solamente la tecla de ESTA vista de ESTE
      // workspace. La misma tecla puede reutilizarse en otro workspace o
      // carpeta sin interferencias.
      final scopedKey = KeyBindingsNotifier.scopedKey(
        workspaceId: workspaceId,
        pageIndex: pageIndex,
        keyId: keyId,
      );
      map.removeWhere((k, v) => k == scopedKey || v == padId);
      map[scopedKey] = padId;
    }

    await _service.save(map);
    state = map;
    return true;
  }

  Future<void> unbindPad(
    String padId, {
    required int workspaceId,
    required int pageIndex,
  }) async {
    var map = {...state}
      ..removeWhere(
        (k, v) =>
            v == padId &&
            keyIdForScope(k, workspaceId: workspaceId, pageIndex: pageIndex) !=
                null,
      );
    await _service.save(map);
    state = map;
  }

  Future<void> resetMasterHotkeys() async {
    var map = {...state}
      ..removeWhere((k, v) => v == 'action_stop_all' || v == 'action_mute_all');
    await _service.save(map);
    state = map;
  }

  Future<void> resetAllBindings() async {
    await _service.save({});
    state = {};
  }

  bool hasBinding(
    String padId, {
    required int workspaceId,
    required int pageIndex,
  }) => state.entries.any(
    (entry) =>
        entry.value == padId &&
        keyIdForScope(
              entry.key,
              workspaceId: workspaceId,
              pageIndex: pageIndex,
            ) !=
            null,
  );
}
