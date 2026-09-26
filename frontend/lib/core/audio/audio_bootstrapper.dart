import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../features/settings/data/services/mixer_settings_service.dart';
import 'audio_engine_port.dart';
import 'audio_engine_state.dart';
import 'audio_initialization_result.dart';
import '../diagnostics/startup_timeline.dart';

class AudioBootstrapper {
  AudioBootstrapper._();

  /// El presupuesto externo (30 s) cubre el peor caso de las estrategias
  /// progresivas internas del motor (3 intentos × watchdog nativo de 5 s +
  /// limpiezas), de modo que el motor siempre alcanza un estado terminal
  /// (`noDevice`/`error`) y la UI muestra su overlay con botón de reintento en
  /// vez de quedarse en "Inicializando..." sin salida.
  ///
  /// Cuando el motor queda [AudioEngineState.ready], si se suministra
  /// [mixerSettingsService] se restauran los volúmenes, ecualización y efectos
  /// guardados, y [onMasterVolumeLoaded] notifica el volumen restaurado a la UI.
  static Future<AudioInitializationResult> start(
    AudioEnginePort audioEngine,
    int? savedDeviceId, {
    MixerSettingsService? mixerSettingsService,
    void Function(double volume)? onMasterVolumeLoaded,
  }) async {
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

      if (result.state == AudioEngineState.ready && mixerSettingsService != null) {
        final settings = mixerSettingsService.load();
        audioEngine.setGlobalVolume(settings.masterVolume);
        audioEngine.setMasterReverb(settings.reverb);
        audioEngine.setMasterDelay(settings.delay);
        audioEngine.setMasterFlanger(settings.flanger);
        audioEngine.setMasterDistortion(settings.distortion);
        audioEngine.setMasterLimiter(settings.limiter);
        audioEngine.setMasterEQ(
          lowGain: settings.eqLow,
          midGain: settings.eqMid,
          highGain: settings.eqHigh,
        );
        onMasterVolumeLoaded?.call(settings.masterVolume);
      }

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
