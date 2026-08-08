import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:bdj_studio_sample_pad/core/services/app_storage_service.dart';

/// Configura los mocks de path_provider para funcionar tanto en Windows como en
/// macOS CI. En macOS, path_provider_foundation usa un canal Pigeon diferente
/// al MethodChannel estándar. Este helper registra ambos para garantizar
/// compatibilidad cross-platform en tests unitarios.
void mockPathProviderForAllPlatforms(Directory tempRoot) {
  Future<Object?> handler(MethodCall call) async {
    if (call.method == 'getApplicationSupportDirectory') {
      return p.join(tempRoot.path, 'support');
    }
    return null;
  }

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // Canal estándar (Windows/Linux)
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    handler,
  );

  // Canal federado macOS (path_provider_foundation usa Pigeon)
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider_macos'),
    handler,
  );
}

/// Limpia todos los mocks de path_provider y resetea la caché estática de
/// AppStorageService para evitar que un test reutilice la ruta de otro test
/// que ya fue eliminado (crítico en macOS donde las eliminaciones son inmediatas).
void tearDownPathProviderMocks() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider_macos'),
    null,
  );

  AppStorageService.resetCacheForTesting();
}
