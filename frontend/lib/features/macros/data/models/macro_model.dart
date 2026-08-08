import 'package:isar/isar.dart';

part 'macro_model.g.dart';

@collection
class MacroModel {
  Id id = Isar.autoIncrement;

  @Index()
  late String name;

  late String actionsJson;

  late DateTime createdAt;

  DateTime? updatedAt;
}
