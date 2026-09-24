import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/features/audio_engine/data/audio_load_scheduler.dart';

void main() {
  group('AudioLoadScheduler', () {
    test('never runs more than maxConcurrent at the same time', () async {
      final completers = <String, Completer<void>>{};
      int peakRunning = 0;

      final scheduler = AudioLoadScheduler(
        maxConcurrent: 2,
        load: (id, path) {
          final c = Completer<void>();
          completers[id] = c;
          return c.future;
        },
      );

      scheduler.replaceQueue({
        'pad1': 'path1',
        'pad2': 'path2',
        'pad3': 'path3',
        'pad4': 'path4',
      });

      expect(scheduler.runningCount, equals(2));
      expect(scheduler.pendingCount, equals(2));
      peakRunning = scheduler.runningCount;

      // Complete one task
      completers['pad1']!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(scheduler.runningCount, equals(2));
      if (scheduler.runningCount > peakRunning) {
        peakRunning = scheduler.runningCount;
      }
      expect(completers.containsKey('pad3'), isTrue);

      // Complete remaining tasks
      completers['pad2']!.complete();
      completers['pad3']!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(completers.containsKey('pad4'), isTrue);
      completers['pad4']!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(scheduler.runningCount, equals(0));
      expect(scheduler.pendingCount, equals(0));
      expect(scheduler.isIdle, isTrue);
      expect(peakRunning, lessThanOrEqualTo(2));
    });

    test('replaceQueue discards pending items but keeps running items', () async {
      final completers = <String, Completer<void>>{};
      final loadedIds = <String>[];

      final scheduler = AudioLoadScheduler(
        maxConcurrent: 2,
        load: (id, path) {
          loadedIds.add(id);
          final c = Completer<void>();
          completers[id] = c;
          return c.future;
        },
      );

      // Page 1 loads pads A, B, C, D
      scheduler.replaceQueue({
        'A': 'pathA',
        'B': 'pathB',
        'C': 'pathC',
        'D': 'pathD',
      });

      expect(loadedIds, equals(['A', 'B']));
      expect(scheduler.pendingCount, equals(2)); // C and D pending

      // User immediately switches to Page 2 (pads E, F)
      scheduler.replaceQueue({
        'E': 'pathE',
        'F': 'pathF',
      });

      expect(scheduler.pendingCount, equals(2)); // E and F now pending, C and D discarded
      expect(loadedIds, equals(['A', 'B']));

      // Finish A and B from Page 1
      completers['A']!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(loadedIds, equals(['A', 'B', 'E']));

      completers['B']!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(loadedIds, equals(['A', 'B', 'E', 'F']));

      // Finish E and F
      completers['E']!.complete();
      completers['F']!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(scheduler.isIdle, isTrue);
      // C and D should NEVER have been loaded
      expect(loadedIds.contains('C'), isFalse);
      expect(loadedIds.contains('D'), isFalse);
    });

    test('error in a load does not stop or stall the queue', () async {
      final completers = <String, Completer<void>>{};
      final loadedIds = <String>[];

      final scheduler = AudioLoadScheduler(
        maxConcurrent: 1,
        load: (id, path) {
          loadedIds.add(id);
          final c = Completer<void>();
          completers[id] = c;
          return c.future;
        },
      );

      scheduler.replaceQueue({
        'errPad': 'pathErr',
        'okPad': 'pathOk',
      });

      expect(loadedIds, equals(['errPad']));

      // Complete errPad with error
      completers['errPad']!.completeError(Exception('Corrupt audio file'));
      await Future<void>.delayed(Duration.zero);

      // Queue should automatically pump okPad despite the error
      expect(loadedIds, equals(['errPad', 'okPad']));
      expect(scheduler.runningCount, equals(1));

      completers['okPad']!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(scheduler.isIdle, isTrue);
    });
  });
}
