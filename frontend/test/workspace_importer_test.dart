import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;

import 'helpers/path_provider_test_helper.dart';

import 'package:bdj_studio_sample_pad/features/workspace/data/models/workspace_model.dart';
import 'package:bdj_studio_sample_pad/features/workspace/data/models/page_model.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/data/models/pad_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/sample_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/genre_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/folder_model.dart';
import 'package:bdj_studio_sample_pad/features/workspace/domain/services/workspace_importer.dart';

/// Localiza la librería nativa de Isar empaquetada por `isar_flutter_libs`
/// (dependencia de ruta local) para cargarla en `flutter test`.
/// Funciona en Windows, macOS y Linux sin depender del pub cache.
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
    tempRoot = await Directory.systemTemp.createTemp('import_test');
    mockPathProviderForAllPlatforms(tempRoot);
  });

  tearDown(() async {
    tearDownPathProviderMocks();
    try {
      await tempRoot.delete(recursive: true);
    } catch (_) {}
  });

  test('importa estructura completa: carpetas, subcarpetas y audios', () async {
    final dbDir = Directory(p.join(tempRoot.path, 'db'))
      ..createSync(recursive: true);
    final isar = await Isar.open([
      WorkspaceModelSchema,
      PageModelSchema,
      PadModelSchema,
      SampleModelSchema,
      GenreModelSchema,
      FolderModelSchema,
    ], directory: dbDir.path);
    addTearDown(() => isar.close());

    final src = Directory(p.join(tempRoot.path, 'voces'));
    Directory(p.join(src.path, 'Carpeta1')).createSync(recursive: true);
    Directory(
      p.join(src.path, 'Carpeta1', 'SubCarpeta'),
    ).createSync(recursive: true);
    Directory(p.join(src.path, 'Carpeta2')).createSync(recursive: true);
    File(p.join(src.path, 'raiz.wav')).writeAsBytesSync([1, 2, 3]);
    File(
      p.join(src.path, 'Carpeta1', 'audio_uno.mp3'),
    ).writeAsBytesSync([1, 2, 3]);
    File(
      p.join(src.path, 'Carpeta1', 'SubCarpeta', 'audio_dos.flac'),
    ).writeAsBytesSync([1, 2, 3]);
    File(p.join(src.path, 'Carpeta2', 'otro.wav')).writeAsBytesSync([1, 2, 3]);

    final importer = WorkspaceImporter(Future.value(isar));
    final ws = await importer.importWorkspace(src.path);
    expect(ws, isNotNull, reason: 'El import debió devolver un workspace');
    if (ws == null) return;

    await ws.pages.load();

    // Verificaciones de estructura esperada.
    final pageByIndex = {for (final pg in ws.pages.toList()) pg.pageIndex: pg};
    expect(
      pageByIndex.containsKey(0),
      isTrue,
      reason: 'Debe existir página raíz',
    );
    expect(
      ws.pages.length,
      4,
      reason: 'Raíz + Carpeta1 + SubCarpeta + Carpeta2',
    );

    // Raíz: folder pads a Carpetas + audio raiz.wav.
    final root = pageByIndex[0]!;
    await root.pads.load();
    final rootFolderPads = root.pads.where((p) => p.padTypeIndex == 1).toList();
    expect(rootFolderPads.length, 2, reason: 'Raíz debe tener 2 pads-carpeta');
    final rootAudioPads = root.pads.where((p) => p.padTypeIndex == 0).toList();
    expect(rootAudioPads.length, 1, reason: 'Raíz debe tener 1 pad de audio');

    // Carpeta1: audio_uno.mp3 + folder pad a SubCarpeta.
    final carpeta1Page = pageByIndex.values
        .where((pg) => pg.name == 'Carpeta1')
        .first;
    await carpeta1Page.pads.load();
    expect(
      carpeta1Page.pads.where((p) => p.padTypeIndex == 0).length,
      1,
      reason: 'Carpeta1 debe tener su audio',
    );

    // SubCarpeta: audio_dos.flac.
    final subPage = pageByIndex.values
        .where((pg) => pg.name == 'SubCarpeta')
        .first;
    await subPage.pads.load();
    expect(
      subPage.pads.where((p) => p.padTypeIndex == 0).length,
      1,
      reason: 'SubCarpeta debe tener su audio',
    );

    // Los archivos deben existir en disco dentro de media.
    final mediaDir = Directory(
      p.join(tempRoot.path, 'BDJ Studio Sample Pad', 'Assets', 'Audio'),
    );
    expect(
      File(
        p.join(mediaDir.path, ws.name, 'Carpeta1', 'audio_uno.mp3'),
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        p.join(
          mediaDir.path,
          ws.name,
          'Carpeta1',
          'SubCarpeta',
          'audio_dos.flac',
        ),
      ).existsSync(),
      isTrue,
    );
  });
}
