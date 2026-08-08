import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/features/midi/domain/entities/midi_mapping_entity.dart';

void main() {
  // MidiController persiste actionType como String usando `.name` y luego
  // compara con `MidiActionType.triggerPad.name`. Estos tests protegen ese
  // contrato de nombres (Fase 11.1 - Tests de MIDI mapping).
  group('MidiActionType - nombres estables', () {
    test('los nombres usados en persistencia no deben cambiar', () {
      expect(MidiActionType.triggerPad.name, 'triggerPad');
      expect(MidiActionType.changeWorkspace.name, 'changeWorkspace');
      expect(MidiActionType.masterFx.name, 'masterFx');
      expect(MidiActionType.executeMacro.name, 'executeMacro');
      expect(MidiActionType.unassigned.name, 'unassigned');
    });

    test('round-trip name -> enum vía byName', () {
      for (var t in MidiActionType.values) {
        expect(MidiActionType.values.byName(t.name), t);
      }
    });
  });

  group('MidiMappingEntity', () {
    test('mapea nota/CC + status a una acción con valor', () {
      var mapping = MidiMappingEntity(
        id: 'm1',
        noteOrCC: 36, // kick clásico en pads MPC
        statusByte: 144, // Note On canal 1
        actionType: MidiActionType.triggerPad,
        actionValue: '5',
      );

      expect(mapping.noteOrCC, 36);
      expect(mapping.statusByte, 144);
      expect(mapping.actionType, MidiActionType.triggerPad);
      expect(mapping.actionValue, '5');
    });
  });
}
