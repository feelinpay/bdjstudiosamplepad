import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:isar_community/isar.dart';

import 'app_storage_service.dart';
import 'local_audio_storage_service.dart';
import '../theme/app_colors.dart';
import '../utils/library_write_lock.dart';
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
  static int _suspendCount = 0;
  static final Set<String> _pendingAffectedDirs = {};

  /// Indica si el watcher está actualmente suspendido.
  static bool get isSuspended => _suspendCount > 0;

  /// Suspende temporalmente el procesamiento de eventos del watcher.
  /// Contador anidable: cada llamada a [suspend] debe tener su correspondiente [resume].
  static void suspend() {
    _suspendCount++;
  }

  /// Reanuda el procesamiento de eventos del watcher. Al llegar a 0 el contador,
  /// reconcilia únicamente los directorios de workspace acumulados durante la suspensión.
  static Future<int> resume([
    Isar? isar,
    VoidCallback? onChangesDetected,
  ]) async {
    if (_suspendCount > 0) {
      _suspendCount--;
    }
    if (_suspendCount == 0 && _pendingAffectedDirs.isNotEmpty && isar != null) {
      final dirsToSync = Set<String>.from(_pendingAffectedDirs);
      _pendingAffectedDirs.clear();
      int totalNew = 0;
      for (final dir in dirsToSync) {
        totalNew += await reconcileWorkspaceDir(isar, dir);
      }
      if (totalNew > 0 && onChangesDetected != null) {
        onChangesDetected();
      }
      return totalNew;
    }
    return 0;
  }

  /// Reconcilia únicamente el Workspace especificado por [dirName] (directorio de primer nivel).
  static Future<int> reconcileWorkspaceDir(Isar isar, String dirName) =>
      LibraryWriteLock.run(() => _reconcileWorkspaceDirInternal(isar, dirName));

  static Future<int> _reconcileWorkspaceDirInternal(
    Isar isar,
    String dirName,
  ) async {
    final cleanName = dirName.trim();
    if (cleanName.isEmpty || cleanName.startsWith('.')) return 0;
    if (LocalAudioStorageService.isInternalMediaDirName(cleanName)) return 0;

    final mediaDir = await AppStorageService.mediaDirectory();
    final wsDir = Directory(p.join(mediaDir.path, cleanName));

    int newItemsCount = 0;
    if (await wsDir.exists()) {
      WorkspaceModel? workspace = await isar.workspaceModels
          .filter()
          .nameEqualTo(cleanName, caseSensitive: false)
          .findFirst();

      if (workspace == null) {
        workspace = WorkspaceModel()
          ..name = cleanName
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
      }

      try {
        newItemsCount += await _syncFolderRecursive(
          isar,
          workspace,
          wsDir,
          0,
          {wsDir.path},
        );
      } catch (e) {
        debugPrint('FilesystemSync: no se pudo sincronizar "$cleanName": $e');
      }
    } else {
      // La carpeta de este workspace ya no existe en disco.
      final workspace = await isar.workspaceModels
          .filter()
          .nameEqualTo(cleanName, caseSensitive: false)
          .findFirst();
      if (workspace != null) {
        final hasContent = await _workspaceHasAudioPads(isar, workspace);
        if (hasContent) {
          debugPrint(
            'FilesystemSync: carpeta de "${workspace.name}" ausente en disco pero '
            'el workspace tiene contenido; se conserva en BD.',
          );
        } else {
          await isar.writeTxn(() async {
            await workspace.pages.load();
            for (final page in workspace.pages.toList()) {
              await page.pads.load();
              await isar.padModels.deleteAll(
                page.pads.map((pd) => pd.id).toList(),
              );
              await isar.pageModels.delete(page.id);
            }
            await isar.workspaceModels.delete(workspace.id);
          });
          newItemsCount++;
        }
      }
    }
    return newItemsCount;
  }

  /// Fase 1: Reconciliación al arrancar.
  /// Escanea la carpeta raíz de medios en el disco duro y registra en tiempo real
  /// en la base de datos cualquier Workspace, subcarpeta o archivo de audio que
  /// haya sido agregado de forma externa desde la computadora.
  /// Devuelve el número de nuevos elementos reconciliados.
  static Future<int> reconcileOnStartup(Isar isar) =>
      LibraryWriteLock.run(() => _reconcileOnStartupInternal(isar));

  static Future<int> _reconcileOnStartupInternal(Isar isar) async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    try {
      final mediaDir = await AppStorageService.mediaDirectory();

      int newItemsCount = 0;
      final topLevelEntities = await mediaDir.list().toList();
      final workspaces = await isar.workspaceModels.where().findAll();

      final diskDirNames = <String>{};
      for (final entity in topLevelEntities) {
        if (entity is Directory) {
          final dirName = p.basename(entity.path).trim();
          if (dirName.isEmpty || dirName.startsWith('.')) continue;
          if (LocalAudioStorageService.isInternalMediaDirName(dirName)) {
            continue;
          }
          diskDirNames.add(dirName.toLowerCase());
          newItemsCount += await _reconcileWorkspaceDirInternal(isar, dirName);
        }
      }

      // Limpieza de workspaces huérfanos que no estén en disco
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

  /// Verifica si el contenido de un pad-carpeta todavía existe en disco
  /// (audios o subcarpetas con audio). Se usa para no borrar carpetas
  /// importadas cuya data física vive en `folder_imports/` y no dentro de la
  /// carpeta física del workspace.
  static Future<bool> _folderContentExists(
    Isar isar,
    WorkspaceModel workspace,
    PadModel folderPad,
  ) async {
    if (folderPad.targetPageIndex == null) return false;

    final rootPage = await workspace.pages
        .filter()
        .pageIndexEqualTo(folderPad.targetPageIndex!)
        .findFirst();
    if (rootPage == null) return false;

    final pagesToVisit = <PageModel>[rootPage];
    final visited = <int>{};
    while (pagesToVisit.isNotEmpty) {
      final page = pagesToVisit.removeLast();
      if (!visited.add(page.id)) continue;
      await page.pads.load();
      for (final pad in page.pads.toList()) {
        if (pad.padTypeIndex == 0 && pad.samplePath != null) {
          try {
            final resolved = LocalAudioStorageService.resolvePathSync(
              pad.samplePath!,
            );
            if (await File(resolved).exists()) return true;
          } catch (_) {
            // No se puede resolver la ruta: no lo tratamos como contenido vivo.
          }
        } else if (pad.padTypeIndex == 1 && pad.targetPageIndex != null) {
          final childPage = await workspace.pages
              .filter()
              .pageIndexEqualTo(pad.targetPageIndex!)
              .findFirst();
          if (childPage != null) pagesToVisit.add(childPage);
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
    final page = await workspace.pages
        .filter()
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
          final resolved = LocalAudioStorageService.resolvePathSync(
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

    final children = await currentDir.list().toList()
      ..sort((a, b) {
        return p
            .basename(a.path)
            .toLowerCase()
            .compareTo(p.basename(b.path).toLowerCase());
      });

    final mediaDir = await AppStorageService.mediaDirectory();
    final mediaDirPath = mediaDir.path;
    final newAudioPads = <PadModel>[];

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
          targetHiddenIndex = await _getNextHiddenIndex(workspace);
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

        final newPad = PadModel()
          ..padId = maxPadId
          ..label = cleanName.replaceAll('_', ' ')
          ..colorHex = AppColors.audioPadPalette[maxPadId % AppColors.audioPadPalette.length]
          ..padTypeIndex = 0
          ..samplePath = relPath
          ..triggerModeIndex = 0
          ..page.value = page;

        newAudioPads.add(newPad);
        audioPadsByName[cleanName.toLowerCase()] = newPad;
        addedCount++;
      }
    }

    if (newAudioPads.isNotEmpty) {
      const batchSize = 500;
      for (var i = 0; i < newAudioPads.length; i += batchSize) {
        final end = (i + batchSize < newAudioPads.length)
            ? i + batchSize
            : newAudioPads.length;
        final batch = newAudioPads.sublist(i, end);
        await isar.writeTxn(() async {
          await isar.padModels.putAll(batch);
          for (final pad in batch) {
            await pad.page.save();
          }
        });
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
        // Pad de tipo carpeta: solo se elimina si el usuario lo borró de verdad
        // desde el explorador. Las carpetas importadas pueden no tener
        // subcarpeta física en el workspace (su audio vive en folder_imports/),
        // así que se verifica además que su contenido ya no exista en disco.
        if (!diskChildDirs.contains(pad.label.trim().toLowerCase())) {
          final stillHasContent = await _folderContentExists(
            isar,
            workspace,
            pad,
          );
          if (stillHasContent) continue;
          // La carpeta fue eliminada externamente → limpiar el pad y su página oculta
          await isar.writeTxn(() async {
            if (pad.targetPageIndex != null) {
              final hiddenPage = await workspace.pages
                  .filter()
                  .pageIndexEqualTo(pad.targetPageIndex!)
                  .findFirst();
              if (hiddenPage != null) {
                await _deletePageAndChildren(isar, workspace, hiddenPage);
              }
            }
            await isar.padModels.delete(pad.id);
          });
          addedCount++;
        }
      } else if (pad.padTypeIndex == 0 && pad.samplePath != null) {
        // Pad de audio: verificar si el archivo aún existe en disco
        try {
          final resolved = LocalAudioStorageService.resolvePathSync(
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
    WorkspaceModel workspace,
    PageModel page,
  ) async {
    // Buscar subpáginas que tienen esta página como padre
    final childPages = await workspace.pages
        .filter()
        .parentPageIdEqualTo(page.id)
        .findAll();

    for (final childPage in childPages) {
      await _deletePageAndChildren(isar, workspace, childPage);
    }

    // Eliminar todos los pads de esta página
    await page.pads.load();
    if (page.pads.isNotEmpty) {
      await isar.padModels.deleteAll(page.pads.map((pd) => pd.id).toList());
    }
    await isar.pageModels.delete(page.id);
  }

  static Future<int> _getNextHiddenIndex(WorkspaceModel workspace) async {
    final hidden = await workspace.pages
        .filter()
        .pageIndexGreaterThan(999)
        .findAll();
    return hidden.isEmpty
        ? 1000
        : hidden.map((p) => p.pageIndex).reduce((a, b) => a > b ? a : b) + 1;
  }

   /// Fase 2: Watcher en vivo con bajo consumo de recursos (solo Desktop).
   /// Captura cambios externos en tiempo real con un debounce configurable
   /// y reconcilia de forma incremental únicamente los workspaces afectados.
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

        bool added = false;
        final srcTop = _extractTopDir(event.path, mediaDir.path);
        if (srcTop != null) {
          _pendingAffectedDirs.add(srcTop);
          added = true;
        }
        if (event is FileSystemMoveEvent && event.destination != null) {
          final destTop = _extractTopDir(event.destination!, mediaDir.path);
          if (destTop != null) {
            _pendingAffectedDirs.add(destTop);
            added = true;
          }
        }

        if (!added && _pendingAffectedDirs.isEmpty) return;

        // Si está suspendido por una importación en curso, no disparamos debounce.
        // Los directorios permanecen en _pendingAffectedDirs y se procesarán en resume().
        if (_suspendCount > 0) return;

        _debounceTimer?.cancel();
        _debounceTimer = Timer(debounce, () {
          Zone.root.run(() async {
            if (_suspendCount > 0 || _isSyncing) return;
            if (_pendingAffectedDirs.isEmpty) return;
            final dirsToSync = Set<String>.from(_pendingAffectedDirs);
            _pendingAffectedDirs.clear();
            int totalNew = 0;
            for (final dir in dirsToSync) {
              totalNew += await reconcileWorkspaceDir(isar, dir);
            }
            if (totalNew > 0 && onChangesDetected != null) {
              onChangesDetected();
            }
          });
        });
      });
    } catch (e) {
      debugPrint('No se pudo iniciar el watcher en vivo: $e');
    }
  }

  static String? _extractTopDir(String eventPath, String mediaDirPath) {
    String? candidate;
    if (p.isWithin(mediaDirPath, eventPath)) {
      final rel = p
          .relative(eventPath, from: mediaDirPath)
          .replaceAll('\\', '/');
      if (LocalAudioStorageService.isInternalMediaDirPath(rel)) return null;
      final segments = rel.split('/');
      if (segments.isNotEmpty && segments.first.isNotEmpty) {
        candidate = segments.first.trim();
      }
    } else {
      final base = p.basename(eventPath).trim();
      candidate = base;
    }

    if (candidate == null || candidate.isEmpty || candidate.startsWith('.')) {
      return null;
    }
    if (candidate.endsWith('.tmp') || candidate.endsWith('.dat')) {
      return null;
    }
    if (LocalAudioStorageService.isInternalMediaDirName(candidate)) {
      return null;
    }
    final ext = p.extension(candidate).toLowerCase();
    if (ext.isNotEmpty &&
        LocalAudioStorageService.supportedAudioExtensions.contains(ext)) {
      return null;
    }
    return candidate;
  }

  /// Detiene el watcher en vivo y limpia los temporizadores de debounce y colas pendientes.
  static void stopLiveWatcher() {
    _watcherSubscription?.cancel();
    _watcherSubscription = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingAffectedDirs.clear();
  }

  /// Restablece el estado estático del servicio para entornos de prueba.
  @visibleForTesting
  static void resetForTesting() {
    stopLiveWatcher();
    _isSyncing = false;
    _suspendCount = 0;
    _pendingAffectedDirs.clear();
  }
}
