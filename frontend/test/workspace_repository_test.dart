import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
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

// Reutiliza el mismo bootstrap de lib nativa de Isar que workspace_importer_test.
String? _isarNativeLibPath() {
  final configFile = File(p.join('.dart_tool', 'package_config.json'));
  if (!configFile.existsSync()) return null;
  final configDir = configFile.parent;
  final dynamic decoded;
  try {
    decoded = jsonDecode(configFile.readAsStringSync());
  } catch (_) {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  final packages = decoded['packages'];
  if (packages is! List) return null;
  for (final entry in packages) {
    if (entry is! Map<String, dynamic>) continue;
    if (entry['name'] != 'isar_flutter_libs') continue;
    final rootUri = entry['rootUri'];
    if (rootUri is! String) continue;
    final uri = Uri.parse(rootUri);
    final pkgDir = uri.isAbsolute
        ? Directory.fromUri(uri)
        : Directory(p.join(configDir.path, rootUri));
    if (Platform.isWindows) return p.join(pkgDir.path, 'windows', 'isar.dll');
    if (Platform.isMacOS) return p.join(pkgDir.path, 'macos', 'libisar.dylib');
    if (Platform.isLinux) return p.join(pkgDir.path, 'linux', 'libisar.so');
    return null;
  }
  return null;
}

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
    ],
    directory: dbDir.path,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUpAll(() async {
    final libPath = _isarNativeLibPath();
    if (libPath != null && File(libPath).existsSync()) {
      await Isar.initializeIsarCore(libraries: {Abi.current(): libPath});
    }
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
}
