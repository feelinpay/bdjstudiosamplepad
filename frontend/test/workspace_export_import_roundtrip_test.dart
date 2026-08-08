import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:archive/archive_io.dart';
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
import 'package:bdj_studio_sample_pad/features/workspace/domain/services/workspace_exporter.dart';
import 'package:bdj_studio_sample_pad/core/services/local_audio_storage_service.dart';

/// Localiza la librería nativa de Isar empaquetada por `isar_flutter_libs`
/// (dependencia de ruta local) para cargarla en `flutter test`.
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

/// Snapshot de la jerarquía de un workspace: página -> (nombre, pageIndex del
/// padre, nº de pads de audio, targets de los pads-carpeta). Permite comparar
/// la estructura original con la reimportada sin depender de ids internos.
Future<Map<int, Map<String, dynamic>>> _snapshotHierarchy(
  Isar isar,
  int workspaceId,
) async {
  final ws = await isar.workspaceModels.get(workspaceId);
  final pages = await isar.pageModels
      .filter()
      .workspace((q) => q.idEqualTo(ws!.id))
      .findAll();
  final indexById = {for (final pg in pages) pg.id: pg.pageIndex};

  final result = <int, Map<String, dynamic>>{};
  for (final page in pages) {
    await page.pads.load();
    final folderTargets = <int>[];
    var audioCount = 0;
    for (final pad in page.pads.toList()) {
      if (pad.padTypeIndex == 1) {
        if (pad.targetPageIndex != null) folderTargets.add(pad.targetPageIndex!);
      } else if (pad.padTypeIndex == 0) {
        audioCount++;
      }
    }
    folderTargets.sort();
    result[page.pageIndex] = {
      'name': page.name,
      'parent': page.parentPageId == null ? null : indexById[page.parentPageId!],
      'audioCount': audioCount,
      'folderTargets': folderTargets,
    };
  }
  return result;
}

/// Regresión 1.1 de punta a punta: exportar un workspace CON carpetas anidadas
/// debe generar un `.sppworkspace` no vacío (antes salía con 0 entradas) y ese
/// archivo debe contener la información suficiente para reimportarlo
/// reproduciendo la misma jerarquía (páginas raíz/carpeta, padres, pads y audios).
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
    tempRoot = await Directory.systemTemp.createTemp('export_import_test');
    mockPathProviderForAllPlatforms(tempRoot);
  });

  tearDown(() async {
    tearDownPathProviderMocks();
    try {
      await tempRoot.delete(recursive: true);
    } catch (_) {}
  });

  Future<Isar> openDb(String name) {
    final dbDir = Directory(p.join(tempRoot.path, name))
      ..createSync(recursive: true);
    return Isar.open([
      WorkspaceModelSchema,
      PageModelSchema,
      PadModelSchema,
      SampleModelSchema,
      GenreModelSchema,
      FolderModelSchema,
    ], directory: dbDir.path, name: name);
  }

  test('export→import ida y vuelta reproduce la jerarquía de carpetas anidadas',
      () async {
    // 1) Carpeta fuente con estructura anidada real.
    final src = Directory(p.join(tempRoot.path, 'Set en vivo'));
    Directory(p.join(src.path, 'Drums', 'Kicks')).createSync(recursive: true);
    Directory(p.join(src.path, 'Drums', 'Perc')).createSync(recursive: true);
    Directory(p.join(src.path, 'Vocals')).createSync(recursive: true);
    File(p.join(src.path, 'raiz.wav')).writeAsBytesSync(List.generate(256, (i) => i));
    File(
      p.join(src.path, 'Drums', 'Kicks', 'kick_one.wav'),
    ).writeAsBytesSync(List.generate(512, (i) => (i * 3) % 256));
    File(
      p.join(src.path, 'Drums', 'Perc', 'shaker.flac'),
    ).writeAsBytesSync(List.generate(128, (i) => (i * 7) % 256));
    File(
      p.join(src.path, 'Vocals', 'hook.mp3'),
    ).writeAsBytesSync(List.generate(384, (i) => (i * 11) % 256));

    // 2) Importar en DB1 (misma ruta que la app).
    final db1 = await openDb('db1');
    addTearDown(() => db1.close());
    final importer = WorkspaceImporter(Future.value(db1));
    final ws1 = await importer.importWorkspace(src.path);
    expect(ws1, isNotNull, reason: 'el import inicial debe crear el workspace');
    if (ws1 == null) return;

    final original = await _snapshotHierarchy(db1, ws1.id);
    expect(
      original.keys,
      containsAll(<int>[0, 1000, 1001, 1002]),
      reason: 'raíz + Drums + Kicks + Perc + Vocals (4 carpetas en DB)',
    );
    expect(original.keys.length, 5);

    // 3) Exportar con el flujo real (incluye compute/zip).
    final exporter = WorkspaceExporter(Future.value(db1));
    final exportPath = await exporter.exportWorkspace(ws1.id);
    expect(exportPath, isNotNull, reason: 'el export debe devolver una ruta');
    if (exportPath == null) return;

    final zipFile = File(exportPath);
    expect(
      zipFile.existsSync(),
      isTrue,
      reason: '1.1: el .sppworkspace debe existir en disco',
    );
    expect(
      zipFile.lengthSync(),
      greaterThan(0),
      reason: '1.1: el .sppworkspace NO puede quedar vacío (regresión principal)',
    );

    // 4) El zip debe contener metadata.json y todos los audios. El exporter
    //    renombra los archivos con un prefijo numérico (dedupe por samplePath),
    //    así que se verifica que cada audio original viaja con su nombre intacto.
    final archive = ZipDecoder().decodeBytes(zipFile.readAsBytesSync());
    final byBaseName = {for (final f in archive.files) p.basename(f.name): f};
    expect(byBaseName.keys, contains('metadata.json'));

    final expectedAudioNames = <String>{
      'raiz.wav',
      'kick_one.wav',
      'shaker.flac',
      'hook.mp3',
    };
    final mediaEntries = byBaseName.keys
        .where((name) => name != 'metadata.json')
        .where((name) => !name.endsWith('/'))
        .toList();
    expect(
      mediaEntries.length,
      expectedAudioNames.length,
      reason: 'todos los audios de la jerarquía viajan en el export',
    );
    final strippedNames =
        mediaEntries.map((n) => n.replaceFirst(RegExp(r'^\d+_'), '')).toSet();
    expect(
      strippedNames,
      equals(expectedAudioNames),
      reason: 'cada audio conserva su nombre original dentro del export',
    );

    // 5) La metadata exportada codifica la jerarquía completa.
    final metadata = jsonDecode(
      utf8.decode(byBaseName['metadata.json']!.content as List<int>),
    ) as Map<String, dynamic>;
    final metaPages = (metadata['pages'] as List).cast<Map<String, dynamic>>();
    final metaPads = (metadata['pads'] as List).cast<Map<String, dynamic>>();

    expect(metaPages.length, original.length);
    for (final entry in original.entries) {
      final metaPage = metaPages.firstWhere(
        (pg) => pg['pageIndex'] == entry.key,
        orElse: () => <String, dynamic>{},
      );
      expect(metaPage, isNotEmpty, reason: 'la página ${entry.key} debe exportarse');
      expect(metaPage['name'], entry.value['name']);
      expect(metaPage['parentPageIndex'], entry.value['parent']);
    }

    final originalAudioCount = original.values
        .map((v) => v['audioCount'] as int)
        .fold(0, (a, b) => a + b);
    final exportedAudioPads =
        metaPads.where((pad) => pad['padTypeIndex'] == 0).toList();
    expect(exportedAudioPads.length, originalAudioCount);
    for (final pad in exportedAudioPads) {
      final media = pad['media'] as String?;
      expect(media, isNotNull, reason: 'todo pad de audio exporta su archivo');
      expect(
        byBaseName.containsKey(media),
        isTrue,
        reason: 'el audio $media debe viajar dentro del .sppworkspace',
      );
    }

    // 6) Reimportar: reconstruir el árbol de carpetas desde la metadata (lo que
    //    haría una restauración) y pasárselo al importador de la app en DB2.
    final rebuildRoot = Directory(p.join(tempRoot.path, 'rebuild'))
      ..createSync(recursive: true);
    final nameByIndex = {
      for (final pg in metaPages) pg['pageIndex'] as int: pg['name'] as String,
    };
    final parentByIndex = {
      for (final pg in metaPages)
        pg['pageIndex'] as int: pg['parentPageIndex'] as int?,
    };
    final dirByIndex = <int, String>{};
    String dirFor(int idx) {
      final cached = dirByIndex[idx];
      if (cached != null) return cached;
      final parent = parentByIndex[idx];
      if (parent == null) {
        dirByIndex[idx] = rebuildRoot.path;
        return rebuildRoot.path;
      }
      final dir = p.join(dirFor(parent), nameByIndex[idx]!);
      dirByIndex[idx] = dir;
      return dir;
    }

    for (final idx in metaPages.map((pg) => pg['pageIndex'] as int)) {
      Directory(dirFor(idx)).createSync(recursive: true);
    }
    for (final pad in exportedAudioPads) {
      final media = pad['media'] as String;
      final entry = byBaseName[media];
      if (entry == null) continue;
      File(p.join(dirFor(pad['pageIndex'] as int), media))
          .writeAsBytesSync(entry.content as List<int>);
    }

    final db2 = await openDb('db2');
    addTearDown(() => db2.close());
    final ws2 = await WorkspaceImporter(Future.value(db2))
        .importWorkspace(rebuildRoot.path);
    expect(ws2, isNotNull, reason: 'el workspace reimportado debe crearse');
    if (ws2 == null) return;

    // 7) La jerarquía reimportada debe ser idéntica a la original.
    final reimported = await _snapshotHierarchy(db2, ws2.id);
    expect(reimported, equals(original));

    // 8) Los audios reimportados existen en disco.
    final pages = await db2.pageModels
        .filter()
        .workspace((q) => q.idEqualTo(ws2.id))
        .findAll();
    var audioPadsOnDisk = 0;
    for (final page in pages) {
      await page.pads.load();
      for (final pad in page.pads.toList()) {
        if (pad.padTypeIndex != 0) continue;
        final abs = await LocalAudioStorageService.resolvePath(pad.samplePath!);
        expect(File(abs).existsSync(), isTrue,
            reason: 'el audio ${pad.samplePath} debe copiarse en media');
        audioPadsOnDisk++;
      }
    }
    expect(audioPadsOnDisk, originalAudioCount);
  });
}
