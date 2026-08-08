import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../audio/audio_engine_port.dart';

final audioEngineProvider = Provider<AudioEnginePort>((ref) {
  throw UnimplementedError(
    'AudioEngine no inicializado. Debe ser sobreescrito en ProviderScope.',
  );
});
