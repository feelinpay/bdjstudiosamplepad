import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_provider.dart';
import '../services/filesystem_sync_service.dart';
import '../../features/workspace/data/repositories/isar_workspace_repository.dart';
import '../../features/workspace/presentation/providers/workspace_providers.dart';
import '../../features/pad_system/presentation/providers/pad_providers.dart';

/// Refresca las vistas de la biblioteca invalidando los providers de workspace y pads.
void refreshLibraryViews(Ref ref) {
  ref.invalidate(workspaceListProvider);
  ref.invalidate(currentWorkspaceProvider);
  ref.invalidate(padPageProvider);
}

/// Variante para llamadas desde widgets (WidgetRef).
void refreshLibraryViewsWidget(WidgetRef ref) {
  ref.invalidate(workspaceListProvider);
  ref.invalidate(currentWorkspaceProvider);
  ref.invalidate(padPageProvider);
}

/// Sincronización disco↔BD que corre DESPUÉS de mostrar la UI.
/// Devuelve cuántos elementos cambió para decidir si refrescar la vista.
final librarySyncProvider = FutureProvider<int>((ref) async {
  final isar = await ref.read(isarProvider.future);
  int changed = 0;
  try {
    changed = await FilesystemSyncService.reconcileOnStartup(isar);
    await IsarWorkspaceRepository(Future.value(isar))
        .reconcileAllPageIndexIntegrity();
  } finally {
    Zone.root.run(() {
      FilesystemSyncService.startLiveWatcher(
        isar,
        onChangesDetected: () => refreshLibraryViews(ref),
      );
    });
  }
  return changed;
});

/// Indica a la UI que hay una sincronización en curso (bloquea el modo edición).
final librarySyncInProgressProvider = Provider<bool>(
  (ref) => ref.watch(librarySyncProvider).isLoading,
);
