import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/core/audio/trigger_mode.dart';

void main() {
  // La persistencia (PadModel.triggerModeIndex) guarda el ÍNDICE del enum.
  // El mapeo TriggerMode.values[index] se usa en _mapToEntity, por lo que
  // reordenar este enum corrompería los workspaces guardados. Estos tests
  // fijan el contrato de índices para prevenir regresiones.
  group('TriggerMode - estabilidad de índices (contrato de persistencia)', () {
    test('los índices no deben cambiar', () {
      expect(TriggerMode.oneShot.index, 0);
      expect(TriggerMode.gate.index, 1);
      expect(TriggerMode.loop.index, 2);
      expect(TriggerMode.toggle.index, 3);
      expect(TriggerMode.hold.index, 4);
    });

    test('values contiene exactamente los 5 modos', () {
      expect(TriggerMode.values.length, 5);
    });

    test('round-trip index -> enum', () {
      for (var mode in TriggerMode.values) {
        expect(TriggerMode.values[mode.index], mode);
      }
    });
  });
}
