import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;

import '../../helpers/path_provider_test_helper.dart';

import 'package:bdj_studio_sample_pad/core/services/local_audio_storage_service.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/data/models/pad_model.dart';
import 'package:bdj_studio_sample_pad/features/workspace/data/models/page_model.dart';
import 'package:bdj_studio_sample_pad/features/workspace/data/models/workspace_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/folder_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/genre_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/sample_model.dart';

/// Consistencia del formato `app_local://<workspace>/<...>/<archivo>`.
///
/// Ese string es la única forma que tiene un pad de encontrar su audio. Se
/// genera en dos sitios distintos (al importar un archivo suelto y al importar
/// una carpeta completa) y se consume en un tercero (la migración al renombrar
/// un workspace). Si los tres no coinciden en el separador, el pad queda mudo.
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

Future<Isar> _openIsar(Directory tempRoot) {
  final dbDir = Directory(p.join(tempRoot.path, 'db'))
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
    tempRoot = await Directory.systemTemp.createTemp('sample_path_test');
    mockPathProviderForAllPlatforms(tempRoot);
  });

  tearDown(() async {
    tearDownPathProviderMocks();
    try {
      await tempRoot.delete(recursive: true);
    } catch (_) {}
  });

  /// Crea un audio de origen fuera de la biblioteca, como el que el usuario
  /// arrastra desde su disco.
  Future<File> makeSourceAudio(String name) async {
    final src = File(p.join(tempRoot.path, 'origen', name));
    await src.parent.create(recursive: true);
    await src.writeAsBytes(List<int>.filled(64, 7));
    return src;
  }

  group('formato de samplePath generado por importAudioFile', () {
    test('devuelve una URI con el prefijo app_local://', () async {
      final src = await makeSourceAudio('kick.wav');

      final uri = await LocalAudioStorageService.importAudioFile(
        src.path,
        namespace: 'Set A',
      );

      expect(uri, startsWith(LocalAudioStorageService.prefix));
    });

    test('usa "/" como separador, igual que el importador de carpetas',
        () async {
      // El importador de workspaces construye el path a mano con "/", y
      // migrateWorkspaceSamplePaths busca por el prefijo "app_local://<ws>/".
      // Si importAudioFile usa el separador nativo, en Windows los dos
      // formatos divergen y la migración deja de encontrar estos pads.
      final src = await makeSourceAudio('snare.wav');

      final uri = await LocalAudioStorageService.importAudioFile(
        src.path,
        namespace: 'Set A',
      );

      expect(
        uri,
        isNot(contains(r'\')),
        reason: 'samplePath debe ser independiente de la plataforma',
      );
      expect(uri, 'app_local://Set A/snare.wav');
    });

    test('la ruta anidada también usa "/" en todos los niveles', () async {
      final src = await makeSourceAudio('hat.wav');

      final uri = await LocalAudioStorageService.importAudioFile(
        src.path,
        namespace: 'Set A/Drums/Hats',
      );

      expect(uri, 'app_local://Set A/Drums/Hats/hat.wav');
    });

    test('importAudioBytes produce el mismo formato que importAudioFile',
        () async {
      final uri = await LocalAudioStorageService.importAudioBytes(
        'clap.wav',
        List<int>.filled(32, 1),
        namespace: 'Set A/Perc',
      );

      expect(uri, 'app_local://Set A/Perc/clap.wav');
    });

    test('resolvePath() reconstruye una ruta existente en disco', () async {
      final src = await makeSourceAudio('tom.wav');
      final uri = await LocalAudioStorageService.importAudioFile(
        src.path,
        namespace: 'Set A/Drums',
      );

      final resolved = await LocalAudioStorageService.resolvePath(uri);

      expect(File(resolved).existsSync(), isTrue);
    });

    test('nombres duplicados no se pisan entre sí', () async {
      final src = await makeSourceAudio('loop.wav');

      final first = await LocalAudioStorageService.importAudioFile(
        src.path,
        namespace: 'Set A',
      );
      final second = await LocalAudioStorageService.importAudioFile(
        src.path,
        namespace: 'Set A',
      );

      expect(first, isNot(second));
      expect(File(await LocalAudioStorageService.resolvePath(first)).existsSync(),
          isTrue);
      expect(
          File(await LocalAudioStorageService.resolvePath(second)).existsSync(),
          isTrue);
    });
  });

  group('migrateWorkspaceSamplePaths al renombrar un workspace', () {
    /// Inserta un pad con el samplePath dado y devuelve su id.
    Future<int> seedPad(Isar isar, String samplePath) async {
      final ws = WorkspaceModel()
        ..name = 'Set A'
        ..createdAt = DateTime.now();
      final page = PageModel()
        ..pageIndex = 0
        ..workspace.value = ws;
      final pad = PadModel()
        ..padId = 0
        ..label = 'Kick'
        ..colorHex = 0xFF000000
        ..samplePath = samplePath
        ..page.value = page;

      await isar.writeTxn(() async {
        await isar.workspaceModels.put(ws);
        await isar.pageModels.put(page);
        await page.workspace.save();
        await isar.padModels.put(pad);
        await pad.page.save();
      });
      return pad.id;
    }

    test('migra un samplePath escrito por el importador de carpetas', () async {
      final isar = await _openIsar(tempRoot);
      addTearDown(() => isar.close());
      final padId = await seedPad(isar, 'app_local://Set A/kick.wav');

      final migrated = await LocalAudioStorageService
          .migrateWorkspaceSamplePaths(isar, 'Set A', 'Set B');

      expect(migrated, 1);
      expect(
        (await isar.padModels.get(padId))!.samplePath,
        'app_local://Set B/kick.wav',
      );
    });

    test('migra un samplePath producido por importAudioFile', () async {
      // Este es el caso real de un pad al que el DJ le asignó un audio desde
      // el explorador: si el formato no coincide, el pad queda apuntando al
      // nombre viejo del workspace y se queda sin sonido tras renombrarlo.
      final isar = await _openIsar(tempRoot);
      addTearDown(() => isar.close());
      final src = await makeSourceAudio('kick.wav');
      final uri = await LocalAudioStorageService.importAudioFile(
        src.path,
        namespace: 'Set A',
      );
      final padId = await seedPad(isar, uri);

      final migrated = await LocalAudioStorageService
          .migrateWorkspaceSamplePaths(isar, 'Set A', 'Set B');

      expect(
        migrated,
        1,
        reason: 'el pad de un audio importado también debe migrarse',
      );
      expect(
        (await isar.padModels.get(padId))!.samplePath,
        startsWith('app_local://Set B'),
      );
    });

    test('no toca pads de otros workspaces', () async {
      final isar = await _openIsar(tempRoot);
      addTearDown(() => isar.close());
      final padId = await seedPad(isar, 'app_local://Otro Set/kick.wav');

      final migrated = await LocalAudioStorageService
          .migrateWorkspaceSamplePaths(isar, 'Set A', 'Set B');

      expect(migrated, 0);
      expect(
        (await isar.padModels.get(padId))!.samplePath,
        'app_local://Otro Set/kick.wav',
      );
    });

    test('un samplePath heredado con "\\" se migra tras normalizarlo',
        () async {
      // Estado real de una base creada por una versión anterior en Windows.
      final isar = await _openIsar(tempRoot);
      addTearDown(() => isar.close());
      final padId = await seedPad(isar, r'app_local://Set A\Drums\kick.wav');

      await LocalAudioStorageService.normalizeLegacySamplePaths(isar);
      final migrated = await LocalAudioStorageService
          .migrateWorkspaceSamplePaths(isar, 'Set A', 'Set B');

      expect(migrated, 1);
      expect(
        (await isar.padModels.get(padId))!.samplePath,
        'app_local://Set B/Drums/kick.wav',
      );
    });

    test('renombrar al mismo nombre no hace trabajo', () async {
      final isar = await _openIsar(tempRoot);
      addTearDown(() => isar.close());
      await seedPad(isar, 'app_local://Set A/kick.wav');

      final migrated = await LocalAudioStorageService
          .migrateWorkspaceSamplePaths(isar, 'Set A', 'Set A');

      expect(migrated, 0);
    });
  });

  group('normalizeLegacySamplePaths', () {
    Future<int> seedRawPad(Isar isar, String samplePath) async {
      final ws = WorkspaceModel()
        ..name = 'Set A'
        ..createdAt = DateTime.now();
      final page = PageModel()
        ..pageIndex = 0
        ..workspace.value = ws;
      final pad = PadModel()
        ..padId = 0
        ..label = 'Kick'
        ..colorHex = 0xFF000000
        ..samplePath = samplePath
        ..page.value = page;
      await isar.writeTxn(() async {
        await isar.workspaceModels.put(ws);
        await isar.pageModels.put(page);
        await page.workspace.save();
        await isar.padModels.put(pad);
        await pad.page.save();
      });
      return pad.id;
    }

    test('convierte los separadores de Windows a "/"', () async {
      final isar = await _openIsar(tempRoot);
      addTearDown(() => isar.close());
      final padId = await seedRawPad(isar, r'app_local://Set A\Drums\kick.wav');

      final migrated =
          await LocalAudioStorageService.normalizeLegacySamplePaths(isar);

      expect(migrated, 1);
      expect(
        (await isar.padModels.get(padId))!.samplePath,
        'app_local://Set A/Drums/kick.wav',
      );
    });

    test('no toca los que ya están normalizados', () async {
      final isar = await _openIsar(tempRoot);
      addTearDown(() => isar.close());
      await seedRawPad(isar, 'app_local://Set A/kick.wav');

      expect(
        await LocalAudioStorageService.normalizeLegacySamplePaths(isar),
        0,
      );
    });

    test('es idempotente: la segunda pasada no migra nada', () async {
      final isar = await _openIsar(tempRoot);
      addTearDown(() => isar.close());
      await seedRawPad(isar, r'app_local://Set A\kick.wav');

      await LocalAudioStorageService.normalizeLegacySamplePaths(isar);

      expect(
        await LocalAudioStorageService.normalizeLegacySamplePaths(isar),
        0,
      );
    });

    test('una base sin pads no falla', () async {
      final isar = await _openIsar(tempRoot);
      addTearDown(() => isar.close());

      expect(
        await LocalAudioStorageService.normalizeLegacySamplePaths(isar),
        0,
      );
    });
  });

  group('cleanUnusedAudioFiles', () {
    test('borra un audio que ya no referencia ningún pad', () async {
      final src = await makeSourceAudio('huerfano.wav');
      final uri = await LocalAudioStorageService.importAudioFile(
        src.path,
        namespace: 'Set A',
      );
      final onDisk = await LocalAudioStorageService.resolvePath(uri);

      final deleted = await LocalAudioStorageService.cleanUnusedAudioFiles([]);

      expect(deleted, greaterThan(0));
      expect(File(onDisk).existsSync(), isFalse);
    });

    test('conserva un audio referenciado por su URI app_local://', () async {
      final src = await makeSourceAudio('en_uso.wav');
      final uri = await LocalAudioStorageService.importAudioFile(
        src.path,
        namespace: 'Set A',
      );
      final onDisk = await LocalAudioStorageService.resolvePath(uri);

      await LocalAudioStorageService.cleanUnusedAudioFiles([uri]);

      expect(File(onDisk).existsSync(), isTrue);
    });

    test('conserva un audio referenciado por ruta absoluta heredada', () async {
      // Los pads creados por versiones anteriores guardan la ruta absoluta en
      // vez de la URI. La limpieza solo mira las entradas con prefijo, así que
      // esos audios se ven como huérfanos y se borran con el pad aún usándolos.
      final src = await makeSourceAudio('heredado.wav');
      final uri = await LocalAudioStorageService.importAudioFile(
        src.path,
        namespace: 'Set A',
      );
      final absolutePath = await LocalAudioStorageService.resolvePath(uri);

      await LocalAudioStorageService.cleanUnusedAudioFiles([absolutePath]);

      expect(
        File(absolutePath).existsSync(),
        isTrue,
        reason: 'un pad con ruta absoluta sigue usando este audio',
      );
    });
  });
}
