import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../../domain/repositories/workspace_repository.dart';
import '../models/workspace_model.dart';
import '../models/page_model.dart';
import '../../../pad_system/data/models/pad_model.dart';
import '../../../macros/data/models/macro_model.dart';
import '../../../../core/services/local_audio_storage_service.dart';

class IsarWorkspaceRepository implements WorkspaceRepository {
  final Future<Isar> dbFuture;

  IsarWorkspaceRepository(this.dbFuture);

  Future<void> _deletePageTree(Isar isar, PageModel page) async {
    final children = await isar.pageModels
        .filter()
        .parentPageIdEqualTo(page.id)
        .findAll();
    for (final child in children) {
      await _deletePageTree(isar, child);
    }

    await page.pads.load();
    await isar.padModels.deleteAll(page.pads.map((p) => p.id).toList());
    await isar.pageModels.delete(page.id);
  }

  /// Evita borrar un audio si otro pad que permanece en la base lo comparte.
  Future<List<String>> _unsharedAudioPaths(
    Isar isar,
    Iterable<String> candidates,
    Set<int> deletingPadIds,
  ) async {
    final pathsInUse = (await isar.padModels.where().findAll())
        .where((pad) => !deletingPadIds.contains(pad.id))
        .map((pad) => pad.samplePath)
        .whereType<String>()
        .toSet();
    return candidates.where((path) => !pathsInUse.contains(path)).toList();
  }

  @override
  Future<List<WorkspaceModel>> getAllWorkspaces() async {
    var isar = await dbFuture;
    final list = await isar.workspaceModels.where().findAll();
    list.sort((a, b) => a.id.compareTo(b.id));
    for (final ws in list) {
      LocalAudioStorageService.ensureWorkspaceDir(ws.name);
    }
    return list;
  }

  @override
  Future<WorkspaceModel?> getWorkspace(int id) async {
    var isar = await dbFuture;
    return isar.workspaceModels.get(id);
  }

  @override
  Future<WorkspaceModel> createWorkspace(String name) async {
    var isar = await dbFuture;
    var workspace = WorkspaceModel()
      ..name = name
      ..createdAt = DateTime.now();

    await isar.writeTxn(() async {
      await isar.workspaceModels.put(workspace);
    });

    // Inicia con UNA pagina vacia (rediseño simple: sin escenas de ejemplo).
    await createPage(workspace.id, 0);
    await LocalAudioStorageService.ensureWorkspaceDir(workspace.name);

    return workspace;
  }

  @override
  Future<WorkspaceModel> duplicateWorkspace(int id) async {
    var isar = await dbFuture;
    var src = await getWorkspace(id);
    if (src == null) throw Exception('Workspace not found');
    await src.pages.load();

    // Nombre unico (Isar exige name unico).
    var baseName = '${src.name} (copia)';
    var existing = (await getAllWorkspaces()).map((w) => w.name).toSet();
    var name = baseName;
    var n = 2;
    while (existing.contains(name)) {
      name = '$baseName $n';
      n++;
    }

    var newWs = WorkspaceModel()
      ..name = name
      ..createdAt = DateTime.now()
      ..isLocked = false;

    await isar.writeTxn(() async {
      await isar.workspaceModels.put(newWs);
      
      // Build remapping tables for proper reference updates
      final pagesById = <int, PageModel>{};
      final pageIndexToNewPageIndex = <int, int>{};
      final pageIdToNewPageId = <int, int>{};
      
      final sourcePages = [...src.pages]
        ..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));

      // First pass: create all pages with new pageIndex values
      for (final srcPage in sourcePages) {
        await srcPage.pads.load();
        
        // Generate new pageIndex to avoid conflicts
        var newPageIndex = srcPage.pageIndex;
        final existingIndexes = pagesById.values.map((p) => p.pageIndex).toSet();
        while (existingIndexes.contains(newPageIndex)) {
          newPageIndex++;
        }
        
        final newPage = PageModel()
          ..pageIndex = newPageIndex
          ..name = srcPage.name
          ..columns = srcPage.columns
          ..rows = srcPage.rows
          ..parentPageId = srcPage.parentPageId // Will be updated in second pass
          ..workspace.value = newWs;
        await isar.pageModels.put(newPage);
        await newPage.workspace.save();
        
        pagesById[srcPage.id] = newPage;
        pageIndexToNewPageIndex[srcPage.pageIndex] = newPageIndex;
        pageIdToNewPageId[srcPage.id] = newPage.id;
      }

      // Second pass: update parentPageId references
      for (final srcPage in sourcePages) {
        final newPage = pagesById[srcPage.id];
        if (newPage == null) continue;
        
        if (srcPage.parentPageId != null) {
          final newParentPageId = pageIdToNewPageId[srcPage.parentPageId];
          if (newParentPageId != null) {
            newPage.parentPageId = newParentPageId;
            await isar.pageModels.put(newPage);
          }
        }
      }

      // Third pass: copy pads with updated references
      for (final srcPage in sourcePages) {
        final newPage = pagesById[srcPage.id];
        if (newPage == null) continue;
        await srcPage.pads.load();
        for (final pad in srcPage.pads) {
          final copy = PadModel()
            ..padId = pad.padId
            ..label = pad.label
            ..colorHex = pad.colorHex
            ..samplePath = pad.samplePath
            ..triggerModeIndex = pad.triggerModeIndex
            ..padTypeIndex = pad.padTypeIndex
            ..targetPageIndex = pad.targetPageIndex != null 
                ? pageIndexToNewPageIndex[pad.targetPageIndex] 
                : null
            ..targetMacroId = pad.targetMacroId
            ..chokeGroup = pad.chokeGroup
            ..pan = pad.pan
            ..pitch = pad.pitch
            ..isProtected = pad.isProtected
            ..reverse = pad.reverse
            ..fadeInMs = pad.fadeInMs
            ..fadeOutMs = pad.fadeOutMs
            ..startPointMs = pad.startPointMs
            ..endPointMs = pad.endPointMs
            ..loopPointMs = pad.loopPointMs
            ..backgroundImagePath = pad.backgroundImagePath;
          copy.page.value = newPage;
          await isar.padModels.put(copy);
          await copy.page.save();
        }
      }
    });
    await LocalAudioStorageService.ensureWorkspaceDir(newWs.name);
    return newWs;
  }

  @override
  Future<void> saveWorkspace(WorkspaceModel workspace) async {
    var isar = await dbFuture;
    await isar.writeTxn(() async {
      await isar.workspaceModels.put(workspace);
    });
  }

   @override
  Future<void> deleteWorkspace(int id) async {
    var isar = await dbFuture;
    var all = await getAllWorkspaces();
    if (all.length <= 1) {
      throw Exception('No se puede eliminar el único workspace existente.');
    }

    // Capturar el nombre ANTES de tocar la DB: se usa para limpiar
    // el directorio físico en disco que lleva el mismo nombre.
    final wsName = (await isar.workspaceModels.get(id))?.name;

    // Get workspace before deletion to collect pad IDs for audio cleanup
    var ws = await isar.workspaceModels.get(id);
    List<String> padIds = [];
    List<String> samplePaths = [];
    if (ws != null) {
      await ws.pages.load();
      for (final page in ws.pages) {
        await page.pads.load();
        for (final pad in page.pads) {
          padIds.add(pad.id.toString());
          if (pad.samplePath != null && pad.samplePath!.isNotEmpty) {
            samplePaths.add(pad.samplePath!);
          }
        }
      }
    }

    await isar.writeTxn(() async {
      var ws = await isar.workspaceModels.get(id);
      if (ws != null) {
        await ws.pages.load();
        final rootPages = ws.pages.toList()
          ..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
        for (final page in rootPages) {
          await _deletePageTree(isar, page);
        }
        await isar.workspaceModels.delete(id);
      }
    });

    // Defense-in-depth: la UI ya detiene el audio y borra archivos, pero el
    // repo también limpia el directorio físico y los huérfanos por si se
    // invoca directamente (p.ej. tests, restauraciones de backup).
    // Solo se borran los audios que NINGÚN pad que permanece en la base siga
    // usando: un archivo compartido (importado o copiado por duplicateWorkspace)
    // no debe desaparecer solo porque un workspace se elimine.
    final unsharedPaths = await _unsharedAudioPaths(
      isar,
      samplePaths,
      padIds.map(int.parse).toSet(),
    );
    if (unsharedPaths.isNotEmpty) {
      await LocalAudioStorageService.deleteAudioFiles(unsharedPaths);
    }
    if (wsName != null) {
      final wsSegment = LocalAudioStorageService.sanitizeSegment(wsName);
      final stillReferenced = await isar.padModels
          .filter()
          .samplePathStartsWith(
            '${LocalAudioStorageService.prefix}$wsSegment/',
          )
          .count();
      if (stillReferenced > 0) {
        // Un workspace duplicado u otro pad sigue usando audios dentro de esta
        // carpeta: conservarla en disco para no dejar a la copia sin sonido.
        debugPrint(
          'WorkspaceRepository: se conserva la carpeta física de "$wsName" '
          'porque $stillReferenced pads aún la referencian.',
        );
      } else {
        await LocalAudioStorageService.deleteWorkspaceDir(wsName);
      }
    }
    await LocalAudioStorageService.autoCleanOrphans(isar);

    // Return pad IDs for audio engine cleanup — caller should stop playback
    // before invoking this method to avoid orphaned voices.
    // padIds is intentionally surfaced for callers that manage live audio.
  }

  @override
  Future<PageModel> createPage(
    int workspaceId,
    int pageIndex, {
    int cols = 4,
    int rows = 4,
    String? name,
    int? parentPageId,
  }) async {
    var isar = await dbFuture;
    var workspace = await getWorkspace(workspaceId);
    if (workspace == null) throw Exception('Workspace not found');

    await workspace.pages.load();
    final siblingPages = workspace.pages
        .where((p) => p.parentPageId == parentPageId)
        .toList();
    siblingPages.sort((a, b) => a.pageIndex.compareTo(b.pageIndex));

    int targetIndex = pageIndex;
    final existingIndexes = workspace.pages.map((p) => p.pageIndex).toSet();
    if (existingIndexes.contains(targetIndex)) {
      if (parentPageId == null) {
        while (existingIndexes.contains(targetIndex) && targetIndex < 1000) {
          targetIndex++;
        }
      } else {
        while (existingIndexes.contains(targetIndex) || targetIndex < 1000) {
          targetIndex++;
        }
      }
    }

    var page = PageModel()
      ..pageIndex = targetIndex
      ..name = name ?? 'Página ${targetIndex + 1}'
      ..columns = cols
      ..rows = rows;
    page.parentPageId = parentPageId;

    page.workspace.value = workspace;

    await isar.writeTxn(() async {
      await isar.pageModels.put(page);
      await page.workspace.save();
    });

    return page;
  }

  @override
  Future<void> deletePage(int pageId) async {
    var isar = await dbFuture;
    var page = await isar.pageModels.get(pageId);
    if (page == null) return;

    await isar.writeTxn(() async {
      await _deletePageTree(isar, page);
    });
  }

  @override
  Future<void> deletePages(List<int> pageIds) async {
    var isar = await dbFuture;
    await isar.writeTxn(() async {
      for (final pageId in pageIds) {
        final page = await isar.pageModels.get(pageId);
        if (page != null) {
          await _deletePageTree(isar, page);
        }
      }
    });
  }

  @override
  Future<void> updatePageLayout(int pageId, int cols, int rows) async {
    var isar = await dbFuture;
    await isar.writeTxn(() async {
      var page = await isar.pageModels.get(pageId);
      if (page != null) {
        page.columns = cols;
        page.rows = rows;
        await isar.pageModels.put(page);
      }
    });
  }

  /// Remapea las referencias a paginas (pageIndex/targetPageIndex) guardadas
  /// en el actionsJson de una macro cuando el indice de una pagina fue
  /// renumerado por la reconciliacion. Respeta el ambito del workspace: una
  /// accion con workspaceId explicito de OTRO workspace no se toca.
  static String _remapMacroPageIndexes(
    String source,
    Map<int, int> pageIndexMap,
    int workspaceId,
  ) {
    try {
      final actions = jsonDecode(source) as List<dynamic>;
      var changed = false;
      for (final raw in actions) {
        final action = raw as Map<String, dynamic>;
        final params = action['params'] as Map<String, dynamic>?;
        if (params == null) continue;
        final wsRaw = params['targetWorkspaceId'] ?? params['workspaceId'];
        final wsRef = wsRaw is num
            ? wsRaw.toInt()
            : int.tryParse(wsRaw?.toString() ?? '');
        if (wsRef != null && wsRef != workspaceId) continue;
        for (final key in const ['targetPageIndex', 'pageIndex']) {
          final rawVal = params[key];
          final val = rawVal is num
              ? rawVal.toInt()
              : int.tryParse(rawVal?.toString() ?? '');
          if (val == null) continue;
          final mapped = pageIndexMap[val];
          if (mapped == null || mapped == val) continue;
          params[key] = mapped;
          changed = true;
        }
      }
      return changed ? jsonEncode(actions) : source;
    } catch (_) {
      return source;
    }
  }

  @override
  Future<void> reconcilePageIndexIntegrity(int workspaceId) async {
    final isar = await dbFuture;
    final ws = await isar.workspaceModels.get(workspaceId);
    if (ws == null) return;

    await ws.pages.load();
    final pages = [...ws.pages];
    if (pages.isEmpty) return;

    // Convención de integridad: root (parentPageId == null) → pageIndex < 1000;
    // folder-hidden (parentPageId != null) → pageIndex >= 1000. Se preserva el
    // orden relativo (por pageIndex actual) y se renumberan los duplicados.
    final roots = [for (final p in pages) if (p.parentPageId == null) p]
      ..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
    final folders = [for (final p in pages) if (p.parentPageId != null) p]
      ..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));

    // Mapeo pageIndex viejo -> nuevo: se usa para remapear targetPageIndex de
    // los pads-carpeta cuando una pagina es renumerada por la reconciliacion.
    final pageIndexMap = <int, int>{};
    final used = <int>{};
    int cursorRoot = 0;
    for (final p in roots) {
      final oldIdx = p.pageIndex;
      var idx = oldIdx;
      if (idx >= 1000 || used.contains(idx)) idx = cursorRoot;
      while (used.contains(idx)) {
        idx++;
      }
      used.add(idx);
      cursorRoot = idx + 1;
      if (oldIdx != idx) pageIndexMap[oldIdx] = idx;
      p.pageIndex = idx;
    }

    int cursorFolder = 1000;
    for (final p in folders) {
      final oldIdx = p.pageIndex;
      var idx = oldIdx;
      if (idx < 1000 || used.contains(idx)) idx = cursorFolder;
      while (used.contains(idx)) {
        idx++;
      }
      used.add(idx);
      cursorFolder = idx + 1;
      if (oldIdx != idx) pageIndexMap[oldIdx] = idx;
      p.pageIndex = idx;
    }

    await isar.writeTxn(() async {
      for (final p in pages) {
        await isar.pageModels.put(p);
      }
      // Remapear los pads-carpeta cuyo targetPageIndex apuntaba a una pagina
      // que fue renumerada; de lo contrario los links de carpetas quedan rotos.
      if (pageIndexMap.isNotEmpty) {
        final pads = <PadModel>[];
        for (final p in pages) {
          await p.pads.load();
          pads.addAll(p.pads);
        }
        for (final pad in pads) {
          final oldTarget = pad.targetPageIndex;
          if (pad.padTypeIndex != 1 || oldTarget == null) continue;
          final newTarget = pageIndexMap[oldTarget];
          if (newTarget == null || newTarget == oldTarget) continue;
          pad.targetPageIndex = newTarget;
          await isar.padModels.put(pad);
        }
        // Remapear tambien las referencias de pagina guardadas en las macros
        // (navegacion a carpeta, triggerPad a destino) para que no apunten a
        // indices que dejaron de existir tras la renumeracion.
        final macros = await isar.macroModels.where().findAll();
        for (final macro in macros) {
          final remapped = _remapMacroPageIndexes(
            macro.actionsJson,
            pageIndexMap,
            workspaceId,
          );
          if (remapped != macro.actionsJson) {
            macro.actionsJson = remapped;
            await isar.macroModels.put(macro);
          }
        }
      }
    });
  }

  @override
  Future<void> reconcileAllPageIndexIntegrity() async {
    final isar = await dbFuture;
    final workspaces = await isar.workspaceModels.where().findAll();
    for (final ws in workspaces) {
      await reconcilePageIndexIntegrity(ws.id);
    }
  }
}
