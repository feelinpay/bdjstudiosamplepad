import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/core/audio/trigger_mode.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/domain/entities/pad_entity.dart';

void main() {
  group('AsignarSonido - localized pad update', () {
    // Reproduce el patrón de actualización usado en assignSampleToPad:
    // state = AsyncData([for (e in current) if (e.index == padId) updated else e]);
    group('list update pattern — only target pad changes', () {
      test('El pad objetivo cambia, todos los demás permanecen idénticos', () {
        final padA = PadEntity(
          id: 'pad_0',
          index: 0,
          label: 'Kick',
          colorHex: 0xFF4CAF50,
          sampleId: 'old_kick.wav',
          playMode: TriggerMode.oneShot,
          chokeGroup: 1,
          pan: -0.1,
          pitch: 1.2,
          isProtected: true,
          reverse: true,
          fadeIn: Duration(milliseconds: 50),
          fadeOut: Duration(milliseconds: 100),
          startPoint: Duration(milliseconds: 20),
          endPoint: Duration(milliseconds: 800),
          loopPoint: Duration(milliseconds: 100),
        );
        final padB = PadEntity(
          id: 'pad_1',
          index: 1,
          label: 'Snare',
          colorHex: 0xFF2196F3,
          sampleId: 'old_snare.wav',
          playMode: TriggerMode.loop,
          chokeGroup: 2,
          pan: 0.0,
          pitch: 1.0,
          isProtected: false,
          reverse: false,
          fadeIn: Duration.zero,
          fadeOut: Duration.zero,
          startPoint: Duration.zero,
          endPoint: null,
          loopPoint: Duration.zero,
        );
        final padC = PadEntity(
          id: 'pad_2',
          index: 2,
          label: 'HiHat',
          colorHex: 0xFFE0E0E0,
          sampleId: 'old_hihat.wav',
        );

        final current = [padA, padB, padC];

        // Simulate _mapToEntity with new audio path + new label, all else preserved
        final updatedPadB = padB.copyWith(
          sampleId: 'new_snare.wav',
          label: 'New Snare',
        );

        final updated = <PadEntity>[
          for (final e in current)
            if (e.index == 1) updatedPadB else e,
        ];

        // Only pad B changed
        expect(updated, hasLength(3));
        expect(updated[0], equals(padA));
        expect(updated[1], equals(updatedPadB));
        expect(updated[2], equals(padC));

        // Pad A unchanged
        expect(updated[0].label, 'Kick');
        expect(updated[0].sampleId, 'old_kick.wav');
        // Pad C unchanged
        expect(updated[2].label, 'HiHat');
        expect(updated[2].sampleId, 'old_hihat.wav');
      });

      test('No pad se mantiene en el mismo orden', () {
        final pads = List.generate(
          10,
          (i) => PadEntity(id: 'pad_$i', index: i, label: 'PAD $i'),
        );

        final padToUpdate = pads[5].copyWith(sampleId: 'new_audio.wav');
        final updated = <PadEntity>[
          for (final e in pads)
            if (e.index == 5) padToUpdate else e,
        ];

        expect(updated.length, 10);
        expect(updated[0].index, 0);
        expect(updated[9].index, 9);
        expect(updated[5].index, 5);
        expect(updated[5].sampleId, 'new_audio.wav');

        // Verify order is preserved
        for (var i = 0; i < 10; i++) {
          expect(updated[i].index, i);
        }
      });

      test('El pad no recibe un nuevo ID — conserva pad.id', () {
        final original = PadEntity(
          id: 'pad_3',
          index: 3,
          label: 'Original Label',
          sampleId: 'old.wav',
          colorHex: 0xFF00FF00,
          chokeGroup: 5,
          pan: 0.5,
          pitch: 0.8,
          reverse: true,
          isProtected: true,
          playMode: TriggerMode.gate,
          fadeIn: Duration(milliseconds: 10),
          fadeOut: Duration(milliseconds: 20),
          startPoint: Duration(milliseconds: 30),
          endPoint: Duration(milliseconds: 400),
          loopPoint: Duration(milliseconds: 50),
          backgroundImagePath: 'bg.png',
        );

        final updated = original.copyWith(
          sampleId: 'new_audio.mp3',
          label: 'New Label',
        );

        // ID estable conservado
        expect(updated.id, original.id);
        expect(updated.index, original.index);
        // Todo lo no relacionado con audio se conserva
        expect(updated.colorHex, original.colorHex);
        expect(updated.chokeGroup, original.chokeGroup);
        expect(updated.pan, original.pan);
        expect(updated.pitch, original.pitch);
        expect(updated.reverse, original.reverse);
        expect(updated.isProtected, original.isProtected);
        expect(updated.playMode, original.playMode);
        expect(updated.fadeIn, original.fadeIn);
        expect(updated.fadeOut, original.fadeOut);
        expect(updated.startPoint, original.startPoint);
        expect(updated.endPoint, original.endPoint);
        expect(updated.loopPoint, original.loopPoint);
        expect(updated.backgroundImagePath, original.backgroundImagePath);
        // Solo sampleId y label cambian
        expect(updated.sampleId, isNot(original.sampleId));
        expect(updated.label, isNot(original.label));
      });
    });

    group('PadEntity key stability', () {
      test('ValueKey<String>(pad.id) es estable para el mismo pad', () {
        final pad1 = PadEntity(id: 'pad_0', index: 0, label: 'Kick');
        final pad2 = PadEntity(id: 'pad_0', index: 0, label: 'Kick Updated');

        final key1 = ValueKey<String>(pad1.id);
        final key2 = ValueKey<String>(pad2.id);

        expect(key1, equals(key2));
      });

      test('Keys diferentes para pads diferentes', () {
        final pad1 = PadEntity(id: 'pad_0', index: 0);
        final pad2 = PadEntity(id: 'pad_1', index: 1);

        expect(
          ValueKey<String>(pad1.id) == ValueKey<String>(pad2.id),
          isFalse,
        );
      });
    });

    group('List identity preservation', () {
      test('La lista nueva no es la misma instancia pero contiene los mismos pads', () {
        final pads = List.generate(
          5,
          (i) => PadEntity(id: 'pad_$i', index: i),
        );

        final unchanged = <PadEntity>[
          for (final e in pads) e,
        ];

        // Los elementos unchanged deben ser las mismas instancias
        for (var i = 0; i < pads.length; i++) {
          expect(identical(unchanged[i], pads[i]), isTrue);
        }

        // La lista no es la misma instancia
        expect(identical(unchanged, pads), isFalse);
      });
    });

    group('PadEntity copyWith conserva configuraciones', () {
      final base = PadEntity(
        id: 'pad_7',
        index: 7,
        label: 'Original',
        sampleId: 'old.wav',
        colorHex: 0xFFff0000,
        chokeGroup: 3,
        pan: 0.3,
        pitch: 1.5,
        isProtected: true,
        reverse: true,
        playMode: TriggerMode.toggle,
        fadeIn: Duration(milliseconds: 200),
        fadeOut: Duration(milliseconds: 300),
        startPoint: Duration(milliseconds: 500),
        endPoint: Duration(milliseconds: 2000),
        loopPoint: Duration(milliseconds: 100),
        backgroundImagePath: 'bg.jpg',
      );

      test('Asignar audio conserva TriggerMode', () {
        final updated = base.copyWith(
          sampleId: 'new.wav',
          label: 'New Name',
        );
        expect(updated.playMode, TriggerMode.toggle);
      });

      test('Asignar audio conserva ChokeGroup', () {
        final updated = base.copyWith(sampleId: 'new.wav');
        expect(updated.chokeGroup, 3);
      });

      test('Asignar audio conserva Pan', () {
        final updated = base.copyWith(sampleId: 'new.wav');
        expect(updated.pan, 0.3);
      });

      test('Asignar audio conserva Pitch', () {
        final updated = base.copyWith(sampleId: 'new.wav');
        expect(updated.pitch, 1.5);
      });

      test('Asignar audio conserva Reverse', () {
        final updated = base.copyWith(sampleId: 'new.wav');
        expect(updated.reverse, isTrue);
      });

      test('Asignar audio conserva IsProtected', () {
        final updated = base.copyWith(sampleId: 'new.wav');
        expect(updated.isProtected, isTrue);
      });

      test('Asignar audio conserva FadeIn', () {
        final updated = base.copyWith(sampleId: 'new.wav');
        expect(updated.fadeIn, Duration(milliseconds: 200));
      });

      test('Asignar audio conserva FadeOut', () {
        final updated = base.copyWith(sampleId: 'new.wav');
        expect(updated.fadeOut, Duration(milliseconds: 300));
      });

      test('Asignar audio conserva StartPoint', () {
        final updated = base.copyWith(sampleId: 'new.wav');
        expect(updated.startPoint, Duration(milliseconds: 500));
      });

      test('Asignar audio conserva LoopPoint', () {
        final updated = base.copyWith(sampleId: 'new.wav');
        expect(updated.loopPoint, Duration(milliseconds: 100));
      });

      test('Asignar audio conserva EndPoint', () {
        final updated = base.copyWith(sampleId: 'new.wav');
        expect(updated.endPoint, Duration(milliseconds: 2000));
      });

      test('Asignar audio conserva ColorHex', () {
        final updated = base.copyWith(sampleId: 'new.wav');
        expect(updated.colorHex, 0xFFff0000);
      });

      test('Asignar audio conserva backgroundImagePath', () {
        final updated = base.copyWith(sampleId: 'new.wav');
        expect(updated.backgroundImagePath, 'bg.jpg');
      });

      test('Asignar audio conserva id e index', () {
        final updated = base.copyWith(sampleId: 'new.wav');
        expect(updated.id, 'pad_7');
        expect(updated.index, 7);
      });
    });

    group('Equality based on id, not position', () {
      test('El mismo pad antes y después del update tiene el mismo id', () {
        final original = PadEntity.empty(5);
        final updated = original.copyWith(sampleId: 'new.wav');
        expect(updated.id, original.id);
      });

      test('Dos pads con misma id pero diferente posición no son iguales', () {
        final a = PadEntity(id: 'pad_1', index: 1, label: 'A');
        final b = PadEntity(id: 'pad_1', index: 3, label: 'B');
        // Same id but different index → not equal
        expect(a == b, isFalse);
      });

      test('El update busca por index (padId) no por posición en la lista', () {
        final pads = [
          PadEntity(id: 'pad_0', index: 0, label: 'A'),
          PadEntity(id: 'pad_1', index: 10, label: 'B'),
          PadEntity(id: 'pad_2', index: 20, label: 'C'),
        ];

        // Simulate updating index 10 (which is at list position 1)
        final updatedPad =
            pads[1].copyWith(sampleId: 'new.wav');
        final updated = <PadEntity>[
          for (final e in pads)
            if (e.index == 10) updatedPad else e,
        ];

        // The pad at list position 1 changed
        expect(updated[1].sampleId, 'new.wav');
        // The pad at list position 0 and 2 are untouched
        expect(updated[0].sampleId, isNull);
        expect(updated[2].sampleId, isNull);
      });
    });
  });
}
