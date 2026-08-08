import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Punto único para los archivos administrados por Sample Pad.
///
/// Cada plataforma proporciona un directorio privado de soporte para la app;
/// dentro de ella mantenemos una sola raíz y subdirectorios con responsabilidades
/// explícitas. Las exportaciones elegidas por el usuario son la única excepción:
/// se escriben en la ruta que éste selecciona.
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
    await _migrateDesktopRoot();
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
    final segments = <String>[_rootPath(support)];
    if (first != null) segments.add(first);
    if (second != null) segments.add(second);
    return Directory(p.joinAll(segments)).create(recursive: true);
  }

  static String _rootPath(Directory support) {
    if (Platform.isWindows || Platform.isMacOS) {
      return p.join(support.parent.path, _rootName);
    }
    if (p.basename(support.path).toLowerCase() == _rootName.toLowerCase()) {
      return support.path;
    }
    return p.join(support.path, _brandFolder, _rootName);
  }

  static Future<void> _migrateDesktopRoot() async {
    if (!Platform.isWindows && !Platform.isMacOS) return;
    final support = await _supportDirectory();
    final target = Directory(_rootPath(support));
    final legacy = Directory(p.join(support.path, _brandFolder, _rootName));
    if (legacy.path != target.path &&
        await legacy.exists() &&
        !await target.exists()) {
      await legacy.rename(target.path);
      await _deleteIfEmpty(legacy.parent);
      await _deleteIfEmpty(support);
    }
  }

  static Future<void> _deleteIfEmpty(Directory directory) async {
    if (await directory.exists() && (await directory.list().isEmpty)) {
      await directory.delete();
    }
  }
}
