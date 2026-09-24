import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/core/audio/audio_bootstrapper.dart';
import 'package:bdj_studio_sample_pad/core/audio/audio_engine_state.dart';
import 'package:bdj_studio_sample_pad/core/audio/audio_initialization_result.dart';
import '../../helpers/mock_audio_engine.dart';

class _FailingAudioEngine extends MockAudioEngine {
  @override
  Future<AudioInitializationResult> initializeAndRestoreDevice(int? savedDeviceId) async {
    throw Exception('Simulated fatal audio failure');
  }
}

void main() {
  group('AudioBootstrapper', () {
    test('successfully initializes audio engine and returns ready result', () async {
      final mockEngine = MockAudioEngine();
      final result = await AudioBootstrapper.start(mockEngine, 42);

      expect(mockEngine.initialized, isTrue);
      expect(result.state, equals(AudioEngineState.ready));
    });

    test('returns safe error result if engine throws exception', () async {
      final failingEngine = _FailingAudioEngine();
      final result = await AudioBootstrapper.start(failingEngine, null);

      expect(result.state, equals(AudioEngineState.error));
      expect(result.userMessage, contains('Error al inicializar'));
    });
  });
}
