import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/features/macros/domain/entities/macro_entity.dart';

void main() {
  // Fase 11.2 (integración de datos): exportar/importar macros debe ser
  // idempotente. Estos tests validan el round-trip JSON real.
  group('MacroAction JSON', () {
    test('round-trip conserva tipo y params', () {
      const action = MacroAction(
        type: MacroActionType.setVolume,
        params: {'target': 'master', 'value': 0.8},
      );
      var restored = MacroAction.fromJson(action.toJson());
      expect(restored.type, MacroActionType.setVolume);
      expect(restored.params['target'], 'master');
      expect(restored.params['value'], 0.8);
    });

    test('los nombres de MacroActionType son estables (persistencia)', () {
      expect(MacroActionType.changeWorkspace.name, 'changeWorkspace');
      expect(MacroActionType.triggerPad.name, 'triggerPad');
      expect(MacroActionType.sendMidiNote.name, 'sendMidiNote');
      expect(MacroActionType.setLimiter.name, 'setLimiter');
      expect(MacroActionType.delay.name, 'delay');
    });
  });

  group('MacroEntity JSON', () {
    test('round-trip de un macro con múltiples acciones', () {
      var macro = MacroEntity(
        id: 7,
        name: 'Drop Set',
        createdAt: DateTime.parse('2026-07-21T10:00:00.000'),
        actions: const [
          MacroAction(
            type: MacroActionType.changeWorkspace,
            params: {'id': '2'},
          ),
          MacroAction(type: MacroActionType.setVolume, params: {'value': 0.3}),
          MacroAction(type: MacroActionType.triggerPad, params: {'padId': '5'}),
        ],
      );

      var restored = MacroEntity.fromJson(macro.toJson());

      expect(restored.name, 'Drop Set');
      expect(restored.actions, hasLength(3));
      expect(restored.actions.first.type, MacroActionType.changeWorkspace);
      expect(restored.actions.last.params['padId'], '5');
      expect(restored.createdAt, macro.createdAt);
    });

    test('copyWith conserva actions cuando no se sobreescriben', () {
      var macro = MacroEntity(
        id: 1,
        name: 'A',
        createdAt: DateTime(2026),
        actions: const [
          MacroAction(type: MacroActionType.delay, params: {'ms': 500}),
        ],
      );
      var renamed = macro.copyWith(name: 'B');
      expect(renamed.name, 'B');
      expect(renamed.actions, macro.actions);
    });
  });
}
