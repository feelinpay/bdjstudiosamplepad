import 'package:isar/isar.dart';

part 'midi_mapping_model.g.dart';

@collection
class MidiMappingModel {
  Id id = Isar.autoIncrement;

  /// The hardware MIDI Note or Control Change number (e.g. 60)
  @Index()
  late int noteOrCC;

  /// Type of MIDI event (144 = Note On, 176 = CC)
  late int statusByte;

  /// What kind of action this maps to (e.g. "TriggerPad", "NextWorkspace")
  late String actionType;

  /// The parameter for the action (e.g. "Pad_1", "Global_FX")
  late String actionValue;
}
