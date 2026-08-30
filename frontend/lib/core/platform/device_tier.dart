import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Device performance tier used to auto-tune resource budgets at startup.
///
/// Detection runs once and the result is cached for the lifetime of the app.
/// Desktop platforms are always [DeviceTier.high].
enum DeviceTier {
  /// Budget device: ≤ 3 GB RAM or SDK < 26.
  low,

  /// Mid-range device: 4-6 GB RAM.
  mid,

  /// Flagship / desktop.
  high,
}

class DeviceTierDetector {
  DeviceTierDetector._();

  static DeviceTier? _cached;

  /// Returns the cached tier or detects it for the first time.
  static Future<DeviceTier> detect() async {
    if (_cached != null) return _cached!;
    _cached = await _detectInternal();
    debugPrint('[DeviceTier] detected: $_cached');
    return _cached!;
  }

  /// Synchronous access after [detect] has been awaited at least once.
  static DeviceTier get current => _cached ?? DeviceTier.high;

  // ──────────────────────────────────────────────────────────────────────────
  // Tuning knobs per tier
  // ──────────────────────────────────────────────────────────────────────────

  /// Max concurrent sounds kept in the LRU cache.
  static int get soundCacheCapacity => switch (current) {
    DeviceTier.low  => 25,
    DeviceTier.mid  => 50,
    DeviceTier.high => 100,
  };

  /// Interval at which the audio engine polls voice handles (ms).
  static int get audioPollingIntervalMs => switch (current) {
    DeviceTier.low  => 75,
    DeviceTier.mid  => 50,
    DeviceTier.high => 25,
  };

  /// Whether real-time audio visualization should be enabled by default.
  static bool get enableVisualizationByDefault => current != DeviceTier.low;

  // ──────────────────────────────────────────────────────────────────────────
  // Internal detection
  // ──────────────────────────────────────────────────────────────────────────

  static Future<DeviceTier> _detectInternal() async {
    // Desktop / Web → always high.
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return DeviceTier.high;
    }

    if (Platform.isAndroid) {
      return _detectAndroid();
    }

    if (Platform.isIOS) {
      return _detectIOS();
    }

    return DeviceTier.high;
  }

  static Future<DeviceTier> _detectAndroid() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;

      final sdk = info.version.sdkInt;
      final model = info.model.toLowerCase();
      final brand = info.brand.toLowerCase();

      // Very old SDK levels indicate legacy hardware.
      if (sdk < 26) return DeviceTier.low;

      // Real total RAM (world-readable /proc/meminfo) beats every heuristic:
      // a modern-looking 2 GB phone must still be treated as low tier.
      // The virtual file is tiny and reads in microseconds.
      final ramGb = _readTotalRamGb();
      debugPrint('[DeviceTier] Android MemTotal: ${ramGb?.toStringAsFixed(2) ?? '?'} GB');
      if (ramGb != null) {
        if (ramGb <= 2.5) return DeviceTier.low;
        if (ramGb <= 6.5) return DeviceTier.mid;
        return DeviceTier.high;
      }

      // Known budget prefixes / keywords (Samsung Galaxy A0x, Xiaomi Redmi Go, etc.)
      final budgetMarkers = [
        'redmi go', 'galaxy a0', 'galaxy a10', 'galaxy a11', 'galaxy a12',
        'galaxy a13', 'galaxy a01', 'galaxy a02', 'galaxy a03',
        'nokia 1', 'nokia 2', 'moto e', 'y5', 'y6',
      ];
      for (final marker in budgetMarkers) {
        if (model.contains(marker)) return DeviceTier.low;
      }

      // Heuristic fallbacks below run only when /proc/meminfo is unavailable.
      // SDK 26-29 + non-flagship brand hints → mid
      if (sdk < 30) return DeviceTier.mid;

      // Modern SDK but could still be budget — check for Go Edition
      if (info.systemFeatures.contains('android.software.leanback_only') ||
          model.contains('go edition')) {
        return DeviceTier.low;
      }

      // Modern device with recent SDK → mid by default, high for flagships
      final flagshipBrands = ['samsung', 'google', 'oneplus', 'huawei', 'xiaomi', 'oppo'];
      if (sdk >= 33 && flagshipBrands.contains(brand)) {
        return DeviceTier.high;
      }

      return DeviceTier.mid;
    } catch (e) {
      debugPrint('[DeviceTier] Android detection failed: $e');
      return DeviceTier.mid; // Safe default
    }
  }

  /// Total physical RAM in GB parsed from `/proc/meminfo` (Android/Linux).
  /// Returns null when the file cannot be read or has no MemTotal entry.
  static double? _readTotalRamGb() {
    try {
      for (final line in File('/proc/meminfo').readAsLinesSync()) {
        if (!line.startsWith('MemTotal:')) continue;
        final kb = int.tryParse(
          line.substring('MemTotal:'.length).trim().split(RegExp(r'\s+')).first,
        );
        if (kb == null || kb <= 0) break;
        return kb / (1024 * 1024);
      }
    } catch (_) {}
    return null;
  }

  static Future<DeviceTier> _detectIOS() async {
    try {
      final info = await DeviceInfoPlugin().iosInfo;

      // iPhone / iPad model identifiers: iPhoneXX,Y
      final machine = info.utsname.machine;

      // iPhone 6s (8,1) through iPhone SE 1st gen (8,4): low
      // iPhone 7 (9,x) through iPhone X (10,x): mid
      // iPhone XS (11,x) and later: high
      final match = RegExp(r'iPhone(\d+),').firstMatch(machine);
      if (match != null) {
        final major = int.tryParse(match.group(1)!) ?? 99;
        if (major <= 8) return DeviceTier.low;
        if (major <= 10) return DeviceTier.mid;
        return DeviceTier.high;
      }

      // iPads: generally mid or high
      return DeviceTier.mid;
    } catch (e) {
      debugPrint('[DeviceTier] iOS detection failed: $e');
      return DeviceTier.mid;
    }
  }
}
