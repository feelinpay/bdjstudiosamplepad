import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/services/local_audio_storage_service.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../../../workspace/data/models/page_model.dart';
import '../../data/models/pad_model.dart';
import '../../domain/entities/pad_entity.dart';
import '../../../../core/utils/concurrency_shield.dart';
import '../providers/pad_providers.dart';

/// Servicio centralizado de acciones de eliminación (Menú del botón [-]):
/// Administra borrado de Pads seleccionados, Carpetas y Workspaces.
/// Todas las confirmaciones soportan confirmación directa por teclado (Enter / NumpadEnter).
class PadDeleteActions {
  static Future<void> showDeleteMenu(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final currentIndex = ref.read(currentPageIndexProvider);
    final isFolder = currentIndex >= 1000;
    final selectedPads = ref.read(selectedPadsProvider);
    final currentPads = ref.read(padPageProvider(currentIndex)).value ?? [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'MENÚ DE ELIMINACIÓN',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),

              // 1. Eliminar Pads seleccionados (si hay selección)
              if (selectedPads.isNotEmpty) ...[
                ListTile(
                  leading: const Icon(
                    Icons.check_box_outlined,
                    color: Colors.redAccent,
                  ),
                  title: Text(
                    'Eliminar ${selectedPads.length} pad(s) seleccionado(s)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Borra únicamente los pads marcados',
                    style: TextStyle(color: Colors.grey),
                  ),
                  onTap: () async {
                    ConcurrencyShield.safePop(ctx);
                    await _deleteSelectedPads(
                      context,
                      ref,
                      selectedPads,
                      currentIndex,
                    );
                  },
                ),
                const Divider(color: Colors.white12, height: 16),
              ],

              // 2. Vaciar los pads de la página actual
              if (currentPads.isNotEmpty)
                ListTile(
                  leading: const Icon(
                    Icons.cleaning_services_rounded,
                    color: Colors.orangeAccent,
                  ),
                  title: const Text(
                    'Vaciar todos los pads de aquí',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Mantiene la carpeta pero borra todos sus contenidos',
                    style: TextStyle(color: Colors.grey),
                  ),
                  onTap: () async {
                    ConcurrencyShield.safePop(ctx);
                    await _clearAllPadsInPage(
                      context,
                      ref,
                      currentIndex,
                      currentPads,
                    );
                  },
                ),

              // 3. Eliminar la carpeta actual (si se está dentro de una carpeta)
              if (isFolder) ...[
                const Divider(color: Colors.white12, height: 16),
                ListTile(
                  leading: const Icon(
                    Icons.folder_delete_rounded,
                    color: Colors.amberAccent,
                  ),
                  title: const Text(
                    'Eliminar la carpeta completa',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Elimina esta carpeta y todas sus subcarpetas y audios',
                    style: TextStyle(color: Colors.grey),
                  ),
                  onTap: () async {
                    ConcurrencyShield.safePop(ctx);
                    await _deleteCurrentFolder(context, ref, currentIndex);
                  },
                ),
              ],

              const Divider(color: Colors.white12, height: 16),
              ListTile(
                leading: const Icon(
                  Icons.cleaning_services_rounded,
                  color: Colors.cyanAccent,
                ),
                title: const Text(
                  'Limpiar audios huérfanos del disco',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Elimina del almacenamiento del sistema los archivos .wav/.mp3 no usados por ningún pad',
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () async {
                  ConcurrencyShield.safePop(ctx);
                  await _cleanOrphanAudios(context, ref);
                },
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  static Future<bool?> _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    required String confirmText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): () =>
              ConcurrencyShield.safePop(ctx, true),
          const SingleActivator(LogicalKeyboardKey.numpadEnter): () =>
              ConcurrencyShield.safePop(ctx, true),
        },
        child: Focus(
          autofocus: true,
          child: AlertDialog(
            backgroundColor: const Color(0xFF141822),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(content, style: const TextStyle(color: Colors.grey)),
            actions: [
              TextButton(
                onPressed: () => ConcurrencyShield.safePop(ctx, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => ConcurrencyShield.safePop(ctx, true),
                child: Text(
                  confirmText,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _deleteSelectedPads(
    BuildContext context,
    WidgetRef ref,
    Set<String> selectedPads,
    int pageIndex,
  ) async {
    var ok = await _showConfirmDialog(
      context,
      title: '¿Eliminar ${selectedPads.length} pad(s)?',
      content: 'Se eliminarán los pads seleccionados.',
      confirmText: 'Eliminar',
    );
    if (ok == true) {
      await ref
          .read(padPageProvider(pageIndex).notifier)
          .deleteSelectedPads(selectedPads);
      ref.read(selectedPadsProvider.notifier).state = {};
    }
  }

  static Future<void> _clearAllPadsInPage(
    BuildContext context,
    WidgetRef ref,
    int pageIndex,
    List<PadEntity> currentPads,
  ) async {
    var ok = await _showConfirmDialog(
      context,
      title: '¿Vaciar todos los pads?',
      content: 'Se eliminarán todos los pads de esta carpeta.',
      confirmText: 'Vaciar',
    );
    if (ok == true) {
      var padIds = currentPads.map((p) => p.id).toSet();
      await ref
          .read(padPageProvider(pageIndex).notifier)
          .deleteSelectedPads(padIds);
    }
  }

  static Future<void> _deleteCurrentFolder(
    BuildContext context,
    WidgetRef ref,
    int folderPageIndex,
  ) async {
    var ok = await _showConfirmDialog(
      context,
      title: '¿Eliminar carpeta completa?',
      content: 'Se eliminará esta carpeta y todo su contenido.',
      confirmText: 'Eliminar',
    );

    if (ok == true) {
      var isar = await ref.read(isarProvider.future);
      var page = await isar.pageModels
          .filter()
          .pageIndexEqualTo(folderPageIndex)
          .findFirst();

      if (page == null) return;

      // Encontrar el pad carpeta que apunta a esta página
      var repo = ref.read(workspaceRepositoryProvider);
      final referencingPads = await isar.padModels
          .filter()
          .targetPageIndexEqualTo(page.pageIndex)
          .findFirst();
      if (referencingPads != null) {
        await referencingPads.page.load();
        final refPage = referencingPads.page.value;
        if (refPage != null) {
          await ref
              .read(padPageProvider(refPage.pageIndex).notifier)
              .deletePad(referencingPads.id.toString());
        } else {
          await repo.deletePage(page.id);
        }
      } else {
        await repo.deletePage(page.id);
      }

      // Volver a la página padre usando SafeFolderNavigator
      if (!context.mounted) return;
      SafeFolderNavigator.goBack(ref);

      await LocalAudioStorageService.autoCleanOrphans(isar);
      ref.invalidate(currentWorkspaceProvider);
      ref.invalidate(workspaceListProvider);
    }
  }

  static Future<bool> deleteWorkspace(
    BuildContext context,
    WidgetRef ref,
    int wsId,
    String wsName,
  ) async {
    var list = ref.read(workspaceListProvider).value ?? [];
    if (list.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: const Duration(seconds: 2),
          content: Text('No se puede eliminar el único workspace activo'),
        ),
      );
      return false;
    }

    var ok = await _showConfirmDialog(
      context,
      title: '¿Eliminar Workspace "$wsName"?',
      content: 'Se eliminará este workspace y todas sus carpetas.',
      confirmText: 'Eliminar',
    );

    if (ok == true) {
      var repo = ref.read(workspaceRepositoryProvider);
      var audioEngine = ref.read(audioEngineProvider);

      // Detener toda reproducción ANTES de borrar archivos del disco para
      // evitar voces huérfanas. El repo se encargará del borrado físico y de
      // los pads en la base de datos (defense-in-depth).
      audioEngine.stopAll();

      var ws = await repo.getWorkspace(wsId);
      if (ws != null) {
        await ws.pages.load();
        for (var pg in ws.pages) {
          await pg.pads.load();
          for (var pad in pg.pads) {
            audioEngine.stop(pad.id.toString());
          }
        }
      }

      // deleteWorkspace: borra pads/paginas/workspace en DB y, como
      // defense-in-depth, elimina el directorio físico + huérfagos en disco.
      await repo.deleteWorkspace(wsId);
      ref.invalidate(workspaceListProvider);
      var remaining = (await repo.getAllWorkspaces());
      if (remaining.isNotEmpty) {
        // Use safe workspace switching with request ID
        await switchWorkspaceWithRequestId(ref, remaining.first.id);
        ref.read(currentPageIndexProvider.notifier).state = 0;
      }
      return true;
    }
    return false;
  }

  static Future<void> _cleanOrphanAudios(
    BuildContext context,
    WidgetRef ref,
  ) async {
    var isar = await ref.read(isarProvider.future);
    var allPads = await isar.padModels.where().findAll();
    var activePaths = allPads
        .map((p) => p.samplePath)
        .whereType<String>()
        .toList();
    var count = await LocalAudioStorageService.cleanUnusedAudioFiles(
      activePaths,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? 'Se eliminaron $count archivos huérfanos del disco'
                : 'No se encontraron archivos huérfanos para limpiar',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
