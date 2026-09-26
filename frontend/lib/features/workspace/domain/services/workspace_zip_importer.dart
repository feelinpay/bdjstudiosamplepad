import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

import '../../../../core/services/app_storage_service.dart';
import '../../../../core/services/filesystem_sync_service.dart';
import '../../../../core/services/local_audio_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/library_write_lock.dart';
import '../../../../core/utils/zip_utils.dart';
import '../../../pad_system/data/models/pad_model.dart';
import '../../data/models/page_model.dart';
import '../../data/models/workspace_model.dart';

/// Importa un archivo `.sppworkspace` completo generado en cualquier plataforma
/// (Windows, macOS o Android) y lo reconstruye en la base de datos local
/// preservando la jerarquía de páginas/carpetas, los audios y las imágenes de pads.
///
/// La extracción se realiza en streaming hacia un directorio temporal de staging
/// (sin cargar el ZIP ni los audios completos en memoria RAM), garantizando
/// inmunidad contra Out-Of-Memory en dispositivos móviles.
class WorkspaceZipImporter {
  final Future<Isar> dbFuture;

  static const String supportedFormat = 'bdj-studio-sample-pad-workspace';
  static const int currentVersion = 1;

  WorkspaceZipImporter(this.dbFuture);

  /// Lee y descomprime el archivo .sppworkspace en staging y lo importa.
  Future<WorkspaceModel?> importFromZipFile(
    String filePath, {
    void Function(int current, int total)? onProgress,
  }) =>
      LibraryWriteLock.run(() async {
    FilesystemSyncService.suspend();
    Isar? isarInstance;
    final file = File(filePath);
    if (!await file.exists()) {
      await FilesystemSyncService.resume();
      debugPrint('[WorkspaceZipImporter] El archivo no existe: $filePath');
      return null;
    }

    final work = await AppStorageService.workDirectory('workspace_import');
    final stagingDir = Directory(p.join(work.path, 'staging'));
    await stagingDir.create(recursive: true);

    Directory? createdWorkspaceDir;

    try {
      final isar = await dbFuture;
      isarInstance = isar;
      // 1. Descomprimir en isolate directamente a disco (sin cargar en RAM)
      await compute(
        extractZipInIsolate,
        ExtractZipArgs(zipPath: filePath, targetDir: stagingDir.path),
      );

      final metadataFile = File(p.join(stagingDir.path, 'metadata.json'));
      if (!await metadataFile.exists()) {
        debugPrint('[WorkspaceZipImporter] Archivo inválido: falta metadata.json');
        return null;
      }

      final metadataRaw = await metadataFile.readAsString();
      final metadata = jsonDecode(metadataRaw) as Map<String, dynamic>;

      // 2. Validación de formato y versión
      final format = metadata['format'] as String?;
      final version = metadata['version'] as int?;

      if (format != null && format != supportedFormat) {
        debugPrint(
          '[WorkspaceZipImporter] Formato incompatible: "$format" (se esperaba "$supportedFormat")',
        );
        return null;
      }

      if (version != null && version > currentVersion) {
        debugPrint(
          '[WorkspaceZipImporter] Versión $version no soportada. Requiere actualizar la aplicación.',
        );
        return null;
      }

      final wsMeta = metadata['workspace'] as Map<String, dynamic>?;
      if (wsMeta == null) {
        debugPrint('[WorkspaceZipImporter] Metadata no contiene sección workspace');
        return null;
      }

      final baseWsName = (wsMeta['name'] as String?)?.trim();
      if (baseWsName == null || baseWsName.isEmpty) {
        debugPrint('[WorkspaceZipImporter] Nombre de workspace inválido');
        return null;
      }

      // 3. Nombre único de workspace
      final existingNames = (await isar.workspaceModels.where().findAll())
          .map((w) => w.name.toLowerCase().trim())
          .toSet();

      var uniqueWsName = baseWsName;
      var suffix = 1;
      while (existingNames.contains(uniqueWsName.toLowerCase().trim())) {
        uniqueWsName = '$baseWsName ($suffix)';
        suffix++;
      }

      final cleanNamespace =
          LocalAudioStorageService.sanitizeSegment(uniqueWsName);

      // 4. Directorio de destino para audios dentro de Assets/Audio/<Workspace>
      final audiosBaseDir = await AppStorageService.mediaDirectory();
      final wsDir = Directory(p.join(audiosBaseDir.path, cleanNamespace));
      await wsDir.create(recursive: true);
      createdWorkspaceDir = wsDir;

      final audioMapping = <String, String>{}; // mediaName -> app_local:// URI

      final mediaStagingDir = Directory(p.join(stagingDir.path, 'media'));
      if (await mediaStagingDir.exists()) {
        final entries =
            (await mediaStagingDir.list().toList()).whereType<File>().toList();
        final totalFiles = entries.length;
        var copiedFiles = 0;
        onProgress?.call(0, totalFiles > 0 ? totalFiles : 1);

        for (final srcFile in entries) {
          final fileName = p.basename(srcFile.path);
          final destAudioFile = File(p.join(wsDir.path, fileName));
          await srcFile.copy(destAudioFile.path);
          final relPosix = '$cleanNamespace/$fileName';
          audioMapping[fileName] =
              '${LocalAudioStorageService.prefix}$relPosix';
          copiedFiles++;
          onProgress?.call(copiedFiles, totalFiles > 0 ? totalFiles : 1);
        }
      }

      // 5. Extraer páginas y pads
      final pagesMeta =
          (metadata['pages'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final padsMeta =
          (metadata['pads'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      WorkspaceModel? newWorkspace;

      // 6. Transacción atómica en Isar
      await isar.writeTxn(() async {
        newWorkspace = WorkspaceModel()
          ..name = uniqueWsName
          ..createdAt = DateTime.now();
        await isar.workspaceModels.put(newWorkspace!);

        final pageModelByExportIndex = <int, PageModel>{};

        for (final pData in pagesMeta) {
          final expIndex = pData['pageIndex'] as int;
          final page = PageModel()
            ..pageIndex = expIndex
            ..name = (pData['name'] as String?) ??
                (expIndex == 0 ? 'Página 1' : 'Carpeta')
            ..columns = (pData['columns'] as int?) ?? 4
            ..rows = (pData['rows'] as int?) ?? 4
            ..workspace.value = newWorkspace;
          await isar.pageModels.put(page);
          await page.workspace.save();
          pageModelByExportIndex[expIndex] = page;
        }

        if (pageModelByExportIndex.isEmpty) {
          final rootPage = PageModel()
            ..pageIndex = 0
            ..name = 'Página 1'
            ..columns = 4
            ..rows = 4
            ..workspace.value = newWorkspace;
          await isar.pageModels.put(rootPage);
          await rootPage.workspace.save();
          pageModelByExportIndex[0] = rootPage;
        }

        for (final pData in pagesMeta) {
          final expIndex = pData['pageIndex'] as int;
          final parentExpIndex = pData['parentPageIndex'] as int?;
          if (parentExpIndex != null &&
              pageModelByExportIndex.containsKey(parentExpIndex)) {
            final page = pageModelByExportIndex[expIndex]!;
            page.parentPageId = pageModelByExportIndex[parentExpIndex]!.id;
            await isar.pageModels.put(page);
          }
        }

        for (final padData in padsMeta) {
          final pageIndex = (padData['pageIndex'] as int?) ?? 0;
          final page = pageModelByExportIndex[pageIndex];
          if (page == null) continue;

          final mediaKey = padData['media'] as String?;
          final samplePath = mediaKey != null ? audioMapping[mediaKey] : null;

          final pad = PadModel()
            ..padId = (padData['padId'] as int?) ?? 0
            ..label = (padData['label'] as String?) ?? ''
            ..colorHex = (padData['colorHex'] as int?) ??
                AppColors.audioPadPalette.first
            ..triggerModeIndex = (padData['triggerModeIndex'] as int?) ?? 0
            ..padTypeIndex = (padData['padTypeIndex'] as int?) ?? 0
            ..targetPageIndex = padData['targetPageIndex'] as int?
            ..targetMacroId = padData['targetMacroId'] as int?
            ..chokeGroup = (padData['chokeGroup'] as int?) ?? 0
            ..pan = ((padData['pan'] as num?)?.toDouble()) ?? 0.0
            ..pitch = ((padData['pitch'] as num?)?.toDouble()) ?? 1.0
            ..volume = ((padData['volume'] as num?)?.toDouble()) ?? 1.0
            ..isProtected = (padData['isProtected'] as bool?) ?? false
            ..reverse = (padData['reverse'] as bool?) ?? false
            ..fadeInMs = (padData['fadeInMs'] as int?) ?? 0
            ..fadeOutMs = (padData['fadeOutMs'] as int?) ?? 0
            ..startPointMs = (padData['startPointMs'] as int?) ?? 0
            ..endPointMs = padData['endPointMs'] as int?
            ..loopPointMs = (padData['loopPointMs'] as int?) ?? 0
            ..samplePath = samplePath
            ..page.value = page;

          await isar.padModels.put(pad);
          await pad.page.save();
        }
      });

      return newWorkspace;
    } catch (e, st) {
      debugPrint('[WorkspaceZipImporter] Error en importación: $e\n$st');
      // Rollback de archivos copiados para evitar residuos huérfanos
      if (createdWorkspaceDir != null && await createdWorkspaceDir.exists()) {
        try {
          await createdWorkspaceDir.delete(recursive: true);
        } catch (_) {}
      }
      return null;
    } finally {
      // Limpieza garantizada del directorio temporal de staging
      if (await work.exists()) {
        try {
          await work.delete(recursive: true);
        } catch (_) {}
      }
      await FilesystemSyncService.resume(isarInstance);
    }
  });

  /// Importa un archivo de workspace (.sppworkspace) solicitándolo al usuario con FilePicker.
  Future<WorkspaceModel?> importWorkspaceWithPicker({
    void Function(int current, int total)? onProgress,
  }) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Seleccionar archivo de workspace (.sppworkspace)',
      type: FileType.custom,
      allowedExtensions: const ['sppworkspace', 'zip'],
      withReadStream: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final single = result.files.single;
    final resolvedPath = await resolvePickedFilePath(
      single,
      workSubdir: 'workspace_import_picker',
    );
    if (resolvedPath == null) {
      return null;
    }

    try {
      return await importFromZipFile(resolvedPath, onProgress: onProgress);
    } finally {
      if (single.path == null) {
        try {
          final tempF = File(resolvedPath);
          if (await tempF.exists()) await tempF.delete();
        } catch (_) {}
      }
    }
  }
}
