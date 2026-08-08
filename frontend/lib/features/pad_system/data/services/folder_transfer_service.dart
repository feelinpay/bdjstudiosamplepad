import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../../../../core/services/local_audio_storage_service.dart';
import '../../../../core/services/app_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/zip_utils.dart';
import '../../../workspace/data/models/page_model.dart';

/// Datos de una carpeta importada desde un archivo .sppfolder.
class ImportedFolder {
  final String name;
  final int colorHex;
  final List<ImportedPad> pads;
  final List<ImportedFolder> subfolders;
  ImportedFolder({
    required this.name,
    required this.colorHex,
    required this.pads,
    required this.subfolders,
  });
}

class ImportedPad {
  final String label;
  final int colorHex;
  final int triggerModeIndex;
  final int padTypeIndex;
  final int chokeGroup;
  final double pan;
  final double pitch;
  final bool isProtected;
  final bool reverse;
  final String? samplePath;
  final int? targetPageIndex;
  final int? targetMacroId;
  final ImportedFolder? childFolder;
  final int fadeInMs;
  final int fadeOutMs;
  final int startPointMs;
  final int? endPointMs;
  final int loopPointMs;
  final String? backgroundImagePath;
  ImportedPad({
    required this.label,
    required this.colorHex,
    required this.triggerModeIndex,
    required this.padTypeIndex,
    required this.chokeGroup,
    required this.pan,
    required this.pitch,
    required this.isProtected,
    required this.reverse,
    required this.samplePath,
    required this.targetPageIndex,
    required this.targetMacroId,
    required this.childFolder,
    this.fadeInMs = 0,
    this.fadeOutMs = 0,
    this.startPointMs = 0,
    this.endPointMs,
    this.loopPointMs = 0,
    this.backgroundImagePath,
  });
}

/// Exporta e importa una carpeta de pads COMPLETA (metadata + audios) en un
/// solo archivo .sppfolder, para compartir/reutilizar kits entre workspaces.
class FolderTransferService {
  const FolderTransferService._();

  static Future<ImportedFolder?> _buildFolderNode(
    Isar isar,
    int pageIndex,
    Directory mediaDir,
  ) async {
    final page = await isar.pageModels
        .filter()
        .pageIndexEqualTo(pageIndex)
        .findFirst();
    if (page == null) return null;

    await page.pads.load();
    final sortedPads = [...page.pads]
      ..sort((a, b) => a.padId.compareTo(b.padId));

    final pads = <ImportedPad>[];
    final subfolders = <ImportedFolder>[];
    for (final pad in sortedPads) {
      String? mediaName;
      if (pad.samplePath != null && pad.samplePath!.isNotEmpty) {
        final resolvedPath = await LocalAudioStorageService.resolvePath(
          pad.samplePath!,
        );
        final src = File(resolvedPath);
        if (await src.exists()) {
          mediaName = '${pad.padId}_${src.uri.pathSegments.last}';
          await src.copy('${mediaDir.path}/$mediaName');
        }
      }

      ImportedFolder? childFolder;
      if (pad.padTypeIndex == 1 && pad.targetPageIndex != null) {
        childFolder = await _buildFolderNode(
          isar,
          pad.targetPageIndex!,
          mediaDir,
        );
      }

      if (childFolder != null) {
        subfolders.add(childFolder);
      }

      pads.add(
        ImportedPad(
          label: pad.label,
          colorHex: pad.colorHex,
          triggerModeIndex: pad.triggerModeIndex,
          padTypeIndex: pad.padTypeIndex,
          chokeGroup: pad.chokeGroup,
          pan: pad.pan,
          pitch: pad.pitch,
          isProtected: pad.isProtected,
          reverse: pad.reverse,
          samplePath: mediaName,
          targetPageIndex: pad.targetPageIndex,
          targetMacroId: pad.targetMacroId,
          childFolder: childFolder,
          fadeInMs: pad.fadeInMs,
          fadeOutMs: pad.fadeOutMs,
          startPointMs: pad.startPointMs,
          endPointMs: pad.endPointMs,
          loopPointMs: pad.loopPointMs,
          backgroundImagePath: pad.backgroundImagePath,
        ),
      );
    }

    return ImportedFolder(
      name: page.name ?? 'Carpeta',
      colorHex: sortedPads.isNotEmpty ? sortedPads.first.colorHex : AppColors.folderPadColor,
      pads: pads,
      subfolders: subfolders,
    );
  }

  /// Exporta la carpeta indicada por [pageIndex] con toda su jerarquía.
  static Future<String?> exportFolder({
    required String name,
    required int colorHex,
    required int pageIndex,
    required Future<Isar> dbFuture,
  }) async {
    final isar = await dbFuture;
    final work = await AppStorageService.workDirectory('folder_export');
    try {
      var mediaDir = Directory('${work.path}/media');
      await mediaDir.create();
      final root = await _buildFolderNode(isar, pageIndex, mediaDir);
      if (root == null) return null;

      final metadata = {
        'folder': {'name': name, 'colorHex': colorHex, 'pageIndex': pageIndex},
        'pads': _serializePads(root.pads),
        'subfolders': root.subfolders.map(_serializeFolder).toList(),
      };
      await File(
        '${work.path}/metadata.json',
      ).writeAsString(jsonEncode(metadata));

      var output = await FilePicker.saveFile(
        dialogTitle: 'Exportar carpeta',
        fileName: '${name.replaceAll(' ', '_')}.sppfolder',
        type: FileType.custom,
        allowedExtensions: ['sppfolder'],
      );
      if (output == null) return null;

      // Comprimir en un isolate para no bloquear la UI.
      await compute(
        zipDirectoryInIsolate,
        ZipHelperArgs(
          metadataPath: '${work.path}/metadata.json',
          mediaDirPath: mediaDir.path,
          outputPath: output,
        ),
      );
      return output;
    } finally {
      // Limpiar el directorio temporal de trabajo (metadata + audios copiados)
      // para no dejar basura en disco tras exportar o cancelar.
      if (await work.exists()) {
        try {
          await work.delete(recursive: true);
        } catch (e, st) {
          debugPrint('[FolderTransfer] No se pudo limpiar el temp: $e\n$st');
        }
      }
    }
  }

  static List<Map<String, dynamic>> _serializePads(List<ImportedPad> pads) {
    return pads
        .map(
          (pad) => {
            'label': pad.label,
            'colorHex': pad.colorHex,
            'triggerModeIndex': pad.triggerModeIndex,
            'padTypeIndex': pad.padTypeIndex,
            'chokeGroup': pad.chokeGroup,
            'pan': pad.pan,
            'pitch': pad.pitch,
            'isProtected': pad.isProtected,
            'reverse': pad.reverse,
            'samplePath': pad.samplePath,
            'targetPageIndex': pad.targetPageIndex,
            'targetMacroId': pad.targetMacroId,
            'childFolder': pad.childFolder != null
                ? _serializeFolder(pad.childFolder!)
                : null,
            'fadeInMs': pad.fadeInMs,
            'fadeOutMs': pad.fadeOutMs,
            'startPointMs': pad.startPointMs,
            'endPointMs': pad.endPointMs,
            'loopPointMs': pad.loopPointMs,
            'backgroundImagePath': pad.backgroundImagePath,
          },
        )
        .toList();
  }

  static Map<String, dynamic> _serializeFolder(ImportedFolder folder) {
    return {
      'name': folder.name,
      'colorHex': folder.colorHex,
      'pads': _serializePads(folder.pads),
      'subfolders': folder.subfolders.map(_serializeFolder).toList(),
    };
  }

  /// Selecciona un .sppfolder, copia sus audios a la app y devuelve los datos.
  static Future<ImportedFolder?> pickFolder() async {
    var picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['sppfolder'],
    );
    if (picked == null || picked.files.single.path == null) return null;

    // Leer y descomprimir en isolate.
    var bytes = await File(picked.files.single.path!).readAsBytes();
    var archive = await compute(decodeZipInIsolate, bytes);

    return _processArchive(archive);
  }

  /// Lee un .sppfolder o .zip desde una ruta de archivo y devuelve los datos.
  static Future<ImportedFolder?> readFolderFile(String filePath) async {
    try {
      var bytes = await File(filePath).readAsBytes();
      var archive = await compute(decodeZipInIsolate, bytes);
      return _processArchive(archive);
    } catch (_) {
      return null;
    }
  }

  /// Procesa un archivo ya descomprimido (reutilizado por pickFolder y readFolderFile).
  static Future<ImportedFolder?> _processArchive(Archive archive) async {
    Map<String, dynamic>? metadata;
    var mediaPaths = <String, String>{};
    final pendingMedia = <MapEntry<String, List<int>>>[];
    for (var entry in archive) {
      if (!entry.isFile) continue;
      if (entry.name.endsWith('metadata.json')) {
        metadata =
            jsonDecode(utf8.decode(entry.content as List<int>))
                as Map<String, dynamic>;
      } else if (entry.name.contains('media/')) {
        var base = entry.name.split('/').last;
        pendingMedia.add(MapEntry(base, entry.content as List<int>));
      }
    }
    if (metadata == null) return null;

    var folder = metadata['folder'] as Map<String, dynamic>;
    final namespace =
        'folder_imports/${_sanitizeNamespace(folder['name'] as String? ?? 'Carpeta')}';
    for (final item in pendingMedia) {
      final localPath = await LocalAudioStorageService.importAudioBytes(
        item.key,
        item.value,
        namespace: namespace,
      );
      mediaPaths[item.key] = localPath;
    }

    var padsList = (metadata['pads'] as List).cast<Map<String, dynamic>>();
    var pads = padsList.map((p) => _deserializePad(p, mediaPaths)).toList();
    var subfolders = ((metadata['subfolders'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((folderData) => _deserializeFolder(folderData, mediaPaths))
        .toList();

    return ImportedFolder(
      name: folder['name'] as String? ?? 'Carpeta',
      colorHex: folder['colorHex'] as int? ?? AppColors.folderPadColor,
      pads: pads,
      subfolders: subfolders,
    );
  }

  static String _sanitizeNamespace(String value) {
    // Mismas reglas que el almacenamiento de audios: preserva los espacios
    // naturales (antes usaba guiones bajos, lo que hacía que el import no
    // coincidiera con la carpeta física del pad-carpeta).
    return LocalAudioStorageService.sanitizeSegment(value);
  }

  static ImportedPad _deserializePad(
    Map<String, dynamic> data,
    Map<String, String> mediaPaths,
  ) {
    final media = data['samplePath'] as String?;
    final childFolderData = data['childFolder'] as Map<String, dynamic>?;
    return ImportedPad(
      label: data['label'] as String? ?? 'PAD',
      colorHex: data['colorHex'] as int? ?? 0xFF7C4DFF,
      triggerModeIndex: data['triggerModeIndex'] as int? ?? 0,
      padTypeIndex: data['padTypeIndex'] as int? ?? 0,
      chokeGroup: data['chokeGroup'] as int? ?? 0,
      pan: (data['pan'] as num?)?.toDouble() ?? 0.0,
      pitch: (data['pitch'] as num?)?.toDouble() ?? 1.0,
      isProtected: data['isProtected'] as bool? ?? false,
      reverse: data['reverse'] as bool? ?? false,
      samplePath: media != null ? mediaPaths[media] : null,
      targetPageIndex: data['targetPageIndex'] as int?,
      targetMacroId: data['targetMacroId'] as int?,
      childFolder: childFolderData != null
          ? _deserializeFolder(childFolderData, mediaPaths)
          : null,
      fadeInMs: data['fadeInMs'] as int? ?? 0,
      fadeOutMs: data['fadeOutMs'] as int? ?? 0,
      startPointMs: data['startPointMs'] as int? ?? 0,
      endPointMs: data['endPointMs'] as int?,
      loopPointMs: data['loopPointMs'] as int? ?? 0,
      backgroundImagePath: data['backgroundImagePath'] as String?,
    );
  }

  static ImportedFolder _deserializeFolder(
    Map<String, dynamic> data,
    Map<String, String> mediaPaths,
  ) {
    final pads = ((data['pads'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((pad) => _deserializePad(pad, mediaPaths))
        .toList();
    final subfolders = ((data['subfolders'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((folder) => _deserializeFolder(folder, mediaPaths))
        .toList();
    return ImportedFolder(
      name: data['name'] as String? ?? 'Carpeta',
      colorHex: data['colorHex'] as int? ?? AppColors.folderPadColor,
      pads: pads,
      subfolders: subfolders,
    );
  }
}
