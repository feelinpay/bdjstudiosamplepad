import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;

/// Localiza la biblioteca nativa de Isar para la plataforma actual.
///
/// Prueba los nombres conocidos por plataforma (`libisar.dll`, `isar.dll`,
/// `libisar.dylib`, `libisar.so`) dentro del paquete `isar_community_flutter_libs`
/// resuelto en `.dart_tool/package_config.json`.
///
/// Si no encuentra ninguna, falla de inmediato con un mensaje explícito que
/// lista todas las rutas comprobadas, en lugar de continuar en silencio y
/// producir un fallo opaco posterior (`error code 126`).
String getIsarNativeLibPath() {
  final configFile = File(p.join('.dart_tool', 'package_config.json'));
  if (!configFile.existsSync()) {
    throw StateError(
      'No se encontró .dart_tool/package_config.json. Ejecuta `flutter pub get` antes de correr los tests.',
    );
  }

  final configDir = configFile.parent;
  final dynamic decoded;
  try {
    decoded = jsonDecode(configFile.readAsStringSync());
  } catch (e) {
    throw StateError('Error decodificando package_config.json: $e');
  }

  if (decoded is! Map<String, dynamic> || decoded['packages'] is! List) {
    throw StateError('Formato inválido en package_config.json');
  }

  final packages = decoded['packages'] as List;
  Directory? pkgDir;
  for (final entry in packages) {
    if (entry is Map<String, dynamic> &&
        entry['name'] == 'isar_community_flutter_libs') {
      final rootUri = entry['rootUri'];
      if (rootUri is String) {
        final uri = Uri.parse(rootUri);
        pkgDir = uri.isAbsolute
            ? Directory.fromUri(uri)
            : Directory(p.join(configDir.path, rootUri));
      }
      break;
    }
  }

  if (pkgDir == null || !pkgDir.existsSync()) {
    throw StateError(
      'No se encontró la carpeta del paquete isar_community_flutter_libs en package_config.json.',
    );
  }

  final candidates = <String>[
    if (Platform.isWindows) ...[
      p.join(pkgDir.path, 'windows', 'libisar.dll'),
      p.join(pkgDir.path, 'windows', 'isar.dll'),
    ],
    if (Platform.isMacOS) ...[
      p.join(pkgDir.path, 'macos', 'libisar.dylib'),
      p.join(pkgDir.path, 'macos', 'isar.dylib'),
    ],
    if (Platform.isLinux) ...[
      p.join(pkgDir.path, 'linux', 'libisar.so'),
      p.join(pkgDir.path, 'linux', 'isar.so'),
    ],
  ];

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }

  throw StateError(
    'No se encontró la biblioteca nativa de Isar para ${Platform.operatingSystem}.\n'
    'Se probaron las siguientes rutas sin éxito:\n'
    '${candidates.map((c) => '  - $c').join('\n')}\n'
    'Asegúrate de que `isar_community_flutter_libs` esté descargado en el pub cache.',
  );
}

/// Inicializa el núcleo de Isar para pruebas una sola vez.
Future<void> ensureTestIsarInitialized() async {
  final libPath = getIsarNativeLibPath();
  await Isar.initializeIsarCore(libraries: {Abi.current(): libPath});
}
