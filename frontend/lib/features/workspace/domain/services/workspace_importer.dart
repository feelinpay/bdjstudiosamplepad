import 'dart:io';
import 'package:isar/isar.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../../data/models/workspace_model.dart';
import '../../data/models/page_model.dart';
import '../../../pad_system/data/models/pad_model.dart';
import '../../../../core/services/app_storage_service.dart';
import '../../../../core/services/local_audio_storage_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Nodo del árbol de carpetas: subcarpetas + archivos de audio.
class _TreeNode {
  _TreeNode(this.children, this.audioFiles);

  final Map<String, _TreeNode> children;
  final List<String> audioFiles;
}

/// Importa una CARPETA común (como el explorador de archivos) convirtiéndola
/// en un Workspace. El workspace es una carpeta raíz dentro de la biblioteca
/// de medios: la estructura de subcarpetas se respeta tal cual, cada subcarpeta
/// se convierte en un pad-carpeta (con su página interna oculta) y cada archivo
/// de audio en un pad de sonido.
class WorkspaceImporter {
  final Future<Isar> dbFuture;

  WorkspaceImporter(this.dbFuture);

  static const String _legacyImportNamespace = 'workspace_imports';

  static const int _folderPadColor = AppColors.folderPadColor;

  /// Paleta de colores usada por la app al agregar pads con audio
  /// (mismo formato que `addPads` en pad_providers).
  static const List<int> _padPalette = AppColors.audioPadPalette;

  /// Copia la carpeta [sourcePath] a la biblioteca de medios como un nuevo
  /// Workspace y construye su estructura en la base de datos.
  /// Devuelve el Workspace recién importado o `null` si falla.
  Future<WorkspaceModel?> importWorkspace(String sourcePath) async {
    Directory? stagingDir;
    try {
      final source = Directory(sourcePath);
      if (!await source.exists()) return null;

      final hasContent = await _hasImportableContent(source);
      if (!hasContent) return null;

      final isar = await dbFuture;
      final mediaDir = await AppStorageService.mediaDirectory();

      // Limpieza de la estructura heredada de versiones anteriores que
      // creaba un falso Workspace llamado "workspace_imports".
      await _removeLegacyImportNamespace(mediaDir);
      await _removeLegacyImportWorkspaces(isar);

      final dbNames = (await isar.workspaceModels.where().findAll())
          .map((w) => w.name)
          .toSet();
      final targetName =
          await _uniqueFolderName(mediaDir, dbNames, p.basename(source.path));
      
      // Use staging directory for atomic commit
      stagingDir = Directory(p.join(mediaDir.path, '${targetName}_staging_${DateTime.now().millisecondsSinceEpoch}'));
      
      // Copy to staging directory first
      await _copyRecursive(source, stagingDir);

      final tree = _readTree(stagingDir, '');

      // Build database structure (transactional)
      final workspace = await _buildDatabaseStructure(
        isar,
        targetName,
        tree,
      );

      if (workspace == null) {
        // Database build failed, return null
        return null;
      }

      // Atomic commit: rename staging to final target
      final target = Directory(p.join(mediaDir.path, targetName));
      if (await target.exists()) {
        await target.delete(recursive: true);
      }
      await stagingDir.rename(target.path);
      stagingDir = null; // Don't delete on success

      return workspace;
    } catch (e) {
      debugPrint('Import Error: $e');
      // Rollback: clean up staging directory
      if (stagingDir != null && await stagingDir.exists()) {
        try {
          await stagingDir.delete(recursive: true);
          debugPrint('Import rollback: cleaned up staging directory');
        } catch (cleanupError) {
          debugPrint('Import rollback cleanup failed: $cleanupError');
        }
      }
      return null;
    }
  }

  /// Verifica que la carpeta contenga al menos un archivo de audio.
  Future<bool> _hasImportableContent(Directory source) async {
    try {
      await for (final entity in source.list(recursive: true)) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (LocalAudioStorageService.supportedAudioExtensions.contains(ext)) return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Copia la carpeta preservando la estructura de subcarpetas (aunque estén
  /// vacías) y solo los archivos de audio.
  Future<void> _copyRecursive(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      if (entity is Directory) {
        await _copyRecursive(entity, Directory(p.join(target.path, name)));
      } else if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (LocalAudioStorageService.supportedAudioExtensions.contains(ext)) {
          await entity.copy(p.join(target.path, name));
        }
      }
    }
  }

  /// Lee la estructura de carpetas del destino (relativo al workspace).
  _TreeNode _readTree(Directory dir, String relDir) {
    final children = <String, _TreeNode>{};
    final audioFiles = <String>[];
    try {
      for (final entity in dir.listSync()) {
        final name = p.basename(entity.path);
        if (name.startsWith('.')) continue;
        if (entity is Directory) {
          final childRel = relDir.isEmpty ? name : '$relDir/$name';
          children[name] = _readTree(entity, childRel);
        } else if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (LocalAudioStorageService.supportedAudioExtensions.contains(ext)) {
            audioFiles.add(name);
          }
        }
      }
    } catch (e) {
      debugPrint('Error leyendo estructura: $e');
    }
    return _TreeNode(children, audioFiles);
  }

  /// Construye en la base de datos el Workspace, sus páginas (raíz + ocultas)
  /// y sus pads (carpetas y audios) respetando la estructura importada.
  Future<WorkspaceModel?> _buildDatabaseStructure(
    Isar isar,
    String workspaceName,
    _TreeNode rootNode,
  ) async {
    // Recorrido en pre-orden: los padres siempre se crean antes que los hijos.
    final dirs = <String>[];
    final nodes = <_TreeNode>[];
    void visit(String rel, _TreeNode node) {
      dirs.add(rel);
      nodes.add(node);
      final subNames = node.children.keys.toList()..sort();
      for (final sub in subNames) {
        final childRel = rel.isEmpty ? sub : '$rel/$sub';
        visit(childRel, node.children[sub]!);
      }
    }

    visit('', rootNode);

    WorkspaceModel? workspace;
    try {
      await isar.writeTxn(() async {
        workspace = WorkspaceModel()
          ..name = workspaceName
          ..createdAt = DateTime.now();
        await isar.workspaceModels.put(workspace!);

        final rootPage = PageModel()
          ..pageIndex = 0
          ..name = 'Página 1'
          ..columns = 4
          ..rows = 4
          ..workspace.value = workspace;
        await isar.pageModels.put(rootPage);
        await rootPage.workspace.save();

        final pageByDir = <String, PageModel>{'': rootPage};
        var hiddenIndex = 1000;

        for (var i = 1; i < dirs.length; i++) {
          final rel = dirs[i];
          final parentRel = rel.contains('/')
              ? rel.substring(0, rel.lastIndexOf('/'))
              : '';
          final parentPage = pageByDir[parentRel];
          if (parentPage == null) continue;

          final page = PageModel()
            ..pageIndex = hiddenIndex++
            ..name = p.basename(rel)
            ..columns = 4
            ..rows = 4
            ..parentPageId = parentPage.id
            ..workspace.value = workspace;
          await isar.pageModels.put(page);
          await page.workspace.save();
          pageByDir[rel] = page;
        }

        for (var i = 0; i < dirs.length; i++) {
          final rel = dirs[i];
          final node = nodes[i];
          final page = pageByDir[rel]!;
          var padIdCounter = 0;
          var audioIndex = 0;

          final subNames = node.children.keys.toList()..sort();
          for (final sub in subNames) {
            final childRel = rel.isEmpty ? sub : '$rel/$sub';
            final childPage = pageByDir[childRel];
            if (childPage == null) continue;
            final folderPad = PadModel()
              ..padId = padIdCounter++
              ..label = sub
              ..colorHex = _folderPadColor
              ..padTypeIndex = 1
              ..targetPageIndex = childPage.pageIndex
              ..triggerModeIndex = 0
              ..page.value = page;
            await isar.padModels.put(folderPad);
            await folderPad.page.save();
          }

          for (final audioName in node.audioFiles) {
            final relPath =
                rel.isEmpty ? audioName : '$rel/${audioName.replaceAll('\\', '/')}';
            final audioPad = PadModel()
              ..padId = padIdCounter++
              ..label = _cleanLabel(audioName)
              ..colorHex = _padPalette[audioIndex % _padPalette.length]
              ..padTypeIndex = 0
              ..samplePath =
                  '${LocalAudioStorageService.prefix}$workspaceName/$relPath'
              ..triggerModeIndex = 0
              ..page.value = page;
            await isar.padModels.put(audioPad);
            await audioPad.page.save();
            audioIndex++;
          }
        }
      });
    } catch (e) {
      debugPrint('Database build failed: $e');
      throw Exception('Database structure build failed: $e'); // Throw to trigger rollback
    }
    return workspace;
  }

  static String _cleanLabel(String fileName) {
    return p.basenameWithoutExtension(fileName).replaceAll('_', ' ').trim();
  }

  Future<String> _uniqueFolderName(
    Directory mediaDir,
    Set<String> dbNames,
    String base,
  ) async {
    var name = base.trim().isEmpty ? 'Workspace importado' : base.trim();
    var n = 2;
    bool used(String candidate) =>
        dbNames.contains(candidate) ||
        Directory(p.join(mediaDir.path, candidate)).existsSync();
    while (used(name)) {
      name = '$base ${n++}';
    }
    return name;
  }

  /// Elimina la carpeta `workspace_imports` creada por versiones anteriores.
  Future<void> _removeLegacyImportNamespace(Directory mediaDir) async {
    final legacy = Directory(p.join(mediaDir.path, _legacyImportNamespace));
    if (await legacy.exists()) {
      try {
        await legacy.delete(recursive: true);
      } catch (e) {
        debugPrint('No se pudo limpiar workspace_imports heredado: $e');
      }
    }
  }

  /// Elimina de la base de datos los Workspaces cuyos pads apuntan a la
  /// carpeta `workspace_imports` que ya no existe en disco (imports rotos de
  /// versiones anteriores). Así el import puede reutilizar el nombre limpio.
  Future<void> _removeLegacyImportWorkspaces(Isar isar) async {
    final workspaces = await isar.workspaceModels.where().findAll();
    for (final ws in workspaces) {
      await ws.pages.load();
      var isLegacy = false;
      for (final page in ws.pages.toList()) {
        await page.pads.load();
        for (final pad in page.pads.toList()) {
          if ((pad.samplePath ?? '').contains(
            '$_legacyImportNamespace/',
          )) {
            isLegacy = true;
            break;
          }
        }
        if (isLegacy) break;
      }
      if (!isLegacy) continue;

      await isar.writeTxn(() async {
        for (final page in ws.pages.toList()) {
          await page.pads.load();
          await isar.padModels
              .deleteAll(page.pads.map((p) => p.id).toList());
          await isar.pageModels.delete(page.id);
        }
        await isar.workspaceModels.delete(ws.id);
      });
    }
  }
}
