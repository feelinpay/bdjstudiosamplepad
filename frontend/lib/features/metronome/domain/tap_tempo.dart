/// Cálculo puro de BPM a partir de golpes (Tap-Tempo). Sin dependencias,
/// para poder testearlo de forma determinista.
class TapTempo {
  final List<DateTime> _taps = [];

  /// Ventana máxima entre golpes; si pasa más, se reinicia la medición.
  static const _resetGap = Duration(seconds: 2);
  static const int minBpm = 40;
  static const int maxBpm = 300;

  /// Registra un golpe y devuelve el BPM estimado (o null si aún no hay 2).
  int? tap(DateTime now) {
    if (_taps.isNotEmpty && now.difference(_taps.last) > _resetGap) {
      _taps.clear();
    }
    _taps.add(now);
    if (_taps.length > 6) _taps.removeAt(0);
    return bpm;
  }

  /// BPM promedio de los intervalos actuales (null si hay menos de 2 golpes).
  int? get bpm {
    if (_taps.length < 2) return null;
    var totalMs = 0;
    for (var i = 1; i < _taps.length; i++) {
      totalMs += _taps[i].difference(_taps[i - 1]).inMilliseconds;
    }
    var avgMs = totalMs / (_taps.length - 1);
    if (avgMs <= 0) return null;
    var value = (60000 / avgMs).round();
    return value.clamp(minBpm, maxBpm);
  }

  void reset() => _taps.clear();
}
