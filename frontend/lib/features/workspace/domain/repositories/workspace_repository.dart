import '../../data/models/workspace_model.dart';
import '../../data/models/page_model.dart';

abstract class WorkspaceRepository {
  Future<List<WorkspaceModel>> getAllWorkspaces();
  Future<WorkspaceModel?> getWorkspace(int id);
  Future<WorkspaceModel> createWorkspace(String name);
  Future<WorkspaceModel> duplicateWorkspace(int id);
  Future<void> saveWorkspace(WorkspaceModel workspace);
  Future<void> deleteWorkspace(int id);
  Future<PageModel> createPage(
    int workspaceId,
    int pageIndex, {
    int cols = 4,
    int rows = 4,
    String? name,
  });
  Future<void> deletePage(int pageId);
  Future<void> deletePages(List<int> pageIds);
  Future<void> updatePageLayout(int pageId, int cols, int rows);

  /// Garantiza la integridad de `pageIndex` dentro de un workspace:
  /// elimina duplicados y preserva la convención root (<1000) / folder (>=1000).
  /// No rompe el esquema existente (no es migration breaking); safe de correr en startup.
  Future<void> reconcilePageIndexIntegrity(int workspaceId);
  Future<void> reconcileAllPageIndexIntegrity();
}
