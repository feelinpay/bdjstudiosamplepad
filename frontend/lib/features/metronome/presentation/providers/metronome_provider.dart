import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/audio/synth_tone.dart';
import '../../domain/tap_tempo.dart';

class MetronomeState {
  final bool isOn;
  final int bpm;
  const MetronomeState({this.isOn = false, this.bpm = 120});

  MetronomeState copyWith({bool? isOn, int? bpm}) =>
      MetronomeState(isOn: isOn ?? this.isOn, bpm: bpm ?? this.bpm);
}

/// Metronomo: reproduce un click sintetizado al pulso indicado (sin samples).
/// Se sincroniza con el motor de audio existente.
class MetronomeController extends StateNotifier<MetronomeState> {
  final Ref ref;
  final TapTempo _tapTempo = TapTempo();
  Timer? _timer;

  MetronomeController(this.ref) : super(const MetronomeState());

  void toggle() => state.isOn ? stop() : start();

  void start() {
    state = state.copyWith(isOn: true);
    _schedule();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(isOn: false);
  }

  void setBpm(int bpm) {
    state = state.copyWith(bpm: bpm.clamp(TapTempo.minBpm, TapTempo.maxBpm));
    if (state.isOn) _schedule();
  }

  /// Registra un golpe de Tap-Tempo y ajusta el BPM.
  void tap() {
    var bpm = _tapTempo.tap(DateTime.now());
    if (bpm != null) setBpm(bpm);
  }

  void _schedule() {
    _timer?.cancel();
    var intervalMs = (60000 / state.bpm).round();
    _timer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _click(),
    );
    _click();
  }

  void _click() {
    // Click corto y agudo generado en runtime.
    ref
        .read(audioEngineProvider)
        .playSynthTone(
          SynthTone.sineWav(frequency: 1200, durationMs: 40, volume: 0.5),
        );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final metronomeProvider =
    StateNotifierProvider<MetronomeController, MetronomeState>(
      (ref) => MetronomeController(ref),
    );
