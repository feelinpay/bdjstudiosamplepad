import 'package:isar/isar.dart';
import 'genre_model.dart';
import 'folder_model.dart';

part 'sample_model.g.dart';

@collection
class SampleModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String path;

  @Index(type: IndexType.value)
  late String name;

  late String extension;
  late int sizeInBytes;
  late DateTime importedAt;

  @Index()
  bool isFavorite = false;

  @Index()
  double? bpm;

  @Index(type: IndexType.hashElements)
  List<String> tags = [];

  @Index()
  DateTime? lastUsedAt;

  @Index()
  int useCount = 0;

  double? durationInSeconds;

  String? waveformPath;

  final genre = IsarLink<GenreModel>();
  final folder = IsarLink<FolderModel>();
}
