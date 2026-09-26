import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/domain/entities/pad_entity.dart';

void main() {
  group('PadEntity - needsRandomAccess (T19)', () {
    test('pad por defecto no requiere acceso aleatorio', () {
      final pad = PadEntity.empty(0);
      expect(pad.needsRandomAccess, isFalse);
    });

    test('reverse = true requiere acceso aleatorio', () {
      final pad = PadEntity.empty(0).copyWith(reverse: true);
      expect(pad.needsRandomAccess, isTrue);
    });

    test('startPoint > 0 requiere acceso aleatorio', () {
      final pad = PadEntity.empty(0).copyWith(startPoint: const Duration(milliseconds: 500));
      expect(pad.needsRandomAccess, isTrue);
    });

    test('loopPoint > 0 requiere acceso aleatorio', () {
      final pad = PadEntity.empty(0).copyWith(loopPoint: const Duration(milliseconds: 200));
      expect(pad.needsRandomAccess, isTrue);
    });

    test('todos en cero/falso mantiene needsRandomAccess en false', () {
      final pad = PadEntity.empty(0).copyWith(
        reverse: false,
        startPoint: Duration.zero,
        loopPoint: Duration.zero,
      );
      expect(pad.needsRandomAccess, isFalse);
    });
  });
}
