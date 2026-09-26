import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'device_tier.dart';

/// Señales de hardware recopiladas para determinar el perfil de rendimiento.
class DeviceSignals {
  final int? totalRamMb;
  final int? availRamMb;
  final int cores;
  final int? androidSdk;
  final bool legacyGpu;

  const DeviceSignals({
    this.totalRamMb,
    this.availRamMb,
    required this.cores,
    this.androidSdk,
    this.legacyGpu = false,
  });

  @override
  String toString() =>
      'DeviceSignals(totalRam: ${totalRamMb != null ? '$totalRamMb MB' : 'desconocida'}, '
      'availRam: ${availRamMb != null ? '$availRamMb MB' : 'desconocida'}, '
      'cores: $cores, sdk: $androidSdk, legacyGpu: $legacyGpu)';
}

/// Modos de anulación manual de rendimiento desde Ajustes.
enum PerformanceOverride {
  auto,
  powerSave,
  balanced,
  performance;

  static PerformanceOverride fromKey(String? key) {
    return switch (key) {
      'power_save' || 'ahorro' => PerformanceOverride.powerSave,
      'balanced' || 'equilibrado' => PerformanceOverride.balanced,
      'performance' || 'maximo' || 'máximo' => PerformanceOverride.performance,
      _ => PerformanceOverride.auto,
    };
  }

  String get key => switch (this) {
    PerformanceOverride.auto => 'auto',
    PerformanceOverride.powerSave => 'power_save',
    PerformanceOverride.balanced => 'balanced',
    PerformanceOverride.performance => 'performance',
  };

  String get label => switch (this) {
    PerformanceOverride.auto => 'Automático',
    PerformanceOverride.powerSave => 'Ahorro',
    PerformanceOverride.balanced => 'Equilibrado',
    PerformanceOverride.performance => 'Máximo',
  };
}

/// Parámetros inmutables del perfil de rendimiento del dispositivo.
class DeviceProfile {
  final DeviceTier tier;
  final PerformanceOverride performanceOverride;
  final int cacheBudgetMb;
  final int maxConcurrentLoads;
  final int diskThresholdSeconds;
  final bool reducedVisualEffects;
  final int voicePollingIntervalMs;
  final String summary;

  const DeviceProfile({
    required this.tier,
    required this.performanceOverride,
    required this.cacheBudgetMb,
    required this.maxConcurrentLoads,
    required this.diskThresholdSeconds,
    required this.reducedVisualEffects,
    required this.voicePollingIntervalMs,
    required this.summary,
  });

  /// Presupuesto de memoria para la caché en bytes.
  int get cacheBudgetBytes => cacheBudgetMb * 1024 * 1024;

  @override
  String toString() =>
      'DeviceProfile(tier: ${tier.name}, override: ${performanceOverride.name}, '
      'cacheBudget: $cacheBudgetMb MB, concurrency: $maxConcurrentLoads, '
      'diskThreshold: ${diskThresholdSeconds}s, polling: ${voicePollingIntervalMs}ms)';
}

/// Función pura y testeable que resuelve el perfil de ejecución a partir
/// de las señales de hardware y el override manual del usuario.
DeviceProfile resolveProfile(DeviceSignals s, PerformanceOverride o) {
  // 1. Determinar el tier base a partir de las señales de hardware.
  // Regla: Si falla la lectura de RAM (null), asumimos mid por defecto (nunca high).
  final DeviceTier baseTier;
  if (s.totalRamMb == null) {
    baseTier = DeviceTier.mid;
  } else {
    // low: ≤ 4 GB (4096 MB) o ≤ 2 núcleos o Android con SDK < 26.
    final isLowRam = s.totalRamMb! <= 4096;
    final isLowCores = s.cores <= 2;
    final isOldAndroid = s.androidSdk != null && s.androidSdk! < 26;

    if (isLowRam || isLowCores || isOldAndroid) {
      baseTier = DeviceTier.low;
    } else if (s.totalRamMb! >= 12288 && s.cores >= 8) {
      // high: ≥ 12 GB y ≥ 8 núcleos.
      baseTier = DeviceTier.high;
    } else {
      // mid: resto (ej. 8 GB Mac, 4 núcleos, 6 GB Android, etc.).
      baseTier = DeviceTier.mid;
    }
  }

  // 2. Aplicar el override manual si existe
  final DeviceTier effectiveTier = switch (o) {
    PerformanceOverride.powerSave => DeviceTier.low,
    PerformanceOverride.balanced => DeviceTier.mid,
    PerformanceOverride.performance => DeviceTier.high,
    PerformanceOverride.auto => baseTier,
  };

  // 3. Presupuesto de memoria para la caché de audio:
  // low:  10 % de la RAM total, máx. 256 MB
  // mid:  15 % de la RAM total, máx. 768 MB
  // high: 20 % de la RAM total, máx. 2 GB (2048 MB)
  final refRam = s.totalRamMb ?? switch (effectiveTier) {
    DeviceTier.low => 2048,
    DeviceTier.mid => 8192,
    DeviceTier.high => 16384,
  };

  int budgetMb = switch (effectiveTier) {
    DeviceTier.low => min(256, (refRam * 0.10).round()),
    DeviceTier.mid => min(768, (refRam * 0.15).round()),
    DeviceTier.high => min(2048, (refRam * 0.20).round()),
  };

  // La RAM disponible recorta el presupuesto si hay presión de memoria,
  // pero no altera el tier del perfil: min(presupuesto, disponible * 0.5)
  if (s.availRamMb != null && s.availRamMb! > 0) {
    final maxAllowedFromAvail = (s.availRamMb! * 0.5).round();
    if (maxAllowedFromAvail < budgetMb) {
      budgetMb = maxAllowedFromAvail;
    }
  }
  // Mínimo de seguridad para que la app pueda operar al menos con un set básico
  if (budgetMb < 32) budgetMb = 32;

  // 4. Parámetros derivados del tier efectivo:
  final int maxConcurrentLoads = switch (effectiveTier) {
    DeviceTier.low => 1,
    DeviceTier.mid => 2,
    DeviceTier.high => min(4, max(1, s.cores ~/ 2)),
  };

  final int diskThresholdSeconds = switch (effectiveTier) {
    DeviceTier.low => 30,
    DeviceTier.mid => 90,
    DeviceTier.high => 180,
  };

  final bool reducedVisualEffects =
      effectiveTier == DeviceTier.low || s.legacyGpu;

  final int voicePollingIntervalMs = switch (effectiveTier) {
    DeviceTier.low => 75,
    DeviceTier.mid => 50,
    DeviceTier.high => 25,
  };

  final summary = '${effectiveTier.name.toUpperCase()}'
      '${o != PerformanceOverride.auto ? ' (manual: ${o.label})' : ''}'
      ' | RAM: ${s.totalRamMb != null ? '${(s.totalRamMb! / 1024).toStringAsFixed(1)} GB' : 'N/D'}'
      ' | Caché: $budgetMb MB | Cargas: $maxConcurrentLoads';

  return DeviceProfile(
    tier: effectiveTier,
    performanceOverride: o,
    cacheBudgetMb: budgetMb,
    maxConcurrentLoads: maxConcurrentLoads,
    diskThresholdSeconds: diskThresholdSeconds,
    reducedVisualEffects: reducedVisualEffects,
    voicePollingIntervalMs: voicePollingIntervalMs,
    summary: summary,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Win32 FFI Struct para GlobalMemoryStatusEx en Windows
// ─────────────────────────────────────────────────────────────────────────────

final class _MemoryStatusEx extends Struct {
  @Uint32()
  external int dwLength;
  @Uint32()
  external int dwMemoryLoad;
  @Uint64()
  external int ullTotalPhys;
  @Uint64()
  external int ullAvailPhys;
  @Uint64()
  external int ullTotalPageFile;
  @Uint64()
  external int ullAvailPageFile;
  @Uint64()
  external int ullTotalVirtual;
  @Uint64()
  external int ullAvailVirtual;
  @Uint64()
  external int ullAvailExtendedVirtual;
}

/// Recolector de señales de hardware del sistema operativo sin dependencias externas.
class DeviceSignalsCollector {
  DeviceSignalsCollector._();

  static Future<DeviceSignals> collect({bool legacyGpu = false}) async {
    int? totalRam;
    int? availRam;

    if (Platform.isWindows) {
      final winMem = _readWindowsMemory();
      if (winMem != null) {
        totalRam = winMem.totalMb;
        availRam = winMem.availMb;
      }
    } else if (Platform.isLinux || Platform.isAndroid) {
      final meminfo = _readProcMeminfo();
      if (meminfo != null) {
        totalRam = meminfo.totalMb;
        availRam = meminfo.availMb;
      }
    } else if (Platform.isMacOS) {
      totalRam = _readMacOsTotalRamMb();
    }

    int? androidSdk;
    if (Platform.isAndroid) {
      // Si se ejecuta en Android, intentamos leer la versión de SDK
      try {
        final versionFile = File('/system/build.prop');
        if (versionFile.existsSync()) {
          for (final line in versionFile.readAsLinesSync()) {
            if (line.startsWith('ro.build.version.sdk=')) {
              androidSdk = int.tryParse(line.split('=').last.trim());
              break;
            }
          }
        }
      } catch (_) {}
    }

    return DeviceSignals(
      totalRamMb: totalRam,
      availRamMb: availRam,
      cores: Platform.numberOfProcessors,
      androidSdk: androidSdk,
      legacyGpu: legacyGpu,
    );
  }

  static ({int totalMb, int availMb})? _readWindowsMemory() {
    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      final getProcessHeap = kernel32.lookupFunction<Pointer Function(), Pointer Function()>('GetProcessHeap');
      final heapAlloc = kernel32.lookupFunction<
        Pointer Function(Pointer, Uint32, IntPtr),
        Pointer Function(Pointer, int, int)
      >('HeapAlloc');
      final heapFree = kernel32.lookupFunction<
        Int32 Function(Pointer, Uint32, Pointer),
        int Function(Pointer, int, Pointer)
      >('HeapFree');
      final globalMemoryStatusEx = kernel32.lookupFunction<
        Int32 Function(Pointer<_MemoryStatusEx>),
        int Function(Pointer<_MemoryStatusEx>)
      >('GlobalMemoryStatusEx');

      final heap = getProcessHeap();
      if (heap == nullptr) return null;

      final structSize = sizeOf<_MemoryStatusEx>();
      final ptr = heapAlloc(heap, 8 /* HEAP_ZERO_MEMORY */, structSize).cast<_MemoryStatusEx>();
      if (ptr == nullptr) return null;

      try {
        ptr.ref.dwLength = structSize;
        final res = globalMemoryStatusEx(ptr);
        if (res != 0) {
          final total = ptr.ref.ullTotalPhys ~/ (1024 * 1024);
          final avail = ptr.ref.ullAvailPhys ~/ (1024 * 1024);
          return (totalMb: total, availMb: avail);
        }
      } finally {
        heapFree(heap, 0, ptr);
      }
    } catch (e) {
      debugPrint('[DeviceSignalsCollector] Error leyendo memoria en Windows: $e');
    }
    return null;
  }

  static ({int totalMb, int? availMb})? _readProcMeminfo() {
    try {
      final file = File('/proc/meminfo');
      if (!file.existsSync()) return null;
      int? totalKb;
      int? availKb;
      for (final line in file.readAsLinesSync()) {
        if (line.startsWith('MemTotal:')) {
          totalKb = int.tryParse(line.substring('MemTotal:'.length).trim().split(RegExp(r'\s+')).first);
        } else if (line.startsWith('MemAvailable:')) {
          availKb = int.tryParse(line.substring('MemAvailable:'.length).trim().split(RegExp(r'\s+')).first);
        }
        if (totalKb != null && availKb != null) break;
      }
      if (totalKb != null && totalKb > 0) {
        return (
          totalMb: totalKb ~/ 1024,
          availMb: (availKb != null && availKb > 0) ? (availKb ~/ 1024) : null,
        );
      }
    } catch (_) {}
    return null;
  }

  static int? _readMacOsTotalRamMb() {
    try {
      final libc = DynamicLibrary.open('/usr/lib/libc.dylib');
      final malloc = libc.lookupFunction<Pointer Function(IntPtr), Pointer Function(int)>('malloc');
      final free = libc.lookupFunction<Void Function(Pointer), void Function(Pointer)>('free');
      final sysctlbyname = libc.lookupFunction<
        Int32 Function(Pointer<Uint8>, Pointer<Uint64>, Pointer<IntPtr>, Pointer, IntPtr),
        int Function(Pointer<Uint8>, Pointer<Uint64>, Pointer<IntPtr>, Pointer, int)
      >('sysctlbyname');

      final nameBytes = 'hw.memsize'.codeUnits;
      final namePtr = malloc(nameBytes.length + 1).cast<Uint8>();
      for (int i = 0; i < nameBytes.length; i++) {
        namePtr[i] = nameBytes[i];
      }
      namePtr[nameBytes.length] = 0;

      final valPtr = malloc(8).cast<Uint64>();
      final sizePtr = malloc(8).cast<IntPtr>();
      sizePtr.value = 8;

      final res = sysctlbyname(namePtr, valPtr, sizePtr, nullptr, 0);
      int? bytes;
      if (res == 0) {
        bytes = valPtr.value;
      }
      free(namePtr);
      free(valPtr);
      free(sizePtr);

      if (bytes != null && bytes > 0) {
        return bytes ~/ (1024 * 1024);
      }
    } catch (_) {}
    return null;
  }
}
