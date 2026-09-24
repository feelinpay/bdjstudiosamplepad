import 'dart:async';
import 'package:flutter/foundation.dart';
import 'audio_initialization_result.dart';
import 'audio_engine_port.dart';
import '../diagnostics/startup_timeline.dart';

class AudioBootstrapper {
  AudioBootstrapper._();

  /// El presupuesto externo (30 s) cubre el peor caso de las estrategias
  /// progresivas internas del motor (3 intentos × watchdog nativo de 5 s +
  /// limpiezas), de modo que el motor siempre alcanza un estado terminal
  /// (`noDevice`/`error`) y la UI muestra su overlay con botón de reintento en
  /// vez de quedarse en "Inicializando..." sin salida.
  static Future<AudioInitializationResult> start(
    AudioEnginePort audioEngine,
    int? savedDeviceId,
  ) async {
    StartupTimeline.mark('audio_start');
    try {
      final result = await audioEngine
          .initializeAndRestoreDevice(savedDeviceId)
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('[AudioBootstrapper] Audio init timeout after 30 s');
          return const AudioInitializationResult.noDevice(
            userMessage:
                'El motor de audio tardó demasiado en responder. '
                'Los pads funcionarán cuando el audio esté disponible.',
          );
        },
      );
      StartupTimeline.mark('audio');
      return result;
    } catch (e, st) {
      StartupTimeline.mark('audio');
      debugPrint('[AudioBootstrapper] Error inicializando motor de audio: $e\n$st');
      return const AudioInitializationResult.error(
        userMessage: 'Error al inicializar el motor de audio',
      );
    }
  }
}
