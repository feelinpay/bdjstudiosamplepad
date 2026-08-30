import 'dart:io';

import 'package:flutter/foundation.dart';
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
    } on PlatformException catch (error) {
      // Android puede rechazar el arranque del servicio en primer plano (por
      // ejemplo si considera que la app no esta realmente en primer plano).
      // Se invoca sin await desde el modo performance: si la excepcion escapa
      // queda como error asincrono no capturado. El modo performance debe
      // seguir funcionando aunque el sistema niegue la prioridad extra.
      final action = enabled ? 'iniciarse' : 'detenerse';
      debugPrint(
        '[BackgroundAudio] El servicio en primer plano no pudo $action: '
        '${error.code} ${error.message}',
      );
    }
  }
}
