import 'package:isar/isar.dart';
import 'page_model.dart';

part 'workspace_model.g.dart';

@collection
class WorkspaceModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String name;

  late DateTime createdAt;
  bool isLocked = false;

  @Backlink(to: 'workspace')
  final pages = IsarLinks<PageModel>();
}
