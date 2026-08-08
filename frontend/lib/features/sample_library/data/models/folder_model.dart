import 'package:isar/isar.dart';

part 'folder_model.g.dart';

@collection
class FolderModel {
  Id id = Isar.autoIncrement;

  late String name;
  int colorHex = 0xFF9E9E9E;
  String iconData = "📁";

  final parent = IsarLink<FolderModel>();
}
