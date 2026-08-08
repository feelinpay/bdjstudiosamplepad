import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../helpers/path_provider_test_helper.dart';

import 'package:bdj_studio_sample_pad/core/services/app_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('app_storage_test');
    mockPathProviderForAllPlatforms(tempRoot);
  });

  tearDown(() async {
    tearDownPathProviderMocks();
    try {
      await tempRoot.delete(recursive: true);
    } catch (_) {}
  });

  /// Simula el directorio de soporte que path_provider resuelve en cada OS.
  Future<void> mockSupportAs(Directory supportDir) async {
    AppStorageService.resetCacheForTesting();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    Future<Object?> handler(MethodCall call) async {
      if (call.method == 'getApplicationSupportDirectory') {
        return supportDir.path;
      }
      return null;
    }

    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      handler,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider_macos'),
      handler,
    );
  }

  test('root() es el directorio de soporte (una sola carpeta)', () async {
    final root = await AppStorageService.root();
    expect(
      root.path,
      p.join(tempRoot.path, 'support'),
      reason: 'la raíz de datos debe ser el support dir de path_provider',
    );
  });

  test('initialize() crea la data dentro del support, sin carpeta de marca',
      () async {
    await AppStorageService.initialize();

    final root = await AppStorageService.root();
    expect(
      FileSystemEntity.isDirectorySync(p.join(root.path, 'Database')),
      isTrue,
    );
    expect(
      Directory(p.join(tempRoot.path, 'BDJ Studio')).existsSync(),
      isFalse,
      reason: 'no debe crearse una carpeta de marca paralela al support',
    );
  });

  test('no importa que el support viva bajo un nombre con marca', () async {
    final supportDir = Directory(
      p.join(tempRoot.path, 'BDJ Studio', 'bdj_studio_sample_pad'),
    );
    await supportDir.create(recursive: true);
    await mockSupportAs(supportDir);

    final root = await AppStorageService.root();
    expect(root.path, supportDir.path,
        reason: 'la raíz es el support sin importar su nombre');
  });

  test('initialize() migra la data de la ruta antigua base/marca/App al support',
      () async {
    final supportDir = Directory(p.join(tempRoot.path, 'support'));
    await supportDir.create(recursive: true);
    await mockSupportAs(supportDir);

    // Ruta que usaban versiones anteriores en Linux/macOS: base/marca/App.
    final legacyRoot = Directory(
      p.join(tempRoot.path, 'BDJ Studio', 'BDJ Studio Sample Pad'),
    );
    final marker = File(p.join(legacyRoot.path, 'Database', 'keep.txt'));
    await marker.create(recursive: true);

    await AppStorageService.initialize();

    expect(
      File(p.join(supportDir.path, 'Database', 'keep.txt')).existsSync(),
      isTrue,
      reason: 'los datos deben quedar en el support (una sola carpeta)',
    );
    expect(legacyRoot.existsSync(), isFalse,
        reason: 'la ruta antigua debe desaparecer');
    expect(
      Directory(p.join(tempRoot.path, 'BDJ Studio')).existsSync(),
      isFalse,
      reason: 'la carpeta de marca vacía debe eliminarse',
    );
  });

  test(
      'migra la ruta duplicada base/marca/marca/App y conserva la data del support',
      () async {
    final supportDir = Directory(
      p.join(tempRoot.path, 'BDJ Studio', 'BDJ Studio Sample Pad'),
    );
    await supportDir.create(recursive: true);
    await mockSupportAs(supportDir);
    // Data que ya existe en el support (p.ej. preferencias de plugins).
    await File(p.join(supportDir.path, 'shared_preferences.json'))
        .writeAsString('{"keep":true}');

    // Ruta duplicada vieja del bug: base/marca/marca/App.
    final buggyRoot = Directory(
      p.join(tempRoot.path, 'BDJ Studio', 'BDJ Studio', 'BDJ Studio Sample Pad'),
    );
    final marker = File(p.join(buggyRoot.path, 'Database', 'keep.txt'));
    await marker.create(recursive: true);

    await AppStorageService.initialize();

    expect(
      File(p.join(supportDir.path, 'shared_preferences.json')).existsSync(),
      isTrue,
      reason: 'no debe perderse la data que ya estaba en el support',
    );
    expect(
      File(p.join(supportDir.path, 'Database', 'keep.txt')).existsSync(),
      isTrue,
      reason: 'la data duplicada debe fusionarse al support',
    );
    expect(buggyRoot.existsSync(), isFalse,
        reason: 'la ruta duplicada debe desaparecer');
  });

  test(
      'initialize() migra los datos de plugins desde <brand>/bdj_studio_sample_pad '
      'y elimina la carpeta heredada', () async {
    if (!Platform.isWindows) {
      markTestSkipped('La carpeta heredada de plugins es un artefacto de Windows');
      return;
    }

    final correctSupport = Directory(
      p.join(tempRoot.path, 'BDJ Studio', 'BDJ Studio Sample Pad'),
    );
    await correctSupport.create(recursive: true);
    await mockSupportAs(correctSupport);

    // Simula el support dir de una build antigua (ProductName = paquete).
    final legacyDir = Directory(
      p.join(tempRoot.path, 'BDJ Studio', 'bdj_studio_sample_pad'),
    );
    await legacyDir.create(recursive: true);
    await File(p.join(legacyDir.path, 'flutter_secure_storage.dat'))
        .writeAsString('encrypted-license');
    await File(p.join(legacyDir.path, 'shared_preferences.json'))
        .writeAsString('{"flutter.bdj_sample_pad_installation_v1":true}');

    await AppStorageService.initialize();

    expect(
      File(p.join(correctSupport.path, 'flutter_secure_storage.dat'))
          .existsSync(),
      isTrue,
      reason: 'el almacén seguro debe migrar al support correcto',
    );
    expect(
      File(p.join(correctSupport.path, 'shared_preferences.json')).existsSync(),
      isTrue,
      reason: 'las preferencias deben migrar al support correcto',
    );
    expect(legacyDir.existsSync(), isFalse,
        reason: 'la carpeta heredada bdj_studio_sample_pad debe desaparecer');
  });
}
