import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bdj_studio_sample_pad/core/audio/audio_duration_estimator.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('audio_estimator_test_');
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('AudioDurationEstimator', () {
    test('WAV PCM: calcula la duracion exacta a partir de las cabeceras RIFF', () async {
      final wavFile = File('${tempDir.path}/test.wav');
      final bb = BytesBuilder();

      // RIFF header
      bb.add('RIFF'.codeUnits);
      final bbSize = ByteData(4)..setUint32(0, 36 + 176400, Endian.little);
      bb.add(bbSize.buffer.asUint8List());
      bb.add('WAVE'.codeUnits);

      // fmt chunk
      bb.add('fmt '.codeUnits);
      final fmtSize = ByteData(4)..setUint32(0, 16, Endian.little);
      bb.add(fmtSize.buffer.asUint8List());
      final fmtData = ByteData(16)
        ..setUint16(0, 1, Endian.little) // PCM format
        ..setUint16(2, 2, Endian.little) // 2 channels
        ..setUint32(4, 44100, Endian.little) // 44.1 kHz
        ..setUint32(8, 176400, Endian.little) // 44100 * 2 * 2 = 176400 bytes/sec
        ..setUint16(12, 4, Endian.little) // block align
        ..setUint16(14, 16, Endian.little); // 16 bits per sample
      bb.add(fmtData.buffer.asUint8List());

      // data chunk (176400 bytes = exactly 1 second)
      bb.add('data'.codeUnits);
      final dataSize = ByteData(4)..setUint32(0, 176400, Endian.little);
      bb.add(dataSize.buffer.asUint8List());
      // Write some dummy bytes
      bb.add(Uint8List(100));

      await wavFile.writeAsBytes(bb.toBytes());

      final duration = await AudioDurationEstimator.estimateDecodedDuration(wavFile);
      expect(duration, isNotNull);
      expect(duration!.inMilliseconds, equals(1000));
    });

    test('AIFF: calcula la duracion exacta a partir de COMM chunk', () async {
      final aiffFile = File('${tempDir.path}/test.aiff');
      final bb = BytesBuilder();

      // FORM header
      bb.add('FORM'.codeUnits);
      final bbSize = ByteData(4)..setUint32(0, 100, Endian.big);
      bb.add(bbSize.buffer.asUint8List());
      bb.add('AIFF'.codeUnits);

      // COMM chunk
      bb.add('COMM'.codeUnits);
      final commSize = ByteData(4)..setUint32(0, 18, Endian.big);
      bb.add(commSize.buffer.asUint8List());

      final commData = ByteData(18)
        ..setUint16(0, 2, Endian.big) // 2 channels
        ..setUint32(2, 44100, Endian.big) // 44100 frames = 1 second
        ..setUint16(6, 16, Endian.big); // 16 bits
      // 80-bit float for 44100.0:
      // Exponent: 16383 + 15 = 16398 = 0x400E
      // Mantissa: 44100 * 2^(63 - 15) = 44100 * 2^48 = 0xAC44000000000000
      commData.setUint16(8, 0x400E, Endian.big);
      commData.setUint32(10, 0xAC440000, Endian.big);
      commData.setUint32(14, 0x00000000, Endian.big);

      bb.add(commData.buffer.asUint8List());

      await aiffFile.writeAsBytes(bb.toBytes());

      final duration = await AudioDurationEstimator.estimateDecodedDuration(aiffFile);
      expect(duration, isNotNull);
      expect(duration!.inMilliseconds, equals(1000));
    });

    test('FLAC: calcula la duracion exacta a partir del bloque STREAMINFO', () async {
      final flacFile = File('${tempDir.path}/test.flac');
      final bb = BytesBuilder();

      // fLaC magic
      bb.add('fLaC'.codeUnits);

      // Metadata block header: blockType 0 (STREAMINFO), length 34
      bb.add([0x00, 0x00, 0x00, 0x22]);

      // STREAMINFO block (34 bytes)
      final sInfo = Uint8List(34);
      // Sample rate: 48000 (0x0BB80) -> 20 bits
      // Bytes 10, 11, 12:
      // byte 10: 0x0B
      // byte 11: 0xB8
      // byte 12 (high 4 bits): 0x00
      sInfo[10] = 0x0B;
      sInfo[11] = 0xB8;
      sInfo[12] = 0x00;

      // Total samples: 96000 (0x000017700) -> 36 bits
      // 96000 samples at 48000 Hz = 2.0 seconds
      // byte 13 (low 4 bits): 0x00
      // byte 14: 0x00
      // byte 15: 0x01
      // byte 16: 0x77
      // byte 17: 0x00
      sInfo[13] = 0x00;
      sInfo[14] = 0x00;
      sInfo[15] = 0x01;
      sInfo[16] = 0x77;
      sInfo[17] = 0x00;

      bb.add(sInfo);

      await flacFile.writeAsBytes(bb.toBytes());

      final duration = await AudioDurationEstimator.estimateDecodedDuration(flacFile);
      expect(duration, isNotNull);
      expect(duration!.inMilliseconds, equals(2000));
    });

    test('Archivo inexistente o corrupto retorna null', () async {
      final nonExistent = File('${tempDir.path}/non_existent.wav');
      expect(await AudioDurationEstimator.estimateDecodedDuration(nonExistent), isNull);

      final emptyFile = File('${tempDir.path}/empty.wav');
      await emptyFile.writeAsBytes([]);
      expect(await AudioDurationEstimator.estimateDecodedDuration(emptyFile), isNull);
    });

    test('estimateSoundMemoryBytes: calcula RAM segun LoadMode y duracion', () {
      // En modo disco: fijo 256 KB
      expect(
        AudioDurationEstimator.estimateSoundMemoryBytes(
          const Duration(seconds: 120),
          LoadMode.disk,
        ),
        equals(256 * 1024),
      );

      // En memoria: ~384 KB por segundo
      final bytes1s = AudioDurationEstimator.estimateSoundMemoryBytes(
        const Duration(seconds: 1),
        LoadMode.memory,
      );
      expect(bytes1s, equals(384000));

      final bytes10s = AudioDurationEstimator.estimateSoundMemoryBytes(
        const Duration(seconds: 10),
        LoadMode.memory,
      );
      expect(bytes10s, equals(3840000));
    });
  });
}
