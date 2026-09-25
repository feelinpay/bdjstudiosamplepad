import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'process_runner.dart';

/// true solo para GPUs que ANGLE no puede servir con D3D11 (DX10.1 o inferior).
@visibleForTesting
bool isLegacyGpuName(String adapter) {
  final n = adapter.toLowerCase().trim();
  if (n.isEmpty) return false;
  // Intel "HD Graphics" sin número o 2000/2500/3000. "UHD" y la serie 5xx/6xx son modernas.
  final intel = RegExp(r'(?<!u)hd graphics(?:\s+[a-z]?(\d+))?\b').firstMatch(n);
  if (intel != null) {
    final gen = intel.group(1);
    if (gen == null) return true;
    return gen.length == 4 && (int.tryParse(gen) ?? 9999) < 4000;
  }
  if (n.contains('gma')) return true;
  if (RegExp(r'geforce\s+[89]\d{3}\b').hasMatch(n)) return true; // 8xxx/9xxx de 4 cifras
  if (RegExp(r'geforce\s+[23]\d0m?\b').hasMatch(n)) return true; // 210/310/320M
  if (RegExp(r'radeon hd [56]\d{3}\b').hasMatch(n)) return true;
  if (n.contains('quadro fx')) return true;
  return false;
}

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

  /// True when the GPU is known to have issues with ANGLE/Skia gradients.
  /// On such hardware, pad rendering should use flat colors instead of
  /// gradients and heavy box shadows.
  static bool _reducedGpu = false;

  /// Returns the cached tier or detects it for the first time.
  static Future<DeviceTier> detect() async {
    if (_cached != null) return _cached!;
    _cached = await _detectInternal();
    debugPrint('[DeviceTier] detected: $_cached (reducedGpu=$_reducedGpu)');
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

  /// Whether pad rendering should use simplified effects (flat colors, no
  /// heavy box shadows) because the GPU cannot reliably render gradients
  /// through ANGLE. True on legacy GPUs (Intel HD 3000, etc.) and on
  /// low-tier Android devices.
  static bool get reducedGpuEffects =>
      _reducedGpu || current == DeviceTier.low;

  // ──────────────────────────────────────────────────────────────────────────
  // Internal detection
  // ──────────────────────────────────────────────────────────────────────────

  static Future<DeviceTier> _detectInternal() async {
    // Desktop: always high for audio/performance budgets, but check GPU
    // capabilities separately to decide whether to simplify visual effects.
    if (Platform.isWindows) {
      await _detectWindowsGpu();
      return DeviceTier.high;
    }
    if (Platform.isMacOS || Platform.isLinux) {
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

  static const String gpuCacheKey = 'gpu_probe_v1';

  @visibleForTesting
  static bool get reducedGpu => _reducedGpu;

  @visibleForTesting
  static set reducedGpu(bool value) => _reducedGpu = value;

  @visibleForTesting
  static void resetForTesting() {
    _cached = null;
    _reducedGpu = false;
  }

  @visibleForTesting
  static Future<void> detectWindowsGpuForTesting({SharedPreferences? prefs}) =>
      _detectWindowsGpu(prefsInstance: prefs);

  /// Queries Win32_VideoController via PowerShell to detect legacy GPUs.
  /// Sets [_reducedGpu] = true when all detected GPUs match known
  /// legacy patterns.
  ///
  /// Uses SharedPreferences cache to avoid spawning PowerShell on subsequent runs.
  /// Timeout-guarded so it never delays startup > 3 s.
  static Future<void> _detectWindowsGpu({SharedPreferences? prefsInstance}) async {
    SharedPreferences? prefs = prefsInstance;
    try {
      prefs ??= await SharedPreferences.getInstance();
      final cached = prefs.getString(gpuCacheKey);
      if (cached != null) {
        final decoded = jsonDecode(cached);
        if (decoded is Map<String, dynamic> &&
            decoded['os'] == Platform.operatingSystemVersion &&
            decoded['reduced'] is bool) {
          _reducedGpu = decoded['reduced'] as bool;
          debugPrint('[DeviceTier] Windows GPU (from cache): reducedGpu=$_reducedGpu');
          unawaited(_probeAndCacheWindowsGpu(prefs));
          return;
        }
      }
    } catch (e) {
      debugPrint('[DeviceTier] Windows GPU cache read error: $e');
    }

    await _probeAndCacheWindowsGpu(prefs);
  }

  static Future<void> _probeAndCacheWindowsGpu(SharedPreferences? prefs) async {
    try {
      final result = await runProcessWithTimeout(
        'powershell',
        [
          '-NoProfile', '-NonInteractive', '-Command',
          'Get-CimInstance Win32_VideoController '
              '| Select-Object -ExpandProperty Name',
        ],
        const Duration(seconds: 3),
      );

      if (result == null || result.exitCode != 0) return;

      final stdoutStr = result.stdout as String;
      final adapters = stdoutStr
          .split(RegExp(r'\r?\n'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (adapters.isEmpty) return;

      _reducedGpu = adapters.every(isLegacyGpuName);
      debugPrint('[DeviceTier] Windows GPU probed: $adapters (reducedGpu=$_reducedGpu)');

      try {
        final targetPrefs = prefs ?? await SharedPreferences.getInstance();
        await targetPrefs.setString(
          gpuCacheKey,
          jsonEncode(<String, dynamic>{
            'os': Platform.operatingSystemVersion,
            'reduced': _reducedGpu,
          }),
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('[DeviceTier] Windows GPU detection failed: $e');
      // Fail open: assume GPU is fine.
    }
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
      final ramGb = await _readTotalRamGb();
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
  static Future<double?> _readTotalRamGb() async {
    try {
      for (final line in await File('/proc/meminfo').readAsLines()) {
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
