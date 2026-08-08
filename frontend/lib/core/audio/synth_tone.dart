import 'dart:math' as math;
import 'dart:typed_data';

/// Genera tonos sintetizados en memoria (formato WAV PCM 16-bit mono),
/// sin depender de ningún archivo de sample.
///
/// Se usa en el onboarding (Fase 12) para el momento "toca un pad -> suena"
/// sin incluir samples en la app: el sonido se genera en runtime.
class SynthTone {
  const SynthTone._();

  /// Frecuencias sugeridas (escala pentatónica) para dar variedad agradable
  /// a los pads del onboarding sin sonar disonante.
  static const List<double> pentatonic = [
    261.63, // C4
    293.66, // D4
    329.63, // E4
    392.00, // G4
    440.00, // A4
    523.25, // C5
    587.33, // D5
    659.25, // E5
  ];

  /// Devuelve la frecuencia para un índice de pad (envuelve la escala).
  static double frequencyForPad(int padIndex) =>
      pentatonic[padIndex % pentatonic.length];

  /// Genera un WAV (bytes) con un tono senoidal.
  ///
  /// - [frequency]: Hz.
  /// - [durationMs]: duración en milisegundos.
  /// - [sampleRate]: por defecto 44100.
  /// - [volume]: 0.0 a 1.0.
  /// Aplica un fade in/out corto para evitar clicks.
  static Uint8List sineWav({
    required double frequency,
    int durationMs = 220,
    int sampleRate = 44100,
    double volume = 0.6,
  }) {
    var totalSamples = (sampleRate * durationMs / 1000).round();
    var fadeSamples = math.min(sampleRate ~/ 200, totalSamples ~/ 2); // ~5ms

    var data = ByteData(totalSamples * 2); // 16-bit mono
    for (var i = 0; i < totalSamples; i++) {
      var env = 1.0;
      if (i < fadeSamples) {
        env = i / fadeSamples;
      } else if (i > totalSamples - fadeSamples) {
        env = (totalSamples - i) / fadeSamples;
      }
      var sample =
          math.sin(2 * math.pi * frequency * i / sampleRate) * volume * env;
      var intSample = (sample * 32767).clamp(-32768, 32767).toInt();
      data.setInt16(i * 2, intSample, Endian.little);
    }

    return _wrapWav(data.buffer.asUint8List(), sampleRate);
  }

  /// Envuelve datos PCM 16-bit mono en un contenedor WAV válido.
  static Uint8List _wrapWav(Uint8List pcm, int sampleRate) {
    const channels = 1;
    const bitsPerSample = 16;
    var byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    const blockAlign = channels * bitsPerSample ~/ 8;
    var dataSize = pcm.length;
    var fileSize = 44 + dataSize;

    var out = BytesBuilder();
    void writeString(String s) => out.add(s.codeUnits);
    void writeUint32(int v) {
      var b = ByteData(4)..setUint32(0, v, Endian.little);
      out.add(b.buffer.asUint8List());
    }

    void writeUint16(int v) {
      var b = ByteData(2)..setUint16(0, v, Endian.little);
      out.add(b.buffer.asUint8List());
    }

    // RIFF header
    writeString('RIFF');
    writeUint32(fileSize - 8);
    writeString('WAVE');
    // fmt chunk
    writeString('fmt ');
    writeUint32(16);
    writeUint16(1); // PCM
    writeUint16(channels);
    writeUint32(sampleRate);
    writeUint32(byteRate);
    writeUint16(blockAlign);
    writeUint16(bitsPerSample);
    // data chunk
    writeString('data');
    writeUint32(dataSize);
    out.add(pcm);

    return out.toBytes();
  }
}
