import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import '../../data/models/workspace_model.dart';
import '../../data/models/page_model.dart';
import '../../../pad_system/data/models/pad_model.dart';
import '../../../../core/utils/zip_utils.dart';
import '../../../../core/services/app_storage_service.dart';
import '../../../../core/services/local_audio_storage_service.dart';

/// Exporta un workspace COMPLETO (todas sus paginas visibles y de carpeta,
/// todos los pads con su configuracion y sus audios) a un archivo .sppworkspace.
/// Usa `samplePath` directo (flujo actual de la app).
class WorkspaceExporter {
  final Future<Isar> dbFuture;

  WorkspaceExporter(this.dbFuture);

  /// Exporta el workspace a un archivo temporal y devuelve su ruta.
  /// Mantiene compatibilidad total con llamadas y tests existentes.
  Future<String?> exportWorkspace(
    int workspaceId, {
    void Function(int current, int total)? onProgress,
  }) async {
    var isar = await dbFuture;
    var workspace = await isar.workspaceModels.get(workspaceId);
    if (workspace == null) return null;

    final work = await AppStorageService.workDirectory('workspace_export');
    var mediaDir = Directory('${work.path}/media');
    await mediaDir.create(recursive: true);
    var exportPath = '${work.path}/export.sppworkspace';

    var pages = await isar.pageModels
        .filter()
        .workspace((q) => q.idEqualTo(workspace.id))
        .findAll();
    final pageById = {for (final page in pages) page.id: page};
    pages.sort((a, b) => a.pageIndex.compareTo(b.pageIndex));

    // Validar consistencia de la jerarquía antes de tocar disco: todo
    // parentPageId referenciado debe existir. Si hay páginas/folder huérfanas
    // el workspace está corrupto y no se anuncia éxito (retorna null).
    for (final page in pages) {
      if (page.parentPageId != null &&
          !pageById.containsKey(page.parentPageId)) {
        debugPrint(
          '[WorkspaceExporter] Abortando export: página '
          '${page.pageIndex} referencia parentPageId '
          '${page.parentPageId} inexistente.',
        );
        return null;
      }
    }

    // Pre-cargar pads para saber el total de elementos a exportar
    final pagesWithPads = <(PageModel, List<PadModel>)>[];
    var totalPads = 0;
    for (var page in pages) {
      var pads = await isar.padModels
          .filter()
          .page((q) => q.idEqualTo(page.id))
          .findAll();
      pagesWithPads.add((page, pads));
      totalPads += pads.length;
    }
    onProgress?.call(0, totalPads > 0 ? totalPads : 1);

    var padsMeta = <Map<String, dynamic>>[];
    var mediaSeen = <String, String>{}; // srcPath -> mediaName
    var processedPads = 0;

    for (final (page, pads) in pagesWithPads) {
      for (var pad in pads) {
        String? mediaName;
        if (pad.samplePath != null && pad.samplePath!.isNotEmpty) {
          final resolved = await LocalAudioStorageService.resolvePath(
            pad.samplePath!,
          );
          var src = File(resolved);
          if (await src.exists()) {
            mediaName = mediaSeen[pad.samplePath!];
            if (mediaName == null) {
              mediaName = '${mediaSeen.length}_${src.uri.pathSegments.last}';
              await src.copy('${mediaDir.path}/$mediaName');
              mediaSeen[pad.samplePath!] = mediaName;
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

        processedPads++;
        onProgress?.call(processedPads, totalPads > 0 ? totalPads : 1);
      }
    }

    var metadata = {
      'format': 'bdj-studio-sample-pad-workspace',
      'version': 1,
      'workspace': {'name': workspace.name},
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
    };

    await File(
      '${work.path}/metadata.json',
    ).writeAsString(jsonEncode(metadata));

    // Comprimir en un isolate para no bloquear la UI.
    await compute(
      zipDirectoryInIsolate,
      ZipHelperArgs(
        metadataPath: '${work.path}/metadata.json',
        mediaDirPath: mediaDir.path,
        outputPath: exportPath,
      ),
    );
    return exportPath;
  }

  /// Exporta el workspace solicitando la ruta de guardado al usuario
  /// mediante [FilePicker.saveFile]. Retorna la ruta final elegida o null si cancela.
  Future<String?> exportWorkspaceWithPicker({
    required int workspaceId,
    void Function(int current, int total)? onProgress,
  }) async {
    final isar = await dbFuture;
    final workspace = await isar.workspaceModels.get(workspaceId);
    if (workspace == null) return null;

    final sanitizedName = workspace.name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(' ', '_');

    final output = await FilePicker.saveFile(
      dialogTitle: 'Exportar workspace',
      fileName: '$sanitizedName.sppworkspace',
      type: FileType.custom,
      allowedExtensions: const ['sppworkspace'],
    );
    if (output == null) return null;

    final finalOutput = output.toLowerCase().endsWith('.sppworkspace')
        ? output
        : '$output.sppworkspace';

    final tempExportPath = await exportWorkspace(
      workspaceId,
      onProgress: onProgress,
    );
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
