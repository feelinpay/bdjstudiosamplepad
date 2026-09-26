import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'helpers/isar_test_helper.dart';
import 'package:path/path.dart' as p;

import 'helpers/path_provider_test_helper.dart';

import 'package:bdj_studio_sample_pad/features/workspace/data/models/workspace_model.dart';
import 'package:bdj_studio_sample_pad/features/workspace/data/models/page_model.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/data/models/pad_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/sample_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/genre_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/folder_model.dart';
import 'package:bdj_studio_sample_pad/features/workspace/domain/services/workspace_exporter.dart';
import 'package:bdj_studio_sample_pad/features/workspace/domain/services/workspace_zip_importer.dart';
import 'package:archive/archive_io.dart';
import 'package:bdj_studio_sample_pad/core/services/app_storage_service.dart';
import 'package:bdj_studio_sample_pad/core/services/local_audio_storage_service.dart';
import 'package:bdj_studio_sample_pad/core/utils/zip_utils.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUpAll(() async {
    await ensureTestIsarInitialized();
  });

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('zip_roundtrip_test');
    mockPathProviderForAllPlatforms(tempRoot);
    AppStorageService.resetCacheForTesting();
  });

  tearDown(() async {
    tearDownPathProviderMocks();
    AppStorageService.resetCacheForTesting();
    try {
      await tempRoot.delete(recursive: true);
    } catch (_) {}
  });

  Future<Isar> openDb(String name) {
    final dbDir = Directory(p.join(tempRoot.path, name))
      ..createSync(recursive: true);
    return Isar.open(
      [
        WorkspaceModelSchema,
        PageModelSchema,
        PadModelSchema,
        SampleModelSchema,
        GenreModelSchema,
        FolderModelSchema,
      ],
      name: name,
      directory: dbDir.path,
    );
  }

  test(
    'Workspace export e import conserva posiciones, edición completa y audios',
    () async {
      // 1. Preparar audio simulado
      final srcAudio = File(p.join(tempRoot.path, 'sample_kick.wav'))
        ..writeAsBytesSync(List.filled(1024, 0x55));

      final audioUri = await LocalAudioStorageService.importAudioFile(
        srcAudio.path,
        namespace: 'OriginalSet',
      );

      // 2. Crear DB original y configurar workspace completo con edición y posiciones
      final db1 = await openDb('db1');
      addTearDown(() => db1.close());

      late WorkspaceModel ws1;
      late PageModel rootPage;
      late PageModel childPage;

      await db1.writeTxn(() async {
        ws1 = WorkspaceModel()
          ..name = 'Mi Set En Vivo'
          ..createdAt = DateTime.now();
        await db1.workspaceModels.put(ws1);

        rootPage = PageModel()
          ..pageIndex = 0
          ..name = 'Página Principal'
          ..columns = 4
          ..rows = 4
          ..workspace.value = ws1;
        await db1.pageModels.put(rootPage);
        await rootPage.workspace.save();

        childPage = PageModel()
          ..pageIndex = 1000
          ..name = 'Bancos Drop'
          ..columns = 4
          ..rows = 4
          ..parentPageId = rootPage.id
          ..workspace.value = ws1;
        await db1.pageModels.put(childPage);
        await childPage.workspace.save();

        // Pad 0: Pad de audio con edición minuciosa (recorte, pitch, pan, loop, etc.)
        final pad0 = PadModel()
          ..padId = 0
          ..label = 'Drop Kick FX'
          ..colorHex = 0xFFFF0055
          ..triggerModeIndex = 1 // loop
          ..padTypeIndex = 0 // audio
          ..chokeGroup = 2
          ..pan = -0.6
          ..pitch = 1.25
          ..volume = 0.85
          ..reverse = true
          ..isProtected = true
          ..fadeInMs = 45
          ..fadeOutMs = 80
          ..startPointMs = 120
          ..endPointMs = 900
          ..loopPointMs = 120
          ..samplePath = audioUri
          ..page.value = rootPage;
        await db1.padModels.put(pad0);
        await pad0.page.save();

        // Pad 5: Pad de carpeta que abre la subpágina 1000
        final pad5 = PadModel()
          ..padId = 5
          ..label = 'Bancos Drop'
          ..colorHex = 0xFFFF9800
          ..triggerModeIndex = 0
          ..padTypeIndex = 1 // folder
          ..targetPageIndex = 1000
          ..page.value = rootPage;
        await db1.padModels.put(pad5);
        await pad5.page.save();

        // Pad 15 en la esquina inferior derecha (posición 15)
        final pad15 = PadModel()
          ..padId = 15
          ..label = 'Snare'
          ..colorHex = 0xFF00E5FF
          ..triggerModeIndex = 0
          ..padTypeIndex = 0
          ..samplePath = audioUri
          ..page.value = rootPage;
        await db1.padModels.put(pad15);
        await pad15.page.save();

        // Pad en la subpágina hija (posición 3)
        final childPad3 = PadModel()
          ..padId = 3
          ..label = 'Vocal Chop'
          ..colorHex = 0xFF7C4DFF
          ..triggerModeIndex = 0
          ..padTypeIndex = 0
          ..samplePath = audioUri
          ..page.value = childPage;
        await db1.padModels.put(childPad3);
        await childPad3.page.save();
      });

      // 3. Exportar usando WorkspaceExporter
      final exporter = WorkspaceExporter(Future.value(db1));
      final exportedZipPath = await exporter.exportWorkspace(ws1.id);
      expect(exportedZipPath, isNotNull);
      expect(File(exportedZipPath!).existsSync(), isTrue);

      // 4. Importar en una base de datos limpia db2 usando WorkspaceZipImporter
      final db2 = await openDb('db2');
      addTearDown(() => db2.close());

      final importer = WorkspaceZipImporter(Future.value(db2));
      final ws2 = await importer.importFromZipFile(exportedZipPath);
      expect(ws2, isNotNull);
      expect(ws2!.name, 'Mi Set En Vivo');

      // 5. Verificar estructura de páginas
      final pages2 = await db2.pageModels
          .filter()
          .workspace((q) => q.idEqualTo(ws2.id))
          .findAll();
      expect(pages2.length, 2);

      final root2 = pages2.firstWhere((p) => p.pageIndex == 0);
      final child2 = pages2.firstWhere((p) => p.pageIndex == 1000);

      expect(root2.name, 'Página Principal');
      expect(root2.columns, 4);
      expect(root2.rows, 4);
      expect(root2.parentPageId, isNull);

      expect(child2.name, 'Bancos Drop');
      expect(child2.parentPageId, root2.id,
          reason: 'La jerarquía padre-hijo debe restaurarse exactamente con los nuevos IDs');

      // 6. Verificar pads y posiciones exactas en root2
      await root2.pads.load();
      final rootPads = root2.pads.toList();
      expect(rootPads.length, 3);

      final p0 = rootPads.firstWhere((p) => p.padId == 0);
      expect(p0.label, 'Drop Kick FX');
      expect(p0.colorHex, 0xFFFF0055);
      expect(p0.triggerModeIndex, 1);
      expect(p0.chokeGroup, 2);
      expect(p0.pan, -0.6);
      expect(p0.pitch, 1.25);
      expect(p0.volume, 0.85);
      expect(p0.reverse, isTrue);
      expect(p0.isProtected, isTrue);
      expect(p0.fadeInMs, 45);
      expect(p0.fadeOutMs, 80);
      expect(p0.startPointMs, 120);
      expect(p0.endPointMs, 900);
      expect(p0.loopPointMs, 120);

      // Verificar que el audio fue copiado y se puede resolver en disco
      expect(p0.samplePath, startsWith(LocalAudioStorageService.prefix));
      final resolvedAudio =
          await LocalAudioStorageService.resolvePath(p0.samplePath!);
      expect(File(resolvedAudio).existsSync(), isTrue);

      // Verificar Pad 5 (carpeta con link a subpágina 1000)
      final p5 = rootPads.firstWhere((p) => p.padId == 5);
      expect(p5.padTypeIndex, 1);
      expect(p5.targetPageIndex, 1000);
      expect(p5.label, 'Bancos Drop');

      // Verificar Pad 15 (posición 15 en grid)
      final p15 = rootPads.firstWhere((p) => p.padId == 15);
      expect(p15.padId, 15);
      expect(p15.label, 'Snare');

      // 7. Verificar pads en child2
      await child2.pads.load();
      final childPads = child2.pads.toList();
      expect(childPads.length, 1);
      final cp3 = childPads.first;
      expect(cp3.padId, 3);
      expect(cp3.label, 'Vocal Chop');
      expect(cp3.colorHex, 0xFF7C4DFF);

      // 8. Privacidad: el metadata no debe filtrar rutas locales privadas
      final verifyInput = InputFileStream(exportedZipPath);
      final exportedArchive = ZipDecoder().decodeStream(verifyInput);
      final metaEntry = exportedArchive.firstWhere((e) => e.name.endsWith('metadata.json'));
      final metaText = utf8.decode(metaEntry.content as List<int>);
      await verifyInput.close();

      expect(metaText, contains('"format":"bdj-studio-sample-pad-workspace"'));
      expect(metaText, contains('"version":1'));
      expect(metaText, isNot(contains('"backgroundImagePath"')),
          reason: 'No debe incluir la propiedad interna backgroundImagePath');

      // 9. Borrar un pad y verificar que autoCleanOrphans se ejecuta limpiamente
      await db2.writeTxn(() async {
        await db2.padModels.delete(p15.id);
      });
      final deletedCount = await LocalAudioStorageService.autoCleanOrphans(db2);
      expect(deletedCount, greaterThanOrEqualTo(0));

      // 10. Limpieza: al borrar el workspace, su carpeta de audios se elimina
      final wsDir = File(resolvedAudio).parent;
      expect(wsDir.existsSync(), isTrue);
      await LocalAudioStorageService.deleteWorkspaceDir(ws2.name);
      expect(wsDir.existsSync(), isFalse,
          reason: 'La carpeta física del workspace debe eliminarse junto con el workspace');
    },
  );

  test('WorkspaceZipImporter rechaza formato incompatible o version futura', () async {
    final db = await openDb('db_validation');
    addTearDown(() => db.close());
    final importer = WorkspaceZipImporter(Future.value(db));

    final invalidZip = File(p.join(tempRoot.path, 'invalid.sppworkspace'));
    final workDir = Directory(p.join(tempRoot.path, 'invalid_src'))..createSync();
    File(p.join(workDir.path, 'metadata.json')).writeAsStringSync(
      jsonEncode({
        'format': 'unknown-format',
        'version': 99,
        'workspace': {'name': 'Set Incompatible'},
        'pages': [],
        'pads': [],
      }),
    );
    await zipDirectoryInIsolate(
      ZipHelperArgs(
        metadataPath: p.join(workDir.path, 'metadata.json'),
        mediaDirPath: workDir.path,
        outputPath: invalidZip.path,
      ),
    );

    final result = await importer.importFromZipFile(invalidZip.path);
    expect(result, isNull, reason: 'Debe rechazar archivos con formato o versión incompatible');
  });
}
