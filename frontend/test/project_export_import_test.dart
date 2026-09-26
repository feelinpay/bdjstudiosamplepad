import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'helpers/isar_test_helper.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/path_provider_test_helper.dart';

import 'package:bdj_studio_sample_pad/core/services/app_storage_service.dart';
import 'package:bdj_studio_sample_pad/core/services/local_audio_storage_service.dart';
import 'package:bdj_studio_sample_pad/features/macros/data/models/macro_model.dart';
import 'package:bdj_studio_sample_pad/features/midi/data/models/midi_mapping_model.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/data/models/pad_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/folder_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/genre_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/sample_model.dart';
import 'package:bdj_studio_sample_pad/features/workspace/data/models/page_model.dart';
import 'package:bdj_studio_sample_pad/features/workspace/data/models/workspace_model.dart';
import 'package:bdj_studio_sample_pad/features/workspace/domain/services/project_exporter.dart';
import 'package:bdj_studio_sample_pad/features/workspace/domain/services/project_importer.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUpAll(() async {
    await ensureTestIsarInitialized();
  });

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('project_export_import_test');
    mockPathProviderForAllPlatforms(tempRoot);
    SharedPreferences.setMockInitialValues({
      'workspace_order_ids': ['1'],
      'theme_mode': 'dark',
      'bdj.hwid.v2': 'TEST_HWID_SECRET_123',
      'bdj.sample_pad.license_key': 'SUPER_SECRET_LICENSE',
      'audio_output_device_id': 99,
    });
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
        MacroModelSchema,
        MidiMappingModelSchema,
      ],
      name: name,
      directory: dbDir.path,
    );
  }

  test(
    'ProjectExporter y ProjectImporter roundtrip preserva contenido del proyecto, ediciones de pads y NO exporta licencias/preferencias',
    () async {
      final isarSource = await openDb('source_db');

      // 1. Preparar audio y guardarlo en el almacenamiento local
      final srcAudio = File(p.join(tempRoot.path, 'kick_drum.wav'))
        ..writeAsBytesSync(List.filled(2048, 0x7F));

      final audioUri = await LocalAudioStorageService.importAudioFile(
        srcAudio.path,
        namespace: 'OriginalProjectSet',
      );

      // 2. Crear Macro y Workspace con páginas y pads editados
      late WorkspaceModel wsSource;
      late MacroModel macroSource;
      await isarSource.writeTxn(() async {
        macroSource = MacroModel()
          ..name = 'Strobe FX'
          ..actionsJson = jsonEncode([{'type': 'blink', 'rate': 120}])
          ..createdAt = DateTime.now();
        await isarSource.macroModels.put(macroSource);

        wsSource = WorkspaceModel()
          ..name = 'Festival Set 2026'
          ..createdAt = DateTime.now();
        await isarSource.workspaceModels.put(wsSource);

        final rootPage = PageModel()
          ..pageIndex = 0
          ..name = 'Kits Principales'
          ..columns = 4
          ..rows = 4
          ..workspace.value = wsSource;
        await isarSource.pageModels.put(rootPage);
        await rootPage.workspace.save();

        final padWithEdits = PadModel()
          ..padId = 1
          ..label = 'Sub Kick'
          ..colorHex = 0xFFFF0055
          ..triggerModeIndex = 0 // oneShot
          ..padTypeIndex = 0 // Audio
          ..volume = 0.85
          ..pitch = 1.15
          ..pan = -0.25
          ..reverse = true
          ..chokeGroup = 2
          ..startPointMs = 50
          ..endPointMs = 1200
          ..loopPointMs = 100
          ..fadeInMs = 15
          ..fadeOutMs = 80
          ..samplePath = audioUri
          ..targetMacroId = macroSource.id
          ..page.value = rootPage;
        await isarSource.padModels.put(padWithEdits);
        await padWithEdits.page.save();

        // Pad 2 apunta exactamente al mismo audio para verificar deduplicación canónica
        final pad2SameAudio = PadModel()
          ..padId = 2
          ..label = 'Second Kick'
          ..colorHex = 0xFF00FF00
          ..samplePath = audioUri
          ..page.value = rootPage;
        await isarSource.padModels.put(pad2SameAudio);
        await pad2SameAudio.page.save();

        final midiMapping = MidiMappingModel()
          ..noteOrCC = 36
          ..statusByte = 144
          ..actionType = 'TriggerPad'
          ..actionValue = '1';
        await isarSource.midiMappingModels.put(midiMapping);
      });

      // 3. Exportar proyecto completo
      final exporter = ProjectExporter(Future.value(isarSource));
      int progressUpdates = 0;
      final exportPath = await exporter.exportProject(
        onProgress: (current, total) {
          progressUpdates++;
        },
      );

      expect(exportPath, isNotNull);
      expect(File(exportPath!).existsSync(), isTrue);
      expect(progressUpdates, greaterThanOrEqualTo(1));

      // 4. Inspeccionar archivo exportado para verificar que NO contenga preferencias ni licencias
      final archive = ZipDecoder().decodeBytes(File(exportPath).readAsBytesSync());
      final metadataFile = archive.findFile('metadata.json');
      expect(metadataFile, isNotNull);

      final metadataContent = utf8.decode(metadataFile!.content as List<int>);
      final metadataJson = jsonDecode(metadataContent) as Map<String, dynamic>;

      expect(metadataJson['format'], equals(ProjectExporter.supportedFormat));
      expect(metadataJson['version'], equals(2));
      expect(metadataJson['appVersion'], isNotEmpty);
      expect(metadataJson['workspaces'], isNotEmpty);
      expect(metadataJson['macros'], isNotEmpty);
      expect(metadataJson['midiMappings'], isNotEmpty);

      // Verificar deduplicación en media/: a pesar de 2 pads, solo hay 1 archivo copiado
      final mediaEntries = archive.files.where((f) => f.name.startsWith('media/') && f.isFile).toList();
      expect(mediaEntries.length, equals(1));
      // Verificar que el nombre del archivo está saneado sin caracteres ilegales
      expect(mediaEntries.first.name, isNot(contains(':')));
      expect(mediaEntries.first.name, isNot(contains('?')));
      expect(mediaEntries.first.name, isNot(contains('|')));

      // ¡Verificar que solo viajan preferencias de lista blanca y NUNCA licencias ni hardware!
      expect(metadataJson.containsKey('preferences'), isTrue);
      final exportedPrefs = metadataJson['preferences'] as Map<String, dynamic>;
      expect(exportedPrefs['theme_mode'], equals('dark'));
      expect(exportedPrefs.containsKey('bdj.hwid.v2'), isFalse);
      expect(exportedPrefs.containsKey('bdj.sample_pad.license_key'), isFalse);
      expect(exportedPrefs.containsKey('audio_output_device_id'), isFalse);

      expect(metadataContent.contains('license_key'), isFalse);
      expect(metadataContent.contains('device_id'), isFalse);
      expect(metadataContent.contains('hardware_fingerprint'), isFalse);
      expect(metadataContent.contains('TEST_HWID_SECRET_123'), isFalse);
      expect(metadataContent.contains('SUPER_SECRET_LICENSE'), isFalse);

      await isarSource.close();

      // 5. Crear un archivo de audio huérfano de un proyecto viejo en disco
      final mediaBase = await AppStorageService.mediaDirectory();
      final orphanDir = Directory(p.join(mediaBase.path, 'OldAbandonedWorkspace'));
      await orphanDir.create(recursive: true);
      final orphanFile = File(p.join(orphanDir.path, 'abandoned_sample.wav'));
      await orphanFile.writeAsBytes([0, 1, 2, 3]);
      expect(await orphanFile.exists(), isTrue);

      // 6. Importar en una base limpia (modo Replace)
      final isarDest = await openDb('dest_db');
      final importer = ProjectImporter(Future.value(isarDest));

      final result = await importer.importProject(
        exportPath,
        mode: BackupImportMode.replace,
      );

      expect(result.success, isTrue);
      expect(result.workspacesImported, equals(1));
      expect(result.padsImported, equals(2));
      expect(result.macrosImported, equals(1));
      expect(result.midiMappingsImported, equals(1));

      // Verificar que el archivo huérfano viejo FUE PURGADO del disco
      expect(await orphanFile.exists(), isFalse);

      // Verificar que los datos en destino tienen exactamente las ediciones del pad
      final importedWs = await isarDest.workspaceModels.where().findFirst();
      expect(importedWs, isNotNull);
      expect(importedWs!.name, equals('Festival Set 2026'));

      final importedPages = await isarDest.pageModels
          .filter()
          .workspace((q) => q.idEqualTo(importedWs.id))
          .findAll();
      expect(importedPages.length, equals(1));
      expect(importedPages.first.name, equals('Kits Principales'));

      final importedPads = await isarDest.padModels
          .filter()
          .page((q) => q.idEqualTo(importedPages.first.id))
          .findAll();
      expect(importedPads.length, equals(2));

      final pad = importedPads.firstWhere((p) => p.padId == 1);
      expect(pad.label, equals('Sub Kick'));
      expect(pad.colorHex, equals(0xFFFF0055));
      expect(pad.volume, equals(0.85));
      expect(pad.pitch, equals(1.15));
      expect(pad.pan, equals(-0.25));
      expect(pad.reverse, isTrue);
      expect(pad.chokeGroup, equals(2));
      expect(pad.startPointMs, equals(50));
      expect(pad.endPointMs, equals(1200));
      expect(pad.loopPointMs, equals(100));
      expect(pad.fadeInMs, equals(15));
      expect(pad.fadeOutMs, equals(80));
      expect(pad.samplePath, isNotNull);

      // Verificar que el audio importado existe físicamente en disco y es reproducible
      final resolvedAudioPath =
          await LocalAudioStorageService.resolvePath(pad.samplePath!);
      expect(File(resolvedAudioPath).existsSync(), isTrue);
      expect(File(resolvedAudioPath).lengthSync(), equals(2048));

      // Verificar Macro
      final importedMacros = await isarDest.macroModels.where().findAll();
      expect(importedMacros.length, equals(1));
      expect(importedMacros.first.name, equals('Strobe FX'));
      expect(pad.targetMacroId, equals(importedMacros.first.id));

      // 6. Probar Importación en modo MERGE
      final mergeResult = await importer.importProject(
        exportPath,
        mode: BackupImportMode.merge,
      );

      expect(mergeResult.success, isTrue);
      final allWs = await isarDest.workspaceModels.where().findAll();
      expect(allWs.length, equals(2));
      // El segundo workspace debe haberse renombrado automáticamente para evitar colisión
      expect(allWs.any((w) => w.name == 'Festival Set 2026 (1)'), isTrue);

      await isarDest.close();
    },
  );
}
