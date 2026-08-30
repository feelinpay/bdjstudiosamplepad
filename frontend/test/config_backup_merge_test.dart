import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

import 'helpers/path_provider_test_helper.dart';

import 'package:bdj_studio_sample_pad/features/pad_system/data/models/pad_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/sample_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/folder_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/genre_model.dart';
import 'package:bdj_studio_sample_pad/features/workspace/data/models/workspace_model.dart';
import 'package:bdj_studio_sample_pad/features/workspace/data/models/page_model.dart';
import 'package:bdj_studio_sample_pad/features/midi/data/models/midi_mapping_model.dart';
import 'package:bdj_studio_sample_pad/features/macros/data/models/macro_model.dart';
import 'package:bdj_studio_sample_pad/features/settings/data/services/config_backup_service.dart';

/// Localiza la librería nativa de Isar empaquetada por `isar_community_flutter_libs`.
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
    if (entry['name'] != 'isar_community_flutter_libs') continue;
    final rootUri = entry['rootUri'];
    if (rootUri is! String) continue;
    final uri = Uri.parse(rootUri);
    final pkgDir = uri.isAbsolute
        ? Directory.fromUri(uri)
        : Directory(p.join(configDir.path, rootUri));
    // isar_community renombro la libreria nativa de Windows: `isar.dll` en el
    // paquete original, `libisar.dll` desde isar_community 3.2. Se prueban los
    // nombres conocidos y se devuelve el primero que exista, porque acertar mal
    // aqui falla en silencio: quien llama descarta la ruta inexistente, Isar cae
    // a su nombre por defecto relativo al directorio de trabajo y el sintoma es
    // un `error code 126` que no dice nada sobre la causa real.
    final candidates = <String>[
      if (Platform.isWindows) ...[
        p.join(pkgDir.path, 'windows', 'libisar.dll'),
        p.join(pkgDir.path, 'windows', 'isar.dll'),
      ],
      if (Platform.isMacOS) p.join(pkgDir.path, 'macos', 'libisar.dylib'),
      if (Platform.isLinux) p.join(pkgDir.path, 'linux', 'libisar.so'),
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }
  return null;
}

const _schemas = [
  PadModelSchema,
  SampleModelSchema,
  FolderModelSchema,
  GenreModelSchema,
  WorkspaceModelSchema,
  PageModelSchema,
  MidiMappingModelSchema,
  MacroModelSchema,
];

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
    tempRoot = await Directory.systemTemp.createTemp('backup_merge_test');
    mockPathProviderForAllPlatforms(tempRoot);
  });

  tearDown(() async {
    tearDownPathProviderMocks();
    try {
      await tempRoot.delete(recursive: true);
    } catch (_) {}
  });

  test(
      'mergeDatabase preserva parentPageId y targetPageIndex del arbol de '
      'carpetas al fusionar otra base', () async {
    // 1) Base "entrante" (la de un backup): workspace con 1 pagina raiz y una
    // pagina interna de carpeta cuyo parentPageId enlaza con la raiz.
    const importName = 'merge_import';
    final incomingDir = Directory(p.join(tempRoot.path, 'incoming'))
      ..createSync(recursive: true);
    final seed = await Isar.open(_schemas,
        directory: incomingDir.path, name: importName);
    final ws = WorkspaceModel()..name = 'Set Restaurado'..createdAt = DateTime.now();
    final root = PageModel()..pageIndex = 0..name = 'Página 1'..workspace.value = ws;
    await seed.writeTxn(() async {
      await seed.workspaceModels.put(ws);
      await seed.pageModels.put(root);
      await root.workspace.save();

      final folder = PageModel()
        ..pageIndex = 1000
        ..name = 'Carpeta A'
        ..workspace.value = ws;
      await seed.pageModels.put(folder);
      folder.parentPageId = root.id;
      await seed.pageModels.put(folder);

      final folderPad = PadModel()
        ..padId = 0
        ..label = 'Carpeta A'
        ..colorHex = 0xFF000000
        ..padTypeIndex = 1
        ..targetPageIndex = folder.pageIndex
        ..page.value = root;
      await seed.padModels.put(folderPad);
      await folderPad.page.save();

      ws.pages.addAll([root, folder]);
      await ws.pages.save();
    });
    final importedDb = File(p.join(incomingDir.path, '$importName.isar'));
    expect(importedDb.existsSync(), isTrue);
    await seed.close();

    // 2) Base "actual": sin workspaces, es la instancia por defecto que usa
    // ConfigBackupService a traves de Isar.getInstance().
    final currentDir = Directory(p.join(tempRoot.path, 'current'))
      ..createSync(recursive: true);
    final current = await Isar.open(_schemas, directory: currentDir.path);
    addTearDown(() => current.close());
    expect(Isar.getInstance(), same(current));

    // 3) Fusionar: la base entrante se elimina al terminar (deleteFromDisk).
    await ConfigBackupService.mergeDatabase(importedDb, importName, {});
    expect(importedDb.existsSync(), isFalse);

    // 4) El arbol de paginas debe conservarse: el parentPageId de la pagina
    // interna ahora apunta al id NUEVO de la raiz, y el pad-carpeta sigue
    // apuntando por pageIndex a su pagina interna.
    final workspaces = await current.workspaceModels.where().findAll();
    expect(workspaces.length, 1);
    expect(workspaces.single.name, 'Set Restaurado');

    final pages = await current.pageModels
        .filter()
        .workspace((q) => q.idEqualTo(workspaces.single.id))
        .findAll();
    expect(pages.length, 2);
    final mergedRoot = pages.firstWhere((p) => p.parentPageId == null);
    final mergedFolder = pages.firstWhere((p) => p.parentPageId != null);
    expect(mergedFolder.parentPageId, mergedRoot.id,
        reason: 'la pagina interna debe conservar su parentPageId remapeado');
    expect(mergedFolder.pageIndex, 1000);

    await mergedRoot.pads.load();
    final folderPads = mergedRoot.pads
        .where((pad) => pad.padTypeIndex == 1)
        .toList();
    expect(folderPads.length, 1);
    expect(folderPads.single.targetPageIndex, mergedFolder.pageIndex,
        reason: 'el pad-carpeta debe seguir enlazado a su pagina interna');
  });
}
