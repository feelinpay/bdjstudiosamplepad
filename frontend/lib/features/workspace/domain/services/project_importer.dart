import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/app_storage_service.dart';
import '../../../../core/services/local_audio_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/zip_utils.dart';
import '../../../macros/data/models/macro_model.dart';
import '../../../midi/data/models/midi_mapping_model.dart';
import '../../../pad_system/data/models/pad_model.dart';
import '../../../sample_library/data/models/folder_model.dart';
import '../../../sample_library/data/models/genre_model.dart';
import '../../../sample_library/data/models/sample_model.dart';
import '../../data/models/page_model.dart';
import '../../data/models/workspace_model.dart';
import 'project_exporter.dart';

enum BackupImportMode {
  merge,
  replace,
}

class ProjectImportResult {
  final bool success;
  final String message;
  final int workspacesImported;
  final int padsImported;
  final int macrosImported;
  final int midiMappingsImported;

  const ProjectImportResult({
    required this.success,
    required this.message,
    this.workspacesImported = 0,
    this.padsImported = 0,
    this.macrosImported = 0,
    this.midiMappingsImported = 0,
  });
}

/// Importador de proyecto completo.
///
/// Soporta:
/// 1. Formato v2 moderno (`bdj-studio-sample-pad-project`): `metadata.json` + `media/`.
/// 2. Formato v1 heredado (`bdj-studio-sample-pad-backup`): `manifest.json` + `configuration/database.isar`.
///    Abre la base v1 en una instancia secundaria aislada de Isar para extraer los datos
///    sin tocar ni arriesgar la base de datos principal activa.
///
/// Modos de importación:
/// - [BackupImportMode.replace]: Reemplaza todos los workspaces, pads, macros y mapeos MIDI.
/// - [BackupImportMode.merge]: Fusiona los workspaces con sufijos numéricos y preserva el proyecto actual.
class ProjectImporter {
  final Future<Isar> dbFuture;

  ProjectImporter(this.dbFuture);

  /// Importa un archivo de proyecto completo (`.sppproject` o `.sppbackup`).
  Future<ProjectImportResult> importProject(
    String filePath, {
    BackupImportMode mode = BackupImportMode.merge,
    void Function(int current, int total)? onProgress,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return const ProjectImportResult(
        success: false,
        message: 'El archivo de respaldo no existe o no se puede acceder a él.',
      );
    }

    final work = await AppStorageService.workDirectory('project_import');
    final stagingDir = Directory(p.join(work.path, 'staging'));
    await stagingDir.create(recursive: true);

    Directory? createdMediaDir;

    try {
      // 1. Descomprimir en isolate directamente a disco (sin cargar todo en memoria)
      await compute(
        extractZipInIsolate,
        ExtractZipArgs(zipPath: filePath, targetDir: stagingDir.path),
      );

      // Detectar formato
      final metadataFile = File(p.join(stagingDir.path, 'metadata.json'));
      final manifestFile = File(p.join(stagingDir.path, 'manifest.json'));

      if (await metadataFile.exists()) {
        return await _importFormatV2(
          metadataFile: metadataFile,
          stagingDir: stagingDir,
          mode: mode,
          onProgress: onProgress,
          onMediaDirCreated: (dir) => createdMediaDir = dir,
        );
      } else if (await manifestFile.exists()) {
        return await _importFormatV1Legacy(
          manifestFile: manifestFile,
          stagingDir: stagingDir,
          mode: mode,
          onProgress: onProgress,
          onMediaDirCreated: (dir) => createdMediaDir = dir,
        );
      } else {
        return const ProjectImportResult(
          success: false,
          message: 'El archivo no contiene un formato de respaldo reconocido (falta metadata.json o manifest.json).',
        );
      }
    } catch (e, st) {
      debugPrint('[ProjectImporter] Error durante la importación: $e\n$st');
      // Rollback de audios copiados en disco
      final mediaDir = createdMediaDir;
      if (mediaDir != null && await mediaDir.exists()) {
        try {
          await mediaDir.delete(recursive: true);
        } catch (_) {}
      }
      return ProjectImportResult(
        success: false,
        message: 'Error inesperado al importar el proyecto: $e',
      );
    } finally {
      // Limpieza de archivos temporales
      if (await work.exists()) {
        try {
          await work.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  /// Importa formato v2 moderno (JSON estructurado + carpeta media deduplicada).
  Future<ProjectImportResult> _importFormatV2({
    required File metadataFile,
    required Directory stagingDir,
    required BackupImportMode mode,
    required void Function(int current, int total)? onProgress,
    required void Function(Directory dir) onMediaDirCreated,
  }) async {
    final metadataRaw = await metadataFile.readAsString();
    final metadata = jsonDecode(metadataRaw) as Map<String, dynamic>;

    final format = metadata['format'] as String?;
    final version = (metadata['version'] as int?) ?? 1;

    if (format != null && format != ProjectExporter.supportedFormat) {
      return ProjectImportResult(
        success: false,
        message: 'Formato no soportado: "$format". Se esperaba "${ProjectExporter.supportedFormat}".',
      );
    }

    if (version > ProjectExporter.currentVersion) {
      return ProjectImportResult(
        success: false,
        message: 'Este respaldo fue generado con una versión más reciente (v$version). '
            'Por favor actualiza la aplicación para poder importarlo.',
      );
    }

    // 1. Copiar audios deduplicados a directorio de destino
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final projectMediaNamespace = 'restored_project_$timestamp';
    final audiosBaseDir = await AppStorageService.mediaDirectory();
    final targetMediaDir = Directory(p.join(audiosBaseDir.path, projectMediaNamespace));
    onMediaDirCreated(targetMediaDir);

    final audioMapping = <String, String>{}; // mediaName -> app_local://restored_project_xxx/fileName
    final mediaStagingDir = Directory(p.join(stagingDir.path, 'media'));

    if (await mediaStagingDir.exists()) {
      final mediaFiles = mediaStagingDir.listSync().whereType<File>().toList();
      final totalFiles = mediaFiles.length;
      onProgress?.call(0, totalFiles > 0 ? totalFiles : 1);
      if (mediaFiles.isNotEmpty) {
        await targetMediaDir.create(recursive: true);
      }

      for (var i = 0; i < mediaFiles.length; i++) {
        final src = mediaFiles[i];
        final fileName = p.basename(src.path);
        final dest = File(p.join(targetMediaDir.path, fileName));
        await src.copy(dest.path);
        audioMapping[fileName] =
            '${LocalAudioStorageService.prefix}$projectMediaNamespace/$fileName';
        onProgress?.call(i + 1, totalFiles > 0 ? totalFiles : 1);
      }
    }

    // 2. Transacción en la base de datos principal
    final isar = await dbFuture;
    final workspacesData =
        (metadata['workspaces'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final macrosData =
        (metadata['macros'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final midiData =
        (metadata['midiMappings'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    var importedWorkspacesCount = 0;
    var importedPadsCount = 0;
    var importedMacrosCount = 0;
    var importedMidiCount = 0;

    final oldWsIdToNewWsId = <int, int>{};
    final newlyCreatedWsIds = <int>[];

    await isar.writeTxn(() async {
      // Si es modo reemplazo, vaciar colecciones previas
      if (mode == BackupImportMode.replace) {
        await isar.padModels.clear();
        await isar.pageModels.clear();
        await isar.workspaceModels.clear();
        await isar.macroModels.clear();
        await isar.midiMappingModels.clear();
        await isar.sampleModels.clear();
        await isar.folderModels.clear();
        await isar.genreModels.clear();
      }

      // 3. Mapear e insertar Macros
      final existingMacroNames = (await isar.macroModels.where().findAll())
          .map((m) => m.name.toLowerCase().trim())
          .toSet();
      final macroIdMap = <int, int>{}; // oldId -> newId

      for (final mData in macrosData) {
        final oldId = mData['id'] as int?;
        var macroName = (mData['name'] as String?) ?? 'Macro';
        if (mode == BackupImportMode.merge &&
            existingMacroNames.contains(macroName.toLowerCase().trim())) {
          macroName = '$macroName (Importado)';
        }
        existingMacroNames.add(macroName.toLowerCase().trim());

        final macro = MacroModel()
          ..name = macroName
          ..actionsJson = (mData['actionsJson'] as String?) ?? '[]'
          ..createdAt = DateTime.tryParse(mData['createdAt']?.toString() ?? '') ??
              DateTime.now()
          ..updatedAt = mData['updatedAt'] != null
              ? DateTime.tryParse(mData['updatedAt'].toString())
              : null;

        await isar.macroModels.put(macro);
        if (oldId != null) {
          macroIdMap[oldId] = macro.id;
        }
        importedMacrosCount++;
      }

      // 4. Mapear e insertar Workspaces, Páginas y Pads
      final existingWsNames = (await isar.workspaceModels.where().findAll())
          .map((w) => w.name.toLowerCase().trim())
          .toSet();

      for (final wsData in workspacesData) {
        final oldId = wsData['id'] as int?;
        final baseName = (wsData['name'] as String?)?.trim() ?? 'Workspace';
        var uniqueWsName = baseName;
        if (mode == BackupImportMode.merge) {
          var suffix = 1;
          while (existingWsNames.contains(uniqueWsName.toLowerCase().trim())) {
            uniqueWsName = '$baseName ($suffix)';
            suffix++;
          }
        }
        existingWsNames.add(uniqueWsName.toLowerCase().trim());

        final ws = WorkspaceModel()
          ..name = uniqueWsName
          ..createdAt =
              DateTime.tryParse(wsData['createdAt']?.toString() ?? '') ??
                  DateTime.now();
        await isar.workspaceModels.put(ws);
        importedWorkspacesCount++;
        newlyCreatedWsIds.add(ws.id);
        if (oldId != null) {
          oldWsIdToNewWsId[oldId] = ws.id;
        }

        final pagesData =
            (wsData['pages'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final pageModelByExportIndex = <int, PageModel>{};

        for (final pData in pagesData) {
          final expIndex = pData['pageIndex'] as int;
          final page = PageModel()
            ..pageIndex = expIndex
            ..name = (pData['name'] as String?) ??
                (expIndex == 0 ? 'Página 1' : 'Carpeta')
            ..columns = (pData['columns'] as int?) ?? 4
            ..rows = (pData['rows'] as int?) ?? 4
            ..workspace.value = ws;
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
            ..workspace.value = ws;
          await isar.pageModels.put(rootPage);
          await rootPage.workspace.save();
          pageModelByExportIndex[0] = rootPage;
        }

        // Relaciones de jerarquía de páginas (carpetas)
        for (final pData in pagesData) {
          final expIndex = pData['pageIndex'] as int;
          final parentExpIndex = pData['parentPageIndex'] as int?;
          if (parentExpIndex != null &&
              pageModelByExportIndex.containsKey(parentExpIndex)) {
            final page = pageModelByExportIndex[expIndex]!;
            page.parentPageId = pageModelByExportIndex[parentExpIndex]!.id;
            await isar.pageModels.put(page);
          }
        }

        // Pads
        final padsData =
            (wsData['pads'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        for (final padData in padsData) {
          final pageIndex = (padData['pageIndex'] as int?) ?? 0;
          final page = pageModelByExportIndex[pageIndex];
          if (page == null) continue;

          final mediaKey = padData['media'] as String?;
          final samplePath = mediaKey != null ? audioMapping[mediaKey] : null;

          final oldMacroId = padData['targetMacroId'] as int?;
          final targetMacroId =
              oldMacroId != null ? (macroIdMap[oldMacroId] ?? oldMacroId) : null;

          final pad = PadModel()
            ..padId = (padData['padId'] as int?) ?? 0
            ..label = (padData['label'] as String?) ?? ''
            ..colorHex = (padData['colorHex'] as int?) ??
                AppColors.audioPadPalette.first
            ..triggerModeIndex = (padData['triggerModeIndex'] as int?) ?? 0
            ..padTypeIndex = (padData['padTypeIndex'] as int?) ?? 0
            ..targetPageIndex = padData['targetPageIndex'] as int?
            ..targetMacroId = targetMacroId
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
          importedPadsCount++;
        }
      }

      // 5. Mapeos MIDI
      for (final mData in midiData) {
        final mapping = MidiMappingModel()
          ..noteOrCC = (mData['noteOrCC'] as int?) ?? 0
          ..statusByte = (mData['statusByte'] as int?) ?? 0
          ..actionType = (mData['actionType'] as String?) ?? ''
          ..actionValue = (mData['actionValue'] as String?) ?? '';
        await isar.midiMappingModels.put(mapping);
        importedMidiCount++;
      }
    });

    // 6. Actualizar orden de workspaces y preferencias con lista blanca estricta
    final prefs = await SharedPreferences.getInstance();
    final workspaceOrderOldIds =
        (metadata['workspaceOrderOldIds'] as List?)?.cast<int>() ?? [];

    if (mode == BackupImportMode.replace) {
      final remappedOrder = workspaceOrderOldIds
          .map((oldId) => oldWsIdToNewWsId[oldId])
          .whereType<int>()
          .map((id) => id.toString())
          .toList();
      if (remappedOrder.isNotEmpty) {
        await prefs.setStringList('workspace_order_ids', remappedOrder);
      } else {
        await prefs.setStringList(
          'workspace_order_ids',
          newlyCreatedWsIds.map((id) => id.toString()).toList(),
        );
      }

      // Restaurar preferencias permitidas únicamente por la lista blanca
      final prefsData = metadata['preferences'] as Map<String, dynamic>?;
      if (prefsData != null) {
        for (final entry in prefsData.entries) {
          if (!ProjectExporter.portablePreferencesWhitelist.contains(entry.key)) {
            continue; // WHITELIST: nada fuera de la lista blanca pasa
          }
          final val = entry.value;
          if (val is bool) await prefs.setBool(entry.key, val);
          if (val is int) await prefs.setInt(entry.key, val);
          if (val is double) await prefs.setDouble(entry.key, val);
          if (val is String) await prefs.setString(entry.key, val);
          if (val is List) {
            await prefs.setStringList(entry.key, val.cast<String>());
          }
        }
      }
    } else {
      // Modo MERGE: agregar nuevos workspaces al final del orden existente
      final currentOrder = prefs.getStringList('workspace_order_ids') ?? [];
      currentOrder.addAll(newlyCreatedWsIds.map((id) => id.toString()));
      await prefs.setStringList('workspace_order_ids', currentOrder);
    }

    // 7. En modo reemplazo, purgar del disco todos los audios huérfanos del proyecto anterior
    if (mode == BackupImportMode.replace) {
      await LocalAudioStorageService.autoCleanOrphans(
        isar,
        cleanInternalDirs: true,
      );
    }

    return ProjectImportResult(
      success: true,
      message: 'Proyecto importado exitosamente.',
      workspacesImported: importedWorkspacesCount,
      padsImported: importedPadsCount,
      macrosImported: importedMacrosCount,
      midiMappingsImported: importedMidiCount,
    );
  }

  /// Importa formato v1 heredado abriendo la base `database.isar` en una instancia
  /// secundaria aislada de Isar (`temp_v1_import`), transfiriendo los registros
  /// de forma segura a la base activa sin riesgos de corrupción.
  Future<ProjectImportResult> _importFormatV1Legacy({
    required File manifestFile,
    required Directory stagingDir,
    required BackupImportMode mode,
    required void Function(int current, int total)? onProgress,
    required void Function(Directory dir) onMediaDirCreated,
  }) async {
    final manifestRaw = await manifestFile.readAsString();
    final manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;

    // Localizar base de datos v1 en staging
    File? legacyDbFile;
    final candidate1 =
        File(p.join(stagingDir.path, 'configuration', 'database.isar'));
    final candidate2 = File(p.join(stagingDir.path, 'database.isar'));
    if (await candidate1.exists()) {
      legacyDbFile = candidate1;
    } else if (await candidate2.exists()) {
      legacyDbFile = candidate2;
    }

    if (legacyDbFile == null) {
      return const ProjectImportResult(
        success: false,
        message: 'Respaldo v1 inválido: no se encontró configuration/database.isar.',
      );
    }

    // Copiar a stagingDir/temp_v1_import.isar para que Isar la abra con ese nombre de instancia
    final isolatedDbFile =
        File(p.join(stagingDir.path, 'temp_v1_import.isar'));
    await legacyDbFile.copy(isolatedDbFile.path);

    // 1. Abrir instancia secundaria aislada
    Isar? tempIsar;
    try {
      tempIsar = await Isar.open(
        [
          PadModelSchema,
          SampleModelSchema,
          FolderModelSchema,
          GenreModelSchema,
          WorkspaceModelSchema,
          PageModelSchema,
          MidiMappingModelSchema,
          MacroModelSchema,
        ],
        directory: stagingDir.path,
        name: 'temp_v1_import',
        inspector: false,
      );
    } catch (e) {
      debugPrint('[ProjectImporter] Falló Isar.open en respaldo v1: $e');
      return const ProjectImportResult(
        success: false,
        message:
            'No se pudo leer la base de datos del respaldo v1 antiguo debido a incompatibilidad '
            'de esquema o arquitectura. Tu proyecto actual no fue alterado.',
      );
    }

    List<WorkspaceModel> legacyWorkspaces;
    List<PageModel> legacyPages;
    List<PadModel> legacyPads;
    List<MacroModel> legacyMacros;
    List<MidiMappingModel> legacyMidi;

    try {
      legacyWorkspaces = await tempIsar.workspaceModels.where().findAll();
      legacyPages = await tempIsar.pageModels.where().findAll();
      legacyPads = await tempIsar.padModels.where().findAll();
      legacyMacros = await tempIsar.macroModels.where().findAll();
      legacyMidi = await tempIsar.midiMappingModels.where().findAll();
    } finally {
      await tempIsar.close();
    }

    // 2. Copiar archivos de medios de v1
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final projectMediaNamespace = 'restored_project_$timestamp';
    final audiosBaseDir = await AppStorageService.mediaDirectory();
    final targetMediaDir =
        Directory(p.join(audiosBaseDir.path, projectMediaNamespace));
    onMediaDirCreated(targetMediaDir);

    final pathMappings =
        (manifest['pathMappings'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final oldPathToNewUri = <String, String>{};

    final totalAssets = pathMappings.length;
    onProgress?.call(0, totalAssets > 0 ? totalAssets : 1);
    var copiedCount = 0;

    for (final pm in pathMappings) {
      final storedPath = pm['storedPath'] as String?;
      final entry = pm['entry'] as String?;
      if (storedPath == null || entry == null) continue;

      final srcFile = File(p.join(stagingDir.path, entry));
      if (await srcFile.exists()) {
        if (!await targetMediaDir.exists()) {
          await targetMediaDir.create(recursive: true);
        }
        final fileName = p.basename(entry);
        final destFile = File(p.join(targetMediaDir.path, fileName));
        await srcFile.copy(destFile.path);
        oldPathToNewUri[storedPath] =
            '${LocalAudioStorageService.prefix}$projectMediaNamespace/$fileName';
      }
      copiedCount++;
      onProgress?.call(copiedCount, totalAssets > 0 ? totalAssets : 1);
    }

    // 3. Escribir en base de datos principal de la app
    final isar = await dbFuture;
    var importedWorkspacesCount = 0;
    var importedPadsCount = 0;
    var importedMacrosCount = 0;
    var importedMidiCount = 0;
    final wsIdMap = <int, WorkspaceModel>{};

    await isar.writeTxn(() async {
      if (mode == BackupImportMode.replace) {
        await isar.padModels.clear();
        await isar.pageModels.clear();
        await isar.workspaceModels.clear();
        await isar.macroModels.clear();
        await isar.midiMappingModels.clear();
        await isar.sampleModels.clear();
        await isar.folderModels.clear();
        await isar.genreModels.clear();
      }

      // Macros
      final macroIdMap = <int, int>{};
      final existingMacroNames = (await isar.macroModels.where().findAll())
          .map((m) => m.name.toLowerCase().trim())
          .toSet();

      for (final oldMacro in legacyMacros) {
        var name = oldMacro.name;
        if (mode == BackupImportMode.merge &&
            existingMacroNames.contains(name.toLowerCase().trim())) {
          name = '$name (Importado)';
        }
        existingMacroNames.add(name.toLowerCase().trim());

        final m = MacroModel()
          ..name = name
          ..actionsJson = oldMacro.actionsJson
          ..createdAt = oldMacro.createdAt
          ..updatedAt = oldMacro.updatedAt;
        await isar.macroModels.put(m);
        macroIdMap[oldMacro.id] = m.id;
        importedMacrosCount++;
      }

      // Workspaces & Páginas
      final existingWsNames = (await isar.workspaceModels.where().findAll())
          .map((w) => w.name.toLowerCase().trim())
          .toSet();

      final pageIdMap = <int, PageModel>{};

      for (final oldWs in legacyWorkspaces) {
        var name = oldWs.name;
        if (mode == BackupImportMode.merge) {
          var suffix = 1;
          while (existingWsNames.contains(name.toLowerCase().trim())) {
            name = '${oldWs.name} ($suffix)';
            suffix++;
          }
        }
        existingWsNames.add(name.toLowerCase().trim());

        final newWs = WorkspaceModel()
          ..name = name
          ..createdAt = oldWs.createdAt;
        await isar.workspaceModels.put(newWs);
        wsIdMap[oldWs.id] = newWs;
        importedWorkspacesCount++;
      }

      // Páginas
      for (final oldPage in legacyPages) {
        final oldWsId = oldPage.workspace.value?.id;
        final newWs = oldWsId != null ? wsIdMap[oldWsId] : null;
        if (newWs == null) continue;

        final newPage = PageModel()
          ..pageIndex = oldPage.pageIndex
          ..name = oldPage.name
          ..columns = oldPage.columns
          ..rows = oldPage.rows
          ..workspace.value = newWs;
        await isar.pageModels.put(newPage);
        await newPage.workspace.save();
        pageIdMap[oldPage.id] = newPage;
      }

      // Jerarquía de páginas (parentPageId)
      for (final oldPage in legacyPages) {
        if (oldPage.parentPageId != null &&
            pageIdMap.containsKey(oldPage.parentPageId)) {
          final newPage = pageIdMap[oldPage.id];
          if (newPage != null) {
            newPage.parentPageId = pageIdMap[oldPage.parentPageId!]!.id;
            await isar.pageModels.put(newPage);
          }
        }
      }

      // Pads
      for (final oldPad in legacyPads) {
        final oldPageId = oldPad.page.value?.id;
        final newPage = oldPageId != null ? pageIdMap[oldPageId] : null;
        if (newPage == null) continue;

        final samplePath = oldPad.samplePath != null
            ? (oldPathToNewUri[oldPad.samplePath!] ?? oldPad.samplePath)
            : null;

        final oldMacroId = oldPad.targetMacroId;
        final targetMacroId = oldMacroId != null
            ? (macroIdMap[oldMacroId] ?? oldMacroId)
            : null;

        final newPad = PadModel()
          ..padId = oldPad.padId
          ..label = oldPad.label
          ..colorHex = oldPad.colorHex
          ..triggerModeIndex = oldPad.triggerModeIndex
          ..padTypeIndex = oldPad.padTypeIndex
          ..targetPageIndex = oldPad.targetPageIndex
          ..targetMacroId = targetMacroId
          ..chokeGroup = oldPad.chokeGroup
          ..pan = oldPad.pan
          ..pitch = oldPad.pitch
          ..volume = oldPad.volume
          ..isProtected = oldPad.isProtected
          ..reverse = oldPad.reverse
          ..fadeInMs = oldPad.fadeInMs
          ..fadeOutMs = oldPad.fadeOutMs
          ..startPointMs = oldPad.startPointMs
          ..endPointMs = oldPad.endPointMs
          ..loopPointMs = oldPad.loopPointMs
          ..samplePath = samplePath
          ..page.value = newPage;

        await isar.padModels.put(newPad);
        await newPad.page.save();
        importedPadsCount++;
      }

      // Mapeos MIDI
      for (final oldM in legacyMidi) {
        final newM = MidiMappingModel()
          ..noteOrCC = oldM.noteOrCC
          ..statusByte = oldM.statusByte
          ..actionType = oldM.actionType
          ..actionValue = oldM.actionValue;
        await isar.midiMappingModels.put(newM);
        importedMidiCount++;
      }
    });

    // Remapear orden de workspaces y restaurar preferencias permitidas
    final prefs = await SharedPreferences.getInstance();
    if (mode == BackupImportMode.replace) {
      final remappedOrder = legacyWorkspaces
          .map((w) => wsIdMap[w.id]?.id)
          .whereType<int>()
          .map((id) => id.toString())
          .toList();
      await prefs.setStringList('workspace_order_ids', remappedOrder);

      final prefsFile =
          File(p.join(stagingDir.path, 'configuration', 'preferences.json'));
      if (await prefsFile.exists()) {
        try {
          final prefsData =
              jsonDecode(await prefsFile.readAsString()) as Map<String, dynamic>;
          for (final entry in prefsData.entries) {
            if (!ProjectExporter.portablePreferencesWhitelist.contains(entry.key)) {
              continue; // WHITELIST
            }
            final val = entry.value;
            if (val is bool) await prefs.setBool(entry.key, val);
            if (val is int) await prefs.setInt(entry.key, val);
            if (val is double) await prefs.setDouble(entry.key, val);
            if (val is String) await prefs.setString(entry.key, val);
            if (val is List) {
              await prefs.setStringList(entry.key, val.cast<String>());
            }
          }
        } catch (_) {}
      }
    } else {
      final currentOrder = prefs.getStringList('workspace_order_ids') ?? [];
      currentOrder.addAll(
        legacyWorkspaces
            .map((w) => wsIdMap[w.id]?.id)
            .whereType<int>()
            .map((id) => id.toString()),
      );
      await prefs.setStringList('workspace_order_ids', currentOrder);
    }

    // En modo reemplazo, purgar del disco todos los audios huérfanos del proyecto anterior
    if (mode == BackupImportMode.replace) {
      await LocalAudioStorageService.autoCleanOrphans(
        isar,
        cleanInternalDirs: true,
      );
    }

    return ProjectImportResult(
      success: true,
      message: 'Proyecto (v1 heredado) importado exitosamente.',
      workspacesImported: importedWorkspacesCount,
      padsImported: importedPadsCount,
      macrosImported: importedMacrosCount,
      midiMappingsImported: importedMidiCount,
    );
  }

  /// Importa un archivo de proyecto solicitándolo al usuario con FilePicker.
  Future<ProjectImportResult?> importProjectWithPicker({
    BackupImportMode mode = BackupImportMode.merge,
    void Function(int current, int total)? onProgress,
  }) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Seleccionar archivo de respaldo del proyecto',
      type: FileType.custom,
      allowedExtensions: const ['sppproject', 'sppbackup', 'zip'],
    );
    if (result == null || result.files.isEmpty || result.files.single.path == null) {
      return null;
    }
    return await importProject(
      result.files.single.path!,
      mode: mode,
      onProgress: onProgress,
    );
  }
}
