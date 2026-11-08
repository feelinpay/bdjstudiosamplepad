import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdj_studio_sample_pad/core/audio/audio_engine_state.dart';
import 'package:bdj_studio_sample_pad/features/settings/data/services/settings_service.dart';

import '../../helpers/mock_audio_engine.dart';
import '../../../lib/features/settings/domain/audio_change_result.dart';
import 'package:bdj_studio_sample_pad/core/services/crash_log_service.dart';

void main() {
  group('AudioChangeResult', () {
    test('Success result: isRecoverable true, isNoDevice false', () {
      const result = AudioChangeResult.success('Updated');
      expect(result.isSuccess, isTrue);
      expect(result.isRecoverable, isTrue);
      expect(result.isNoDevice, isFalse);
      expect(result.userMessage, 'Updated');
    });

    test('Failure result: isRecoverable true, isNoDevice false', () {
      const result = AudioChangeResult.failure('Failed');
      expect(result.isSuccess, isFalse);
      expect(result.isRecoverable, isTrue);
      expect(result.isNoDevice, isFalse);
      expect(result.userMessage, 'Failed');
    });

    test('NoDevice result: isRecoverable true, isNoDevice true', () {
      const result = AudioChangeResult.noDevice('No devices');
      expect(result.isSuccess, isFalse);
      expect(result.isRecoverable, isTrue);
      expect(result.isNoDevice, isTrue);
      expect(result.userMessage, 'No devices');
    });
  });

  group('CrashLogService Windows 11 detection', () {
    test('Replaces Windows 10 with Windows 11 when Build >= 22000', () {
      expect(
        CrashLogService.formatOperatingSystemVersion(
          'windows',
          '"Windows 10 Pro" 10.0 (Build 26200)',
        ),
        '"Windows 11 Pro" 10.0 (Build 26200)',
      );
      expect(
        CrashLogService.formatOperatingSystemVersion(
          'windows',
          '"Windows 10 Pro" 10.0 (Build 19045)',
        ),
        '"Windows 10 Pro" 10.0 (Build 19045)',
      );
    });
  });

  group('SettingsService migrateAudioRoutingV105 (in-place upgrade)', () {
    test('Clears legacy 1.0.4 audio device prefs once and preserves subsequent choices', () async {
      SharedPreferences.setMockInitialValues({
        'audio_output_device_id': 0,
        'audio_output_device_name': 'Speaker (Realtek(R) Audio)',
      });
      final prefs = await SharedPreferences.getInstance();
      final service = SettingsService.withPrefs(prefs);

      // First boot after installing 1.0.5 over 1.0.4:
      await service.migrateAudioRoutingV105();
      expect(service.audioOutputDeviceId, isNull);
      expect(service.audioOutputDeviceName, isNull);

      // User explicitly selects a controller in 1.0.5:
      await service.setAudioOutputDeviceId(1);
      await service.setAudioOutputDeviceName('Altavoces (PIONEER DDJ-SX)');

      // Next boot of 1.0.5 preserves the explicit selection:
      await service.migrateAudioRoutingV105();
      expect(service.audioOutputDeviceId, 1);
      expect(service.audioOutputDeviceName, 'Altavoces (PIONEER DDJ-SX)');
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
