import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import '../../../core/midi/midi_engine_port.dart';

class FlutterMidiEngine implements MidiEnginePort {
  final MidiCommand _midiCommand = MidiCommand();
  StreamSubscription? _setupSub;

  @override
  Stream<MidiSetupChange> get onMidiSetupChanged =>
      _midiCommand.onMidiSetupChanged!;

  @override
  Stream<MidiDataReceivedEvent> get onMidiMessageReceived =>
      _midiCommand.onMidiDataReceived!;

  @override
  Future<void> initialize() async {
    _setupSub = _midiCommand.onMidiSetupChanged?.listen((data) {
      debugPrint("MIDI Setup Changed: $data");
    });
  }

  @override
  Future<List<MidiDevice>> getDevices() async {
    var devices = await _midiCommand.devices;
    if (devices == null) return [];
    // Excluir el sintetizador MIDI integrado de Windows ("Microsoft GS
    // Wavetable Synth"): no es hardware real conectado por el usuario.
    return devices
        .where((d) => !d.name.toLowerCase().contains('wavetable'))
        .toList();
  }

  @override
  Future<void> connectToDevice(MidiDevice device) async {
    _midiCommand.connectToDevice(device);
  }

  @override
  Future<void> disconnectDevice(MidiDevice device) async {
    _midiCommand.disconnectDevice(device);
  }

  @override
  void sendMidiData(int status, int data1, int data2) {
    _midiCommand.sendData(Uint8List.fromList([status, data1, data2]));
  }

  @override
  void dispose() {
    _setupSub?.cancel();
    _midiCommand.teardown();
  }
}
