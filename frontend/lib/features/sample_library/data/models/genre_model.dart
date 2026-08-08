import 'package:isar/isar.dart';

part 'genre_model.g.dart';

@collection
class GenreModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String name;

  late int colorHex;
  late String iconData;
}
