import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:bdj_studio_sample_pad/core/utils/zip_utils.dart';

/// El export de workspace (.sppworkspace) comprime `metadata.json` + `media/`
/// mediante [zipDirectoryInIsolate]. Estos tests verifican que el .zip
/// resultante contiene REALMENTE todo lo que se le pasó: es el único punto en
/// el que la app serializa el trabajo del usuario a un archivo portable, así
/// que una compresión incompleta equivale a perder la sesión exportada.
void main() {
  late Directory tempRoot;
  late String metadataPath;
  late Directory mediaDir;
  late String outputPath;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('zip_utils_test');
    metadataPath = p.join(tempRoot.path, 'metadata.json');
    mediaDir = Directory(p.join(tempRoot.path, 'media'))
      ..createSync(recursive: true);
    outputPath = p.join(tempRoot.path, 'export.sppworkspace');
  });

  tearDown(() async {
    try {
      await tempRoot.delete(recursive: true);
    } catch (_) {}
  });

  /// Escribe un metadata.json representativo y [audioCount] audios simulados.
  void seedExportSource({int audioCount = 3, int bytesPerAudio = 2048}) {
    File(metadataPath).writeAsStringSync(
      '{"workspace":{"name":"Set en vivo"},"pages":[],"pads":[]}',
    );
    for (var i = 0; i < audioCount; i++) {
      File(p.join(mediaDir.path, '${i}_kick.wav')).writeAsBytesSync(
        Uint8List.fromList(List<int>.generate(bytesPerAudio, (b) => (b + i) % 256)),
      );
    }
  }

  ZipHelperArgs buildArgs() => ZipHelperArgs(
        metadataPath: metadataPath,
        mediaDirPath: mediaDir.path,
        outputPath: outputPath,
      );

  test('el archivo exportado existe y no queda vacío', () async {
    seedExportSource();

    await zipDirectoryInIsolate(buildArgs());

    final output = File(outputPath);
    expect(
      output.existsSync(),
      isTrue,
      reason: 'zipDirectoryInIsolate debe dejar el .sppworkspace en disco',
    );
    expect(
      output.lengthSync(),
      greaterThan(0),
      reason: 'un export de 0 bytes es un workspace perdido',
    );
  });

  test('el zip contiene metadata.json y todos los audios de media/', () async {
    seedExportSource(audioCount: 3);

    await zipDirectoryInIsolate(buildArgs());

    final archive = ZipDecoder().decodeBytes(File(outputPath).readAsBytesSync());
    final names = archive.files.map((f) => p.basename(f.name)).toSet();

    expect(names, contains('metadata.json'));
    expect(
      names,
      containsAll(<String>['0_kick.wav', '1_kick.wav', '2_kick.wav']),
      reason: 'todos los audios referenciados por los pads deben viajar en el zip',
    );
  });

  test('el contenido de cada audio se preserva byte a byte', () async {
    seedExportSource(audioCount: 1, bytesPerAudio: 4096);
    final original =
        File(p.join(mediaDir.path, '0_kick.wav')).readAsBytesSync();

    await zipDirectoryInIsolate(buildArgs());

    final archive = ZipDecoder().decodeBytes(File(outputPath).readAsBytesSync());
    final entry = archive.files.firstWhere(
      (f) => p.basename(f.name) == '0_kick.wav',
    );
    expect(entry.content, equals(original));
  });

  test('un media/ vacío sigue produciendo un zip válido con metadata.json', () async {
    File(metadataPath).writeAsStringSync('{"workspace":{"name":"Vacio"}}');

    await zipDirectoryInIsolate(buildArgs());

    final archive = ZipDecoder().decodeBytes(File(outputPath).readAsBytesSync());
    expect(
      archive.files.map((f) => p.basename(f.name)),
      contains('metadata.json'),
    );
  });
}
