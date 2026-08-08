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

  /// En la plataforma de test la raíz de datos es el support dir de path_provider:
  ///   support  → tempRoot/support
  ///   root     → tempRoot/support
  ///   mediaDir → tempRoot/support/Assets/Audio
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

  test(
    'reconcileOnStartup ignora directorios internos (folder_imports) sin crear workspace fantasma',
    () async {
      final mediaDir = await _expectedMediaDir();
      final internalDir = Directory(p.join(mediaDir.path, 'folder_imports'));
      final imported = Directory(p.join(internalDir.path, 'Mi Set'));
      await imported.create(recursive: true);
      File(p.join(imported.path, 'kick.wav')).writeAsBytesSync([1, 2, 3]);

      final isar = await _openIsar(tempRoot);
      addTearDown(() => isar.close());

      final count = await FilesystemSyncService.reconcileOnStartup(isar);

      final workspaces = await isar.workspaceModels.where().findAll();
      expect(workspaces, isEmpty,
          reason: 'folder_imports no debe registrar workspaces fantasma');
      expect(count, 0);
    },
  );

  test(
    'reconcileOnStartup conserva folder pads importados cuyo audio vive en folder_imports',
    () async {
      final mediaDir = await _expectedMediaDir();

      // Workspace real con su carpeta física vacía.
      final wsDir = Directory(p.join(mediaDir.path, 'Set A'));
      await wsDir.create(recursive: true);

      // El audio importado vive en folder_imports/Mi Set/kick.wav.
      final importedDir = Directory(
        p.join(mediaDir.path, 'folder_imports', 'Mi Set'),
      );
      await importedDir.create(recursive: true);
      File(p.join(importedDir.path, 'kick.wav')).writeAsBytesSync([1, 2, 3]);

      final isar = await _openIsar(tempRoot);
      addTearDown(() => isar.close());

      // Sembrar workspace + folder pad + página oculta + audio.
      final ws = WorkspaceModel()
        ..name = 'Set A'
        ..createdAt = DateTime.now();
      final rootPage = PageModel()
        ..pageIndex = 0
        ..workspace.value = ws;
      final hiddenPage = PageModel()
        ..pageIndex = 1000
        ..workspace.value = ws;
      final folderPad = PadModel()
        ..padId = 0
        ..label = 'Mi Set'
        ..colorHex = 0xFF7C4DFF
        ..padTypeIndex = 1
        ..targetPageIndex = 1000
        ..page.value = rootPage;
      final audioPad = PadModel()
        ..padId = 1
        ..label = 'Kick'
        ..colorHex = 0xFF000000
        ..padTypeIndex = 0
        ..samplePath = 'app_local://folder_imports/Mi Set/kick.wav'
        ..page.value = hiddenPage;

      await isar.writeTxn(() async {
        await isar.workspaceModels.put(ws);
        await isar.pageModels.put(rootPage);
        await isar.pageModels.put(hiddenPage);
        await rootPage.workspace.save();
        await hiddenPage.workspace.save();
        await isar.padModels.put(folderPad);
        await isar.padModels.put(audioPad);
        await folderPad.page.save();
        await audioPad.page.save();
      });

      await FilesystemSyncService.reconcileOnStartup(isar);

      final savedFolderPads = await isar.padModels
          .filter()
          .padTypeIndexEqualTo(1)
          .findAll();
      expect(
        savedFolderPads.map((p) => p.label),
        contains('Mi Set'),
        reason: 'un folder pad importado no debe borrarse por falta de subcarpeta física',
      );

      final savedAudioPads = await isar.padModels
          .filter()
          .padTypeIndexEqualTo(0)
          .findAll();
      expect(savedAudioPads.length, 1);
      expect(File(p.join(importedDir.path, 'kick.wav')).existsSync(), isTrue,
          reason: 'la reconciliación no debe borrar el audio importado');
    },
  );

  test('cleanUnusedAudioFiles nunca borra archivos de directorios internos',
      () async {
    final mediaDir = await _expectedMediaDir();

    final internalDir = Directory(p.join(mediaDir.path, 'folder_imports'));
    await internalDir.create(recursive: true);
    File(p.join(internalDir.path, 'stray.wav')).writeAsBytesSync([1]);

    final regularDir = Directory(p.join(mediaDir.path, 'Set A'));
    await regularDir.create(recursive: true);
    File(p.join(regularDir.path, 'old.wav')).writeAsBytesSync([2]);

    // Barrido con cero paths activos: solo lo NO interno se limpia.
    await LocalAudioStorageService.cleanUnusedAudioFiles(const []);

    expect(File(p.join(internalDir.path, 'stray.wav')).existsSync(), isTrue,
        reason: 'folder_imports no debe barrerse');
    expect(File(p.join(regularDir.path, 'old.wav')).existsSync(), isFalse,
        reason: 'un archivo huérfano normal sí se limpia');
  });

  test(
    'reconcileOnStartup no aborta si una carpeta de workspace falla al listarse',
    () async {
      // Solo Windows: se usa un junction colgante para simular una subcarpeta
      // inaccesible cuyo listSync() lanza una excepción a mitad del escaneo.
      if (!Platform.isWindows) return;
      final mediaDir = await _expectedMediaDir();

      // Workspace sano que SÍ debe reconciliarse.
      final goodDir = Directory(p.join(mediaDir.path, 'Good Set'));
      await goodDir.create(recursive: true);
      File(p.join(goodDir.path, 'kick.wav')).writeAsBytesSync([1]);

      // Workspace con una subcarpeta inaccesible (junction roto).
      final brokenDir = Directory(p.join(mediaDir.path, 'Broken Set'));
      await brokenDir.create(recursive: true);
      final link = p.join(brokenDir.path, 'BrokenSub');
      final target = p.join(brokenDir.path, 'no_existe_target');
      final result = await Process.run('cmd', ['/c', 'mklink', '/J', link, target]);
      if (result.exitCode != 0) return; // no se pudo crear → omitir

      final isar = await _openIsar(tempRoot);
      addTearDown(() => isar.close());

      // No debe lanzar excepción y debe registrar al menos el workspace sano.
      final count = await FilesystemSyncService.reconcileOnStartup(isar);

      final workspaces = await isar.workspaceModels.where().findAll();
      expect(workspaces.map((w) => w.name), contains('Good Set'));
      expect(count, greaterThan(0));
    },
  );
}
