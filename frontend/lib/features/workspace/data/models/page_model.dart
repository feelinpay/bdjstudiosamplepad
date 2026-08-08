import 'package:isar/isar.dart';
import 'workspace_model.dart';
import '../../../pad_system/data/models/pad_model.dart';

part 'page_model.g.dart';

@collection
class PageModel {
  Id id = Isar.autoIncrement;

  late int pageIndex;

  String? name;

  int columns = 4;
  int rows = 4;

  /// Id de la pagina contenedora inmediata.
  /// Null = pagina raiz del workspace.
  int? parentPageId;

  /// Deprecated: kept only for database schema compatibility.
  @Deprecated('No longer used — pages are sorted by pageIndex instead.')
  int sortOrder = 0;

  final workspace = IsarLink<WorkspaceModel>();

  @Backlink(to: 'page')
  final pads = IsarLinks<PadModel>();
}
