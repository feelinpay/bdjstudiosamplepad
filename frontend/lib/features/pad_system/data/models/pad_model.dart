import 'package:isar/isar.dart';
import '../../../workspace/data/models/page_model.dart';
import '../../../sample_library/data/models/sample_model.dart';

part 'pad_model.g.dart';

@collection
class PadModel {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late int padId;

  late int colorHex;
  late String label;

  @Deprecated('Vestigial property kept for Isar schema compatibility')
  double x = 0.0;
  @Deprecated('Vestigial property kept for Isar schema compatibility')
  double y = 0.0;
  @Deprecated('Vestigial property kept for Isar schema compatibility')
  double width = 100.0;
  @Deprecated('Vestigial property kept for Isar schema compatibility')
  double height = 100.0;

  @Deprecated('Vestigial SampleModel link kept for Isar schema compatibility')
  final sample = IsarLink<SampleModel>();

  String? samplePath;

  int triggerModeIndex = 0; // TriggerMode.oneShot

  int padTypeIndex = 0; // 0 = Audio, 1 = Folder/Link, 2 = Macro
  int? targetPageIndex; // If type is folder, which page/kit does it open?
  int? targetMacroId; // If type is macro, which macro ID does it trigger?

  int chokeGroup = 0;
  double pan = 0.0;
  double pitch = 1.0;
  double volume = 1.0;
  bool isProtected = false;

  bool reverse = false;
  int fadeInMs = 0;
  int fadeOutMs = 0;
  int startPointMs = 0;
  int? endPointMs;
  int loopPointMs = 0;
  String? backgroundImagePath;

  final page = IsarLink<PageModel>();
}
