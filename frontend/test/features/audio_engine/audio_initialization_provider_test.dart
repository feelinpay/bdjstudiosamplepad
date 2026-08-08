import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bdj_studio_sample_pad/core/providers/audio_providers.dart';
import 'package:bdj_studio_sample_pad/core/audio/audio_initialization_result.dart';
import 'package:bdj_studio_sample_pad/core/audio/audio_engine_state.dart';

void main() {
  // Valida el corazón del gate de audio (ALTO #5): el provider derivado refleja
  // el estado del motor SOLO a través de la cache observable que el bootstrap
  // inyecta y el overlay refresca tras un retry.
  group('audioInitializationProvider', () {
    test('exposes initializing while the bootstrap has not injected the result', () {
      final container = ProviderContainer(overrides: [
        audioInitializationCacheProvider.overrideWith((ref) => null),
      ]);
      addTearDown(container.dispose);

      expect(
        container.read(audioInitializationProvider).state,
        AudioEngineState.initializing,
      );
      expect(container.read(isAudioReadyProvider), isFalse);
    });

    test('reflects ready when the bootstrap injects a ready result', () {
      final container = ProviderContainer(overrides: [
        audioInitializationCacheProvider.overrideWith(
          (ref) => const AudioInitializationResult.ready(devices: []),
        ),
      ]);
      addTearDown(container.dispose);

      expect(
        container.read(audioInitializationProvider).state,
        AudioEngineState.ready,
      );
      expect(container.read(isAudioReadyProvider), isTrue);
    });

    test('reflects noDevice/error so the overlay shows a retry button', () {
      final container = ProviderContainer(overrides: [
        audioInitializationCacheProvider.overrideWith(
          (ref) => const AudioInitializationResult.error(userMessage: 'boom'),
        ),
      ]);
      addTearDown(container.dispose);

      expect(
        container.read(audioInitializationProvider).state,
        AudioEngineState.error,
      );
      expect(container.read(isAudioReadyProvider), isFalse);
    });

    test('reactively updates when the cache is overwritten (retry semantics)', () {
      final container = ProviderContainer(overrides: [
        audioInitializationCacheProvider.overrideWith((ref) => null),
      ]);
      addTearDown(container.dispose);

      expect(
        container.read(audioInitializationProvider).state,
        AudioEngineState.initializing,
      );

      // El helper retryAudioInitialization escribe directamente en la cache;
      // verificamos que el provider derivado reacciona a ese set.
      container.read(audioInitializationCacheProvider.notifier).state =
          const AudioInitializationResult.ready(devices: []);
      container.refresh(audioInitializationProvider);

      expect(
        container.read(audioInitializationProvider).state,
        AudioEngineState.ready,
      );
      expect(container.read(isAudioReadyProvider), isTrue);
    });
  });
}
