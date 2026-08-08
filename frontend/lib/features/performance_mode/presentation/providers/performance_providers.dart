import 'package:flutter_riverpod/legacy.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import '../../../../core/services/background_audio_service.dart';

final performanceModeProvider =
    StateNotifierProvider<PerformanceModeNotifier, bool>((ref) {
      return PerformanceModeNotifier();
    });

class PerformanceModeNotifier extends StateNotifier<bool> {
  PerformanceModeNotifier() : super(false);

  void toggle() {
    state = !state;
    _updateSystemUI();
  }

  void enable() {
    state = true;
    _updateSystemUI();
  }

  void disable() {
    state = false;
    _updateSystemUI();
  }

  void _updateSystemUI() {
    if (state) {
      WakelockPlus.enable();
      unawaited(BackgroundAudioService.setEnabled(true));
      if (Platform.isAndroid || Platform.isIOS) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    } else {
      WakelockPlus.disable();
      unawaited(BackgroundAudioService.setEnabled(false));
      if (Platform.isAndroid || Platform.isIOS) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    }
  }
}
