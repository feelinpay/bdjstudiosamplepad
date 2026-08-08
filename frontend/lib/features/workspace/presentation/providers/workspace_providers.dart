import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../domain/repositories/workspace_repository.dart';
import '../../data/repositories/isar_workspace_repository.dart';
import '../../data/models/workspace_model.dart';
import '../../domain/services/workspace_exporter.dart';
import '../../domain/services/workspace_importer.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../settings/data/services/settings_service.dart';
import '../../data/models/page_model.dart';
import '../../../../core/utils/concurrency_shield.dart';
import '../../../pad_system/presentation/providers/pad_providers.dart';

final workspaceRepositoryProvider = Provider<WorkspaceRepository>((ref) {
  var isarFuture = ref.watch(isarProvider.future);
  return IsarWorkspaceRepository(isarFuture);
});

final workspaceListProvider = FutureProvider<List<WorkspaceModel>>((ref) async {
  var repo = ref.watch(workspaceRepositoryProvider);
  var settings = ref.read(settingsServiceProvider);
  var all = await repo.getAllWorkspaces();
  var order = settings.workspaceOrder;
  if (order.isEmpty) return all;

  var map = {for (var ws in all) ws.id: ws};
  var ordered = <WorkspaceModel>[];
  for (var id in order) {
    if (map.containsKey(id)) {
      ordered.add(map.remove(id)!);
    }
  }
  ordered.addAll(map.values);
  return ordered;
});

final currentWorkspaceIdProvider = StateProvider<int?>((ref) {
  final settingsService = ref.read(settingsServiceProvider);
  return settingsService.lastWorkspaceId;
});

// Track the current request ID for workspace switching
final currentWorkspaceRequestIdProvider = StateProvider<String>((ref) => '0');

final currentPageIndexProvider = StateProvider<int>((ref) {
  final settingsService = ref.read(settingsServiceProvider);
  return settingsService.lastPageIndex;
});

/// Obtiene la PageModel que corresponde al pageIndex dado (oculto o raíz).
final currentPageModelProvider = FutureProvider<PageModel?>((ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  final currentIndex = ref.watch(currentPageIndexProvider);
  if (workspace == null) return null;
  await workspace.pages.load();
  for (final page in workspace.pages) {
    if (page.pageIndex == currentIndex) return page;
  }
  return null;
});

final currentWorkspaceProvider = FutureProvider<WorkspaceModel?>((ref) async {
  var repo = ref.watch(workspaceRepositoryProvider);
  var id = ref.watch(currentWorkspaceIdProvider);
  var settingsService = ref.read(settingsServiceProvider);
  
  // Generate request ID for this specific load operation.
  // Escritura diferida: Riverpod no permite modificar otro provider durante
  // la inicializacion de este FutureProvider.
  final requestId = ConcurrencyShield.nextRequestId().toString();
  Future.microtask(() {
    ref.read(currentWorkspaceRequestIdProvider.notifier).state = requestId;
  });

  if (id != null) {
    var ws = await repo.getWorkspace(id);
    // Check if this is still the current request
    if (ref.read(currentWorkspaceRequestIdProvider) != requestId) {
      return null; // Request was superseded
    }
    if (ws != null) {
      await ws.pages.load();
      return ws;
    }
  }

  // Fallback si id es nulo o el workspace fue eliminado
  var all = await repo.getAllWorkspaces();
  // Check if this is still the current request
  if (ref.read(currentWorkspaceRequestIdProvider) != requestId) {
    return null; // Request was superseded
  }
  
  if (all.isNotEmpty) {
    final targetId = all.first.id;
    settingsService.setLastWorkspaceId(targetId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentWorkspaceIdProvider.notifier).state = targetId;
    });
    var ws = all.first;
    await ws.pages.load();
    return ws;
  } else {
    // Primer inicio: siempre hay un proyecto editable, pero no incluimos
    // samples de terceros ni contenido que el DJ no haya elegido.
    var ws = await repo.createWorkspace('Mi primer set');
    settingsService.setLastWorkspaceId(ws.id);
    // workspaceListProvider puede haberse resuelto vacio antes de que Isar
    // terminara de crear el proyecto. Sin invalidarlo, el selector superior
    // queda visualmente en blanco hasta reiniciar la aplicacion.
    ref.invalidate(workspaceListProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentWorkspaceIdProvider.notifier).state = ws.id;
    });
    await ws.pages.load();
    return ws;
  }
});

/// Helper to safely switch workspace with request ID validation
/// Export this function for use in other files
Future<void> switchWorkspaceWithRequestId(WidgetRef ref, int workspaceId) async {
  // Si ya estamos en ese workspace, NO tocar el request-id: un segundo switch
  // al mismo id clobberea el request-id de una carga en vuelo y hace que
  // currentWorkspaceProvider retorne null (workspace vacio) sin que nada lo
  // vuelva a disparar (StateNotifier no notifica si el valor es igual).
  final currentId = ref.read(currentWorkspaceIdProvider);
  if (currentId != workspaceId) {
    final requestId = ConcurrencyShield.nextRequestId().toString();
    ref.read(currentWorkspaceRequestIdProvider.notifier).state = requestId;
    ref.read(currentWorkspaceIdProvider.notifier).state = workspaceId;
  }
  // La navegación (página actual + backstack de carpetas) pertenece a un
  // workspace concreto; al cambiar de workspace debe reiniciarse para no
  // apuntar a índices de página de otro proyecto.
  ref.read(currentPageIndexProvider.notifier).state = 0;
  ref.read(folderBackStackProvider.notifier).state = <int>[];
  final settingsService = ref.read(settingsServiceProvider);
  settingsService.setLastWorkspaceId(workspaceId);
}

final workspaceExporterProvider = Provider((ref) {
  return WorkspaceExporter(ref.watch(isarProvider.future));
});

final workspaceImporterProvider = Provider((ref) {
  return WorkspaceImporter(ref.watch(isarProvider.future));
});

class WorkspaceManager extends StateNotifier<int?> {
  final WorkspaceRepository _repo;
  final SettingsService _settings;

  WorkspaceManager(this._repo, this._settings) : super(null);

  Future<void> switchWorkspace(int id) async {
    await _settings.setLastWorkspaceId(id);
  }

  Future<WorkspaceModel?> createWorkspace(String name) async {
    final all = await _repo.getAllWorkspaces();
    if (all.any((w) => w.name.toLowerCase() == name.trim().toLowerCase())) {
      return null;
    }
    return await _repo.createWorkspace(name);
  }

  Future<void> renameWorkspace(WorkspaceModel workspace, String newName) async {
    workspace.name = newName;
    await _repo.saveWorkspace(workspace);
  }
}

final workspaceManagerProvider =
    StateNotifierProvider<WorkspaceManager, int?>((ref) {
  return WorkspaceManager(
    ref.watch(workspaceRepositoryProvider),
    ref.read(settingsServiceProvider),
  );
});
