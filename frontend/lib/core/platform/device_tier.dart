import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_profile.dart';
import 'process_runner.dart';

export 'device_profile.dart';

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
  static DeviceProfile? _profile;
  static DeviceSignals? _signals;

  /// True when the GPU is known to have issues with ANGLE/Skia gradients.
  /// On such hardware, pad rendering should use flat colors instead of
  /// gradients and heavy box shadows.
  static bool _reducedGpu = false;

  /// Returns the cached tier or detects it for the first time.
  static Future<DeviceTier> detect() async {
    if (_cached != null) return _cached!;
    _cached = await _detectInternal();
    debugPrint('[DeviceTier] detected: $_cached (reducedGpu=$_reducedGpu, profile=$_profile)');
    return _cached!;
  }

  /// Synchronous access after [detect] has been awaited at least once.
  static DeviceTier get current => _cached ?? DeviceTier.high;

  /// Retorna el perfil de rendimiento completo y ajustado.
  static DeviceProfile get profile =>
      _profile ??
      resolveProfile(
        DeviceSignals(cores: Platform.numberOfProcessors),
        PerformanceOverride.auto,
      );

  /// Retorna las señales de hardware detectadas si ya se ejecutó [detect].
  static DeviceSignals? get signals => _signals;

  /// Actualiza en caliente el perfil tras un cambio manual en Ajustes.
  static void updateOverride(PerformanceOverride override) {
    final s = _signals ?? DeviceSignals(cores: Platform.numberOfProcessors);
    _profile = resolveProfile(s, override);
    _cached = _profile!.tier;
    _reducedGpu = _profile!.reducedVisualEffects;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Tuning knobs per tier
  // ──────────────────────────────────────────────────────────────────────────

  /// Max concurrent sounds kept in the LRU cache.
  static int get soundCacheCapacity => switch (current) {
    DeviceTier.low  => 25,
    DeviceTier.mid  => 50,
    DeviceTier.high => 100,
  };

  /// Presupuesto de memoria de la caché en MB según el perfil de hardware.
  static int get soundCacheBudgetMb => profile.cacheBudgetMb;

  /// Interval at which the audio engine polls voice handles (ms).
  static int get audioPollingIntervalMs => profile.voicePollingIntervalMs;

  /// Whether pad rendering should use simplified effects (flat colors, no
  /// heavy box shadows) because the GPU cannot reliably render gradients
  /// through ANGLE. True on legacy GPUs (Intel HD 3000, etc.) and on
  /// low-tier Android devices.
  static bool get reducedGpuEffects => profile.reducedVisualEffects;

  // ──────────────────────────────────────────────────────────────────────────
  // Internal detection
  // ──────────────────────────────────────────────────────────────────────────

  static Future<DeviceTier> _detectInternal() async {
    if (Platform.isWindows) {
      await _detectWindowsGpu();
    }

    String? savedOverrideKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      savedOverrideKey = prefs.getString('performance_profile');
    } catch (_) {}

    final override = PerformanceOverride.fromKey(savedOverrideKey);
    final s = await DeviceSignalsCollector.collect(legacyGpu: _reducedGpu);
    _signals = s;
    _profile = resolveProfile(s, override);
    _cached = _profile!.tier;
    _reducedGpu = _profile!.reducedVisualEffects;
    return _cached!;
  }

  static const String gpuCacheKey = 'gpu_probe_v1';

  @visibleForTesting
  static bool get reducedGpu => _reducedGpu;

  @visibleForTesting
  static set reducedGpu(bool value) => _reducedGpu = value;

  @visibleForTesting
  static void resetForTesting() {
    _cached = null;
    _profile = null;
    _signals = null;
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
}
