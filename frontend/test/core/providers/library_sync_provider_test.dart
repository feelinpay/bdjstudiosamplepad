import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

import '../../helpers/path_provider_test_helper.dart';

import 'package:bdj_studio_sample_pad/core/services/app_storage_service.dart';
import 'package:bdj_studio_sample_pad/core/providers/database_provider.dart';
import 'package:bdj_studio_sample_pad/core/providers/library_sync_provider.dart';
import 'package:bdj_studio_sample_pad/features/workspace/data/models/workspace_model.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/data/models/pad_model.dart';

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
    tempRoot = await Directory.systemTemp.createTemp('lib_sync_test');
    mockPathProviderForAllPlatforms(tempRoot);
  });

  tearDown(() async {
    tearDownPathProviderMocks();
    try {
      await tempRoot.delete(recursive: true);
    } catch (_) {}
  });

  test('openAppDatabase no reconcilia archivos sueltos en Assets/Audio; librarySyncProvider sí', () async {
    final mediaDir = await AppStorageService.mediaDirectory();

    // Crear un archivo de audio en una carpeta nueva en Assets/Audio
    final wsDir = Directory(p.join(mediaDir.path, 'TestDeferredWorkspace'));
    await wsDir.create(recursive: true);
    File(p.join(wsDir.path, 'sample.wav')).writeAsBytesSync([1, 2, 3]);

    // 1. Abrir con openAppDatabase() directo
    final isar = await openAppDatabase();
    addTearDown(() => isar.close());

    // La base está abierta, pero la sincronización NO ocurrió
    final wsBefore = await isar.workspaceModels
        .where()
        .filter()
        .nameEqualTo('TestDeferredWorkspace')
        .findFirst();
    expect(wsBefore, isNull, reason: 'openAppDatabase no debe reconciliar de forma bloqueante');

    // 2. Ejecutar librarySyncProvider a través de un ProviderContainer
    final container = ProviderContainer(
      overrides: [
        isarProvider.overrideWith((ref) => isar),
      ],
    );
    addTearDown(() => container.dispose());

    final changed = await container.read(librarySyncProvider.future);
    expect(changed, greaterThan(0), reason: 'librarySyncProvider debe encontrar y sincronizar los archivos');

    // Ahora sí debe existir el workspace y sus pads
    final wsAfter = await isar.workspaceModels
        .where()
        .filter()
        .nameEqualTo('TestDeferredWorkspace')
        .findFirst();
    expect(wsAfter, isNotNull);
    final pads = await isar.padModels.where().findAll();
    expect(pads.isNotEmpty, isTrue);
  });
}
