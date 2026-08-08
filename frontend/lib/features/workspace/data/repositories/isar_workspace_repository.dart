import 'package:isar/isar.dart';
import '../../domain/repositories/workspace_repository.dart';
import '../models/workspace_model.dart';
import '../models/page_model.dart';
import '../../../pad_system/data/models/pad_model.dart';
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
    if (samplePaths.isNotEmpty) {
      await LocalAudioStorageService.deleteAudioFiles(samplePaths);
    }
    if (wsName != null) {
      await LocalAudioStorageService.deleteWorkspaceDir(wsName);
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

    final used = <int>{};
    int cursorRoot = 0;
    for (final p in roots) {
      var idx = p.pageIndex;
      if (idx >= 1000 || used.contains(idx)) idx = cursorRoot;
      while (used.contains(idx)) {
        idx++;
      }
      used.add(idx);
      cursorRoot = idx + 1;
      p.pageIndex = idx;
    }

    int cursorFolder = 1000;
    for (final p in folders) {
      var idx = p.pageIndex;
      if (idx < 1000 || used.contains(idx)) idx = cursorFolder;
      while (used.contains(idx)) {
        idx++;
      }
      used.add(idx);
      cursorFolder = idx + 1;
      p.pageIndex = idx;
    }

    await isar.writeTxn(() async {
      for (final p in pages) {
        await isar.pageModels.put(p);
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
