import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:bdj_studio_sample_pad/core/midi/midi_engine_port.dart';
import 'package:bdj_studio_sample_pad/features/midi/presentation/providers/midi_providers.dart';

/// Controller MIDI falso que registra cada llamada a [sendPadFeedback] en vez
/// de hablar con hardware. Reemplaza a `midiControllerProvider` en tests de
/// pads (que envían feedback de iluminación al golpear/detener).
class FakeMidiController extends MidiController {
  FakeMidiController(super.ref);

  /// (padId, on) — una entrada por cada sendPadFeedback.
  final List<(String, bool)> feedbackCalls = [];

  @override
  Future<void> sendPadFeedback(String padId, {bool on = true}) async {
    feedbackCalls.add((padId, on));
  }
}

/// Motor MIDI mudo para que el constructor de [MidiController] pueda suscribirse
/// sin tocar plugins nativos.
class FakeMidiEngine implements MidiEnginePort {
  @override
  final Stream<MidiSetupChange> onMidiSetupChanged =
      const Stream<MidiSetupChange>.empty();

  @override
  final Stream<MidiDataReceivedEvent> onMidiMessageReceived =
      const Stream<MidiDataReceivedEvent>.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<List<MidiDevice>> getDevices() async => [];

  @override
  Future<void> connectToDevice(MidiDevice device) async {}

  @override
  Future<void> disconnectDevice(MidiDevice device) async {}

  @override
  void sendMidiData(int status, int data1, int data2) {}

  @override
  void dispose() {}
}
