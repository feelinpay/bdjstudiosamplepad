import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../helpers/path_provider_test_helper.dart';

import 'package:bdj_studio_sample_pad/core/services/app_storage_service.dart';
import 'package:bdj_studio_sample_pad/core/services/local_audio_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('audio_storage_test');
    mockPathProviderForAllPlatforms(tempRoot);
    AppStorageService.resetCacheForTesting();
  });

  tearDown(() async {
    tearDownPathProviderMocks();
    try {
      await tempRoot.delete(recursive: true);
    } catch (_) {}
  });

  test('mediaPathSync y resolvePathSync lanzan StateError antes de initialize()', () {
    expect(
      () => AppStorageService.mediaPathSync,
      throwsA(isA<StateError>()),
      reason: 'mediaPathSync debe fallar si initialize() no ha corrido',
    );

    expect(
      () => LocalAudioStorageService.resolvePathSync('app_local://test.wav'),
      throwsA(isA<StateError>()),
      reason: 'resolvePathSync con prefijo app_local:// debe fallar sin initialize()',
    );

    // Sin prefijo no accede a mediaPathSync, retorna tal cual
    expect(
      LocalAudioStorageService.resolvePathSync('/unmanaged/path.wav'),
      '/unmanaged/path.wav',
    );
  });

  test('resolvePathSync con y sin prefijo tras initialize()', () async {
    await AppStorageService.initialize();

    final expectedMediaDir = await AppStorageService.mediaDirectory();
    expect(AppStorageService.mediaPathSync, expectedMediaDir.path);

    // Con prefijo app_local://
    final resolvedWithPrefix = LocalAudioStorageService.resolvePathSync('app_local://MySet/kick.wav');
    expect(
      resolvedWithPrefix,
      p.join(expectedMediaDir.path, 'MySet/kick.wav'),
    );

    // Con prefijo app_local:// y barras invertidas
    final resolvedWithPrefixPosix = LocalAudioStorageService.resolvePathSync('app_local://kick.wav');
    expect(
      resolvedWithPrefixPosix,
      p.join(expectedMediaDir.path, 'kick.wav'),
    );

    // Sin prefijo (ruta externa)
    const externalPath = 'C:\\DJs\\External\\drop.wav';
    expect(
      LocalAudioStorageService.resolvePathSync(externalPath),
      externalPath,
    );

    // resolvePath (asíncrono) retorna exactamente lo mismo
    expect(
      await LocalAudioStorageService.resolvePath('app_local://MySet/kick.wav'),
      resolvedWithPrefix,
    );
  });
}
