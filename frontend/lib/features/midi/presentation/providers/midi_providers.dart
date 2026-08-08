import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:file_picker/file_picker.dart';
import '../../../macros/presentation/providers/macro_providers.dart';
import '../../../../core/midi/midi_engine_port.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/flutter_midi_engine.dart';
import '../../data/models/midi_mapping_model.dart';
import '../../domain/entities/midi_mapping_entity.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../pad_system/presentation/providers/pad_providers.dart';
import '../../../pad_system/data/models/pad_model.dart';
import '../../../../core/audio/trigger_mode.dart';
import '../../../../core/audio/pad_trigger_resolver.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import 'package:isar/isar.dart';

// Motor MIDI
final midiEngineProvider = Provider<MidiEnginePort>((ref) {
  var engine = FlutterMidiEngine();
  engine.initialize();
  ref.onDispose(() => engine.dispose());
  return engine;
});

// Lista de dispositivos disponibles
final midiDevicesProvider = FutureProvider<List<MidiDevice>>((ref) async {
  var engine = ref.watch(midiEngineProvider);
  return await engine.getDevices();
});

// Dispositivo actualmente conectado
final connectedMidiDeviceProvider = StateProvider<MidiDevice?>((ref) => null);

// Modo MIDI Learn
final midiLearnModeProvider = StateProvider<bool>((ref) => false);
final midiLearnActionProvider = StateProvider<MidiMappingEntity?>(
  (ref) => null,
);

class MidiController {
  final Ref ref;
  // Cache padId -> mapping para feedback MIDI de salida (sin DB en el hot path).
  Map<String, MidiMappingModel>? _feedbackCache;
  bool _isBuildingCache = false;
  StreamSubscription? _midiSub;

  MidiController(this.ref) {
    _listenToMidiData();
  }

  void dispose() {
    _midiSub?.cancel();
    _midiSub = null;
  }

  Future<void> _buildFeedbackCache() async {
    if (_isBuildingCache) return;
    _isBuildingCache = true;
    try {
      var isar = await ref.read(isarProvider.future);
      var all = await isar.midiMappingModels.where().findAll();
      var map = <String, MidiMappingModel>{};
      for (var m in all) {
        if (m.actionType == MidiActionType.triggerPad.name) {
          map[m.actionValue] = m;
        }
      }
      _feedbackCache = map;
    } finally {
      _isBuildingCache = false;
    }
  }

  /// La app como EXTENSION del pad fisico: al disparar un pad desde la app,
  /// envia NoteOn/NoteOff al hardware para que el pad correspondiente se
  /// ilumine y quede sincronizado con la salida de sonido.
  Future<void> sendPadFeedback(String padId, {bool on = true}) async {
    if (_feedbackCache == null) {
      await _buildFeedbackCache();
    }
    var m = _feedbackCache?[padId];
    if (m == null) return;
    ref
        .read(midiEngineProvider)
        .sendMidiData(m.statusByte, m.noteOrCC, on ? 127 : 0);
  }

  void invalidateFeedbackCache() => _feedbackCache = null;

  void _listenToMidiData() {
    var engine = ref.read(midiEngineProvider);
    _midiSub?.cancel();
    _midiSub = engine.onMidiMessageReceived.listen((
      MidiDataReceivedEvent event,
    ) {
      var data = event.message.data;
      if (data.length >= 3) {
        int status = data[0];
        int noteOrCc = data[1];
        int velocityOrValue = data[2];

        // Status 144 to 159 are Note On events
        if (status >= 144 && status <= 159 && velocityOrValue > 0) {
          _handleMidiEvent(noteOrCc, status, velocityOrValue);
        }
        // Status 176 to 191 are Control Change (CC)
        else if (status >= 176 && status <= 191) {
          _handleMidiEvent(noteOrCc, status, velocityOrValue);
        }
        // Status 128 to 143 are Note Off, y un Note On con velocity 0
        // también debe tratarse como Note Off para liberar pads gate/hold.
        else if (status >= 128 && status <= 159) {
          _handleMidiNoteOff(noteOrCc);
        }
      }
    });
  }

  Future<void> _handleMidiEvent(int noteOrCc, int status, int value) async {
    try {
      var isLearning = ref.read(midiLearnModeProvider);
      if (isLearning) {
        var pendingAction = ref.read(midiLearnActionProvider);
        if (pendingAction != null) {
          await _saveMapping(noteOrCc, status, pendingAction);
          ref.read(midiLearnModeProvider.notifier).state = false;
          ref.read(midiLearnActionProvider.notifier).state = null;
        }
      } else {
        await _executeMapping(noteOrCc, value);
      }
    } catch (e) {
      // Captura silenciosa: errores MIDI no deben crashear la app
    }
  }

  /// Libera un pad gate/hold al recibir Note Off o Note On con velocity 0.
  /// Los pads loop/toggle ignoran el Note Off (se detienen con el siguiente Note On).
  Future<void> _handleMidiNoteOff(int noteOrCc) async {
    try {
      var isLearning = ref.read(midiLearnModeProvider);
      if (isLearning) return;
      var isar = await ref.read(isarProvider.future);
      var mappings = await isar.midiMappingModels
          .where()
          .noteOrCCEqualTo(noteOrCc)
          .findAll();
      for (var mapping in mappings) {
        if (mapping.actionType != MidiActionType.triggerPad.name) continue;
        var padId = mapping.actionValue;
        var pageIndex = ref.read(currentPageIndexProvider);
        var pads = ref.read(padPageProvider(pageIndex)).value ?? [];
        try {
          var pad = pads.firstWhere((p) => p.id == padId);
          if (PadTriggerResolver.onUp(pad.playMode) == PadAction.stop) {
            ref.read(padPageProvider(pageIndex).notifier).onPadUp(padId);
          }
        } catch (e) {
          var padIdInt = int.tryParse(padId);
          if (padIdInt != null) {
            var padModel = await isar.padModels.get(padIdInt);
            if (padModel != null) {
              final mode = TriggerMode.values[padModel.triggerModeIndex];
              if (mode == TriggerMode.gate || mode == TriggerMode.hold) {
                ref.read(audioEngineProvider).stop(padId);
              }
            }
          }
        }
      }
    } catch (e) {
      // Captura silenciosa: errores MIDI no deben crashear la app
    }
  }

  Future<void> _saveMapping(
    int note,
    int status,
    MidiMappingEntity action,
  ) async {
    var isar = await ref.read(isarProvider.future);
    var model = MidiMappingModel()
      ..noteOrCC = note
      ..statusByte = status
      ..actionType = action.actionType.name
      ..actionValue = action.actionValue;

    await isar.writeTxn(() async {
      await isar.midiMappingModels.put(model);
    });
    invalidateFeedbackCache();
  }

  Future<void> _executeMapping(int noteOrCc, int value) async {
    var isar = await ref.read(isarProvider.future);
    var mappings = await isar.midiMappingModels
        .where()
        .noteOrCCEqualTo(noteOrCc)
        .findAll();

    for (var mapping in mappings) {
      if (mapping.actionType == MidiActionType.triggerPad.name) {
        // Trigger Pad with Velocity Sensitivity
        var padId = mapping.actionValue;

        // Find the pad to get its parameters
        var pageIndex = ref.read(currentPageIndexProvider);
        var padBankAsync = ref.read(padPageProvider(pageIndex));
        var pads = padBankAsync.value ?? [];

        try {
          var pad = pads.firstWhere((p) => p.id == padId);
          if (pad.sampleId != null && pad.sampleId!.isNotEmpty) {
            ref.read(padVelocityProvider.notifier).state = {
              ...ref.read(padVelocityProvider),
              padId: (value / 127.0).clamp(0.2, 1.0),
            };
            ref.read(padPageProvider(pageIndex).notifier).onPadDown(padId);
          }
        } catch (e) {
          // Pad no encontrado en la página actual, buscarlo en la DB para reproducirlo globalmente
          var padIdInt = int.tryParse(padId);
          if (padIdInt != null) {
            var padModel = await isar.padModels.get(padIdInt);
            if (padModel != null &&
                padModel.samplePath != null &&
                padModel.samplePath!.isNotEmpty) {
              // Asegurar que el audio está cargado antes de reproducirlo
              await ref
                  .read(audioEngineProvider)
                  .loadAudio(padId, padModel.samplePath!);
               ref
                   .read(audioEngineProvider)
                   .play(
                     padId,
                     TriggerMode.values[padModel.triggerModeIndex],
                     pan: padModel.pan,
                     pitch: padModel.pitch,
                     reverse: padModel.reverse,
                     chokeGroup: padModel.chokeGroup,
                     startPoint: Duration(milliseconds: padModel.startPointMs),
                      loopPoint: Duration(milliseconds: padModel.loopPointMs),
                     fadeIn: Duration(milliseconds: padModel.fadeInMs),
                     fadeOut: Duration(milliseconds: padModel.fadeOutMs),
                     endPoint: padModel.endPointMs != null
                         ? Duration(milliseconds: padModel.endPointMs!)
                         : (padModel.loopPointMs > padModel.startPointMs
                             ? Duration(milliseconds: padModel.loopPointMs)
                             : null),
                   );
            }
          }
        }
      } else if (mapping.actionType == MidiActionType.masterFx.name) {
        // Control Master FX via CC
        var fxName = mapping.actionValue;
        var audio = ref.read(audioEngineProvider);
        double normalizedValue = value / 127.0; // 0.0 to 1.0

        if (fxName == 'Limiter') {
          audio.setMasterLimiter(normalizedValue);
        } else if (fxName == 'MasterVolume') {
          audio.setGlobalVolume(normalizedValue);
        }
      } else if (mapping.actionType == MidiActionType.executeMacro.name) {
        // Execute a Macro via MIDI
        var macroId = int.tryParse(mapping.actionValue);
        if (macroId != null) {
          var macrosAsync = ref.read(macroListProvider);
          if (macrosAsync.value != null) {
            var macro = macrosAsync.value!.cast().firstWhere(
              (m) => m.id == macroId,
              orElse: () => null,
            );
            if (macro != null) {
              ref.read(macroExecutorProvider).execute(macro);
            }
          }
        }
      }
    }
  }

  Future<void> connect(MidiDevice device) async {
    var engine = ref.read(midiEngineProvider);
    await engine.connectToDevice(device);
    ref.read(connectedMidiDeviceProvider.notifier).state = device;
  }

  Future<void> disconnect(MidiDevice device) async {
    var engine = ref.read(midiEngineProvider);
    await engine.disconnectDevice(device);
    ref.read(connectedMidiDeviceProvider.notifier).state = null;
  }

  // Perfiles MIDI (Exportar e Importar)
  Future<String?> exportMidiProfile() async {
    var isar = await ref.read(isarProvider.future);
    var mappings = await isar.midiMappingModels.where().findAll();
    List<Map<String, dynamic>> jsonList = mappings
        .map(
          (m) => {
            'noteOrCC': m.noteOrCC,
            'statusByte': m.statusByte,
            'actionType': m.actionType,
            'actionValue': m.actionValue,
          },
        )
        .toList();

    String jsonString = jsonEncode(jsonList);
    String? outputFile = await FilePicker.saveFile(
      dialogTitle: 'Exportar Perfil MIDI',
      fileName: 'mi_perfil.midimap',
      type: FileType.custom,
      allowedExtensions: ['midimap'],
    );

    if (outputFile != null) {
      await File(outputFile).writeAsString(jsonString);
      return outputFile;
    }
    return null;
  }

  Future<bool> importMidiProfile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['midimap'],
    );

    if (result != null && result.files.single.path != null) {
      String jsonString = await File(result.files.single.path!).readAsString();
      List<dynamic> jsonList = jsonDecode(jsonString);

      var isar = await ref.read(isarProvider.future);
      await isar.writeTxn(() async {
        await isar.midiMappingModels.clear(); // Limpiar el perfil anterior
        invalidateFeedbackCache();
        for (var item in jsonList) {
          var model = MidiMappingModel()
            ..noteOrCC = item['noteOrCC']
            ..statusByte = item['statusByte']
            ..actionType = item['actionType']
            ..actionValue = item['actionValue'];
          await isar.midiMappingModels.put(model);
        }
      });
      return true;
    }
    return false;
  }
}

final midiControllerProvider = Provider<MidiController>((ref) {
  final controller = MidiController(ref);
  ref.onDispose(() => controller.dispose());
  return controller;
});
