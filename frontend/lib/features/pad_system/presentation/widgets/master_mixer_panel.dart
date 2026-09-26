import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../settings/data/services/mixer_settings_service.dart';
import '../../../../core/audio/audio_engine_port.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/ui_providers.dart';
import '../../../midi/presentation/providers/midi_providers.dart';
import '../../../midi/domain/entities/midi_mapping_entity.dart';
import '../../../../core/widgets/app_snack.dart';

class MasterMixerPanel extends ConsumerStatefulWidget {
  const MasterMixerPanel({super.key});

  @override
  ConsumerState<MasterMixerPanel> createState() => _MasterMixerPanelState();
}

class _MasterMixerPanelState extends ConsumerState<MasterMixerPanel>
    with SingleTickerProviderStateMixin {
  double _reverb = 0.0;
  double _delay = 0.0;
  double _flanger = 0.0;
  double _distortion = 0.0;
  double _limiter = 0.0;

  double _eqLow = 0.0;
  double _eqMid = 0.0;
  double _eqHigh = 0.0;

  double _leftLevel = 0.0;
  double _rightLevel = 0.0;
  late Ticker _ticker;
  late final AudioEnginePort _engine;

  @override
  void initState() {
    super.initState();
    _engine = ref.read(audioEngineProvider)..acquireVisualization();
    _ticker = createTicker(_onTick);
    _ticker.start();
    _loadMixerSettings();
  }

  void _loadMixerSettings() {
    final service = ref.read(mixerSettingsServiceProvider);
    final settings = service.load();
    ref.read(masterVolumeProvider.notifier).state = settings.masterVolume;
    setState(() {
      _reverb = settings.reverb;
      _delay = settings.delay;
      _flanger = settings.flanger;
      _distortion = settings.distortion;
      _limiter = settings.limiter;
      _eqLow = settings.eqLow;
      _eqMid = settings.eqMid;
      _eqHigh = settings.eqHigh;
    });

    final engine = ref.read(audioEngineProvider);
    engine.setGlobalVolume(settings.masterVolume);
    engine.setMasterReverb(_reverb);
    engine.setMasterDelay(_delay);
    engine.setMasterFlanger(_flanger);
    engine.setMasterDistortion(_distortion);
    engine.setMasterLimiter(_limiter);
    engine.setMasterEQ(lowGain: _eqLow, midGain: _eqMid, highGain: _eqHigh);
  }

  MixerSettings _currentSettings() {
    return MixerSettings(
      masterVolume: ref.read(masterVolumeProvider),
      reverb: _reverb,
      delay: _delay,
      flanger: _flanger,
      distortion: _distortion,
      limiter: _limiter,
      eqLow: _eqLow,
      eqMid: _eqMid,
      eqHigh: _eqHigh,
    );
  }

  void _persistSettings() {
    ref.read(mixerSettingsServiceProvider).save(_currentSettings());
  }

  void _resetMixer() async {
    ref.read(masterVolumeProvider.notifier).state = 1.0;
    setState(() {
      _reverb = 0.0;
      _delay = 0.0;
      _flanger = 0.0;
      _distortion = 0.0;
      _limiter = 0.0;
      _eqLow = 0.0;
      _eqMid = 0.0;
      _eqHigh = 0.0;
    });
    var engine = ref.read(audioEngineProvider);
    engine.setGlobalVolume(1.0);
    engine.setMasterReverb(0.0);
    engine.setMasterDelay(0.0);
    engine.setMasterFlanger(0.0);
    engine.setMasterDistortion(0.0);
    engine.setMasterLimiter(0.0);
    engine.setMasterEQ(lowGain: 0.0, midGain: 0.0, highGain: 0.0);
    await ref.read(mixerSettingsServiceProvider).save(const MixerSettings());
    if (mounted) {
      AppSnack.show(
        context,
        'Master Mixer restablecido',
        duration: const Duration(seconds: 2),
      );
    }
  }

  void _onTick(Duration elapsed) {
    var wave = _engine.getAudioWave();

    if (wave != null && wave.length >= 2) {
      double leftPeak = 0.0;
      double rightPeak = 0.0;
      for (int i = 0; i < wave.length; i += 2) {
        if (i + 1 < wave.length) {
          leftPeak = max(leftPeak, wave[i].abs());
          rightPeak = max(rightPeak, wave[i + 1].abs());
        }
      }

      double nextLeft = max(leftPeak, _leftLevel * 0.85);
      double nextRight = max(rightPeak, _rightLevel * 0.85);

      if ((nextLeft - _leftLevel).abs() > 0.01 ||
          (nextRight - _rightLevel).abs() > 0.01) {
        setState(() {
          _leftLevel = nextLeft;
          _rightLevel = nextRight;
        });
      }
    } else {
      if (_leftLevel > 0.01 || _rightLevel > 0.01) {
        double nextLeft = _leftLevel * 0.85;
        double nextRight = _rightLevel * 0.85;
        if (nextLeft < 0.01) nextLeft = 0.0;
        if (nextRight < 0.01) nextRight = 0.0;
        setState(() {
          _leftLevel = nextLeft;
          _rightLevel = nextRight;
        });
      }
    }
  }

  @override
  void dispose() {
    _engine.releaseVisualization();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = screenWidth < 360
        ? screenWidth * 0.75
        : (screenWidth < 600 ? screenWidth * 0.65 : 300.0);
    return Container(
      width: panelWidth,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: const Border(left: BorderSide(color: Colors.white24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.black26,
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'MASTER MIXER',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orangeAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: const Text(
                    'RESET',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _resetMixer,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildVuMeterBar('L', _leftLevel),
                const SizedBox(width: 8),
                _buildVuMeterBar('R', _rightLevel),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _buildKnob(
                  label: 'VOLUME',
                  value: ref.watch(masterVolumeProvider),
                  min: 0.0,
                  max: 2.0,
                  color: Colors.blueAccent,
                  midiActionValue: 'MasterVolume',
                  onChanged: (val) {
                    ref.read(masterVolumeProvider.notifier).state = val;
                    ref.read(audioEngineProvider).setGlobalVolume(val);
                    _persistSettings();
                  },
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const SizedBox(height: 16),
                const Text(
                  'MASTER EQ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildFullEqSlider(
                  label: 'LOW (Bajos)',
                  value: _eqLow,
                  color: Colors.blueAccent,
                  onChanged: (val) {
                    setState(() => _eqLow = val);
                    ref
                        .read(audioEngineProvider)
                        .setMasterEQ(
                          lowGain: _eqLow,
                          midGain: _eqMid,
                          highGain: _eqHigh,
                        );
                    _persistSettings();
                  },
                ),
                const SizedBox(height: 12),
                _buildFullEqSlider(
                  label: 'MID (Medios)',
                  value: _eqMid,
                  color: Colors.lightBlueAccent,
                  onChanged: (val) {
                    setState(() => _eqMid = val);
                    ref
                        .read(audioEngineProvider)
                        .setMasterEQ(
                          lowGain: _eqLow,
                          midGain: _eqMid,
                          highGain: _eqHigh,
                        );
                    _persistSettings();
                  },
                ),
                const SizedBox(height: 12),
                _buildFullEqSlider(
                  label: 'HIGH (Agudos)',
                  value: _eqHigh,
                  color: Colors.cyanAccent,
                  onChanged: (val) {
                    setState(() => _eqHigh = val);
                    ref
                        .read(audioEngineProvider)
                        .setMasterEQ(
                          lowGain: _eqLow,
                          midGain: _eqMid,
                          highGain: _eqHigh,
                        );
                    _persistSettings();
                  },
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const SizedBox(height: 16),
                const Text(
                  'MASTER FX',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildKnob(
                  label: 'REVERB',
                  value: _reverb,
                  min: 0.0,
                  max: 1.0,
                  color: Colors.purpleAccent,
                  midiActionValue: 'Reverb',
                  onChanged: (val) {
                    setState(() => _reverb = val);
                    ref.read(audioEngineProvider).setMasterReverb(val);
                    _persistSettings();
                  },
                ),
                _buildKnob(
                  label: 'DELAY',
                  value: _delay,
                  min: 0.0,
                  max: 1.0,
                  color: Colors.cyanAccent,
                  midiActionValue: 'Delay',
                  onChanged: (val) {
                    setState(() => _delay = val);
                    ref.read(audioEngineProvider).setMasterDelay(val);
                    _persistSettings();
                  },
                ),
                _buildKnob(
                  label: 'FLANGER',
                  value: _flanger,
                  min: 0.0,
                  max: 1.0,
                  color: Colors.pinkAccent,
                  midiActionValue: 'Flanger',
                  onChanged: (val) {
                    setState(() => _flanger = val);
                    ref.read(audioEngineProvider).setMasterFlanger(val);
                    _persistSettings();
                  },
                ),
                _buildKnob(
                  label: 'LOFI DISTORTION',
                  value: _distortion,
                  min: 0.0,
                  max: 1.0,
                  color: Colors.orangeAccent,
                  midiActionValue: 'Distortion',
                  onChanged: (val) {
                    setState(() => _distortion = val);
                    ref.read(audioEngineProvider).setMasterDistortion(val);
                    _persistSettings();
                  },
                ),
                _buildKnob(
                  label: 'MASTER LIMITER',
                  value: _limiter,
                  min: 0.0,
                  max: 1.0,
                  color: Colors.redAccent,
                  midiActionValue: 'Limiter',
                  onChanged: (val) {
                    setState(() => _limiter = val);
                    ref.read(audioEngineProvider).setMasterLimiter(val);
                    _persistSettings();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVuMeterBar(String label, double level) {
    int blocks = 20;
    int activeBlocks = (level * blocks).round().clamp(0, blocks);

    return Column(
      children: [
        Container(
          width: 12,
          height: 122,
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: List.generate(blocks, (index) {
              int blockIndex = blocks - 1 - index;
              bool isActive = blockIndex < activeBlocks;
              Color color = Colors.green;
              if (blockIndex >= 14) color = Colors.yellow;
              if (blockIndex >= 18) color = Colors.red;

              return Container(
                height: 4,
                margin: const EdgeInsets.only(bottom: 2),
                color: isActive ? color : color.withValues(alpha: 0.1),
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildFullEqSlider({
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                '${value > 0 ? "+" : ""}${value.toStringAsFixed(2)} dB',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            activeTrackColor: color,
            inactiveTrackColor: Colors.white10,
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
          ),
          child: Slider(
            value: value,
            min: -1.0,
            max: 1.0,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildKnob({
    required String label,
    required double value,
    required double min,
    required double max,
    required Color color,
    required ValueChanged<double> onChanged,
    String? midiActionValue,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            if (midiActionValue != null)
              IconButton(
                icon: const Icon(Icons.piano, size: 14, color: Colors.white54),
                onPressed: () {
                  ref.read(midiLearnModeProvider.notifier).state = true;
                  ref
                      .read(midiLearnActionProvider.notifier)
                      .state = MidiMappingEntity(
                    id: 'fx_$midiActionValue',
                    noteOrCC: 0,
                    statusByte: 0,
                    actionType: MidiActionType.masterFx,
                    actionValue: midiActionValue,
                  );
                  AppSnack.show(
                    context,
                    'Mueve el Knob/Fader MIDI para $label...',
                    duration: const Duration(seconds: 4),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: color,
            inactiveTrackColor: Colors.white12,
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.2),
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
        Text(
          value.toStringAsFixed(2),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}
