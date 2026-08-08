enum MidiActionType {
  triggerPad,
  changeWorkspace,
  masterFx,
  executeMacro,
  unassigned,
}

class MidiMappingEntity {
  final String id;
  final int noteOrCC;
  final int statusByte;
  final MidiActionType actionType;
  final String actionValue;

  MidiMappingEntity({
    required this.id,
    required this.noteOrCC,
    required this.statusByte,
    required this.actionType,
    required this.actionValue,
  });
}
