import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MixerSettings {
  final double masterVolume;
  final double reverb;
  final double delay;
  final double flanger;
  final double distortion;
  final double limiter;
  final double eqLow;
  final double eqMid;
  final double eqHigh;

  const MixerSettings({
    this.masterVolume = 1.0,
    this.reverb = 0.0,
    this.delay = 0.0,
    this.flanger = 0.0,
    this.distortion = 0.0,
    this.limiter = 0.0,
    this.eqLow = 0.0,
    this.eqMid = 0.0,
    this.eqHigh = 0.0,
  });

  MixerSettings copyWith({
    double? masterVolume,
    double? reverb,
    double? delay,
    double? flanger,
    double? distortion,
    double? limiter,
    double? eqLow,
    double? eqMid,
    double? eqHigh,
  }) {
    return MixerSettings(
      masterVolume: masterVolume ?? this.masterVolume,
      reverb: reverb ?? this.reverb,
      delay: delay ?? this.delay,
      flanger: flanger ?? this.flanger,
      distortion: distortion ?? this.distortion,
      limiter: limiter ?? this.limiter,
      eqLow: eqLow ?? this.eqLow,
      eqMid: eqMid ?? this.eqMid,
      eqHigh: eqHigh ?? this.eqHigh,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MixerSettings &&
          runtimeType == other.runtimeType &&
          masterVolume == other.masterVolume &&
          reverb == other.reverb &&
          delay == other.delay &&
          flanger == other.flanger &&
          distortion == other.distortion &&
          limiter == other.limiter &&
          eqLow == other.eqLow &&
          eqMid == other.eqMid &&
          eqHigh == other.eqHigh;

  @override
  int get hashCode => Object.hash(
        masterVolume,
        reverb,
        delay,
        flanger,
        distortion,
        limiter,
        eqLow,
        eqMid,
        eqHigh,
      );
}

class MixerSettingsService {
  final SharedPreferences _prefs;

  MixerSettingsService(this._prefs);

  static const String keyMasterVolume = 'mixer_masterVolume';
  static const String keyReverb = 'mixer_reverb';
  static const String keyDelay = 'mixer_delay';
  static const String keyFlanger = 'mixer_flanger';
  static const String keyDistortion = 'mixer_distortion';
  static const String keyLimiter = 'mixer_limiter';
  static const String keyEqLow = 'mixer_eqLow';
  static const String keyEqMid = 'mixer_eqMid';
  static const String keyEqHigh = 'mixer_eqHigh';

  MixerSettings load() {
    return MixerSettings(
      masterVolume: _prefs.getDouble(keyMasterVolume) ?? 1.0,
      reverb: _prefs.getDouble(keyReverb) ?? 0.0,
      delay: _prefs.getDouble(keyDelay) ?? 0.0,
      flanger: _prefs.getDouble(keyFlanger) ?? 0.0,
      distortion: _prefs.getDouble(keyDistortion) ?? 0.0,
      limiter: _prefs.getDouble(keyLimiter) ?? 0.0,
      eqLow: _prefs.getDouble(keyEqLow) ?? 0.0,
      eqMid: _prefs.getDouble(keyEqMid) ?? 0.0,
      eqHigh: _prefs.getDouble(keyEqHigh) ?? 0.0,
    );
  }

  Future<void> save(MixerSettings settings) async {
    await _prefs.setDouble(keyMasterVolume, settings.masterVolume);
    await _prefs.setDouble(keyReverb, settings.reverb);
    await _prefs.setDouble(keyDelay, settings.delay);
    await _prefs.setDouble(keyFlanger, settings.flanger);
    await _prefs.setDouble(keyDistortion, settings.distortion);
    await _prefs.setDouble(keyLimiter, settings.limiter);
    await _prefs.setDouble(keyEqLow, settings.eqLow);
    await _prefs.setDouble(keyEqMid, settings.eqMid);
    await _prefs.setDouble(keyEqHigh, settings.eqHigh);
  }

  Future<void> saveMasterVolume(double volume) async {
    await _prefs.setDouble(keyMasterVolume, volume.clamp(0.0, 2.0));
  }
}

final mixerSettingsServiceProvider = Provider<MixerSettingsService>((ref) {
  throw UnimplementedError('MixerSettingsService must be overridden in ProviderScope');
});
