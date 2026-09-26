import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/core/platform/device_tier.dart';

void main() {
  group('DeviceProfile y resolveProfile (T18)', () {
    test('4 GB / 8 núcleos → low (límite de memoria baja)', () {
      const signals = DeviceSignals(
        totalRamMb: 4096,
        availRamMb: 2048,
        cores: 8,
      );
      final profile = resolveProfile(signals, PerformanceOverride.auto);

      expect(profile.tier, equals(DeviceTier.low));
      expect(profile.maxConcurrentLoads, equals(1));
      expect(profile.diskThresholdSeconds, equals(30));
      expect(profile.voicePollingIntervalMs, equals(75));
      expect(profile.reducedVisualEffects, isTrue);
    });

    test('16 GB / 4 núcleos → mid (memoria alta pero núcleos insuficientes para high)', () {
      const signals = DeviceSignals(
        totalRamMb: 16384,
        availRamMb: 8192,
        cores: 4,
      );
      final profile = resolveProfile(signals, PerformanceOverride.auto);

      expect(profile.tier, equals(DeviceTier.mid));
      expect(profile.maxConcurrentLoads, equals(2));
      expect(profile.diskThresholdSeconds, equals(90));
      expect(profile.voicePollingIntervalMs, equals(50));
      expect(profile.reducedVisualEffects, isFalse);
    });

    test('16 GB / 8 núcleos → high (cumple RAM >= 12 GB y núcleos >= 8)', () {
      const signals = DeviceSignals(
        totalRamMb: 16384,
        availRamMb: 8192,
        cores: 8,
      );
      final profile = resolveProfile(signals, PerformanceOverride.auto);

      expect(profile.tier, equals(DeviceTier.high));
      expect(profile.maxConcurrentLoads, equals(4)); // min(4, 8 ~/ 2) = 4
      expect(profile.diskThresholdSeconds, equals(180));
      expect(profile.voicePollingIntervalMs, equals(25));
      expect(profile.reducedVisualEffects, isFalse);
    });

    test('Señales nulas (RAM desconocida) → mid por defecto seguro (nunca high)', () {
      const signals = DeviceSignals(
        totalRamMb: null,
        availRamMb: null,
        cores: 8,
      );
      final profile = resolveProfile(signals, PerformanceOverride.auto);

      expect(profile.tier, equals(DeviceTier.mid));
      expect(profile.maxConcurrentLoads, equals(2));
    });

    test('Android SDK < 26 fuerza low tier independientemente de núcleos', () {
      const signals = DeviceSignals(
        totalRamMb: 8192,
        availRamMb: 4096,
        cores: 8,
        androidSdk: 24, // SDK antiguo
      );
      final profile = resolveProfile(signals, PerformanceOverride.auto);

      expect(profile.tier, equals(DeviceTier.low));
    });

    test('Override manual se impone sobre la detección automática', () {
      // Hardware potente (16 GB / 8 núcleos) pero usuario selecciona Ahorro
      const highSignals = DeviceSignals(
        totalRamMb: 16384,
        availRamMb: 8192,
        cores: 8,
      );
      final powerSaveProfile = resolveProfile(highSignals, PerformanceOverride.powerSave);
      expect(powerSaveProfile.tier, equals(DeviceTier.low));
      expect(powerSaveProfile.maxConcurrentLoads, equals(1));

      // Hardware básico (2 GB / 2 núcleos) pero usuario selecciona Máximo
      const lowSignals = DeviceSignals(
        totalRamMb: 2048,
        availRamMb: 1024,
        cores: 2,
      );
      final perfProfile = resolveProfile(lowSignals, PerformanceOverride.performance);
      expect(perfProfile.tier, equals(DeviceTier.high));
    });

    test('availRamMb recorta el presupuesto de memoria pero no altera el tier del perfil', () {
      // 16 GB y 8 núcleos es tier high (presupuesto base ~2048 MB)
      const normalSignals = DeviceSignals(
        totalRamMb: 16384,
        availRamMb: 8192,
        cores: 8,
      );
      final normalProfile = resolveProfile(normalSignals, PerformanceOverride.auto);
      expect(normalProfile.tier, equals(DeviceTier.high));
      expect(normalProfile.cacheBudgetMb, equals(2048));

      // Mismo hardware pero con presión severa de RAM disponible (500 MB disponibles)
      const constrainedSignals = DeviceSignals(
        totalRamMb: 16384,
        availRamMb: 500, // min(2048, 500 * 0.5) = 250 MB
        cores: 8,
      );
      final constrainedProfile = resolveProfile(constrainedSignals, PerformanceOverride.auto);
      expect(constrainedProfile.tier, equals(DeviceTier.high), reason: 'El tier debe ser estable y no oscilar');
      expect(constrainedProfile.cacheBudgetMb, equals(250), reason: 'El presupuesto debe haberse recortado por la RAM disponible');
    });

    test('DeviceSignalsCollector recolecta señales válidas en la plataforma actual', () async {
      final signals = await DeviceSignalsCollector.collect();
      expect(signals.cores, greaterThan(0));
      // En Windows o Linux donde se ejecuta el test, totalRamMb debe ser detectado vía FFI o /proc/meminfo
      expect(signals.totalRamMb, isNotNull);
      expect(signals.totalRamMb!, greaterThan(512));
    });
  });
}
