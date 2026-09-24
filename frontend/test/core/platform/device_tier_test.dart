import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdj_studio_sample_pad/core/platform/device_tier.dart';

void main() {
  group('isLegacyGpuName', () {
    final testCases = <String, bool>{
      'Intel(R) HD Graphics': true,
      'Intel(R) HD Graphics 3000': true,
      'Intel(R) HD Graphics 4600': false,
      'Intel(R) HD Graphics 520': false,
      'Intel(R) UHD Graphics 620': false,
      'Intel(R) Iris(R) Xe Graphics': false,
      'NVIDIA GeForce 9400 GT': true,
      'NVIDIA GeForce 940MX': false,
      'NVIDIA GeForce 210': true,
      'NVIDIA GeForce GTX 1050': false,
      'AMD Radeon HD 6450': true,
      // Extra legacy patterns
      'Intel GMA 3150': true,
      'NVIDIA Quadro FX 380': true,
      'GeForce 310M': true,
      'GeForce 8800 GT': true,
    };

    testCases.forEach((gpu, expected) {
      test('classified "$gpu" as ${expected ? "legacy" : "modern"}', () {
        expect(isLegacyGpuName(gpu), equals(expected));
      });
    });

    test('multi-adapter list: modern GPU prevents degradation', () {
      final dualAdapters = ['Intel(R) UHD Graphics 630', 'NVIDIA GeForce RTX 3060'];
      expect(dualAdapters.every(isLegacyGpuName), isFalse);

      final mixedAdapters = ['Intel(R) HD Graphics 3000', 'NVIDIA GeForce RTX 3060'];
      expect(mixedAdapters.every(isLegacyGpuName), isFalse);

      final bothLegacy = ['Intel(R) HD Graphics 3000', 'NVIDIA GeForce 210'];
      expect(bothLegacy.every(isLegacyGpuName), isTrue);
    });
  });

  group('DeviceTierDetector Windows GPU cache', () {
    setUp(() {
      DeviceTierDetector.resetForTesting();
    });

    test('reads from cache when OS matches', () async {
      SharedPreferences.setMockInitialValues({
        DeviceTierDetector.gpuCacheKey: jsonEncode({
          'os': Platform.operatingSystemVersion,
          'reduced': true,
        }),
      });

      final prefs = await SharedPreferences.getInstance();
      await DeviceTierDetector.detectWindowsGpuForTesting(prefs: prefs);

      expect(DeviceTierDetector.reducedGpu, isTrue);
    });

    test('does not use cache when OS does not match', () async {
      SharedPreferences.setMockInitialValues({
        DeviceTierDetector.gpuCacheKey: jsonEncode({
          'os': 'Old Windows Version 10.0.10000',
          'reduced': true,
        }),
      });

      final prefs = await SharedPreferences.getInstance();
      // On non-Windows OS or when powershell does not return legacy GPU,
      // mismatched cache should not set reducedGpu to true from cache.
      DeviceTierDetector.reducedGpu = false;
      await DeviceTierDetector.detectWindowsGpuForTesting(prefs: prefs);

      if (!Platform.isWindows) {
        expect(DeviceTierDetector.reducedGpu, isFalse);
      }
    });
  });
}
