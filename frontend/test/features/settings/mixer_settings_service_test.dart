import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdj_studio_sample_pad/features/settings/data/services/mixer_settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MixerSettingsService', () {
    test('load() returns default values when no prefs are set', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = MixerSettingsService(prefs);

      final settings = service.load();
      expect(settings.masterVolume, equals(1.0));
      expect(settings.reverb, equals(0.0));
      expect(settings.delay, equals(0.0));
      expect(settings.flanger, equals(0.0));
      expect(settings.distortion, equals(0.0));
      expect(settings.limiter, equals(0.0));
      expect(settings.eqLow, equals(0.0));
      expect(settings.eqMid, equals(0.0));
      expect(settings.eqHigh, equals(0.0));
    });

    test('save() persists all mixer settings and load() retrieves them', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = MixerSettingsService(prefs);

      const customSettings = MixerSettings(
        masterVolume: 0.6,
        reverb: 0.45,
        delay: 0.3,
        flanger: 0.25,
        distortion: 0.15,
        limiter: 0.8,
        eqLow: 0.2,
        eqMid: -0.1,
        eqHigh: 0.3,
      );

      await service.save(customSettings);

      final loaded = service.load();
      expect(loaded.masterVolume, equals(0.6));
      expect(loaded.reverb, equals(0.45));
      expect(loaded.delay, equals(0.3));
      expect(loaded.flanger, equals(0.25));
      expect(loaded.distortion, equals(0.15));
      expect(loaded.limiter, equals(0.8));
      expect(loaded.eqLow, equals(0.2));
      expect(loaded.eqMid, equals(-0.1));
      expect(loaded.eqHigh, equals(0.3));
    });

    test('saveMasterVolume() updates only volume and clamps within bounds', () async {
      SharedPreferences.setMockInitialValues({'mixer_reverb': 0.7});
      final prefs = await SharedPreferences.getInstance();
      final service = MixerSettingsService(prefs);

      await service.saveMasterVolume(1.8);
      var loaded = service.load();
      expect(loaded.masterVolume, equals(1.8));
      expect(loaded.reverb, equals(0.7));

      await service.saveMasterVolume(3.5);
      loaded = service.load();
      expect(loaded.masterVolume, equals(2.0));
    });
  });
}
