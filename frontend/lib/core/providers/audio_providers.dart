import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../audio/audio_initialization_result.dart';
import '../audio/audio_engine_state.dart';

/// Cache observable del resultado de inicialización del motor de audio.
///
/// La UI arranca con null (estado `initializing` expuesto por
/// [audioInitializationProvider]). Tras el primer frame, [AudioBootstrapper]
/// ejecuta la inicialización en segundo plano y escribe aquí el resultado.
/// El overlay de audio refresca esta cache tras un `retryAudioInitialization`
/// para que la UI vuelva a reconstruirse.
final audioInitializationCacheProvider =
    StateProvider<AudioInitializationResult?>((ref) => null);

/// Resultado observable de la inicialización asíncrona del motor de audio.
///
/// Mientras el bootstrap no ha inyectado el resultado (cache == null), expone un
/// estado `initializing` para que la UI muestre el overlay de carga. Una vez
/// seteado, refleja el estado real (`ready` / `noDevice` / `error`) y se refresca
/// automáticamente cuando el overlay escribe un nuevo resultado en la cache.
final audioInitializationProvider = Provider<AudioInitializationResult>((ref) {
  final cached = ref.watch(audioInitializationCacheProvider);
  if (cached != null) return cached;
  return const AudioInitializationResult(
    state: AudioEngineState.initializing,
    devices: [],
  );
});

/// Conveniencia: true sólo cuando el motor está operativo y se puede tocar.
final isAudioReadyProvider = Provider<bool>((ref) {
  final result = ref.watch(audioInitializationProvider);
  return result.state == AudioEngineState.ready;
});
