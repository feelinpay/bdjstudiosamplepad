import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:isar/isar.dart';

import 'app_storage_service.dart';
import 'local_audio_storage_service.dart';
import '../theme/app_colors.dart';
import '../../features/workspace/data/models/workspace_model.dart';
import '../../features/workspace/data/models/page_model.dart';
import '../../features/pad_system/data/models/pad_model.dart';

/// Servicio arquitectónico de sincronización bidireccional Disco ↔ Base de Datos.
/// Garantiza que cualquier cambio realizado externamente (desde el explorador
/// de Windows o macOS) sea reconciliado de manera segura en el sistema, numerando
/// sistemáticamente las carpetas y archivos en su posición correspondiente.
class FilesystemSyncService {
  static StreamSubscription<FileSystemEvent>? _watcherSubscription;
  static Timer? _debounceTimer;
  static bool _isSyncing = false;

  /// Fase 1: Reconciliación al arrancar.
  /// Escanea la carpeta raíz de medios en el disco duro y registra en tiempo real
  /// en la base de datos cualquier Workspace, subcarpeta o archivo de audio que
  /// haya sido agregado de forma externa desde la computadora.
  /// Devuelve el número de nuevos elementos reconciliados.
  static Future<int> reconcileOnStartup(Isar isar) async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    try {
      final mediaDir = await AppStorageService.mediaDirectory();

      int newItemsCount = 0;
      final topLevelEntities = mediaDir.listSync();
      final workspaces = await isar.workspaceModels.where().findAll();
      final wsMap = <String, WorkspaceModel>{
        for (final w in workspaces) w.name.trim().toLowerCase(): w,
      };

      for (final entity in topLevelEntities) {
        if (entity is Directory) {
          final dirName = p.basename(entity.path).trim();
          if (dirName.isEmpty || dirName.startsWith('.')) continue;

          WorkspaceModel? workspace = wsMap[dirName.toLowerCase()];
          if (workspace == null) {
            // Se encontró un Workspace nuevo creado desde el explorador de Windows
            workspace = WorkspaceModel()
              ..name = dirName
              ..createdAt = DateTime.now()
              ..isLocked = false;

            await isar.writeTxn(() async {
              await isar.workspaceModels.put(workspace!);
              final rootPage = PageModel()
                ..pageIndex = 0
                ..name = 'Página 1'
                ..columns = 4
                ..rows = 4
                ..workspace.value = workspace;
              await isar.pageModels.put(rootPage);
              await rootPage.workspace.save();
            });

            newItemsCount++;
            wsMap[dirName.toLowerCase()] = workspace;
          }

          newItemsCount += await _syncFolderRecursive(
            isar,
            workspace,
            entity,
            0,
            {entity.path},
          );
        }
      }

      // Limpieza de workspaces huérfanos: si el usuario borró la carpeta desde
      // el explorador de archivos, eliminar el workspace de la base de datos.
      // POR SEGURIDAD solo se eliminan workspaces VACÍOS (sin pads con audio):
      // si la carpeta falta pero el workspace tiene contenido, no debe borrarse
      // su estructura en BD, porque la ausencia en disco puede ser transitoria
      // (disco extraíble, sync de nube, nombre cambiado) y borrar equivaldría a
      // perder el trabajo del DJ.
      final diskDirNames = topLevelEntities
          .whereType<Directory>()
          .map((d) => p.basename(d.path).trim().toLowerCase())
          .toSet();

      for (final ws in workspaces) {
        if (diskDirNames.contains(ws.name.trim().toLowerCase())) {
          continue;
        }
        final hasContent = await _workspaceHasAudioPads(isar, ws);
        if (hasContent) {
          debugPrint(
            'FilesystemSync: carpeta de "${ws.name}" ausente en disco pero '
            'el workspace tiene contenido; se conserva en BD.',
          );
          continue;
        }
        // La carpeta de este workspace ya no existe en disco y está vacía
        await isar.writeTxn(() async {
          await ws.pages.load();
          for (final page in ws.pages.toList()) {
            await page.pads.load();
            await isar.padModels.deleteAll(
              page.pads.map((pd) => pd.id).toList(),
            );
            await isar.pageModels.delete(page.id);
          }
          await isar.workspaceModels.delete(ws.id);
        });
        newItemsCount++;
      }

      // Limpieza automática de vínculos huérfanos sin alterar ni eliminar pads
      await LocalAudioStorageService.autoCleanOrphans(isar);

      return newItemsCount;
    } catch (e) {
      debugPrint('Error durante reconciliación de archivos: $e');
      return 0;
    } finally {
      _isSyncing = false;
    }
  }

  /// Verifica si un workspace tiene al menos un pad con audio asignado.
  /// Se usa para no eliminar de la BD workspaces cuyo contenido sigue
  /// existiendo aunque su carpeta no esté presente en disco.
  static Future<bool> _workspaceHasAudioPads(
    Isar isar,
    WorkspaceModel ws,
  ) async {
    await ws.pages.load();
    for (final page in ws.pages.toList()) {
      await page.pads.load();
      for (final pad in page.pads.toList()) {
        if (pad.padTypeIndex == 0 &&
            pad.samplePath != null &&
            pad.samplePath!.isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  /// Recursivamente sincroniza el contenido del directorio en la página correspondiente,
  /// numerando los nuevos elementos justo después del último número en la misma carpeta.
  static Future<int> _syncFolderRecursive(
    Isar isar,
    WorkspaceModel workspace,
    Directory currentDir,
    int pageIndex,
    Set<String> visitedPaths,
  ) async {
    int addedCount = 0;
    final page = await isar.pageModels
        .filter()
        .workspace((w) => w.idEqualTo(workspace.id))
        .pageIndexEqualTo(pageIndex)
        .findFirst();

    if (page == null) return 0;
    await page.pads.load();

    final existingPads = page.pads.toList();
    int maxPadId = existingPads.isEmpty
        ? -1
        : existingPads.map((p) => p.padId).reduce((a, b) => a > b ? a : b);

    final folderPadsByLabel = <String, List<PadModel>>{};
    final audioPadsByName = <String, PadModel>{};
    final usedTargetPageIndexes = <int>{};

    for (final pad in existingPads) {
      if (pad.padTypeIndex == 1) {
        folderPadsByLabel.putIfAbsent(
          pad.label.trim().toLowerCase(),
          () => <PadModel>[],
        ).add(pad);
      } else if (pad.padTypeIndex == 0) {
        audioPadsByName[pad.label.trim().toLowerCase()] = pad;
        if (pad.samplePath != null) {
          final resolved = await LocalAudioStorageService.resolvePath(
            pad.samplePath!,
          );
          final base = p
              .basenameWithoutExtension(resolved)
              .trim()
              .toLowerCase();
          audioPadsByName[base] = pad;
        }
      }
    }

    final children = currentDir.listSync()
      ..sort((a, b) {
        return p
            .basename(a.path)
            .toLowerCase()
            .compareTo(p.basename(b.path).toLowerCase());
      });

    final mediaDir = await AppStorageService.mediaDirectory();
    final mediaDirPath = mediaDir.path;

    for (final child in children) {
      final name = p.basename(child.path).trim();
      if (name.startsWith('.')) continue;

      if (child is Directory) {
        if (visitedPaths.contains(child.path)) continue;
        visitedPaths.add(child.path);

        // Reutilizar el folder pad existente con este nombre cuya página
        // objetivo NO haya sido ya asociada a otra subcarpeta en esta pasada.
        // Esto evita el cross-content que ocurría cuando dos subcarpetas
        // compartían label y el lookup devolvía siempre el primero.
        final candidates = folderPadsByLabel[name.toLowerCase()] ?? [];
        int? reusedTargetIndex;
        for (final candidate in candidates) {
          final target = candidate.targetPageIndex;
          if (target == null) continue;
          if (usedTargetPageIndexes.contains(target)) continue;
          reusedTargetIndex = target;
          break;
        }

        int targetHiddenIndex;

        if (reusedTargetIndex == null) {
          // Nueva carpeta creada por el usuario externamente -> se enumera al final
          targetHiddenIndex = await _getNextHiddenIndex(isar, workspace.id);
          maxPadId++;
          usedTargetPageIndexes.add(targetHiddenIndex);

          await isar.writeTxn(() async {
            final hiddenPage = PageModel()
              ..pageIndex = targetHiddenIndex
              ..columns = page.columns
              ..rows = page.rows
              ..parentPageId = page.id
              ..workspace.value = workspace;
            await isar.pageModels.put(hiddenPage);
            await hiddenPage.workspace.save();

            final newPad = PadModel()
              ..padId = maxPadId
              ..label = name
              ..colorHex = AppColors.folderPadColor
              ..padTypeIndex = 1
              ..targetPageIndex = targetHiddenIndex
              ..triggerModeIndex = 0
              ..page.value = page;
            await isar.padModels.put(newPad);
            await newPad.page.save();
          });

          addedCount++;
        } else {
          targetHiddenIndex = reusedTargetIndex;
          usedTargetPageIndexes.add(targetHiddenIndex);
        }

        addedCount += await _syncFolderRecursive(
          isar,
          workspace,
          child,
          targetHiddenIndex,
          visitedPaths,
        );
      } else if (child is File) {
        final ext = p.extension(child.path).toLowerCase();
        if (!LocalAudioStorageService.supportedAudioExtensions.contains(ext)) {
          continue;
        }

        final cleanName = p.basenameWithoutExtension(child.path).trim();
        if (audioPadsByName.containsKey(cleanName.toLowerCase())) continue;

        // Nuevo archivo de audio agregado desde el OS -> se enumera al final
        maxPadId++;
        String relPath;
        if (child.path.startsWith(mediaDirPath)) {
          final sub = child.path
              .substring(mediaDirPath.length)
              .replaceAll('\\', '/');
          final cleanSub = sub.startsWith('/') ? sub.substring(1) : sub;
          relPath = '${LocalAudioStorageService.prefix}$cleanSub';
        } else {
          relPath = child.path;
        }

        await isar.writeTxn(() async {
          final newPad = PadModel()
            ..padId = maxPadId
            ..label = cleanName.replaceAll('_', ' ')
            ..colorHex = AppColors.audioPadPalette[maxPadId % AppColors.audioPadPalette.length]
            ..padTypeIndex = 0
            ..samplePath = relPath
            ..triggerModeIndex = 0
            ..page.value = page;
          await isar.padModels.put(newPad);
          await newPad.page.save();
        });

        audioPadsByName[cleanName.toLowerCase()] = PadModel()
          ..label = cleanName;
        addedCount++;
      }
    }

    // ── Limpieza de pads huérfanos ──
    // Si el usuario borró una subcarpeta o archivo de audio desde el explorador
    // de Windows/macOS, eliminar el pad de la base de datos.
    final diskChildDirs = children
        .whereType<Directory>()
        .map((d) => p.basename(d.path).trim().toLowerCase())
        .toSet();

    // Recargar pads después de posibles inserciones
    await page.pads.load();
    final currentPads = page.pads.toList();

    for (final pad in currentPads) {
      if (pad.padTypeIndex == 1) {
        // Pad de tipo carpeta: verificar si la carpeta aún existe en disco
        if (!diskChildDirs.contains(pad.label.trim().toLowerCase())) {
          // La carpeta fue eliminada externamente → limpiar el pad y su página oculta
          await isar.writeTxn(() async {
            if (pad.targetPageIndex != null) {
              final hiddenPage = await isar.pageModels
                  .filter()
                  .workspace((w) => w.idEqualTo(workspace.id))
                  .pageIndexEqualTo(pad.targetPageIndex!)
                  .findFirst();
              if (hiddenPage != null) {
                await _deletePageAndChildren(isar, workspace.id, hiddenPage);
              }
            }
            await isar.padModels.delete(pad.id);
          });
          addedCount++;
        }
      } else if (pad.padTypeIndex == 0 && pad.samplePath != null) {
        // Pad de audio: verificar si el archivo aún existe en disco
        try {
          final resolved = await LocalAudioStorageService.resolvePath(
            pad.samplePath!,
          );
          final file = File(resolved);
          if (!await file.exists()) {
            // El archivo de audio fue eliminado externamente → limpiar el pad
            await isar.writeTxn(() async {
              await isar.padModels.delete(pad.id);
            });
            addedCount++;
          }
        } catch (_) {
          // Si no se puede resolver la ruta, dejar el pad intacto
        }
      }
    }

    return addedCount;
  }

  /// Elimina recursivamente una página oculta y todos sus hijos (subpáginas y pads).
  static Future<void> _deletePageAndChildren(
    Isar isar,
    int workspaceId,
    PageModel page,
  ) async {
    // Buscar subpáginas que tienen esta página como padre
    final childPages = await isar.pageModels
        .filter()
        .workspace((w) => w.idEqualTo(workspaceId))
        .parentPageIdEqualTo(page.id)
        .findAll();

    for (final childPage in childPages) {
      await _deletePageAndChildren(isar, workspaceId, childPage);
    }

    // Eliminar todos los pads de esta página
    await page.pads.load();
    if (page.pads.isNotEmpty) {
      await isar.padModels.deleteAll(page.pads.map((pd) => pd.id).toList());
    }
    await isar.pageModels.delete(page.id);
  }

  static Future<int> _getNextHiddenIndex(Isar isar, int workspaceId) async {
    final pages = await isar.pageModels
        .filter()
        .workspace((w) => w.idEqualTo(workspaceId))
        .findAll();
    final hidden = pages.map((p) => p.pageIndex).where((i) => i >= 1000);
    return hidden.isEmpty ? 1000 : hidden.reduce((a, b) => a > b ? a : b) + 1;
  }

   /// Fase 2: Watcher en vivo con bajo consumo de recursos (solo Desktop).
   /// Captura cambios externos en tiempo real con un debounce configurable.
   static void startLiveWatcher(
     Isar isar, {
     VoidCallback? onChangesDetected,
     Duration debounce = const Duration(seconds: 2),
   }) async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      // En móviles (Android/iOS), para preservar batería y recursos de gama baja,
      // se utiliza exclusivamente la reconciliación en el arranque (Fase 1).
      return;
    }

    stopLiveWatcher();

    try {
      final mediaDir = await AppStorageService.mediaDirectory();

      _watcherSubscription = mediaDir.watch(recursive: true).listen((event) {
        final name = p.basename(event.path);
        if (name.startsWith('.') ||
            name.endsWith('.tmp') ||
            name.endsWith('.dat')) {
          return;
        }

        _debounceTimer?.cancel();
        _debounceTimer = Timer(debounce, () async {
          if (_isSyncing) return;
          final newCount = await reconcileOnStartup(isar);
          if (newCount > 0 && onChangesDetected != null) {
            onChangesDetected();
          }
        });
      });
    } catch (e) {
      debugPrint('No se pudo iniciar el watcher en vivo: $e');
    }
  }

  /// Detiene el watcher en vivo y limpia los temporizadores de debounce.
  static void stopLiveWatcher() {
    _watcherSubscription?.cancel();
    _watcherSubscription = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
}
