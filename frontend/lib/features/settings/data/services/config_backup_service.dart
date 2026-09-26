import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../pad_system/data/models/pad_model.dart';
import '../../../workspace/data/models/workspace_model.dart';
import '../../../workspace/data/models/page_model.dart';
import '../../../sample_library/data/models/sample_model.dart';
import '../../../sample_library/data/models/folder_model.dart';
import '../../../sample_library/data/models/genre_model.dart';
import '../../../midi/data/models/midi_mapping_model.dart';
import '../../../macros/data/models/macro_model.dart';
import '../../../../core/services/app_storage_service.dart';
import '../../../../core/services/local_audio_storage_service.dart';
import '../../../../core/utils/zip_utils.dart';

enum BackupImportMode { merge, replace }

/// Respaldo portable de toda la configuracion de Sample Pad.
///
/// Incluye la base Isar completa (workspaces, paginas, carpetas, pads, macros,
/// MIDI y biblioteca), preferencias/efectos globales y todos los audios,
/// waveforms e imagenes referenciados. La licencia, el HWID y los datos de
/// seguridad no se exportan porque pertenecen al dispositivo de origen.
class ConfigBackupService {
  const ConfigBackupService._();

  static const _format = 'bdj-studio-sample-pad-backup';
  static const _version = 2;
  static const _dbFileName = 'default.isar';
  static const _pendingDb = 'restore_pending.isar';
  static const _pendingPaths = 'restore_pending_paths.json';
  static const _restoreApplied = 'restore_applied.marker';
  static const _prefsEntry = 'configuration/preferences.json';
  static const _dbEntry = 'configuration/database.isar';
  static const _manifestEntry = 'manifest.json';

  /// Prefijo de las URIs de audio gestionadas por la app. Se reexporta desde
  /// LocalAudioStorageService para evitar dos definiciones del mismo string.
  static String get _localMediaPrefix => LocalAudioStorageService.prefix;

  /// Lista blanca estricta de preferencias de usuario portables (apariencia y accesibilidad).
  /// Cualquier clave que no esté explícitamente en esta lista se descarta por defecto.
  /// Garantiza que nunca viajen ni se restauren datos de hardware (HWID 'bdj.hwid.v2'),
  /// licencias ('spp_*', 'bdj.sample_pad.*'), tokens o identificadores de dispositivo.
  static const _portablePreferencesWhitelist = <String>{
    'theme_mode',
    'left_handed',
    'high_contrast',
    'font_scale',
    'snap_to_grid',
    'app_mode',
    'enable_pad_shortcuts',
  };

  /// Exporta un .sppbackup autosuficiente y devuelve su ruta.
  static Future<String?> exportAll() async {
    final isar = Isar.getInstance();
    if (isar == null) {
      throw StateError('La base de datos todavia no esta disponible.');
    }

    final output = await FilePicker.saveFile(
      dialogTitle: 'Exportar configuracion completa',
      fileName: 'bdj_studio_sample_pad_backup.sppbackup',
      type: FileType.custom,
      allowedExtensions: const ['sppbackup'],
    );
    if (output == null) return null;

    final finalOutput = output.toLowerCase().endsWith('.sppbackup')
        ? output
        : '$output.sppbackup';
    final work = await AppStorageService.workDirectory('full_backup');

    try {
      final databaseSnapshot = File(p.join(work.path, 'database.isar'));
      await isar.copyToFile(databaseSnapshot.path);

      final prefs = await SharedPreferences.getInstance();
      final preferences = <String, dynamic>{};
      for (final key in _portablePreferencesWhitelist) {
        final val = prefs.get(key);
        if (val != null) {
          preferences[key] = val;
        }
      }
      final preferencesFile = File(p.join(work.path, 'preferences.json'));
      await preferencesFile.writeAsString(jsonEncode(preferences), flush: true);

      final referencedPaths = await _collectReferencedPaths(isar);
      final archivedFiles = <String, String>{};
      final pathMappings = <Map<String, dynamic>>[];
      final mediaFiles = <MapEntry<String, File>>[];
      final missingFiles = <String>[];

      for (final storedPath in referencedPaths) {
        final resolvedPath = storedPath.startsWith(_localMediaPrefix)
            ? await LocalAudioStorageService.resolvePath(storedPath)
            : (p.isAbsolute(storedPath) ? storedPath : null);
        if (resolvedPath == null) continue;
        final source = File(resolvedPath);
        if (!await source.exists()) {
          missingFiles.add(storedPath);
          continue;
        }

        var entry = archivedFiles[source.absolute.path];
        if (entry == null) {
          final extension = p.extension(source.path);
          entry =
              'assets/${archivedFiles.length.toString().padLeft(5, '0')}$extension';
          archivedFiles[source.absolute.path] = entry;
          mediaFiles.add(MapEntry(entry, source));
        }
        pathMappings.add({'storedPath': storedPath, 'entry': entry});
      }
      if (missingFiles.isNotEmpty) {
        // Registrar archivos faltantes pero permitir que el respaldo se cree
        // omitiendo las muestras inexistentes en lugar de cancelar la exportación.
      }

      final manifest = <String, dynamic>{
        'format': _format,
        'version': _version,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'missingFilesCount': missingFiles.length,
        'database': {
          'entry': _dbEntry,
          'size': await databaseSnapshot.length(),
          'sha256': await _fileHash(databaseSnapshot),
        },
        'preferences': {
          'entry': _prefsEntry,
          'size': await preferencesFile.length(),
          'sha256': await _fileHash(preferencesFile),
        },
        'paths': pathMappings,
        'assets': [
          for (final media in mediaFiles)
            {
              'entry': media.key,
              'size': await media.value.length(),
              'sha256': await _fileHash(media.value),
            },
        ],
      };
      final manifestFile = File(p.join(work.path, 'manifest.json'));
      await manifestFile.writeAsString(jsonEncode(manifest), flush: true);

      final encoder = ZipFileEncoder();
      try {
        encoder.create(finalOutput);
        encoder.addFile(manifestFile, _manifestEntry);
        encoder.addFile(databaseSnapshot, _dbEntry);
        encoder.addFile(preferencesFile, _prefsEntry);
        for (final media in mediaFiles) {
          encoder.addFile(media.value, media.key);
        }
      } finally {
        encoder.close();
      }
      return finalOutput;
    } finally {
      // Limpieza del temporal EN SEGUNDO PLANO: no bloquea el retorno del
      // respaldo ya creado, asi el dialogo de exito aparece de inmediato.
      unawaited(_deleteTempQuietly(work));
    }
  }

  /// Borra un temporal de forma tolerante. En Windows algunos handles (Isar/zip)
  /// se liberan con un pequeno retraso, por lo que reintenta varias veces y NUNCA
  /// lanza: un fallo al limpiar el temporal no debe invalidar un respaldo que ya
  /// se creo correctamente.
  static Future<void> _deleteTempQuietly(Directory dir) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        if (await dir.exists()) await dir.delete(recursive: true);
        return;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  /// Valida y prepara un backup para aplicarlo en el siguiente arranque.
  static Future<bool> importAll({required BackupImportMode mode}) async {
    final docs = await AppStorageService.databaseDirectory();
    final mediaRoot = await AppStorageService.mediaDirectory();
    final pendingDbFile = File(p.join(docs.path, _pendingDb));
    final pendingPathsFile = File(p.join(docs.path, _pendingPaths));
    final appliedMarker = File(p.join(docs.path, _restoreApplied));

    if (await pendingDbFile.exists()) {
      if (await appliedMarker.exists()) {
        throw StateError(
          'Ya existe una restauracion pendiente. Reinicia la aplicacion antes '
          'de importar otro respaldo.',
        );
      } else {
        // Limpiar restauración pendiente incompleta o huérfana de un intento fallido previo
        try {
          await pendingDbFile.delete();
          if (await pendingPathsFile.exists()) await pendingPathsFile.delete();
        } catch (_) {}
      }
    }

    var picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['sppbackup', 'zip'],
      withReadStream: true,
    );
    if (picked == null || picked.files.isEmpty) {
      picked = await FilePicker.pickFiles(
        type: FileType.any,
        withReadStream: true,
      );
    }
    if (picked == null || picked.files.isEmpty) return false;

    final singleFile = picked.files.single;
    final zipFilePath = await resolvePickedFilePath(
      singleFile,
      workSubdir: 'config_backup_import',
    );

    if (zipFilePath == null || !await File(zipFilePath).exists()) {
      throw const FormatException(
        'No se pudo acceder a los datos del archivo de respaldo.',
      );
    }

    final restoreId = DateTime.now().microsecondsSinceEpoch.toString();
    final work = await AppStorageService.workDirectory('config_backup_import');
    final stagingDir = Directory(p.join(work.path, 'staging_$restoreId'));
    await stagingDir.create(recursive: true);

    try {
      // Descomprimir en streaming dentro de un isolate directamente a disco.
      await compute(
        extractZipInIsolate,
        ExtractZipArgs(zipPath: zipFilePath, targetDir: stagingDir.path),
      );

      final manifestFile = _findStagedFile(stagingDir, _manifestEntry);
      if (manifestFile == null || !await manifestFile.exists()) {
        throw const FormatException('El respaldo no contiene un manifiesto.');
      }

      final manifestRaw = await manifestFile.readAsString();
      final manifest = jsonDecode(manifestRaw);
      if (manifest is! Map<String, dynamic> ||
          manifest['format'] != _format ||
          manifest['version'] != _version) {
        throw const FormatException('Formato de respaldo no compatible.');
      }

      final restoredMedia = await Directory(
        p.join(mediaRoot.path, 'restored_$restoreId'),
      ).create(recursive: true);
      final extractedEntries = <String, String>{};

      try {
        final databaseInfo = manifest['database'] as Map<String, dynamic>;
        final databaseEntry = databaseInfo['entry'] as String;
        final importName = 'spp_import_$restoreId';
        final databaseFile = mode == BackupImportMode.replace
            ? File(p.join(docs.path, _pendingDb))
            : File(p.join(restoredMedia.path, '$importName.isar'));
        await _verifyAndMove(
          stagingDir,
          databaseEntry,
          databaseFile,
          databaseInfo,
        );

        final preferencesInfo = manifest['preferences'] as Map<String, dynamic>;
        final preferencesFile = File(
          p.join(restoredMedia.path, 'preferences.json'),
        );
        await _verifyAndMove(
          stagingDir,
          preferencesInfo['entry'] as String,
          preferencesFile,
          preferencesInfo,
        );

        final assets = (manifest['assets'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        for (var index = 0; index < assets.length; index++) {
          final info = assets[index];
          final entry = info['entry'] as String;
          final extension = p.extension(entry);
          final fileName = '${index.toString().padLeft(5, '0')}$extension';
          final target = File(p.join(restoredMedia.path, fileName));
          await _verifyAndMove(stagingDir, entry, target, info);
          extractedEntries[entry] =
              '${_localMediaPrefix}restored_$restoreId/$fileName';
        }

        final pathMap = <String, String>{};
        for (final raw in (manifest['paths'] as List<dynamic>)) {
          final mapping = raw as Map<String, dynamic>;
          final restored = extractedEntries[mapping['entry'] as String];
          if (restored != null) {
            pathMap[mapping['storedPath'] as String] = restored;
          }
        }
        if (mode == BackupImportMode.replace) {
          await File(
            p.join(docs.path, _pendingPaths),
          ).writeAsString(jsonEncode(pathMap), flush: true);
          await _restorePreferences(preferencesFile);
        } else {
          await mergeDatabase(databaseFile, importName, pathMap);
        }
        await preferencesFile.delete();
        if (assets.isEmpty &&
            mode == BackupImportMode.merge &&
            await restoredMedia.exists()) {
          await restoredMedia.delete();
        }
        return true;
      } catch (_) {
        if (mode == BackupImportMode.replace) {
          final pendingDb = File(p.join(docs.path, _pendingDb));
          final pendingPaths = File(p.join(docs.path, _pendingPaths));
          if (await pendingDb.exists()) await pendingDb.delete();
          if (await pendingPaths.exists()) await pendingPaths.delete();
        }
        if (await restoredMedia.exists()) {
          await restoredMedia.delete(recursive: true);
        }
        rethrow;
      }
    } finally {
      if (await stagingDir.exists()) {
        try {
          await stagingDir.delete(recursive: true);
        } catch (_) {}
      }
      if (singleFile.path == null) {
        try {
          final tempF = File(zipFilePath);
          if (await tempF.exists()) await tempF.delete();
        } catch (_) {}
      }
    }
  }

  /// Bandera para notificar a la UI si se tuvo que revertir una restauración fallida.
  static bool lastRestoreRolledBack = false;

  /// Sustituye la base antes de que Isar sea abierto.
  /// Conserva `.before_restore` hasta que `openAppDatabase()` confirme que abre sin errores.
  static Future<void> applyPendingRestore() async {
    final docs = await AppStorageService.databaseDirectory();
    final pending = File(p.join(docs.path, _pendingDb));
    if (!await pending.exists()) return;

    final database = File(p.join(docs.path, _dbFileName));
    final rollback = File(p.join(docs.path, '$_dbFileName.before_restore'));
    final appliedMarker = File(p.join(docs.path, _restoreApplied));
    var databaseWasReplaced = false;
    try {
      if (await appliedMarker.exists()) await appliedMarker.delete();
      if (await rollback.exists()) await rollback.delete();
      if (await database.exists()) await database.rename(rollback.path);
      await pending.rename(database.path);
      databaseWasReplaced = true;
      await appliedMarker.writeAsString('ready', flush: true);
      // NO borrar rollback (.before_restore) aquí. Se borra en main.dart tras abrir la base con éxito.
    } catch (_) {
      if (await appliedMarker.exists()) await appliedMarker.delete();
      if (databaseWasReplaced && await database.exists()) {
        if (await pending.exists()) await pending.delete();
        await database.rename(pending.path);
      }
      if (await rollback.exists()) {
        if (await database.exists()) await database.delete();
        await rollback.rename(database.path);
      }
      // La base anterior queda restaurada para no impedir que la app inicie.
    }
  }

  /// Borra el respaldo `.before_restore` una vez que `openAppDatabase()` abrió exitosamente.
  static Future<void> cleanupBeforeRestoreBackup() async {
    try {
      final docs = await AppStorageService.databaseDirectory();
      final rollback = File(p.join(docs.path, '$_dbFileName.before_restore'));
      if (await rollback.exists()) {
        await rollback.delete();
        debugPrint('[ConfigBackupService] Respaldo previo .before_restore limpiado tras arranque exitoso.');
      }
    } catch (e) {
      debugPrint('[ConfigBackupService] Error al limpiar .before_restore: $e');
    }
  }

  /// Deshace la sustitución de base de datos restaurando el archivo original `.before_restore`.
  static Future<bool> rollbackFailedRestore() async {
    try {
      final docs = await AppStorageService.databaseDirectory();
      final database = File(p.join(docs.path, _dbFileName));
      final rollback = File(p.join(docs.path, '$_dbFileName.before_restore'));
      final appliedMarker = File(p.join(docs.path, _restoreApplied));
      final mappingFile = File(p.join(docs.path, _pendingPaths));

      if (await appliedMarker.exists()) await appliedMarker.delete();
      if (await mappingFile.exists()) await mappingFile.delete();

      if (await rollback.exists()) {
        if (await database.exists()) {
          final failedDb = File(p.join(docs.path, '$_dbFileName.failed_restore'));
          if (await failedDb.exists()) await failedDb.delete();
          await database.rename(failedDb.path);
        }
        await rollback.rename(database.path);
        lastRestoreRolledBack = true;
        debugPrint('[ConfigBackupService] Rollback completado: Base de datos previa restaurada intacta.');
        return true;
      }
    } catch (e) {
      debugPrint('[ConfigBackupService] Error en rollbackFailedRestore: $e');
    }
    return false;
  }

  /// Reescribe las rutas de medios tras abrir la base restaurada.
  static Future<void> finalizePendingRestore(Isar isar) async {
    final docs = await AppStorageService.databaseDirectory();
    final mappingFile = File(p.join(docs.path, _pendingPaths));
    final appliedMarker = File(p.join(docs.path, _restoreApplied));
    if (!await mappingFile.exists() || !await appliedMarker.exists()) return;

    final decoded = jsonDecode(await mappingFile.readAsString());
    final mapping = (decoded as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as String),
    );
    if (mapping.isEmpty) {
      await mappingFile.delete();
      await appliedMarker.delete();
      return;
    }

    final pads = await isar.padModels.where().findAll();
    final samples = await isar.sampleModels.where().findAll();
    await isar.writeTxn(() async {
      final changedPads = <PadModel>[];
      for (final pad in pads) {
        var changed = false;
        final samplePath = pad.samplePath;
        final backgroundPath = pad.backgroundImagePath;
        if (samplePath != null && mapping.containsKey(samplePath)) {
          pad.samplePath = mapping[samplePath];
          changed = true;
        }
        if (backgroundPath != null && mapping.containsKey(backgroundPath)) {
          pad.backgroundImagePath = mapping[backgroundPath];
          changed = true;
        }
        if (changed) changedPads.add(pad);
      }
      if (changedPads.isNotEmpty) await isar.padModels.putAll(changedPads);

      final changedSamples = <SampleModel>[];
      for (final sample in samples) {
        var changed = false;
        if (mapping.containsKey(sample.path)) {
          sample.path = mapping[sample.path]!;
          changed = true;
        }
        final waveform = sample.waveformPath;
        if (waveform != null && mapping.containsKey(waveform)) {
          sample.waveformPath = mapping[waveform];
          changed = true;
        }
        if (changed) changedSamples.add(sample);
      }
      if (changedSamples.isNotEmpty) {
        await isar.sampleModels.putAll(changedSamples);
      }
    });
    await mappingFile.delete();
    await appliedMarker.delete();
  }

  /// Agrega el contenido de otra base sin borrar la configuracion actual.
  /// La escritura en la base actual es una sola transaccion: si algo falla,
  /// no queda una importacion parcial.
  @visibleForTesting
  static Future<void> mergeDatabase(
    File importedDatabase,
    String importName,
    Map<String, String> pathMap,
  ) async {
    final current = Isar.getInstance();
    if (current == null) {
      throw StateError('La base de datos actual no esta disponible.');
    }
    final incoming = await Isar.open(
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
      name: importName,
      directory: importedDatabase.parent.path,
      inspector: false,
    );

    try {
      // Cargar TODAS las colecciones en paralelo en vez de secuencialmente.
      final incomingResults = await Future.wait([
        incoming.genreModels.where().findAll(), // 0
        incoming.folderModels.where().findAll(), // 1
        incoming.sampleModels.where().findAll(), // 2
        incoming.macroModels.where().findAll(), // 3
        incoming.workspaceModels.where().findAll(), // 4
        incoming.pageModels.where().findAll(), // 5
        incoming.padModels.where().findAll(), // 6
        incoming.midiMappingModels.where().findAll(), // 7
      ]);
      final incomingGenres = incomingResults[0] as List<GenreModel>;
      final incomingFolders = incomingResults[1] as List<FolderModel>;
      final incomingSamples = incomingResults[2] as List<SampleModel>;
      final incomingMacros = incomingResults[3] as List<MacroModel>;
      final incomingWorkspaces = incomingResults[4] as List<WorkspaceModel>;
      final incomingPages = incomingResults[5] as List<PageModel>;
      final incomingPads = incomingResults[6] as List<PadModel>;
      final incomingMidi = incomingResults[7] as List<MidiMappingModel>;

      for (final folder in incomingFolders) {
        await folder.parent.load();
      }
      for (final sample in incomingSamples) {
        await sample.genre.load();
        await sample.folder.load();
      }
      for (final page in incomingPages) {
        await page.workspace.load();
      }
      for (final pad in incomingPads) {
        await pad.page.load();
        await pad.sample.load();
      }

      // Cargar colecciones existentes en paralelo.
      final existingResults = await Future.wait([
        current.genreModels.where().findAll(),
        current.sampleModels.where().findAll(),
        current.workspaceModels.where().findAll(),
        current.midiMappingModels.where().findAll(),
      ]);
      final existingGenres = existingResults[0] as List<GenreModel>;
      final existingSamples = existingResults[1] as List<SampleModel>;
      final existingWorkspaces = existingResults[2] as List<WorkspaceModel>;
      final existingMidi = existingResults[3] as List<MidiMappingModel>;
      final genreByName = {for (final item in existingGenres) item.name: item};
      final sampleByPath = {
        for (final item in existingSamples) item.path: item,
      };
      final usedWorkspaceNames = {
        for (final item in existingWorkspaces) item.name,
      };
      final midiKeys = {for (final item in existingMidi) _midiKey(item)};

      await current.writeTxn(() async {
        final genreMap = <int, GenreModel>{};
        for (final source in incomingGenres) {
          var target = genreByName[source.name];
          if (target == null) {
            target = GenreModel()
              ..name = source.name
              ..colorHex = source.colorHex
              ..iconData = source.iconData;
            await current.genreModels.put(target);
            genreByName[source.name] = target;
          }
          genreMap[source.id] = target;
        }

        final folderMap = <int, FolderModel>{};
        for (final source in incomingFolders) {
          final target = FolderModel()
            ..name = source.name
            ..colorHex = source.colorHex
            ..iconData = source.iconData;
          await current.folderModels.put(target);
          folderMap[source.id] = target;
        }
        for (final source in incomingFolders) {
          final parent = source.parent.value;
          if (parent == null) continue;
          final target = folderMap[source.id]!;
          target.parent.value = folderMap[parent.id];
          await target.parent.save();
        }

        final sampleMap = <int, SampleModel>{};
        for (final source in incomingSamples) {
          final restoredPath = pathMap[source.path] ?? source.path;
          var target = sampleByPath[restoredPath];
          if (target == null) {
            target = SampleModel()
              ..path = restoredPath
              ..name = source.name
              ..extension = source.extension
              ..sizeInBytes = source.sizeInBytes
              ..importedAt = source.importedAt
              ..isFavorite = source.isFavorite
              ..bpm = source.bpm
              ..tags = List<String>.from(source.tags)
              ..lastUsedAt = source.lastUsedAt
              ..useCount = source.useCount
              ..durationInSeconds = source.durationInSeconds
              ..waveformPath = source.waveformPath == null
                  ? null
                  : pathMap[source.waveformPath!] ?? source.waveformPath;
            target.genre.value = source.genre.value == null
                ? null
                : genreMap[source.genre.value!.id];
            target.folder.value = source.folder.value == null
                ? null
                : folderMap[source.folder.value!.id];
            await current.sampleModels.put(target);
            await target.genre.save();
            await target.folder.save();
            sampleByPath[restoredPath] = target;
          }
          sampleMap[source.id] = target;
        }

        final macroMap = <int, MacroModel>{};
        for (final source in incomingMacros) {
          final target = MacroModel()
            ..name = source.name
            ..actionsJson = source.actionsJson
            ..createdAt = source.createdAt
            ..updatedAt = source.updatedAt;
          await current.macroModels.put(target);
          macroMap[source.id] = target;
        }

        final workspaceMap = <int, WorkspaceModel>{};
        for (final source in incomingWorkspaces) {
          final target = WorkspaceModel()
            ..name = _uniqueWorkspaceName(source.name, usedWorkspaceNames)
            ..createdAt = source.createdAt
            ..isLocked = source.isLocked;
          await current.workspaceModels.put(target);
          usedWorkspaceNames.add(target.name);
          workspaceMap[source.id] = target;
        }

        final pageMap = <int, PageModel>{};
        for (final source in incomingPages) {
          final sourceWorkspace = source.workspace.value;
          if (sourceWorkspace == null) continue;
          final target = PageModel()
            ..pageIndex = source.pageIndex
            ..name = source.name
            ..columns = source.columns
            ..rows = source.rows
            ..workspace.value = workspaceMap[sourceWorkspace.id];
          await current.pageModels.put(target);
          await target.workspace.save();
          pageMap[source.id] = target;
        }
        // Segundo pase: los ids de pagina cambian al importar, por lo que
        // parentPageId debe remapearse (id fuente -> id nuevo) o el arbol de
        // carpetas del workspace restaurado pierde sus paginas internas.
        for (final source in incomingPages) {
          if (source.parentPageId == null) continue;
          final target = pageMap[source.id];
          if (target == null) continue;
          final newParent = pageMap[source.parentPageId];
          if (newParent == null) continue;
          target.parentPageId = newParent.id;
          await current.pageModels.put(target);
        }

        final padIdMap = <int, int>{};
        for (final source in incomingPads) {
          final sourcePage = source.page.value;
          if (sourcePage == null || pageMap[sourcePage.id] == null) continue;
          final target = PadModel()
            ..padId = source.padId
            ..colorHex = source.colorHex
            ..label = source.label
            ..x = source.x
            ..y = source.y
            ..width = source.width
            ..height = source.height
            ..samplePath = source.samplePath == null
                ? null
                : pathMap[source.samplePath!] ?? source.samplePath
            ..triggerModeIndex = source.triggerModeIndex
            ..padTypeIndex = source.padTypeIndex
            ..targetPageIndex = source.targetPageIndex
            ..targetMacroId = source.targetMacroId == null
                ? null
                : macroMap[source.targetMacroId!]?.id
            ..chokeGroup = source.chokeGroup
            ..pan = source.pan
            ..pitch = source.pitch
            ..isProtected = source.isProtected
            ..reverse = source.reverse
            ..fadeInMs = source.fadeInMs
            ..fadeOutMs = source.fadeOutMs
            ..startPointMs = source.startPointMs
            ..endPointMs = source.endPointMs
            ..loopPointMs = source.loopPointMs
            ..backgroundImagePath = source.backgroundImagePath == null
                ? null
                : pathMap[source.backgroundImagePath!] ??
                      source.backgroundImagePath
            ..page.value = pageMap[sourcePage.id]
            ..sample.value = source.sample.value == null
                ? null
                : sampleMap[source.sample.value!.id];
          await current.padModels.put(target);
          await target.page.save();
          await target.sample.save();
          padIdMap[source.id] = target.id;
        }

        for (final source in incomingMacros) {
          final target = macroMap[source.id]!;
          target.actionsJson = _remapMacroActions(
            source.actionsJson,
            workspaceMap,
            padIdMap,
          );
          await current.macroModels.put(target);
        }

        for (final source in incomingMidi) {
          var actionValue = source.actionValue;
          if (source.actionType == 'triggerPad') {
            final oldPadId = int.tryParse(actionValue);
            if (oldPadId != null && padIdMap[oldPadId] != null) {
              actionValue = padIdMap[oldPadId].toString();
            }
          } else if (source.actionType == 'executeMacro') {
            final oldMacroId = int.tryParse(actionValue);
            if (oldMacroId != null && macroMap[oldMacroId] != null) {
              actionValue = macroMap[oldMacroId]!.id.toString();
            }
          }
          final target = MidiMappingModel()
            ..noteOrCC = source.noteOrCC
            ..statusByte = source.statusByte
            ..actionType = source.actionType
            ..actionValue = actionValue;
          if (!midiKeys.add(_midiKey(target))) continue;
          await current.midiMappingModels.put(target);
        }
      });
    } finally {
      await incoming.close(deleteFromDisk: true);
    }
  }

  static String _uniqueWorkspaceName(String source, Set<String> used) {
    if (!used.contains(source)) return source;
    final base = '$source (importado)';
    if (!used.contains(base)) return base;
    var number = 2;
    while (used.contains('$base $number')) {
      number++;
    }
    return '$base $number';
  }

  static String _midiKey(MidiMappingModel item) =>
      '${item.statusByte}|${item.noteOrCC}|${item.actionType}|${item.actionValue}';

  static String _remapMacroActions(
    String source,
    Map<int, WorkspaceModel> workspaceMap,
    Map<int, int> padIdMap,
  ) {
    try {
      final actions = jsonDecode(source) as List<dynamic>;
      for (final raw in actions) {
        final action = raw as Map<String, dynamic>;
        final params = action['params'] as Map<String, dynamic>?;
        if (params == null) continue;
        if (action['type'] == 'changeWorkspace') {
          final oldId = (params['workspaceId'] as num?)?.toInt();
          if (oldId != null && workspaceMap[oldId] != null) {
            params['workspaceId'] = workspaceMap[oldId]!.id;
          }
        } else if (action['type'] == 'triggerPad') {
          final oldId = int.tryParse(params['padId']?.toString() ?? '');
          if (oldId != null && padIdMap[oldId] != null) {
            params['padId'] = padIdMap[oldId].toString();
          }
        }
      }
      return jsonEncode(actions);
    } catch (_) {
      return source;
    }
  }

  static Future<Set<String>> _collectReferencedPaths(Isar isar) async {
    final paths = <String>{};
    final pads = await isar.padModels.where().findAll();
    for (final pad in pads) {
      final samplePath = pad.samplePath;
      final backgroundPath = pad.backgroundImagePath;
      if (samplePath != null && samplePath.isNotEmpty) paths.add(samplePath);
      if (backgroundPath != null && backgroundPath.isNotEmpty) {
        paths.add(backgroundPath);
      }
    }
    final samples = await isar.sampleModels.where().findAll();
    for (final sample in samples) {
      if (sample.path.isNotEmpty) paths.add(sample.path);
      final waveformPath = sample.waveformPath;
      if (waveformPath != null && waveformPath.isNotEmpty) {
        paths.add(waveformPath);
      }
    }
    return paths;
  }

  static File? _findStagedFile(Directory stagingDir, String entryName) {
    final direct = File(p.join(stagingDir.path, entryName));
    if (direct.existsSync()) return direct;

    final normalizedTarget = entryName
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'^[./\\]+'), '')
        .toLowerCase();

    for (final entity in stagingDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final rel = p
          .relative(entity.path, from: stagingDir.path)
          .replaceAll('\\', '/')
          .replaceAll(RegExp(r'^[./\\]+'), '')
          .toLowerCase();

      if (rel == normalizedTarget ||
          rel.endsWith('/$normalizedTarget') ||
          p.basename(rel) == p.basename(normalizedTarget)) {
        return entity;
      }
    }
    return null;
  }

  static Future<void> _verifyAndMove(
    Directory stagingDir,
    String entryName,
    File target,
    Map<String, dynamic> expected,
  ) async {
    if (entryName.contains('..') || p.isAbsolute(entryName)) {
      throw const FormatException('Ruta insegura dentro del respaldo.');
    }
    final source = _findStagedFile(stagingDir, entryName);
    if (source == null || !await source.exists()) {
      throw FormatException('Falta el archivo $entryName.');
    }
    final expectedSize = expected['size'] as int;
    if (expectedSize < 0 || await source.length() != expectedSize) {
      throw FormatException('El tamaño de $entryName no coincide.');
    }
    final expectedHash = expected['sha256'] as String;
    if (await _fileHash(source) != expectedHash) {
      throw FormatException('El archivo $entryName esta dañado.');
    }
    await target.parent.create(recursive: true);
    if (await target.exists()) {
      await target.delete();
    }
    try {
      await source.rename(target.path);
    } catch (_) {
      await source.copy(target.path);
      try {
        await source.delete();
      } catch (_) {}
    }
  }

  static Future<void> _restorePreferences(File source) async {
    final decoded = jsonDecode(await source.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Preferencias invalidas.');
    }
    final prefs = await SharedPreferences.getInstance();
    for (final entry in decoded.entries) {
      if (!_portablePreferencesWhitelist.contains(entry.key)) continue;
      final value = entry.value;
      if (value is bool) await prefs.setBool(entry.key, value);
      if (value is int) await prefs.setInt(entry.key, value);
      if (value is double) await prefs.setDouble(entry.key, value);
      if (value is String) await prefs.setString(entry.key, value);
      if (value is List) {
        await prefs.setStringList(entry.key, value.cast<String>());
      }
    }
  }

  static Future<String> _fileHash(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
