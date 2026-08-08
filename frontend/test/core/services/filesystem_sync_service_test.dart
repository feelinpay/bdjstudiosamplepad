import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;

import '../../helpers/path_provider_test_helper.dart';

import 'package:bdj_studio_sample_pad/core/services/app_storage_service.dart';
import 'package:bdj_studio_sample_pad/core/services/filesystem_sync_service.dart';
import 'package:bdj_studio_sample_pad/core/services/local_audio_storage_service.dart';
import 'package:bdj_studio_sample_pad/features/workspace/data/models/workspace_model.dart';
import 'package:bdj_studio_sample_pad/features/workspace/data/models/page_model.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/data/models/pad_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/sample_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/folder_model.dart';
import 'package:bdj_studio_sample_pad/features/sample_library/data/models/genre_model.dart';

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

Future<Isar> _openIsar(Directory tempRoot) {
  final dbDir = Directory(p.join(tempRoot.path, 'db'))
    ..createSync(recursive: true);
  return Isar.open([
    WorkspaceModelSchema,
    PageModelSchema,
    PadModelSchema,
    SampleModelSchema,
    FolderModelSchema,
    GenreModelSchema,
  ], directory: dbDir.path);
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
    tempRoot = await Directory.systemTemp.createTemp('sync_test');
    mockPathProviderForAllPlatforms(tempRoot);
  });

  tearDown(() async {
    tearDownPathProviderMocks();
    try {
      await tempRoot.delete(recursive: true);
    } catch (_) {}
  });

  /// En la plataforma de test (Windows) AppStorageService._rootPath sube un
  /// nivel del support dir y usa el nombre de la app, de modo que:
  ///   support  → tempRoot/support
  ///   root     → tempRoot/BDJ Studio Sample Pad
  ///   mediaDir → tempRoot/BDJ Studio Sample Pad/Assets/Audio
  Future<Directory> _expectedMediaDir() async {
    return await AppStorageService.mediaDirectory();
  }

  /// El directorio que el código viejo usava (tempRoot/BDJ Studio Sample Pad/media).
  Future<Directory> _legacyMediaDir() async {
    final root = await AppStorageService.root();
    return Directory(p.join(root.path, 'media'));
  }

  test(
    'reconcileOnStartup detecta workspaces dentro de Assets/Audio (no media)',
    () async {
      final mediaDir = await _expectedMediaDir();

      // Crear un workspace con un archivo de audio dentro de Assets/Audio.
      final wsDir = Directory(p.join(mediaDir.path, 'Mi Set'));
      await wsDir.create(recursive: true);
      File(p.join(wsDir.path, 'kick.wav')).writeAsBytesSync([1, 2, 3]);

      // El directorio legado "media" no debe crearse.
      final legacyDir = await _legacyMediaDir();

      final isar = await _openIsar(tempRoot);
      addTearDown(() => isar.close());

      final count = await FilesystemSyncService.reconcileOnStartup(isar);

      expect(count, greaterThan(0), reason: 'debe detectar el workspace nuevo');

      // Verificar que el workspace aparece en la base.
      final workspaces = await isar.workspaceModels.where().findAll();
      expect(workspaces.map((w) => w.name), contains('Mi Set'));

      // El directorio legacy "media" no debe haberse creado.
      expect(await legacyDir.exists(), isFalse);
    },
  );

  test('reconcileOnStartup detecta archivos de audio en subcarpetas', () async {
    final mediaDir = await _expectedMediaDir();

    // Crear estructura: Mi Set/Drums/kick.wav, Mi Set/Vocals/vox.wav
    final drumsDir = Directory(p.join(mediaDir.path, 'Mi Set', 'Drums'));
    final vocalsDir = Directory(p.join(mediaDir.path, 'Mi Set', 'Vocals'));
    await drumsDir.create(recursive: true);
    await vocalsDir.create(recursive: true);
    File(p.join(drumsDir.path, 'kick.wav')).writeAsBytesSync([1]);
    File(p.join(vocalsDir.path, 'vox.wav')).writeAsBytesSync([2]);

    final isar = await _openIsar(tempRoot);
    addTearDown(() => isar.close());

    await FilesystemSyncService.reconcileOnStartup(isar);

    final ws = (await isar.workspaceModels.where().findAll()).single;
    await ws.pages.load();

    // Debe tener la página raíz + 2 páginas ocultas para Drums y Vocals.
    expect(ws.pages.length, 3);

    // Cargar pads de todas las páginas y verificar que los audios existen en
    // disco resolviéndolos a través de LocalAudioStorageService.
    int audioPadsFound = 0;
    for (final page in ws.pages.toList()) {
      await page.pads.load();
      for (final pad in page.pads.toList()) {
        if (pad.padTypeIndex == 0 &&
            pad.samplePath != null &&
            pad.samplePath!.isNotEmpty) {
          final resolved =
              await LocalAudioStorageService.resolvePath(pad.samplePath!);
          expect(File(resolved).existsSync(), isTrue,
              reason: 'el audio del pad debe existir en disco');
          audioPadsFound++;
        }
      }
    }
    expect(audioPadsFound, 2, reason: 'debe encontrar kick.wav y vox.wav');
  });

  test('startLiveWatcher vigila Assets/Audio, no el directorio media', () async {
    final mediaDir = await _expectedMediaDir();
    final legacyDir = await _legacyMediaDir();

    final isar = await _openIsar(tempRoot);
    addTearDown(() async {
      FilesystemSyncService.stopLiveWatcher();
      await isar.close();
    });

    FilesystemSyncService.startLiveWatcher(isar);

    // El watcher debe estar activo.
    // Si escribe un archivo nuevo en Assets/Audio, la reconciliación lo detecta.
    final wsDir = Directory(p.join(mediaDir.path, 'Watcher Set'));
    await wsDir.create(recursive: true);
    File(p.join(wsDir.path, 'snare.wav')).writeAsBytesSync([3, 4, 5]);

    // Esperar al debounce del watcher (2s por defecto).
    await Future.delayed(const Duration(milliseconds: 500));
    await FilesystemSyncService.reconcileOnStartup(isar);

    final workspaces = await isar.workspaceModels.where().findAll();
    expect(workspaces.map((w) => w.name), contains('Watcher Set'));

    // El directorio legacy "media" nunca debe haberse creado.
    expect(await legacyDir.exists(), isFalse);
  });

  test('no crea el directorio legacy root/media al reconciliar', () async {
    final legacyDir = await _legacyMediaDir();

    final isar = await _openIsar(tempRoot);
    addTearDown(() => isar.close());

    await FilesystemSyncService.reconcileOnStartup(isar);

    expect(await legacyDir.exists(), isFalse,
        reason:
            'reconcileOnStartup no debe crear el directorio legacy "media"');
  });

  test('normalizeLegacySamplePaths corrige separadores de Windows', () async {
    final isar = await _openIsar(tempRoot);
    addTearDown(() => isar.close());

    // El media dir real (Assets/Audio) debe existir para crear el archivo.
    final mediaDir = await AppStorageService.mediaDirectory();

    // Sembrar un pad con separador de Windows en samplePath.
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
      ..samplePath = r'app_local://Set A\Drums\kick.wav'
      ..page.value = page;

    // Crear el archivo físico con la ruta corregida para que resolvePath funcione.
    final fileDir = Directory(p.join(mediaDir.path, 'Set A', 'Drums'));
    await fileDir.create(recursive: true);
    File(p.join(fileDir.path, 'kick.wav')).writeAsBytesSync([1, 2, 3]);

    await isar.writeTxn(() async {
      await isar.workspaceModels.put(ws);
      await isar.pageModels.put(page);
      await page.workspace.save();
      await isar.padModels.put(pad);
      await pad.page.save();
    });

    final migrated =
        await LocalAudioStorageService.normalizeLegacySamplePaths(isar);

    expect(migrated, 1);
    final savedPad = (await isar.padModels.where().findAll()).single;
    expect(savedPad.samplePath, 'app_local://Set A/Drums/kick.wav');

    // La ruta normalizada debe resolver a un archivo que existe en disco.
    final resolved =
        await LocalAudioStorageService.resolvePath(savedPad.samplePath!);
    expect(File(resolved).existsSync(), isTrue);
  });
}
