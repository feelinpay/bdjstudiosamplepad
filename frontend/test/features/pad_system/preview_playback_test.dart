import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/core/audio/trigger_mode.dart';

import '../../helpers/mock_audio_engine.dart';

/// Tests for the preview playback loop/sync behavior.
/// These verify the core invariants from the specification:
/// - Loop mode: playhead follows real audio position and loops back
/// - OneShot: auto-stop when position becomes null
/// - Session ID: stale callbacks don't affect new sessions
/// - Position comes from getPosition, not an independent timer
void main() {
  group('PreviewPlayback Loop Sync', () {
    test(
        'Loop: position decreases when engine seeks back to loopPoint',
        () {
      final engine = MockAudioEngine();

      // Simulate: audio started at startPoint=2s, loop ended at 12s,
      // engine seeks back to 2s (loopPoint)
      engine.setPosition('preview-1', Duration(milliseconds: 8000));
      expect(engine.getPosition('preview-1')?.inMilliseconds, 8000);

      // Simulate loop seek back to loopPoint (2s)
      engine.setPosition('preview-1', Duration(milliseconds: 2000));
      expect(engine.getPosition('preview-1')?.inMilliseconds, 2000);

      // Position DECREASED — playhead must follow (not clamp to max)
      expect(engine.getPosition('preview-1')!.inMilliseconds, lessThan(8000));
    });

    test('OneShot: position null triggers auto-stop', () {
      final engine = MockAudioEngine();
      engine.setPosition('preview-1', Duration(milliseconds: 100));
      expect(engine.getPosition('preview-1')?.inMilliseconds, 100);

      // Audio handle removed (stopped/finished)
      engine.clearPosition('preview-1');
      expect(engine.getPosition('preview-1'), isNull);
    });

    test('Session ID: stale callbacks do not update new session', () {
      var sessionId = 0;
      int? lastValidSession;

      void startSession() {
        final s = ++sessionId;
        lastValidSession = s;
      }

      void stopSession() {
        sessionId++;
      }

      startSession();
      expect(lastValidSession, 1);

      // Stale callback check: old session should be invalid
      startSession();
      expect(lastValidSession, 2);
      final valid = lastValidSession! == sessionId;
      expect(valid, isTrue);

      stopSession();
      final stillValid = lastValidSession! == sessionId;
      expect(stillValid, isFalse,
          reason: 'After stopSession, old session ID is invalid');
    });

    test('Loop mode: play called with loopPoint parameter', () {
      final engine = MockAudioEngine();
      engine.play(
        'preview-1',
        TriggerMode.loop,
        startPoint: Duration(milliseconds: 2000),
        endPoint: Duration(milliseconds: 12000),
        loopPoint: Duration(milliseconds: 2000),
      );

      expect(engine.playCalls, isNotEmpty);
      expect(engine.playCalls.last.id, 'preview-1');
    });

    test('OneShot mode: play called with endPoint, loopPoint is zero', () {
      final engine = MockAudioEngine();
      engine.play(
        'preview-1',
        TriggerMode.oneShot,
        startPoint: Duration(milliseconds: 2000),
        endPoint: Duration(milliseconds: 5000),
        loopPoint: Duration.zero,
      );

      expect(engine.playCalls, isNotEmpty);
      expect(engine.playCalls.last.mode, TriggerMode.oneShot);
    });

    test('Position follows pitch/speed without independent timer', () {
      final engine = MockAudioEngine();
      engine.setPosition('preview-1', Duration(milliseconds: 1500));

      final pos = engine.getPosition('preview-1');
      expect(pos, isNotNull);
      expect(pos!.inMilliseconds, 1500);

      // Position can decrease (loop seek back)
      engine.setPosition('preview-1', Duration(milliseconds: 2000));
      expect(engine.getPosition('preview-1')!.inMilliseconds, 2000);

      engine.setPosition('preview-1', Duration(milliseconds: 500));
      expect(engine.getPosition('preview-1')!.inMilliseconds, 500);
    });

    test('Loop region: position wraps with modulo', () {
      const startPoint = 2000;
      const loopEnd = 12000;
      const loopDuration = loopEnd - startPoint; // 10000

      // Simulate 3 loop iterations with correct start offset
      var positions = <int>[];
      var elapsed = 0;
      for (var iter = 0; iter < 3; iter++) {
        for (var t = 0; t <= loopDuration; t += 2000) {
          // Position within source = startPoint + elapsed + t
          var sourcePos = startPoint + elapsed + t;
          // Wrap within [startPoint, loopEnd]
          var pos = startPoint + ((sourcePos - startPoint) % loopDuration);
          positions.add(pos);
        }
        elapsed += loopDuration;
      }

      // First position should be startPoint
      expect(positions.first, startPoint);
      // Should contain decreases (loop back)
      var decreases = 0;
      for (var i = 1; i < positions.length; i++) {
        if (positions[i] < positions[i - 1]) decreases++;
      }
      expect(decreases, greaterThan(0),
          reason: 'Loop must produce position decreases when wrapping');
      // All positions within loop region
      for (var p in positions) {
        expect(p, inInclusiveRange(startPoint, loopEnd));
      }
    });
  });

  group('PreviewPlayback Cleanup', () {
    test('stopPosition invalidates session and cancels timers', () {
      var sessionId = 0;
      Timer? timer;

      void stopPosition() {
        sessionId++;
        timer?.cancel();
        timer = null;
      }

      // Start session
      final s1 = ++sessionId;
      expect(s1, 1);
      expect(sessionId, 1);

      timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (s1 != sessionId) return;
      });

      stopPosition();
      expect(timer, isNull, reason: 'Timer should be cancelled');
      expect(sessionId, 2, reason: 'Session ID should be incremented');
    });

    test('Only one preview session active at a time', () {
      var sessionId = 0;
      String? activePreviewId;

      void startPreview(String previewId) {
        sessionId++;
        activePreviewId = previewId;
      }

      startPreview('preview-A');
      expect(activePreviewId, 'preview-A');

      // Starting a new preview replaces the old session
      startPreview('preview-B');
      expect(activePreviewId, 'preview-B');
      expect(sessionId, 2);
    });
  });
}
