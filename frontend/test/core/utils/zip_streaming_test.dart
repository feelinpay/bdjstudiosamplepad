import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';

import '../../helpers/path_provider_test_helper.dart';
import 'package:bdj_studio_sample_pad/core/services/local_audio_storage_service.dart';
import 'package:bdj_studio_sample_pad/core/utils/zip_utils.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/data/services/folder_transfer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('zip_streaming_test');
    mockPathProviderForAllPlatforms(tempRoot);
  });

  tearDown(() async {
    tearDownPathProviderMocks();
    try {
      await tempRoot.delete(recursive: true);
    } catch (_) {}
  });

  group('resolvePickedFilePath', () {
    test('devuelve file.path directamente cuando está disponible', () async {
      final sampleFile = File(p.join(tempRoot.path, 'sample.zip'));
      await sampleFile.writeAsString('dummy zip');

      final platformFile = PlatformFile(
        name: 'sample.zip',
        size: 9,
        path: sampleFile.path,
      );

      final resolved = await resolvePickedFilePath(platformFile);
      expect(resolved, equals(sampleFile.path));
    });

    test('vuelca readStream en streaming cuando path es null (proveedor SAF)', () async {
      final streamData = utf8.encode('streaming zip content');
      final stream = Stream<List<int>>.value(streamData);

      final platformFile = PlatformFile(
        name: 'saf_backup.zip',
        size: streamData.length,
        path: null,
        readStream: stream,
      );

      final resolved = await resolvePickedFilePath(
        platformFile,
        workSubdir: 'test_saf',
      );
      expect(resolved, isNotNull);
      expect(File(resolved!).existsSync(), isTrue);
      expect(await File(resolved).readAsBytes(), equals(streamData));
    });

    test('respalda con bytes si no hay path ni readStream', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final platformFile = PlatformFile(
        name: 'bytes_backup.zip',
        size: bytes.length,
        path: null,
        bytes: bytes,
      );

      final resolved = await resolvePickedFilePath(
        platformFile,
        workSubdir: 'test_bytes',
      );
      expect(resolved, isNotNull);
      expect(File(resolved!).existsSync(), isTrue);
      expect(await File(resolved).readAsBytes(), equals(bytes));
    });
  });

  group('FolderTransferService streaming import', () {
    test('readFolderFile descomprime y procesa carpeta en streaming sin RAM excesiva', () async {
      final tempZipDir = Directory(p.join(tempRoot.path, 'zip_prep'));
      await tempZipDir.create(recursive: true);

      final mediaPrepDir = Directory(p.join(tempZipDir.path, 'media'));
      await mediaPrepDir.create();
      final audioFile = File(p.join(mediaPrepDir.path, '0_kick.wav'));
      await audioFile.writeAsBytes([0x52, 0x49, 0x46, 0x46]); // RIFF header dummy

      final metadata = {
        'folder': {'name': 'Techno Kit', 'colorHex': 0xFF00FF00, 'pageIndex': 0},
        'pads': [
          {
            'label': 'Kick 1',
            'colorHex': 0xFF00FF00,
            'triggerModeIndex': 0,
            'padTypeIndex': 0,
            'chokeGroup': 0,
            'pan': 0.0,
            'pitch': 1.0,
            'isProtected': false,
            'reverse': false,
            'samplePath': '0_kick.wav',
            'targetPageIndex': null,
            'targetMacroId': null,
            'childFolder': null,
            'fadeInMs': 0,
            'fadeOutMs': 0,
            'startPointMs': 0,
            'endPointMs': null,
            'loopPointMs': 0,
            'backgroundImagePath': null,
          }
        ],
        'subfolders': <Map<String, dynamic>>[],
      };

      final metaFile = File(p.join(tempZipDir.path, 'metadata.json'));
      await metaFile.writeAsString(jsonEncode(metadata));

      final zipPath = p.join(tempRoot.path, 'techno_kit.sppfolder');
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      await encoder.addFile(metaFile);
      await encoder.addDirectory(mediaPrepDir);
      await encoder.close();

      // Leer mediante el servicio streaming
      final imported = await FolderTransferService.readFolderFile(zipPath);
      expect(imported, isNotNull);
      expect(imported!.name, equals('Techno Kit'));
      expect(imported.pads.length, equals(1));
      expect(imported.pads.first.label, equals('Kick 1'));
      expect(
        imported.pads.first.samplePath,
        startsWith('${LocalAudioStorageService.prefix}folder_imports/'),
      );

      // Verificar que el audio físico fue importado
      final resolvedPath = await LocalAudioStorageService.resolvePath(
        imported.pads.first.samplePath!,
      );
      expect(File(resolvedPath).existsSync(), isTrue);
    });
  });
}
