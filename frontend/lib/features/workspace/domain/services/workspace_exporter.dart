import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
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

  Future<String?> exportWorkspace(int workspaceId) async {
    var isar = await dbFuture;
    var workspace = await isar.workspaceModels.get(workspaceId);
    if (workspace == null) return null;

    final work = await AppStorageService.workDirectory('workspace_export');
    var mediaDir = Directory('${work.path}/media');
    await mediaDir.create();
    var exportPath = '${work.path}/export.sppworkspace';

    var pages = await isar.pageModels
        .filter()
        .workspace((q) => q.idEqualTo(workspace.id))
        .findAll();
    final pageById = {for (final page in pages) page.id: page};
    pages.sort((a, b) => a.pageIndex.compareTo(b.pageIndex));

    // Validar consistencia de la jerarquía antes de tocar disco: todo
    // parentPageId referenciado debe existir. Si hay páginas/folder huérfagas
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

    var padsMeta = <Map<String, dynamic>>[];
    var mediaSeen = <String, String>{}; // srcPath -> mediaName

    for (var page in pages) {
      var pads = await isar.padModels
          .filter()
          .page((q) => q.idEqualTo(page.id))
          .findAll();
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
          'isProtected': pad.isProtected,
          'reverse': pad.reverse,
          'media': mediaName,
          'fadeInMs': pad.fadeInMs,
          'fadeOutMs': pad.fadeOutMs,
          'startPointMs': pad.startPointMs,
          'endPointMs': pad.endPointMs,
          'loopPointMs': pad.loopPointMs,
          'backgroundImagePath': pad.backgroundImagePath,
        });
      }
    }

    var metadata = {
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
}
