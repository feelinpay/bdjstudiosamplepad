import 'package:flutter_test/flutter_test.dart';

import 'package:bdj_studio_sample_pad/core/audio/audio_engine_state.dart';
import 'package:bdj_studio_sample_pad/core/audio/trigger_mode.dart';
import 'package:bdj_studio_sample_pad/features/audio_engine/data/soloud_audio_engine.dart';

/// Ciclo de vida de [SoLoudAudioEngine] en un entorno sin tarjeta de sonido
/// (headless), que es exactamente el camino que recorre la app cuando el
/// equipo del DJ arranca sin salida de audio conectada.
///
/// Aquí no se prueba la reproducción real (requiere FFI + dispositivo), sino
/// los invariantes de arranque: que inicializar sea idempotente, que llamadas
/// concurrentes no se queden colgadas y que la superficie pública no lance
/// excepciones antes de estar inicializada.
void main() {
  late SoLoudAudioEngine engine;

  setUp(() {
    engine = SoLoudAudioEngine();
  });

  tearDown(() {
    try {
      engine.dispose();
    } catch (_) {}
  });

  group('inicialización', () {
    test('parte en estado uninitialized', () {
      expect(engine.engineState, AudioEngineState.uninitialized);
    });

    test('initialize() deja el motor fuera de uninitialized', () async {
      await engine.initialize();
      expect(engine.engineState, isNot(AudioEngineState.uninitialized));
    });

    test('initialize() secuencial es idempotente', () async {
      await engine.initialize();
      final first = engine.engineState;
      await engine.initialize();
      expect(engine.engineState, first);
    });

    test(
      'dos initialize() concurrentes resuelven ambos (sin cuelgue)',
      () async {
        // La UI dispara initialize() desde varios sitios a la vez (splash,
        // provider de audio, restauración de dispositivo). Si el guard de
        // concurrencia deja un Completer huérfano, el primer llamador espera
        // para siempre y la app se queda en la pantalla de carga.
        final first = engine.initialize();
        final second = engine.initialize();

        await expectLater(
          Future.wait<void>([first, second]).timeout(
            const Duration(seconds: 5),
          ),
          completes,
        );
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    test(
      'una ráfaga de initialize() concurrentes resuelve todas',
      () async {
        final futures = List<Future<void>>.generate(
          8,
          (_) => engine.initialize(),
        );

        await expectLater(
          Future.wait<void>(futures).timeout(const Duration(seconds: 5)),
          completes,
        );
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );
  });

  group('robustez de la API antes de inicializar', () {
    test('isLoaded() sobre un id desconocido es false y no lanza', () {
      expect(engine.isLoaded('pad-inexistente'), isFalse);
    });

    test('getPosition() sobre un id desconocido devuelve null', () {
      expect(engine.getPosition('pad-inexistente'), isNull);
    });

    test('stop() sobre un id nunca reproducido no lanza', () {
      expect(() => engine.stop('pad-inexistente'), returnsNormally);
    });

    test('stopAll() sin nada sonando no lanza', () {
      expect(() => engine.stopAll(), returnsNormally);
    });

    test('play() antes de initialize() no lanza', () {
      // Un golpe de pad (o una nota MIDI entrante) puede llegar antes de que
      // termine el arranque del motor. Debe ignorarse, no romper la app.
      expect(
        () => engine.play('pad-1', TriggerMode.oneShot),
        returnsNormally,
      );
    });

    test('los setters de mezcla no lanzan antes de inicializar', () {
      expect(() => engine.setVolume('pad-1', 0.5), returnsNormally);
      expect(() => engine.setPadMute('pad-1', true), returnsNormally);
      expect(() => engine.setPadSolo('pad-1', true), returnsNormally);
      expect(() => engine.setPan('pad-1', -1.0), returnsNormally);
      expect(() => engine.setPitch('pad-1', 1.5), returnsNormally);
      expect(() => engine.setGlobalVolume(0.8), returnsNormally);
    });
  });

  group('dispose', () {
    test('dispose() deja el motor en estado disposed', () async {
      await engine.initialize();
      engine.dispose();
      expect(engine.engineState, AudioEngineState.disposed);
    });

    test('initialize() después de dispose() no revive el motor', () async {
      await engine.initialize();
      engine.dispose();
      await engine.initialize();
      expect(engine.engineState, AudioEngineState.disposed);
    });
  });
}
