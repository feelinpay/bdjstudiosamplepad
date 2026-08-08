import 'package:flutter_midi_command/flutter_midi_command.dart';

abstract class MidiEnginePort {
  Stream<MidiSetupChange> get onMidiSetupChanged;
  Stream<MidiDataReceivedEvent> get onMidiMessageReceived;

  Future<void> initialize();
  Future<List<MidiDevice>> getDevices();
  Future<void> connectToDevice(MidiDevice device);
  Future<void> disconnectDevice(MidiDevice device);
  void sendMidiData(int status, int data1, int data2);
  void dispose();
}
