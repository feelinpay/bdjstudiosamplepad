import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

import 'helpers/path_provider_test_helper.dart';

import 'package:bdj_studio_sample_pad/core/services/local_audio_storage_service.dart';
import 'package:bdj_studio_sample_pad/features/workspace/data/models/workspace_model.dart';
import 'package:bdj_studio_sample_pad/features/workspace/data/models/page_model.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/data/models/pad_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/sample_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/genre_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/folder_model.dart';
import 'package:bdj_studio_sample_pad/features/workspace/data/repositories/isar_workspace_repository.dart';
import 'package:bdj_studio_sample_pad/features/macros/data/models/macro_model.dart';
import 'helpers/isar_test_helper.dart';

Future<Isar> _openIsar(Directory tempRoot) async {
  final dbDir = Directory(p.join(tempRoot.path, 'db'))..createSync(recursive: true);
  return Isar.open(
    [
      WorkspaceModelSchema,
      PageModelSchema,
      PadModelSchema,
      SampleModelSchema,
      GenreModelSchema,
      FolderModelSchema,
      MacroModelSchema,
    ],
    directory: dbDir.path,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUpAll(() async {
    await ensureTestIsarInitialized();
  });

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('repo_test');
    mockPathProviderForAllPlatforms(tempRoot);
  });

  tearDown(() async {
    tearDownPathProviderMocks();
    try {
      await tempRoot.delete(recursive: true);
    } catch (_) {}
  });

  test('duplicateWorkspace remapea parentPageId y targetPageIndex', () async {
    final isar = await _openIsar(tempRoot);
    addTearDown(() => isar.close());
    final repo = IsarWorkspaceRepository(Future.value(isar));

    final ws = WorkspaceModel()..name = 'Set A'..createdAt = DateTime.now();
    final root = PageModel()..pageIndex = 0..workspace.value = ws;
    final folder = PageModel()
      ..pageIndex = 1000
      ..workspace.value = ws;
    final folderPad = PadModel()
      ..padId = 0
      ..label = 'Folder'
      ..colorHex = 0xFF000000
      ..padTypeIndex = 1
      ..targetPageIndex = 1000
      ..page.value = root;

    await isar.writeTxn(() async {
      await isar.workspaceModels.put(ws);
      // root.id se asigna al hacer put; folder.parentPageId debe usar ese id real.
      await isar.pageModels.put(root);
      folder.parentPageId = root.id;
      await isar.pageModels.put(folder);
      ws.pages.addAll([root, folder]);
      await ws.pages.save();
      await isar.padModels.put(folderPad);
      await folderPad.page.save();
    });

    final copy = await repo.duplicateWorkspace(ws.id);
    expect(copy.name, 'Set A (copia)');

    await copy.pages.load();
    expect(copy.pages.length, 2);
    final pages = copy.pages.toList();
    final parent = pages.singleWhere((pg) => pg.parentPageId == null);
    final child = pages.singleWhere((pg) => pg.parentPageId != null);
    // el folder-child debe apuntar al root DUPLICADO (id remapeado)
    expect(child.parentPageId, parent.id);
    expect(child.parentPageId, isNot(root.id));

    await parent.pads.load();
    final pad = parent.pads.singleWhere((p) => p.padTypeIndex == 1);
    // el folder-pad debe disparar a la página folder DUPLICADA (remapeada)
    expect(pad.targetPageIndex, child.pageIndex);
  });

  test('deleteWorkspace borra pads/pages y el directorio físico', () async {
    final isar = await _openIsar(tempRoot);
    addTearDown(() => isar.close());
    final repo = IsarWorkspaceRepository(Future.value(isar));

    // Se necesita >1 workspace para superar la guarda de "único".
    final other = WorkspaceModel()..name = 'Set B'..createdAt = DateTime.now();
    await isar.writeTxn(() async {
      await isar.workspaceModels.put(other);
    });

    final ws = WorkspaceModel()..name = 'Set A'..createdAt = DateTime.now();
    final page = PageModel()..pageIndex = 0..workspace.value = ws;
    final pad = PadModel()
      ..padId = 0
      ..label = 'Kick'
      ..colorHex = 0xFF000000
      ..samplePath = 'app_local://Set A/audio.wav'
      ..page.value = page;
    await isar.writeTxn(() async {
      await isar.workspaceModels.put(ws);
      await isar.pageModels.put(page);
      ws.pages.addAll([page]);
      await ws.pages.save();
      await isar.padModels.put(pad);
      await pad.page.save();
    });

    final file = File(
      await LocalAudioStorageService.resolvePath('app_local://Set A/audio.wav'),
    );
    await file.create(recursive: true);
    expect(file.existsSync(), isTrue);

    await repo.deleteWorkspace(ws.id);

    final remaining = await repo.getAllWorkspaces();
    expect(remaining.map((w) => w.name), isNot(contains('Set A')));
    expect(await isar.pageModels.count(), 0);
    expect(await isar.padModels.count(), 0);
    expect(file.existsSync(), isFalse);
  });

  test('deleteWorkspace conserva audios compartidos por otro workspace',
      () async {
    final isar = await _openIsar(tempRoot);
    addTearDown(() => isar.close());
    final repo = IsarWorkspaceRepository(Future.value(isar));

    // Workspace que permanece (p.ej. la copia creada por duplicateWorkspace).
    final other = WorkspaceModel()..name = 'Set B'..createdAt = DateTime.now();

    final ws = WorkspaceModel()..name = 'Set A'..createdAt = DateTime.now();
    final page = PageModel()..pageIndex = 0..workspace.value = ws;
    final pad = PadModel()
      ..padId = 0
      ..label = 'Kick'
      ..colorHex = 0xFF000000
      ..samplePath = 'app_local://Set A/audio.wav'
      ..page.value = page;

    // Un pad del workspace "Set B" comparte el MISMO archivo.
    final otherPage = PageModel()..pageIndex = 0..workspace.value = other;
    final sharedPad = PadModel()
      ..padId = 0
      ..label = 'Kick (copia)'
      ..colorHex = 0xFF000000
      ..samplePath = 'app_local://Set A/audio.wav'
      ..page.value = otherPage;

    await isar.writeTxn(() async {
      await isar.workspaceModels.put(other);
      await isar.workspaceModels.put(ws);
      await isar.pageModels.put(page);
      await isar.pageModels.put(otherPage);
      ws.pages.addAll([page]);
      await ws.pages.save();
      other.pages.addAll([otherPage]);
      await other.pages.save();
      await isar.padModels.put(pad);
      await isar.padModels.put(sharedPad);
      await pad.page.save();
      await sharedPad.page.save();
    });

    final file = File(
      await LocalAudioStorageService.resolvePath('app_local://Set A/audio.wav'),
    );
    await file.create(recursive: true);
    expect(file.existsSync(), isTrue);

    await repo.deleteWorkspace(ws.id);

    // El workspace se elimina, pero el archivo compartido sobrevive porque el
    // pad de "Set B" aún lo referencia.
    final remaining = await repo.getAllWorkspaces();
    expect(remaining.map((w) => w.name), isNot(contains('Set A')));
    expect(await isar.padModels.count(), 1);
    expect(file.existsSync(), isTrue,
        reason: 'un audio compartido por otro workspace no debe borrarse');
  });

  test('reconcilePageIndexIntegrity corrige duplicados y preserva root<1000/folder>=1000',
      () async {
    final isar = await _openIsar(tempRoot);
    addTearDown(() => isar.close());
    final repo = IsarWorkspaceRepository(Future.value(isar));

    final ws = WorkspaceModel()..name = 'Set C'..createdAt = DateTime.now();
    await isar.writeTxn(() async {
      await isar.workspaceModels.put(ws);
      // 3 root pages (pageIndex 0, 0 dupo, 5) + 2 folder-roots (3 corrupt <1000, 1000 ok).
      final r0a = PageModel()..pageIndex = 0..workspace.value = ws;
      final r0b = PageModel()..pageIndex = 0..workspace.value = ws;
      final r5 = PageModel()..pageIndex = 5..workspace.value = ws;
      final f1 = PageModel()..pageIndex = 3..workspace.value = ws;
      final f2 = PageModel()..pageIndex = 1000..workspace.value = ws;
      for (final p in [r0a, r0b, r5, f1, f2]) {
        await isar.pageModels.put(p);
      }
      // r0a.id ya asignado tras el put; los folders apuntan al root duplicado.
      f1.parentPageId = r0a.id;
      f2.parentPageId = r0a.id;
      for (final p in [f1, f2]) {
        await isar.pageModels.put(p);
      }
      ws.pages.addAll([r0a, r0b, r5, f1, f2]);
      await ws.pages.save();
    });

    await repo.reconcilePageIndexIntegrity(ws.id);

    final pages = await isar.pageModels.where().findAll();
    final roots = pages.where((p) => p.parentPageId == null);
    final folders = pages.where((p) => p.parentPageId != null);

    expect(roots.length, 3);
    expect(folders.length, 2);
    // pageIndex uniqueness dentro del workspace.
    expect(pages.map((p) => p.pageIndex).toSet().length, pages.length);
    // Integridad de convención root < 1000 / folder >= 1000.
    expect(roots.every((p) => p.pageIndex < 1000), isTrue);
    expect(folders.every((p) => p.pageIndex >= 1000), isTrue);
  });

  test(
      'reconcilePageIndexIntegrity remapea targetPageIndex de pads-carpeta '
      'cuando su pagina objetivo es renumerada', () async {
    final isar = await _openIsar(tempRoot);
    addTearDown(() => isar.close());
    final repo = IsarWorkspaceRepository(Future.value(isar));

    final ws = WorkspaceModel()..name = 'Set D'..createdAt = DateTime.now();
    final root = PageModel()..pageIndex = 0..workspace.value = ws;
    await isar.writeTxn(() async {
      await isar.workspaceModels.put(ws);
      await isar.pageModels.put(root);
      await root.workspace.save();

      // Pagina interna corrupta: index < 1000 (deberia ser >= 1000). Es la
      // raiz de una carpeta y un pad-carpeta la referencia con targetPageIndex.
      final corruptFolder = PageModel()..pageIndex = 3..workspace.value = ws;
      await isar.pageModels.put(corruptFolder);
      corruptFolder.parentPageId = root.id;
      await isar.pageModels.put(corruptFolder);

      // Pagina interna sana con index >= 1000.
      final healthyFolder = PageModel()..pageIndex = 1000..workspace.value = ws;
      await isar.pageModels.put(healthyFolder);
      healthyFolder.parentPageId = root.id;
      await isar.pageModels.put(healthyFolder);

      final brokenPad = PadModel()
        ..padId = 0
        ..label = 'Rota'
        ..colorHex = 0xFF000000
        ..padTypeIndex = 1
        ..targetPageIndex = 3
        ..page.value = root;
      final healthyPad = PadModel()
        ..padId = 1
        ..label = 'Sana'
        ..colorHex = 0xFF000000
        ..padTypeIndex = 1
        ..targetPageIndex = 1000
        ..page.value = root;
      await isar.padModels.put(brokenPad);
      await isar.padModels.put(healthyPad);
      await brokenPad.page.save();
      await healthyPad.page.save();

      ws.pages.addAll([root, corruptFolder, healthyFolder]);
      await ws.pages.save();
    });

    await repo.reconcilePageIndexIntegrity(ws.id);

    final pages = await isar.pageModels.where().findAll();
    final roots = pages.where((p) => p.parentPageId == null).toList();
    final folders = pages.where((p) => p.parentPageId != null).toList();
    expect(roots.length, 1);
    expect(folders.length, 2);
    // Las carpetas quedan en el rango hidden y sin duplicar indices.
    expect(folders.every((p) => p.pageIndex >= 1000), isTrue);
    expect(pages.map((p) => p.pageIndex).toSet().length, pages.length);

    // Todo pad-carpeta debe seguir apuntando (por pageIndex) a su pagina.
    final folderIndexes = {for (final p in folders) p.pageIndex};
    final pads = await isar.padModels.where().findAll();
    final folderPads = pads.where((p) => p.padTypeIndex == 1).toList();
    expect(folderPads.length, 2);
    for (final pad in folderPads) {
      expect(pad.targetPageIndex, isNotNull,
          reason: '${pad.label}: el pad-carpeta debe conservar su destino');
      expect(folderIndexes.contains(pad.targetPageIndex), isTrue,
          reason: '${pad.label}: target ${pad.targetPageIndex} debe apuntar a '
              'una pagina existente del workspace tras la renumeracion');
    }
  });

  test(
      'reconcilePageIndexIntegrity remapea targetPageIndex en macros cuando '
      'su pagina objetivo es renumerada', () async {
    final isar = await _openIsar(tempRoot);
    addTearDown(() => isar.close());
    final repo = IsarWorkspaceRepository(Future.value(isar));

    final ws = WorkspaceModel()..name = 'Set E'..createdAt = DateTime.now();
    final root = PageModel()..pageIndex = 0..workspace.value = ws;
    await isar.writeTxn(() async {
      await isar.workspaceModels.put(ws);
      await isar.pageModels.put(root);
      await root.workspace.save();

      // Pagina interna corrupta (index < 1000) que sera renumerada a >= 1000.
      final corruptFolder = PageModel()..pageIndex = 3..workspace.value = ws;
      await isar.pageModels.put(corruptFolder);
      corruptFolder.parentPageId = root.id;
      await isar.pageModels.put(corruptFolder);

      final folderPad = PadModel()
        ..padId = 0
        ..label = 'Carpeta'
        ..colorHex = 0xFF000000
        ..padTypeIndex = 1
        ..targetPageIndex = 3
        ..page.value = root;
      await isar.padModels.put(folderPad);
      await folderPad.page.save();

      final macro = MacroModel()
        ..name = 'M1'
        ..createdAt = DateTime.now()
        ..actionsJson = jsonEncode([
          {'type': 'changePage', 'params': {'targetPageIndex': 3}},
          {
            'type': 'triggerPad',
            'params': {
              'targetWorkspaceId': ws.id,
              'targetPageIndex': 3,
              'padId': '1',
            },
          },
          {
            'type': 'triggerPad',
            'params': {
              'targetWorkspaceId': 9999,
              'targetPageIndex': 3,
              'padId': '2',
            },
          },
        ]);
      await isar.macroModels.put(macro);

      ws.pages.addAll([root, corruptFolder]);
      await ws.pages.save();
    });

    await repo.reconcilePageIndexIntegrity(ws.id);

    final folderPage = (await isar.pageModels.where().findAll())
        .firstWhere((p) => p.parentPageId != null);
    final macro = await isar.macroModels.where().findFirst();
    final actions = jsonDecode(macro!.actionsJson) as List<dynamic>;
    int targetOf(int index) =>
        (((actions[index] as Map)['params'] as Map)['targetPageIndex'] as num)
            .toInt();
    expect(targetOf(0), folderPage.pageIndex,
        reason: 'macro sin workspace: page renumerada debe remapearse');
    expect(targetOf(1), folderPage.pageIndex,
        reason: 'macro del mismo workspace debe remapearse');
    expect(targetOf(2), 3,
        reason: 'macro con workspaceId de otro workspace no debe tocarse');
  });

  test(
      'reconcilePageIndexIntegrity no produce escrituras en un workspace íntegro',
      () async {
    final isar = await _openIsar(tempRoot);
    addTearDown(() => isar.close());
    final repo = IsarWorkspaceRepository(Future.value(isar));

    final ws = WorkspaceModel()
      ..name = 'Clean Workspace'
      ..createdAt = DateTime.now();
    final root0 = PageModel()
      ..pageIndex = 0
      ..workspace.value = ws;
    final root1 = PageModel()
      ..pageIndex = 1
      ..workspace.value = ws;
    final folder1000 = PageModel()
      ..pageIndex = 1000
      ..workspace.value = ws;

    await isar.writeTxn(() async {
      await isar.workspaceModels.put(ws);
      await isar.pageModels.putAll([root0, root1, folder1000]);
      folder1000.parentPageId = root0.id;
      await isar.pageModels.put(folder1000);
      await root0.workspace.save();
      await root1.workspace.save();
      await folder1000.workspace.save();
      ws.pages.addAll([root0, root1, folder1000]);
      await ws.pages.save();
    });

    var pageWrites = 0;
    final sub = isar.pageModels.watchLazy().listen((_) => pageWrites++);
    addTearDown(() => sub.cancel());

    await repo.reconcilePageIndexIntegrity(ws.id);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(pageWrites, 0,
        reason:
            'Un workspace con índices correctos no debe escribir en la base de datos');
  });

  test('dos pads comparten el mismo archivo: al borrar uno, el otro se conserva y el archivo existe', () async {
    final isar = await _openIsar(tempRoot);
    addTearDown(() => isar.close());

    final ws = WorkspaceModel()..name = 'Set Shared'..createdAt = DateTime.now();
    final page = PageModel()..pageIndex = 0..workspace.value = ws;
    final pad1 = PadModel()
      ..padId = 0
      ..label = 'Pad 1'
      ..colorHex = 0xFF000000
      ..samplePath = 'app_local://Set Shared/shared.wav'
      ..page.value = page;
    final pad2 = PadModel()
      ..padId = 1
      ..label = 'Pad 2'
      ..colorHex = 0xFF000000
      ..samplePath = 'app_local://Set Shared/shared.wav'
      ..page.value = page;

    await isar.writeTxn(() async {
      await isar.workspaceModels.put(ws);
      await isar.pageModels.put(page);
      ws.pages.addAll([page]);
      await ws.pages.save();
      await isar.padModels.putAll([pad1, pad2]);
      await pad1.page.save();
      await pad2.page.save();
    });

    final file = File(
      await LocalAudioStorageService.resolvePath('app_local://Set Shared/shared.wav'),
    );
    await file.create(recursive: true);
    expect(file.existsSync(), isTrue);

    // Borramos pad1 excluyéndolo de la comprobación
    await LocalAudioStorageService.deleteAudioFiles(
      [pad1.samplePath!],
      isar: isar,
      excludingPadIds: [pad1.id],
    );
    await isar.writeTxn(() async {
      await isar.padModels.delete(pad1.id);
    });

    // pad2 sigue existiendo y el archivo físico NO se borró
    expect(file.existsSync(), isTrue, reason: 'El archivo físico debe persistir porque pad2 aún lo utiliza');
    final pad2InDb = await isar.padModels.get(pad2.id);
    expect(pad2InDb, isNotNull);
    expect(pad2InDb!.samplePath, 'app_local://Set Shared/shared.wav');

    // Ahora borramos pad2 (último pad que usa el archivo)
    await LocalAudioStorageService.deleteAudioFiles(
      [pad2.samplePath!],
      isar: isar,
      excludingPadIds: [pad2.id],
    );
    await isar.writeTxn(() async {
      await isar.padModels.delete(pad2.id);
    });

    // Ahora sí se debió haber borrado el archivo físico
    expect(file.existsSync(), isFalse, reason: 'El archivo físico debe borrarse al eliminarse el último pad');
  });
}
