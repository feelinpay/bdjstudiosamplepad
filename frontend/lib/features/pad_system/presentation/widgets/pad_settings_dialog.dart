import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/audio_engine_port.dart';
import '../../../../core/providers/core_providers.dart';
import '../../domain/entities/pad_entity.dart';
import '../../../../core/audio/trigger_mode.dart';
import '../../../../core/utils/concurrency_shield.dart';
import '../providers/pad_providers.dart';
import '../../../midi/presentation/providers/midi_providers.dart';
import '../../../midi/domain/entities/midi_mapping_entity.dart';
import '../../../editor/presentation/widgets/color_picker_dialog.dart';
import 'waveform_editor_widget.dart';

class PadSettingsDialog extends ConsumerStatefulWidget {
  final PadEntity pad;
  final int pageIndex;

  const PadSettingsDialog({
    super.key,
    required this.pad,
    required this.pageIndex,
  });

  @override
  ConsumerState<PadSettingsDialog> createState() => _PadSettingsDialogState();
}

class _PadSettingsDialogState extends ConsumerState<PadSettingsDialog> {
  late String _label;
  late int _colorHex;
  late TriggerMode _triggerMode;
  late int _chokeGroup;
  late double _pan;
  late double _pitch;
  late double _volume;
  late bool _reverse;
  late int _fadeInMs;
  late int _fadeOutMs;
  late int _startPointMs;
  late int _loopPointMs;
  late final String _previewSoundId;
  late final AudioEnginePort _audioEngine;
  StreamSubscription<String>? _previewFinishedSubscription;
  bool _isPreviewPlaying = false;
  int _previewPositionMs = 0;
  int _previewSessionId = 0;
  Timer? _previewPositionTimer;

  late PadType _padType;
  int? _targetPageIndex;
  int? _targetMacroId;

  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _labelController;

  @override
  void initState() {
    super.initState();
    _label = widget.pad.label;
    _colorHex = widget.pad.colorHex;
    _triggerMode = widget.pad.playMode;
    _chokeGroup = widget.pad.chokeGroup;
    _pan = widget.pad.pan;
    _pitch = widget.pad.pitch;
    _volume = widget.pad.volume;
    _reverse = widget.pad.reverse;
    _fadeInMs = widget.pad.fadeIn.inMilliseconds;
    _fadeOutMs = widget.pad.fadeOut.inMilliseconds;
    _startPointMs = widget.pad.startPoint.inMilliseconds;
    // El manejador "FIN"/loop del editor representa el endPoint persistido
    // (final de la región audible). Inicializarlo desde pad.loopPoint (punto
    // de rebobinado = startPoint) hacía que el handle quedara pegado en el
    // inicio, ocultara el recorte real y sobrescribiera endPoint a null al
    // guardar sin cambios. 0 = duración completa.
    _loopPointMs = widget.pad.endPoint != null
        ? widget.pad.endPoint!.inMilliseconds
        : 0;
    _previewSoundId = 'waveform-preview-${widget.pad.id}';
    _audioEngine = ref.read(audioEngineProvider);
    _preloadPreviewSound();
    _previewFinishedSubscription = _audioEngine.onSoundFinished
        .where((id) => id == _previewSoundId)
        .listen((_) {
          if (mounted && _isPreviewPlaying) {
            // OneShot mode auto-stops when the sound naturally finishes.
            // For Loop mode, onSoundFinished should not fire (the handle
            // stays valid). If it does, treat it as an unexpected stop.
            _stopWaveformPreview();
          }
        });
    _padType = widget.pad.type;
    _targetPageIndex = widget.pad.targetPageIndex;
    _targetMacroId = widget.pad.targetMacroId;
    _labelController = TextEditingController(text: _label);
  }

  @override
  void dispose() {
    _cancelPreview();
    _previewPositionTimer?.cancel();
    _previewFinishedSubscription?.cancel();
    _audioEngine.stop(_previewSoundId, notify: false);
    _scrollController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  /// Cancels all preview resources without touching UI state.
  /// Safe to call from [dispose] where `setState` would throw.
  void _cancelPreview() {
    _previewSessionId++;
    _previewPositionTimer?.cancel();
    _previewPositionTimer = null;
    _audioEngine.stop(_previewSoundId, notify: false);
  }

  void _resetToDefaultAudioSettings() {
    setState(() {
      _triggerMode = TriggerMode.oneShot;
      _pan = 0.0;
      _pitch = 1.0;
      _volume = 1.0;
      _chokeGroup = 0;
      _reverse = false;
      _fadeInMs = 0;
      _fadeOutMs = 0;
      _startPointMs = 0;
      _loopPointMs = 0;
    });
    // Reiniciar la preescucha si está sonando para que el reset se oiga al
    // instante y no quede reproduciendo la región recortada anterior.
    _restartWaveformPreview();
  }

  Future<void> _toggleWaveformPreview() async {
    if (_isPreviewPlaying) {
      _stopWaveformPreview();
      return;
    }
    await _playWaveformPreview();
  }

  /// Precarga el sonido del preview al abrir el diálogo para que el primer
  /// toque en "Escuchar edición" suene de inmediato, sin esperar loadAudio.
  void _preloadPreviewSound() {
    final samplePath = widget.pad.sampleId;
    if (samplePath == null || samplePath.isEmpty) return;
    if (_audioEngine.isLoaded(_previewSoundId)) return;
    _audioEngine.loadAudio(_previewSoundId, samplePath);
  }

  Future<void> _playWaveformPreview() async {
    final samplePath = widget.pad.sampleId;
    if (samplePath == null || samplePath.isEmpty) return;

    // Increment session ID so any stale callbacks from previous sessions
    // are ignored.
    final sessionId = ++_previewSessionId;

    if (!_audioEngine.isLoaded(_previewSoundId)) {
      await _audioEngine.loadAudio(_previewSoundId, samplePath);
    }
    if (!mounted ||
        !_audioEngine.isLoaded(_previewSoundId) ||
        sessionId != _previewSessionId) return;

    final endPoint = _loopPointMs > _startPointMs
        ? Duration(milliseconds: _loopPointMs)
        : null;
    setState(() {
      _isPreviewPlaying = true;
      _previewPositionMs = _startPointMs;
    });
    _audioEngine.play(
      _previewSoundId,
      _triggerMode,
      chokeGroup: _chokeGroup,
      pan: _pan,
      pitch: _pitch,
      volume: _volume,
      reverse: _reverse,
      fadeIn: Duration(milliseconds: _fadeInMs),
      fadeOut: Duration(milliseconds: _fadeOutMs),
      startPoint: Duration(milliseconds: _startPointMs),
      endPoint: endPoint,
      loopPoint: _triggerMode == TriggerMode.loop && endPoint != null
          ? Duration(milliseconds: _startPointMs)
          : Duration.zero,
    );

    // Poll the REAL audio position from the engine — not an independent animation.
    _previewPositionTimer?.cancel();
    _previewPositionTimer =
        Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (sessionId != _previewSessionId || !mounted || !_isPreviewPlaying) {
        return;
      }
      final pos = _audioEngine.getPosition(_previewSoundId);
      if (pos != null) {
        setState(() => _previewPositionMs = pos.inMilliseconds);
      } else {
        // Audio handle no longer valid — auto-stop for all modes.
        _stopWaveformPreview();
      }
    });
  }

  /// Reinicia la preescucha con los parámetros actuales si está sonando,
  /// para reflejar al instante los cambios de edición.
  Future<void> _restartWaveformPreview() async {
    if (!_isPreviewPlaying) return;
    _stopWaveformPreview();
    if (!mounted) return;
    await _playWaveformPreview();
  }

  void _stopWaveformPreview() {
    // Invalidate any pending callbacks from the old session.
    _cancelPreview();
    if (mounted) {
      setState(() {
        _isPreviewPlaying = false;
        _previewPositionMs = 0;
      });
    }
  }

  void _updateStartPoint(int value) {
    setState(() => _startPointMs = value);
    _restartWaveformPreview();
  }

  void _updateLoopPoint(int value) {
    setState(() => _loopPointMs = value);
    _restartWaveformPreview();
  }

  Widget _buildPadTypeBadge() {
    IconData icon;
    String text;
    Color color;
    switch (_padType) {
      case PadType.folder:
        icon = Icons.folder_open_rounded;
        text = 'Carpeta / Enlace a Kit';
        color = Colors.orangeAccent;
        break;
      case PadType.macro:
        // Feature oculta (macros se rediseñan en otra versión): los pads de
        // macro restaurados de un respaldo se presentan como pads vacíos.
        icon = Icons.audiotrack_rounded;
        text = 'Audio / Sample';
        color = Colors.cyanAccent;
        break;
      case PadType.audio:
        icon = Icons.audiotrack_rounded;
        text = 'Audio / Sample';
        color = Colors.cyanAccent;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(120), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white12),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dialog Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ajustes: ${widget.pad.label.isEmpty ? "PAD ${widget.pad.index + 1}" : widget.pad.label}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    tooltip: 'Eliminar Pad',
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 16),

              // Body Content with Gutter-Spaced Scrollbar
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  thickness: 6,
                  radius: const Radius.circular(3),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(
                      right: 18,
                      top: 4,
                      bottom: 8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tipo de Pad (Inmutable / Informativo)
                        const Text(
                          'Tipo de Pad',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        _buildPadTypeBadge(),
                        const SizedBox(height: 16),

                        // Label
                        const Text(
                          'Nombre',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _labelController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Nombre del pad',
                            hintStyle: const TextStyle(color: Colors.white30),
                            filled: true,
                            fillColor: Colors.grey[800],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) => setState(() => _label = val),
                        ),
                        const SizedBox(height: 14),

                        // Color
                        Row(
                          children: [
                            const Text(
                              'Color',
                              style: TextStyle(color: Colors.white70),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => PadColorPicker(
                                    currentColor: _colorHex,
                                    onColorSelected: (color) {
                                      setState(() => _colorHex = color);
                                      ConcurrencyShield.safePop(ctx);
                                    },
                                  ),
                                );
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Color(_colorHex),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white38,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // OPCIONES ESPECÍFICAS SEGÚN EL TIPO DE PAD
                        if (_padType == PadType.folder) ...[
                          const Divider(color: Colors.white24),
                          const SizedBox(height: 14),
                        ],

                        if (_padType == PadType.audio) ...[
                          const Divider(color: Colors.white24),
                          const SizedBox(height: 8),

                          Center(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.cyanAccent,
                                side: const BorderSide(
                                  color: Colors.cyanAccent,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.restore_rounded, size: 18),
                              label: const Text(
                                'Restablecer ajustes a valores predeterminados',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: _resetToDefaultAudioSettings,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Trigger Mode
                          const Text(
                            'Trigger Mode',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: TriggerMode.values.map((mode) {
                              var isSelected = mode == _triggerMode;
                              return ChoiceChip(
                                label: Text(
                                  _triggerModeName(mode),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: Colors.blueAccent,
                                backgroundColor: Colors.grey[800],
                                onSelected: (_) {
                                  setState(() => _triggerMode = mode);
                                  _restartWaveformPreview();
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),

                          // Choke Group
                          const Text(
                            'Choke Group (0 = None)',
                            style: TextStyle(color: Colors.white70),
                          ),
                          Slider(
                            value: _chokeGroup.toDouble(),
                            min: 0,
                            max: 8,
                            divisions: 8,
                            label: _chokeGroup.toString(),
                            activeColor: Colors.blueAccent,
                            onChanged: (val) {
                              setState(() => _chokeGroup = val.toInt());
                              _restartWaveformPreview();
                            },
                          ),
                          const SizedBox(height: 10),

                          // Pan
                          const Text(
                            'Pan (L - R)',
                            style: TextStyle(color: Colors.white70),
                          ),
                          Slider(
                            value: _pan,
                            min: -1.0,
                            max: 1.0,
                            divisions: 20,
                            label: _pan.toStringAsFixed(2),
                            activeColor: Colors.greenAccent,
                            onChanged: (val) {
                              setState(() => _pan = val);
                              _restartWaveformPreview();
                            },
                          ),
                          const SizedBox(height: 10),

                          // Pitch
                          const Text(
                            'Pitch / Speed',
                            style: TextStyle(color: Colors.white70),
                          ),
                          Slider(
                            value: _pitch,
                            min: 0.5,
                            max: 2.0,
                            divisions: 15,
                            label: _pitch.toStringAsFixed(2),
                            activeColor: Colors.orangeAccent,
                            onChanged: (val) {
                              setState(() => _pitch = val);
                              _restartWaveformPreview();
                            },
                          ),
                          const SizedBox(height: 10),

                          // Volume
                          const Text(
                            'Volume',
                            style: TextStyle(color: Colors.white70),
                          ),
                          Slider(
                            value: _volume,
                            min: 0.0,
                            max: 2.0,
                            divisions: 20,
                            label: _volume.toStringAsFixed(2),
                            activeColor: Colors.tealAccent,
                            onChanged: (val) {
                              setState(() => _volume = val);
                              _audioEngine.setVolume(_previewSoundId, val);
                            },
                          ),
                          const SizedBox(height: 10),

                          // Reverse
                          SwitchListTile(
                            title: const Text(
                              'Reverse',
                              style: TextStyle(color: Colors.white70),
                            ),
                            value: _reverse,
                            activeThumbColor: Colors.purpleAccent,
                            onChanged: (val) {
                              setState(() => _reverse = val);
                              _restartWaveformPreview();
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 8),

                          // Fade In
                          const Text(
                            'Fade In (ms)',
                            style: TextStyle(color: Colors.white70),
                          ),
                          Slider(
                            value: _fadeInMs.toDouble(),
                            min: 0,
                            max: 2000,
                            label: '$_fadeInMs ms',
                            activeColor: Colors.pinkAccent,
                            onChanged: (val) {
                              setState(() => _fadeInMs = val.toInt());
                              _restartWaveformPreview();
                            },
                          ),

                          // Fade Out
                          const Text(
                            'Fade Out (ms)',
                            style: TextStyle(color: Colors.white70),
                          ),
                          Slider(
                            value: _fadeOutMs.toDouble(),
                            min: 0,
                            max: 2000,
                            label: '$_fadeOutMs ms',
                            activeColor: Colors.pinkAccent,
                            onChanged: (val) {
                              setState(() => _fadeOutMs = val.toInt());
                              _restartWaveformPreview();
                            },
                          ),

                          const Text(
                            'Editor de Onda (Start / Loop Point)',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          if (widget.pad.sampleId != null &&
                              widget.pad.sampleId!.isNotEmpty)
                            WaveformEditorWidget(
                              audioPath: widget.pad.sampleId!,
                              startPointMs: _startPointMs,
                              loopPointMs: _loopPointMs,
                              isPreviewPlaying: _isPreviewPlaying,
                              previewPositionMs: _previewPositionMs,
                              previewSpeed: _pitch,
                              previewReverse: _reverse,
                              onTogglePreview: _toggleWaveformPreview,
                              onStartPointChanged: _updateStartPoint,
                              onLoopPointChanged: _updateLoopPoint,
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Sin audio cargado.',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                        ],

                        const Divider(color: Colors.white24),

                        // MIDI Learn
                        ElevatedButton.icon(
                          onPressed: () {
                            ref.read(midiLearnModeProvider.notifier).state =
                                true;
                            ref
                                .read(midiLearnActionProvider.notifier)
                                .state = MidiMappingEntity(
                              id: widget.pad.id,
                              noteOrCC: 0,
                              statusByte: 0,
                              actionType: MidiActionType.triggerPad,
                              actionValue: widget.pad.id,
                            );

                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF1E1E1E),
                                title: const Text(
                                  'MIDI Learn',
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: Consumer(
                                  builder: (ctx, ref, child) {
                                    var isLearning = ref.watch(
                                      midiLearnModeProvider,
                                    );
                                    if (!isLearning) {
                                      var nav = Navigator.of(ctx);
                                      Future.microtask(nav.pop);
                                    }
                                    return const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 16),
                                        Text(
                                          'Presiona una tecla/botón en tu controlador MIDI...',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      ref
                                              .read(
                                                midiLearnModeProvider.notifier,
                                              )
                                              .state =
                                          false;
                                      ConcurrencyShield.safePop(ctx);
                                    },
                                    child: const Text(
                                      'Cancelar',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.piano),
                          label: const Text('MIDI Learn'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.withAlpha(77),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Divider(color: Colors.white24, height: 16),
              // Dialog Footer Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => ConcurrencyShield.safePop(context),
                    child: const Text(
                      'CANCELAR',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      if (!ConcurrencyShield.throttle(
                        'save_pad_${widget.pad.id}',
                        cooldown: const Duration(milliseconds: 500),
                      ))
                        return;
                      await ref
                          .read(padPageProvider(widget.pageIndex).notifier)
                          .updatePadVisual(
                            int.parse(widget.pad.id),
                            colorHex: _colorHex,
                            label: _label,
                            triggerModeIndex: _triggerMode.index,
                            backgroundImagePath: null,
                            padTypeIndex: _padType.index,
                            targetPageIndex: _targetPageIndex,
                            targetMacroId: _targetMacroId,
                          );
                      if (_padType == PadType.audio) {
                        await ref
                            .read(padPageProvider(widget.pageIndex).notifier)
                            .updatePadAudioSettings(
                              int.parse(widget.pad.id),
                              chokeGroup: _chokeGroup,
                              pan: _pan,
                              pitch: _pitch,
                              volume: _volume,
                              reverse: _reverse,
                              fadeInMs: _fadeInMs,
                              fadeOutMs: _fadeOutMs,
                              startPointMs: _startPointMs,
                              endPointMs: _loopPointMs > _startPointMs
                                  ? _loopPointMs
                                  : null,
                              loopPointMs: _startPointMs,
                            );
                      }
                      if (context.mounted) {
                        ConcurrencyShield.safePop(context);
                      }
                    },
                    child: const Text(
                      'GUARDAR',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _triggerModeName(TriggerMode mode) {
    switch (mode) {
      case TriggerMode.oneShot:
        return 'One Shot';
      case TriggerMode.gate:
        return 'Gate';
      case TriggerMode.loop:
        return 'Loop';
      case TriggerMode.toggle:
        return 'Toggle';
      case TriggerMode.hold:
        return 'Hold';
    }
  }

  void _confirmDelete(BuildContext context) {
    var isFolder = widget.pad.type == PadType.folder;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Eliminar Pad',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          isFolder
              ? '¿Estás seguro de eliminar esta carpeta?\n\nAdvertencia: El kit asociado quedará inaccesible y perderás el acceso a los samples de su interior.'
              : '¿Estás seguro de eliminar este pad?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => ConcurrencyShield.safePop(ctx),
            child: const Text(
              'CANCELAR',
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (!ConcurrencyShield.throttle(
                'confirm_delete_${widget.pad.id}',
                cooldown: const Duration(milliseconds: 500),
              ))
                return;
              ConcurrencyShield.safePop(ctx); // Cierra el confirm
              ConcurrencyShield.safePop(context); // Cierra el settings
              await ref
                  .read(padPageProvider(widget.pageIndex).notifier)
                  .deletePad(widget.pad.id);
            },
            child: const Text(
              'ELIMINAR',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
