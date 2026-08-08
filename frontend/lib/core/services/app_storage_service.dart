import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Punto único para los archivos administrados por Sample Pad.
///
/// En cada plataforma la raíz de datos es el directorio de soporte que
/// proporciona `path_provider` (una sola carpeta por OS). Todos los datos viven
/// bajo esa raíz en subdirectorios con responsabilidades explícitas; los plugins
/// (preferencias, almacén seguro) escriben en la misma carpeta. Las exportaciones
/// elegidas por el usuario son la única excepción: se escriben en la ruta que
/// éste selecciona.
class AppStorageService {
  AppStorageService._();

  static const _brandFolder = 'BDJ Studio';
  static const _rootName = 'BDJ Studio Sample Pad';

  static Future<Directory> root() => _directory();
  static Future<Directory> databaseDirectory() => _directory('Database');
  /// Recursos de audio administrados por Sample Pad.
  static Future<Directory> mediaDirectory() => _directory('Assets', 'Audio');
  static Future<Directory> waveformDirectory() => _directory('Waveforms');
  static Future<Directory> backupDirectory() => _directory('Recovery', 'Backups');
  static Future<Directory> projectsDirectory() => _directory('Projects');
  static Future<Directory> templatesDirectory() => _directory('Templates');
  static Future<Directory> assetsDirectory() => _directory('Assets');
  static Future<Directory> cacheDirectory() => _directory('Cache');
  static Future<Directory> exportsDirectory() => _directory('Exports');
  static Future<Directory> licensesDirectory() => _directory('Licenses');
  static Future<Directory> logsDirectory() => _directory('Logs');
  static Future<Directory> recoveryDirectory() => _directory('Recovery');
  static Future<Directory> settingsDirectory() => _directory('Settings');
  static Future<Directory> tempDirectory() => _directory('Temp');
  static Future<Directory> thumbnailsDirectory() => _directory('Thumbnails');

  static Future<void> initialize() async {
    final support = await _supportDirectory();
    // Primero el almacén de plugins: sus archivos dejan el support no vacío y
    // sobreviven a la limpieza de `_migrateDesktopRoot`.
    await _migrateLegacyPluginSupport(support);
    await _migrateDesktopRoot(support);
    await Future.wait([
      root(), databaseDirectory(), projectsDirectory(), templatesDirectory(),
      assetsDirectory(), cacheDirectory(), waveformDirectory(), exportsDirectory(),
      licensesDirectory(), logsDirectory(), recoveryDirectory(), settingsDirectory(),
      tempDirectory(), thumbnailsDirectory(), mediaDirectory(), backupDirectory(),
    ]);
  }

  static Future<void> clearPersistentData() async {
    final directory = await root();
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  static Future<Directory> workDirectory(String operation) {
    final safeOperation = operation.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return _directory(
      'Temp',
      '${safeOperation}_${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  static Future<Directory>? _cachedSupportDirectory;

  /// Solo para tests: limpia el directorio cacheado entre pruebas para evitar
  /// que un test reutilice la ruta de un tempRoot eliminado por otro test.
  /// En macOS la eliminación del directorio es inmediata (sin file locks),
  /// así que la caché apunta a un directorio inexistente si no se limpia.
  @visibleForTesting
  static void resetCacheForTesting() => _cachedSupportDirectory = null;

  /// Cachea el directorio de soporte para evitar llamadas repetidas al canal
  /// de plataforma en cada resolución de ruta (crítico para precargas rápidas).
  static Future<Directory> _supportDirectory() {
    return _cachedSupportDirectory ??= getApplicationSupportDirectory();
  }

  static Future<Directory> _directory([String? first, String? second]) async {
    final support = await _supportDirectory();
    final segments = <String>[support.path];
    if (first != null) segments.add(first);
    if (second != null) segments.add(second);
    return Directory(p.joinAll(segments)).create(recursive: true);
  }

  /// Nombre de carpeta que usaban las versiones antiguas como support dir de los
  /// plugins (ProductName del exe = nombre del paquete). Hoy la ruta correcta es
  /// "<base>\BDJ Studio\BDJ Studio Sample Pad"; esta es la migración puntual del
  /// almacén que dejaban flutter_secure_storage y shared_preferences allí.
  static const _legacyPluginSupportName = 'bdj_studio_sample_pad';

  /// Migra los datos que los plugins guardaban en la ruta heredada
  /// `<brand>/bdj_studio_sample_pad` hacia la carpeta de soporte actual. Sin
  /// esto, al cambiar el ProductName del exe se perderían las preferencias y la
  /// licencia (flutter_secure_storage.dat + shared_preferences.json).
  static Future<void> _migrateLegacyPluginSupport(Directory support) async {
    if (!Platform.isWindows) return;
    final legacy = Directory(p.join(support.parent.path, _legacyPluginSupportName));
    if (!await legacy.exists()) return;
    try {
      await support.create(recursive: true);
      for (final fileName in const [
        'flutter_secure_storage.dat',
        'shared_preferences.json',
      ]) {
        final source = File(p.join(legacy.path, fileName));
        if (!await source.exists()) continue;
        final target = File(p.join(support.path, fileName));
        if (await target.exists()) continue;
        await source.rename(target.path);
      }
      await _deleteIfEmpty(legacy);
    } catch (e) {
      debugPrint(
        'AppStorage: no se pudo migrar datos de plugins desde ${legacy.path}: $e',
      );
    }
  }

  static Future<void> _migrateDesktopRoot(Directory support) async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
    final target = support;
    // La raíz de datos es el support dir. Ubicaciones antiguas (carpeta de
    // marca anidada, duplicada, o en la raíz del padre) se fusionan al support
    // para que quede una sola carpeta por OS.
    final candidates = [
      Directory(p.join(support.path, _rootName)),
      Directory(p.join(support.path, _brandFolder, _rootName)),
      Directory(p.join(support.parent.path, _rootName)),
      // Ruta duplicada que creó una versión anterior (base/marca/marca/App)
      // cuando el support ya vivía bajo la marca: se corrige a base/marca/App.
      Directory(p.join(support.parent.path, _brandFolder, _rootName)),
    ];
    for (final legacy in candidates) {
      if (legacy.path == target.path || !await legacy.exists()) continue;
      try {
        await target.create(recursive: true);
        await _moveInto(legacy, target);
        // Nunca borrar la raíz del padre; solo carpetas intermedias vacías.
        if (legacy.parent.path != support.parent.path) {
          await _deleteIfEmpty(legacy.parent);
        }
      } catch (e) {
        debugPrint('AppStorage: no se pudo migrar datos desde ${legacy.path}: $e');
      }
    }
  }

  /// Mueve el contenido de [source] hacia [target] sin sobrescribir entradas
  /// que ya existan, y borra [source] si quedó vacía. Permite fusionar la data
  /// de una ubicación antigua dentro del support aunque éste ya tenga archivos
  /// (p.ej. las preferencias de plugins guardadas por path_provider).
  static Future<void> _moveInto(Directory source, Directory target) async {
    await for (final entry in source.list()) {
      final dest = p.join(target.path, p.basename(entry.path));
      if (await FileSystemEntity.type(dest) != FileSystemEntityType.notFound) {
        continue;
      }
      await entry.rename(dest);
    }
    await _deleteIfEmpty(source);
  }

  static Future<void> _deleteIfEmpty(Directory directory) async {
    if (await directory.exists() && (await directory.list().isEmpty)) {
      await directory.delete();
    }
  }
}
