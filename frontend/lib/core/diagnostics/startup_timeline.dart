import 'package:flutter/scheduler.dart';
import '../services/crash_log_service.dart';

/// Marca hitos del arranque y registra frames lentos en el log de diagnóstico.
class StartupTimeline {
  StartupTimeline._();
  static final Stopwatch _clock = Stopwatch()..start();

  static void mark(String name) =>
      CrashLogService.log('[Startup] $name +${_clock.elapsedMilliseconds} ms');

  /// Registra cualquier frame cuyo build o raster supere [threshold].
  static void watchSlowFrames({Duration threshold = const Duration(milliseconds: 100)}) {
    SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
      for (final t in timings) {
        if (t.buildDuration > threshold || t.rasterDuration > threshold) {
          CrashLogService.log('[Frame] build=${t.buildDuration.inMilliseconds} ms '
              'raster=${t.rasterDuration.inMilliseconds} ms');
        }
      }
    });
  }
}
