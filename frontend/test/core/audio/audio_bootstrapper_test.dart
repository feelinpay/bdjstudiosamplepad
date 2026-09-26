import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdj_studio_sample_pad/core/audio/audio_bootstrapper.dart';
import 'package:bdj_studio_sample_pad/core/audio/audio_engine_state.dart';
import 'package:bdj_studio_sample_pad/core/audio/audio_initialization_result.dart';
import 'package:bdj_studio_sample_pad/features/settings/data/services/mixer_settings_service.dart';
import '../../helpers/mock_audio_engine.dart';

class _FailingAudioEngine extends MockAudioEngine {
  @override
  Future<AudioInitializationResult> initializeAndRestoreDevice(int? savedDeviceId) async {
    throw Exception('Simulated fatal audio failure');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test('restores mixer settings and notifies volume callback when ready', () async {
      SharedPreferences.setMockInitialValues({
        'mixer_masterVolume': 0.6,
        'mixer_reverb': 0.35,
        'mixer_delay': 0.25,
        'mixer_flanger': 0.15,
        'mixer_distortion': 0.05,
        'mixer_limiter': 0.75,
        'mixer_eqLow': 0.4,
        'mixer_eqMid': -0.2,
        'mixer_eqHigh': 0.1,
      });
      final prefs = await SharedPreferences.getInstance();
      final mixerService = MixerSettingsService(prefs);
      final mockEngine = MockAudioEngine();

      double? reportedVolume;
      final result = await AudioBootstrapper.start(
        mockEngine,
        1,
        mixerSettingsService: mixerService,
        onMasterVolumeLoaded: (vol) => reportedVolume = vol,
      );

      expect(result.state, equals(AudioEngineState.ready));
      expect(mockEngine.globalVolume, equals(0.6));
      expect(reportedVolume, equals(0.6));
      expect(mockEngine.masterReverb, equals(0.35));
      expect(mockEngine.masterDelay, equals(0.25));
      expect(mockEngine.masterFlanger, equals(0.15));
      expect(mockEngine.masterDistortion, equals(0.05));
      expect(mockEngine.masterLimiter, equals(0.75));
      expect(mockEngine.eqLow, equals(0.4));
      expect(mockEngine.eqMid, equals(-0.2));
      expect(mockEngine.eqHigh, equals(0.1));
    });
  });
}
