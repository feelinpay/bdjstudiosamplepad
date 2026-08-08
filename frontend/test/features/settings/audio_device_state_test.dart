import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/core/audio/audio_engine_state.dart';

import '../../helpers/mock_audio_engine.dart';
import '../../../lib/features/settings/domain/audio_change_result.dart';

void main() {
  group('AudioChangeResult', () {
    test('Success result: isRecoverable true, isNoDevice false', () {
      const result = AudioChangeResult.success('Updated');
      expect(result.isRecoverable, isTrue);
      expect(result.isNoDevice, isFalse);
      expect(result.userMessage, 'Updated');
    });

    test('Failure result: isRecoverable true, isNoDevice false', () {
      const result = AudioChangeResult.failure('Failed');
      expect(result.isRecoverable, isTrue);
      expect(result.isNoDevice, isFalse);
      expect(result.userMessage, 'Failed');
    });

    test('NoDevice result: isRecoverable true, isNoDevice true', () {
      const result = AudioChangeResult.noDevice('No devices');
      expect(result.isRecoverable, isTrue);
      expect(result.isNoDevice, isTrue);
      expect(result.userMessage, 'No devices');
    });
  });

  group('MockAudioEngine EngineState', () {
    test('Starts as uninitialized', () {
      final engine = MockAudioEngine();
      expect(engine.engineState, AudioEngineState.uninitialized);
    });

    test('After initialize: state becomes ready', () async {
      final engine = MockAudioEngine();
      await engine.initialize();
      expect(engine.engineState, AudioEngineState.ready);
    });
  });

  group('MockAudioEngine getPosition', () {
    test('Returns null for unknown id', () {
      final engine = MockAudioEngine();
      expect(engine.getPosition('unknown'), isNull);
    });

    test('Returns set position for known id', () {
      final engine = MockAudioEngine();
      engine.setPosition('test-1', Duration(milliseconds: 500));
      expect(engine.getPosition('test-1')?.inMilliseconds, 500);
    });

    test('clearPosition makes getPosition return null', () {
      final engine = MockAudioEngine();
      engine.setPosition('test-1', Duration(milliseconds: 500));
      expect(engine.getPosition('test-1'), isNotNull);
      engine.clearPosition('test-1');
      expect(engine.getPosition('test-1'), isNull);
    });
  });

  group('MockAudioEngine Select Output Device Error Handling', () {
    test('Success path: selectOutputDevice does not throw', () async {
      final engine = MockAudioEngine();
      await engine.initialize();
      await engine.selectOutputDevice(1);
      expect(engine.engineState, AudioEngineState.ready);
    });
  });
}
