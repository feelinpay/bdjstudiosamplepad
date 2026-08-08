import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/metronome_provider.dart';
import '../../domain/tap_tempo.dart';

/// Boton de metronomo para la AppBar: toca para abrir el control (on/off,
/// BPM y Tap-Tempo). El icono se pinta verde cuando esta activo.
class MetronomeButton extends ConsumerWidget {
  const MetronomeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var m = ref.watch(metronomeProvider);
    return IconButton(
      icon: Icon(
        Icons.av_timer,
        color: m.isOn ? Colors.greenAccent : Colors.white,
      ),
      tooltip: 'Metronomo',
      onPressed: () => _open(context, ref),
    );
  }

  void _open(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          var m = ref.watch(metronomeProvider);
          var ctrl = ref.read(metronomeProvider.notifier);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${m.bpm} BPM',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Slider(
                    value: m.bpm.toDouble(),
                    min: TapTempo.minBpm.toDouble(),
                    max: TapTempo.maxBpm.toDouble(),
                    onChanged: (v) => ctrl.setBpm(v.round()),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.touch_app),
                        label: const Text('TAP'),
                        onPressed: ctrl.tap,
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: m.isOn
                              ? Colors.red
                              : Colors.greenAccent,
                          foregroundColor: Colors.black,
                        ),
                        icon: Icon(m.isOn ? Icons.stop : Icons.play_arrow),
                        label: Text(m.isOn ? 'Detener' : 'Iniciar'),
                        onPressed: ctrl.toggle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
