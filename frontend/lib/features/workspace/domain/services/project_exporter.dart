import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/app_storage_service.dart';
import '../../../../core/services/local_audio_storage_service.dart';
import '../../../../core/utils/zip_utils.dart';
import '../../../macros/data/models/macro_model.dart';
import '../../../midi/data/models/midi_mapping_model.dart';
import '../../data/models/workspace_model.dart';

/// Exportador de proyecto completo (v2: Formato bdj-studio-sample-pad-project).
///
/// Serializa exclusivamente el contenido musical del proyecto: todos los
/// workspaces, páginas/carpetas, pads con sus ediciones de audio,
/// muestras de audio deduplicadas, macros y mapeos MIDI.
/// De SharedPreferences solo exporta workspace_order_ids (para remapear)
/// y una lista blanca estricta de preferencias cosméticas de UI.
/// NUNCA exporta licencias, tokens, hardware fingerprint (HWID 'bdj.hwid.v2') ni device IDs.
class ProjectExporter {
  final Future<Isar> dbFuture;

  static const String supportedFormat = 'bdj-studio-sample-pad-project';
  static const int currentVersion = 2;

  /// Sanea nombres de archivo para compatibilidad estricta multiplataforma (Windows/Android/macOS/Linux).
  /// Elimina caracteres ilegales en Windows/FAT32/NTFS: < > : " / \ | ? * y caracteres de control (0x00-0x1F),
  /// espacios o puntos finales, y nombres de dispositivos reservados (CON, NUL, COM1-9, etc.).
  static String _sanitizeZipEntryName(String originalName) {
    var ext = p.extension(originalName).toLowerCase();
    ext = ext.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    var base = p.basenameWithoutExtension(originalName);
    base = base.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
    while (base.endsWith('.') || base.endsWith(' ')) {
      base = base.substring(0, base.length - 1).trim();
    }
    const reservedNames = {
      'CON', 'PRN', 'AUX', 'NUL',
      'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
      'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
    };
    if (base.isEmpty || reservedNames.contains(base.toUpperCase())) {
      base = 'sample_${base.isEmpty ? "audio" : base}';
    }
    return '$base$ext';
  }

  /// Lista blanca estricta: NINGUNA otra clave de SharedPreferences sale en la exportación.
  static const portablePreferencesWhitelist = <String>{
    'theme_mode',
    'left_handed',
    'high_contrast',
    'font_scale',
    'snap_to_grid',
    'app_mode',
    'enable_pad_shortcuts',
  };

  ProjectExporter(this.dbFuture);

  /// Exporta el proyecto completo a un archivo temporal y devuelve su ruta.
  Future<String?> exportProject({
    void Function(int current, int total)? onProgress,
  }) async {
    final isar = await dbFuture;
    final workspaces = await isar.workspaceModels.where().findAll();
    if (workspaces.isEmpty) return null;

    final work = await AppStorageService.workDirectory('project_export');
    final mediaDir = Directory(p.join(work.path, 'media'));
    await mediaDir.create(recursive: true);
    final exportPath = p.join(work.path, 'export.sppproject');

    // 1. Recolectar todas las páginas y pads de todos los workspaces
    final allWorkspaceData = <Map<String, dynamic>>[];
    final mediaSeen = <String, String>{}; // storedPath -> mediaName
    final canonicalPathSeen = <String, String>{}; // canonicalPath -> mediaName
    final mediaFilesToCopy = <(File, String)>[]; // (sourceFile, targetName)

    for (final ws in workspaces) {
      final pages = await ws.pages
          .filter()
          .findAll();
      final pageById = {for (final page in pages) page.id: page};
      pages.sort((a, b) => a.pageIndex.compareTo(b.pageIndex));

      final padsMeta = <Map<String, dynamic>>[];

      for (final page in pages) {
        final pads = await page.pads
            .filter()
            .findAll();

        for (final pad in pads) {
          String? mediaName;
          if (pad.samplePath != null && pad.samplePath!.isNotEmpty) {
            final storedPath = pad.samplePath!;
            if (mediaSeen.containsKey(storedPath)) {
              mediaName = mediaSeen[storedPath];
            } else {
              final resolved = await LocalAudioStorageService.resolvePath(
                storedPath,
              );
              final src = File(resolved);
              if (await src.exists()) {
                final canonicalKey = (Platform.isWindows || Platform.isMacOS)
                    ? src.absolute.path.toLowerCase()
                    : src.absolute.path;
                if (canonicalPathSeen.containsKey(canonicalKey)) {
                  mediaName = canonicalPathSeen[canonicalKey];
                  mediaSeen[storedPath] = mediaName!;
                } else {
                  final safeBase = _sanitizeZipEntryName(p.basename(resolved));
                  mediaName = '${mediaFilesToCopy.length}_$safeBase';
                  canonicalPathSeen[canonicalKey] = mediaName;
                  mediaSeen[storedPath] = mediaName;
                  mediaFilesToCopy.add((src, mediaName));
                }
              }
            }
          }

          padsMeta.add({
            'pageIndex': page.pageIndex,
            'padId': pad.padId,
            'label': pad.label,
            'colorHex': pad.colorHex,
            'triggerModeIndex': pad.triggerModeIndex,
            'padTypeIndex': pad.padTypeIndex,
            'targetPageIndex': pad.targetPageIndex,
            'targetMacroId': pad.targetMacroId,
            'chokeGroup': pad.chokeGroup,
            'pan': pad.pan,
            'pitch': pad.pitch,
            'volume': pad.volume,
            'isProtected': pad.isProtected,
            'reverse': pad.reverse,
            'media': mediaName,
            'fadeInMs': pad.fadeInMs,
            'fadeOutMs': pad.fadeOutMs,
            'startPointMs': pad.startPointMs,
            'endPointMs': pad.endPointMs,
            'loopPointMs': pad.loopPointMs,
          });
        }
      }

      allWorkspaceData.add({
        'id': ws.id,
        'name': ws.name,
        'createdAt': ws.createdAt.toIso8601String(),
        'pages': pages
            .map(
              (p) => {
                'pageIndex': p.pageIndex,
                'name': p.name,
                'columns': p.columns,
                'rows': p.rows,
                'parentPageIndex': p.parentPageId != null
                    ? pageById[p.parentPageId!]?.pageIndex
                    : null,
              },
            )
            .toList(),
        'pads': padsMeta,
      });
    }

    // 2. Copiar los archivos de audio deduplicados a media/ (progreso real durante la copia I/O)
    final totalAudioFiles = mediaFilesToCopy.length;
    onProgress?.call(0, totalAudioFiles > 0 ? totalAudioFiles : 1);
    var copiedAudioCount = 0;

    for (final (srcFile, targetName) in mediaFilesToCopy) {
      await srcFile.copy(p.join(mediaDir.path, targetName));
      copiedAudioCount++;
      onProgress?.call(
        copiedAudioCount,
        totalAudioFiles > 0 ? totalAudioFiles : 1,
      );
    }

    // 3. Serializar Macros
    final macros = await isar.macroModels.where().findAll();
    final macrosMeta = macros
        .map(
          (m) => {
            'id': m.id,
            'name': m.name,
            'actionsJson': m.actionsJson,
            'createdAt': m.createdAt.toIso8601String(),
            'updatedAt': m.updatedAt?.toIso8601String(),
          },
        )
        .toList();

    // 4. Serializar Mapeos MIDI
    final midiMappings = await isar.midiMappingModels.where().findAll();
    final midiMeta = midiMappings
        .map(
          (m) => {
            'noteOrCC': m.noteOrCC,
            'statusByte': m.statusByte,
            'actionType': m.actionType,
            'actionValue': m.actionValue,
          },
        )
        .toList();

    // 5. Preferencias estrictamente filtradas por lista blanca y orden de workspaces
    final prefs = await SharedPreferences.getInstance();
    final rawOrder = prefs.getStringList('workspace_order_ids') ?? [];
    final workspaceOrderOldIds = rawOrder
        .map((s) => int.tryParse(s))
        .whereType<int>()
        .toList();

    final preferences = <String, dynamic>{};
    for (final key in portablePreferencesWhitelist) {
      final val = prefs.get(key);
      if (val != null) {
        preferences[key] = val;
      }
    }

    // 6. Versión dinámica de la aplicación obtenida del runtime
    String appVersion = '1.0.3';
    try {
      final pkg = await PackageInfo.fromPlatform();
      appVersion = '${pkg.version}+${pkg.buildNumber}';
    } catch (_) {}

    // 7. Construir metadata.json exclusivamente con datos del proyecto
    final metadata = {
      'format': supportedFormat,
      'version': currentVersion,
      'appVersion': appVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'platform': Platform.operatingSystem,
      'workspaces': allWorkspaceData,
      'workspaceOrderOldIds': workspaceOrderOldIds,
      'macros': macrosMeta,
      'midiMappings': midiMeta,
      'preferences': preferences,
    };

    await File(
      p.join(work.path, 'metadata.json'),
    ).writeAsString(jsonEncode(metadata));

    // 7. Comprimir en isolate directamente a disco
    await compute(
      zipDirectoryInIsolate,
      ZipHelperArgs(
        metadataPath: p.join(work.path, 'metadata.json'),
        mediaDirPath: mediaDir.path,
        outputPath: exportPath,
      ),
    );

    return exportPath;
  }

  /// Exporta el proyecto solicitando la ubicación al usuario con FilePicker.
  Future<String?> exportProjectWithPicker({
    void Function(int current, int total)? onProgress,
  }) async {
    final timestamp = DateTime.now()
        .toIso8601String()
        .substring(0, 10)
        .replaceAll('-', '');
    final output = await FilePicker.saveFile(
      dialogTitle: 'Exportar proyecto completo',
      fileName: 'BDJ_Studio_Project_$timestamp.sppproject',
      type: FileType.custom,
      allowedExtensions: const ['sppproject', 'sppbackup'],
    );
    if (output == null) return null;

    final finalOutput = (output.toLowerCase().endsWith('.sppproject') ||
            output.toLowerCase().endsWith('.sppbackup'))
        ? output
        : '$output.sppproject';

    final tempExportPath = await exportProject(onProgress: onProgress);
    if (tempExportPath == null) return null;

    final tempFile = File(tempExportPath);
    await tempFile.copy(finalOutput);
    try {
      await tempFile.delete();
      final parentDir = tempFile.parent;
      if (await parentDir.exists()) {
        await parentDir.delete(recursive: true);
      }
    } catch (_) {}

    return finalOutput;
  }
}
