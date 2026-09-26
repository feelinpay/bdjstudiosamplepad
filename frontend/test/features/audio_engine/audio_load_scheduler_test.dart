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

    test('accepts List<AudioLoadRequest> and passes needsRandomAccess to load callback', () async {
      final receivedRequests = <AudioLoadRequest>[];
      final completers = <String, Completer<void>>{};

      final scheduler = AudioLoadScheduler(
        maxConcurrent: 2,
        load: (AudioLoadRequest req) {
          receivedRequests.add(req);
          final c = Completer<void>();
          completers[req.id] = c;
          return c.future;
        },
      );

      scheduler.replaceQueue([
        const AudioLoadRequest(id: 'pad1', path: 'path1', needsRandomAccess: true),
        const AudioLoadRequest(id: 'pad2', path: 'path2', needsRandomAccess: false),
      ]);

      expect(scheduler.runningCount, equals(2));
      expect(receivedRequests.length, equals(2));
      expect(receivedRequests[0].needsRandomAccess, isTrue);
      expect(receivedRequests[1].needsRandomAccess, isFalse);

      completers['pad1']!.complete();
      completers['pad2']!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(scheduler.isIdle, isTrue);
    });

    test('idle queue does not process while primary queue has items', () async {
      final completers = <String, Completer<void>>{};
      final loadedIds = <String>[];

      final scheduler = AudioLoadScheduler(
        maxConcurrent: 2,
        load: (AudioLoadRequest req) {
          loadedIds.add(req.id);
          final c = Completer<void>();
          completers[req.id] = c;
          return c.future;
        },
      );

      // Enqueue primary items
      scheduler.replaceQueue([
        const AudioLoadRequest(id: 'pri1', path: 'path1'),
        const AudioLoadRequest(id: 'pri2', path: 'path2'),
      ]);

      // Enqueue idle items
      scheduler.enqueueIdle([
        const AudioLoadRequest(id: 'idle1', path: 'pathIdle1'),
        const AudioLoadRequest(id: 'idle2', path: 'pathIdle2'),
      ]);

      expect(loadedIds, equals(['pri1', 'pri2']));
      expect(scheduler.idlePendingCount, equals(2));

      // Complete pri1: concurrency drops to 1, but pri2 is still running
      completers['pri1']!.complete();
      await Future<void>.delayed(Duration.zero);

      // Idle items should NOT start because runningCount is 1 (> 0)
      expect(loadedIds, equals(['pri1', 'pri2']));
      expect(scheduler.idlePendingCount, equals(2));

      // Complete pri2: now primary is empty and runningCount is 0
      completers['pri2']!.complete();
      await Future<void>.delayed(Duration.zero);

      // Now idle1 should start!
      expect(loadedIds, equals(['pri1', 'pri2', 'idle1']));
      expect(scheduler.idlePendingCount, equals(1));
      expect(scheduler.runningCount, equals(1));

      // Complete idle1: now idle2 should start
      completers['idle1']!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(loadedIds, equals(['pri1', 'pri2', 'idle1', 'idle2']));
      expect(scheduler.idlePendingCount, equals(0));

      completers['idle2']!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(scheduler.isIdle, isTrue);
    });

    test('replaceQueue clears both primary and idle queues', () async {
      final completers = <String, Completer<void>>{};
      final loadedIds = <String>[];

      final scheduler = AudioLoadScheduler(
        maxConcurrent: 1,
        load: (AudioLoadRequest req) {
          loadedIds.add(req.id);
          final c = Completer<void>();
          completers[req.id] = c;
          return c.future;
        },
      );

      scheduler.replaceQueue([
        const AudioLoadRequest(id: 'p1', path: 'path1'),
        const AudioLoadRequest(id: 'p2', path: 'path2'),
      ]);
      scheduler.enqueueIdle([
        const AudioLoadRequest(id: 'i1', path: 'pathI1'),
        const AudioLoadRequest(id: 'i2', path: 'pathI2'),
      ]);

      expect(loadedIds, equals(['p1']));
      expect(scheduler.pendingCount, equals(1)); // p2
      expect(scheduler.idlePendingCount, equals(2)); // i1, i2

      // Switch page before p1 finishes
      scheduler.replaceQueue([
        const AudioLoadRequest(id: 'newPagePad', path: 'pathNew'),
      ]);

      // Both old pending (p2) and idle (i1, i2) should be cleared
      expect(scheduler.pendingCount, equals(1)); // newPagePad
      expect(scheduler.idlePendingCount, equals(0));

      // Finish p1
      completers['p1']!.complete();
      await Future<void>.delayed(Duration.zero);

      // newPagePad should run, but p2, i1, i2 should NEVER run
      expect(loadedIds, equals(['p1', 'newPagePad']));
      expect(loadedIds.contains('p2'), isFalse);
      expect(loadedIds.contains('i1'), isFalse);
      expect(loadedIds.contains('i2'), isFalse);

      completers['newPagePad']!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(scheduler.isIdle, isTrue);
    });
  });
}
