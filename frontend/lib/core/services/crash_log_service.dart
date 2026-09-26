import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../platform/device_tier.dart';
import 'app_storage_service.dart';

/// Servicio centralizado de captura de errores, logging persistente y
/// generación de reportes de diagnóstico para soporte técnico.
class CrashLogService {
  CrashLogService._();

  static const int _maxInMemoryLogs = 100;
  static final Queue<String> _inMemoryLogs = Queue<String>();
  static IOSink? _sink;
  static bool _handlersInstalled = false;
  static bool _attachingLogFile = false;

  /// Registra los interceptores globales de error de manera síncrona.
  static void installHandlers() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;

    // 1. Interceptor de errores del framework Flutter
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      recordFlutterError(details);
    };

    // 2. Interceptor de errores de la plataforma / isolates
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      recordPlatformError(error, stack);
      return false; // permite que continúe el flujo
    };

    // 3. ErrorWidget personalizado para builds en release (evita pantalla gris/negra muda)
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: const Color(0xFF151522),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 52,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error visual en la interfaz',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details.exceptionAsString(),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Puedes ir a Ajustes para copiar el diagnóstico técnico.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    };

    log('=== BDJ Studio App Inició ===');
  }

  /// Conecta el archivo de log en disco de forma asíncrona y vuelca el buffer en memoria.
  static Future<void> attachLogFile() async {
    if (_sink != null || _attachingLogFile) return;
    _attachingLogFile = true;
    try {
      final logsDir = await AppStorageService.logsDirectory();
      var logFile = File('${logsDir.path}/app_runtime.log');

      // Rotar log si supera 2 MB
      if (await logFile.exists()) {
        final length = await logFile.length();
        if (length > 2 * 1024 * 1024) {
          final oldLog = File('${logsDir.path}/app_runtime.old.log');
          if (await oldLog.exists()) await oldLog.delete();
          await logFile.rename(oldLog.path);
          logFile = File('${logsDir.path}/app_runtime.log');
        }
      }

      final sink = logFile.openWrite(mode: FileMode.append);
      sink.done.catchError((Object error, StackTrace stack) => _sink = null);
      _sink = sink;

      // Volcar líneas previas acumuladas en memoria en orden
      for (final line in _inMemoryLogs) {
        sink.writeln(line);
      }
    } catch (e) {
      debugPrint('[CrashLog] Error inicializando archivo de logs: $e');
    } finally {
      _attachingLogFile = false;
    }
  }

  /// Fuerza el volcado al disco del búfer pendiente (ej. cuando la app entra en pausa o segundo plano).
  static Future<void> flush() async {
    final s = _sink;
    if (s != null) {
      try {
        await s.flush();
      } catch (_) {}
    }
  }

  /// Inicializa tanto interceptores como archivo de logs (compatibilidad).
  static Future<void> initialize() async {
    installHandlers();
    await attachLogFile();
  }

  /// Registra una línea informativa o de error en memoria y en disco.
  static void log(String message) {
    final now = DateTime.now().toIso8601String().substring(11, 19);
    final entry = '[$now] $message';

    if (_inMemoryLogs.length >= _maxInMemoryLogs) {
      _inMemoryLogs.removeFirst();
    }
    _inMemoryLogs.add(entry);

    final sink = _sink;
    if (sink != null) {
      sink.writeln(entry);
    }
  }

  @visibleForTesting
  static Future<void> closeSinkForTesting() async {
    final sink = _sink;
    _sink = null;
    _attachingLogFile = false;
    if (sink != null) {
      await sink.flush();
      await sink.close();
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _sink = null;
    _handlersInstalled = false;
    _attachingLogFile = false;
    _inMemoryLogs.clear();
  }

  /// Registra un error de Flutter.
  static void recordFlutterError(FlutterErrorDetails details) {
    final summary = details.exceptionAsString();
    log('ERROR FLUTTER: $summary');
    if (details.stack != null) {
      final topLines = details.stack.toString().split('\n').take(4).join(' | ');
      log('STACK: $topLines');
    }
  }

  /// Registra un error no controlado de plataforma.
  static void recordPlatformError(Object error, StackTrace stack) {
    log('ERROR PLATAFORMA: $error');
    final topLines = stack.toString().split('\n').take(4).join(' | ');
    log('STACK: $topLines');
  }

  /// Genera un reporte técnico completo listo para copiar o enviar por WhatsApp.
  static Future<String> generateDiagnosticReport() async {
    final buffer = StringBuffer();
    buffer.writeln('=== REPORTE DE DIAGNÓSTICO BDJ STUDIO ===');
    buffer.writeln('Fecha: ${DateTime.now().toIso8601String()}');

    try {
      final pkg = await PackageInfo.fromPlatform();
      buffer.writeln('Versión App: ${pkg.version}+${pkg.buildNumber}');
    } catch (_) {
      buffer.writeln('Versión App: 1.0.3');
    }

    buffer.writeln('Sistema: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    buffer.writeln('DeviceTier: ${DeviceTierDetector.current.name}');
    buffer.writeln('Perfil de rendimiento: ${DeviceTierDetector.profile.summary}');
    final signals = DeviceTierDetector.signals;
    if (signals != null) {
      buffer.writeln('Señales de hardware: $signals');
    }

    if (Platform.isAndroid) {
      try {
        final android = await DeviceInfoPlugin().androidInfo;
        buffer.writeln('Dispositivo: ${android.brand} ${android.model} (${android.device})');
        buffer.writeln('Android SDK: ${android.version.sdkInt} (Release: ${android.version.release})');
        buffer.writeln('Fabricante: ${android.manufacturer}');
        buffer.writeln('ABIs Soportadas: ${android.supportedAbis.join(', ')}');
        buffer.writeln('Es emulador: ${android.isPhysicalDevice ? 'No' : 'Sí'}');
      } catch (e) {
        buffer.writeln('Error leyendo info de Android: $e');
      }
    }

    buffer.writeln('\n--- ÚLTIMOS LOGS (${_inMemoryLogs.length} entradas) ---');
    for (final line in _inMemoryLogs) {
      buffer.writeln(line);
    }
    buffer.writeln('==========================================');

    return buffer.toString();
  }
}
