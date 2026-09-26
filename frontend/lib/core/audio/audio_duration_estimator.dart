import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

/// Lee y estima de forma ligera la duración decodificada de un archivo de audio
/// leyendo únicamente la cabecera (≤ 64 KB) sin decodificar todo el contenido en memoria.
class AudioDurationEstimator {
  const AudioDurationEstimator._();

  static const int maxHeaderBytes = 64 * 1024;

  /// Estima la duración de un archivo de audio leyendo solo su cabecera.
  ///
  /// Soporta:
  /// - WAV / AIFF: Duración exacta a partir de las cabeceras PCM / COMM.
  /// - FLAC: Duración exacta a partir del bloque STREAMINFO.
  /// - MP3 / OGG / AAC / otros: Estimación heurística a 128 kbps.
  ///
  /// Retorna `null` si el archivo no existe, está corrupto o no se puede leer.
  static Future<Duration?> estimateDecodedDuration(File file) async {
    try {
      if (!await file.exists()) return null;
      final fileLength = await file.length();
      if (fileLength < 12) return null;

      final header = await _readHeader(file, min(fileLength, maxHeaderBytes));
      if (header == null || header.length < 12) return null;

      // 1. WAV (RIFF ... WAVE)
      if (_matchesMagic(header, 0, 'RIFF') && _matchesMagic(header, 8, 'WAVE')) {
        final wavDuration = _parseWavDuration(header);
        if (wavDuration != null) return wavDuration;
      }

      // 2. AIFF / AIFC (FORM ... AIFF / AIFC)
      if (_matchesMagic(header, 0, 'FORM') &&
          (_matchesMagic(header, 8, 'AIFF') || _matchesMagic(header, 8, 'AIFC'))) {
        final aiffDuration = _parseAiffDuration(header);
        if (aiffDuration != null) return aiffDuration;
      }

      // 3. FLAC (fLaC)
      if (_matchesMagic(header, 0, 'fLaC')) {
        final flacDuration = _parseFlacDuration(header);
        if (flacDuration != null) return flacDuration;
      }

      // 4. Heurística general para formatos comprimidos (MP3, OGG, AAC, etc.)
      // Tasa estimada de 128 kbps (16,000 bytes/segundo)
      final durationUs = ((fileLength * 8 * 1000000) / 128000).round();
      return Duration(microseconds: durationUs);
    } catch (_) {
      return null;
    }
  }

  /// Calcula el peso estimado en bytes de una fuente de audio en memoria RAM.
  ///
  /// - Si se carga en disco ([LoadMode.disk] / WavStream): buffer de streaming fijo (~256 KB).
  /// - Si se carga en memoria ([LoadMode.memory]): float32 estéreo a 48 kHz (~384 KB/s).
  static int estimateSoundMemoryBytes(Duration? duration, LoadMode mode) {
    if (mode == LoadMode.disk) {
      // Buffer de streaming en disco constante (256 KB)
      return 256 * 1024;
    }
    if (duration == null) {
      // Cota por defecto de 5 segundos si no se pudo determinar la duración
      return 5 * 384000;
    }
    return (duration.inMicroseconds * 384) ~/ 1000;
  }

  static Future<Uint8List?> _readHeader(File file, int bytesToRead) async {
    RandomAccessFile? raf;
    try {
      raf = await file.open(mode: FileMode.read);
      return await raf.read(bytesToRead);
    } catch (_) {
      return null;
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
  }

  static bool _matchesMagic(Uint8List bytes, int offset, String magic) {
    if (offset + magic.length > bytes.length) return false;
    for (int i = 0; i < magic.length; i++) {
      if (bytes[offset + i] != magic.codeUnitAt(i)) return false;
    }
    return true;
  }

  static Duration? _parseWavDuration(Uint8List bytes) {
    int offset = 12;
    int? sampleRate;
    int? byteRate;
    int? numChannels;
    int? bitsPerSample;
    int? dataSize;

    final bd = ByteData.sublistView(bytes);

    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = bd.getUint32(offset + 4, Endian.little);

      if (chunkId == 'fmt ' && offset + 8 + min(chunkSize, 16) <= bytes.length) {
        numChannels = bd.getUint16(offset + 8 + 2, Endian.little);
        sampleRate = bd.getUint32(offset + 8 + 4, Endian.little);
        byteRate = bd.getUint32(offset + 8 + 8, Endian.little);
        bitsPerSample = bd.getUint16(offset + 8 + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataSize = chunkSize;
        break;
      }

      offset += 8 + chunkSize;
      if (chunkSize.isOdd) offset += 1;
    }

    if (dataSize != null) {
      if (byteRate != null && byteRate > 0) {
        final us = ((dataSize * 1000000) / byteRate).round();
        return Duration(microseconds: us);
      }
      if (sampleRate != null &&
          sampleRate > 0 &&
          numChannels != null &&
          numChannels > 0 &&
          bitsPerSample != null &&
          bitsPerSample > 0) {
        final bytesPerSec = sampleRate * numChannels * (bitsPerSample ~/ 8);
        if (bytesPerSec > 0) {
          final us = ((dataSize * 1000000) / bytesPerSec).round();
          return Duration(microseconds: us);
        }
      }
    }
    return null;
  }

  static Duration? _parseAiffDuration(Uint8List bytes) {
    int offset = 12;
    final bd = ByteData.sublistView(bytes);

    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = bd.getUint32(offset + 4, Endian.big);

      if (chunkId == 'COMM' && offset + 8 + min(chunkSize, 18) <= bytes.length) {
        final numSampleFrames = bd.getUint32(offset + 8 + 2, Endian.big);
        final sampleRate = _readIeeeExtended(bytes, offset + 8 + 8);
        if (sampleRate > 0 && numSampleFrames > 0) {
          final us = ((numSampleFrames * 1000000) / sampleRate).round();
          return Duration(microseconds: us);
        }
        break;
      }

      offset += 8 + chunkSize;
      if (chunkSize.isOdd) offset += 1;
    }
    return null;
  }

  static Duration? _parseFlacDuration(Uint8List bytes) {
    if (bytes.length < 42) return null;
    final blockType = bytes[4] & 0x7F;
    if (blockType != 0) return null; // Debe comenzar con STREAMINFO (0)

    // Los primeros 4 bytes son 'fLaC', bytes 4..7 encabezado del bloque STREAMINFO
    // Offset 8 en adelante: STREAMINFO
    final sInfo = bytes.sublist(8, 8 + 34);
    final sampleRate = (sInfo[10] << 12) | (sInfo[11] << 4) | (sInfo[12] >> 4);
    final totalSamples = ((sInfo[13] & 0x0F) * 4294967296) +
        (sInfo[14] << 24) +
        (sInfo[15] << 16) +
        (sInfo[16] << 8) +
        sInfo[17];

    if (sampleRate > 0 && totalSamples > 0) {
      final us = ((totalSamples * 1000000) / sampleRate).round();
      return Duration(microseconds: us);
    }
    return null;
  }

  /// Lee un número de punto flotante de precisión extendida IEEE 754 (80 bits) usado en AIFF.
  static double _readIeeeExtended(Uint8List bytes, int offset) {
    if (offset + 10 > bytes.length) return 0.0;
    final exp = ((bytes[offset] & 0x7F) << 8) | bytes[offset + 1];
    int hi = 0;
    for (int i = 0; i < 4; i++) {
      hi = (hi << 8) | bytes[offset + 2 + i];
    }
    int lo = 0;
    for (int i = 0; i < 4; i++) {
      lo = (lo << 8) | bytes[offset + 6 + i];
    }

    if (exp == 0 && hi == 0 && lo == 0) return 0.0;
    if (exp == 0x7FFF) return double.infinity;

    final mantissa = (hi.toDouble() * 4294967296.0) + lo.toDouble();
    return mantissa * pow(2.0, exp - 16383 - 63);
  }
}
