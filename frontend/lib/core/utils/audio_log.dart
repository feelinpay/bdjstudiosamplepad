import 'package:flutter/foundation.dart';

class AudioLog {
  static const bool verbose = bool.fromEnvironment('BDJ_AUDIO_VERBOSE', defaultValue: false);

  static void log(String message) {
    if (verbose) {
      debugPrint(message);
    }
  }
}
