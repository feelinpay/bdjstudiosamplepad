import 'dart:io';

import 'package:flutter/services.dart';

/// Solicita prioridad de foreground en Android mientras el DJ usa el modo
/// performance. En los demás sistemas el audio nativo gestiona su ciclo de
/// vida y esta llamada es un no-op.
class BackgroundAudioService {
  static const _channel = MethodChannel('bdj_studio/background_audio');

  static Future<void> setEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>(enabled ? 'start' : 'stop');
    } on MissingPluginException {
      // Builds antiguos siguen siendo funcionales sin el servicio nativo.
    }
  }
}
