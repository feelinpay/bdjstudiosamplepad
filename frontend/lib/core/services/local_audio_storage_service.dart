import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:isar/isar.dart';
import '../../features/pad_system/data/models/pad_model.dart';
import 'app_storage_service.dart';

class LocalAudioStorageService {
  static const String prefix = 'app_local://';

  /// Única lista oficial de extensiones de audio soportadas.
  /// Las extensiones se comparan en minúsculas para ser case-insensitive.
  /// Incluye formatos de uso común en producción y DJing.
  static const Set<String> supportedAudioExtensions = {
    '.wav',
    '.mp3',
    '.flac',
    '.ogg',
    '.aac',
    '.m4a',
    '.aiff',
    '.aif',
    '.wma',
    '.opus',
    '.webm',
  };

  /// Versión sin puntos de [supportedAudioExtensions], para comparaciones
  /// que no incluyen el carácter del punto (ej. `extension(path).toLowerCase()`).
  static final Set<String> supportedAudioExtensionsNoDot =
      supportedAudioExtensions.map((e) => e.substring(1)).toSet();

  static String _sanitizeSegment(String value) {
    // Preserva nombres naturales con espacios; solo elimina caracteres incompatibles en carpetas/archivos
    return value
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Separador canónico de las rutas relativas guardadas en `samplePath`.
  ///
  /// El valor viaja dentro de la base de datos y se compara como texto (p.ej.
  /// al renombrar un workspace), así que no puede depender de la plataforma:
  /// con `p.join` en Windows quedaba `app_local://Set A\kick.wav` mientras el
  /// importador de carpetas escribía `app_local://Set A/kick.wav`, y las
  /// búsquedas por prefijo dejaban de encontrar la mitad de los pads.
  static String _toPosixRelative(String relativePath) =>
      relativePath.replaceAll('\\', '/');

  static Future<String> _resolveUniqueFilePath(
    Directory baseDir,
    String? namespace,
    String baseName,
    String ext,
  ) async {
    final cleanBase = _sanitizeSegment(baseName.isEmpty ? 'Audio' : baseName);
    var relDir = '';
    if (namespace != null && namespace.trim().isNotEmpty) {
      final segments = namespace
          .split(RegExp(r'[/\\]+'))
          .map((s) => _sanitizeSegment(s))
          .where((s) => s.isNotEmpty);
      relDir = p.joinAll(segments);
    }
    var fileName = '$cleanBase$ext';
    var relPath = relDir.isEmpty ? fileName : p.join(relDir, fileName);
    var fullPath = p.join(baseDir.path, relPath);

    var counter = 1;
    while (File(fullPath).existsSync()) {
      fileName = '${cleanBase}_$counter$ext';
      relPath = relDir.isEmpty ? fileName : p.join(relDir, fileName);
      fullPath = p.join(baseDir.path, relPath);
      counter++;
    }
    return _toPosixRelative(relPath);
  }

  /// Obtiene el directorio principal de almacenamiento en AppData / Application Support.
  static Future<Directory> _getAudiosDir() =>
      AppStorageService.mediaDirectory();

  /// Obtiene la carpeta de waveforms en AppData / Application Support.
  static Future<Directory> _getWaveformDir() =>
      AppStorageService.waveformDirectory();

  /// Convierte URIs de Android SAF (content://...primary:Download/...) a rutas físicas (/storage/emulated/0/Download/...)
  static String resolveContentUriToPath(String path) {
    if (Platform.isAndroid &&
        (path.startsWith('content://') ||
            path.contains('%') ||
            path.contains(':'))) {
      final decoded = Uri.decodeFull(path);
      final primaryIndex = decoded.indexOf('primary:');
      if (primaryIndex != -1) {
        var rel = decoded.substring(primaryIndex + 'primary:'.length);
        final docIdx = rel.indexOf('/document/');
        if (docIdx != -1) {
          final sub = rel.substring(docIdx + '/document/'.length);
          final subPrim = sub.indexOf('primary:');
          rel = subPrim != -1
              ? sub.substring(subPrim + 'primary:'.length)
              : sub;
        }
        rel = rel.replaceAll(RegExp(r'^/+|/+$'), '');
        final candidates = [
          '/storage/emulated/0/$rel',
          '/sdcard/$rel',
          '/storage/self/primary/$rel',
        ];
        for (final c in candidates) {
          if (File(c).existsSync() || Directory(c).existsSync()) {
            return c;
          }
        }
        return '/storage/emulated/0/$rel';
      }
      final rawIndex = decoded.indexOf('raw:');
      if (rawIndex != -1) {
        var rel = decoded.substring(rawIndex + 'raw:'.length);
        final docIdx = rel.indexOf('/document/');
        if (docIdx != -1) rel = rel.substring(0, docIdx);
        rel = rel.replaceAll(RegExp(r'^/+|/+$'), '');
        return rel;
      }
    }
    return path;
  }

  /// Copia un archivo externo al directorio interno de la app con la estructura de carpetas real de PC.
  static Future<String> importAudioFile(
    String originalPath, {
    String? namespace,
  }) async {
    final resolvedOriginal = resolveContentUriToPath(originalPath);
    final ext = p.extension(resolvedOriginal).isEmpty
        ? '.mp3'
        : p.extension(resolvedOriginal);
    final baseName = p.basenameWithoutExtension(resolvedOriginal);

    final audiosDir = await _getAudiosDir();
    final relativePath = await _resolveUniqueFilePath(
      audiosDir,
      namespace,
      baseName,
      ext,
    );
    final newPath = p.join(audiosDir.path, relativePath);
    await Directory(p.dirname(newPath)).create(recursive: true);

    try {
      final srcFile = File(resolvedOriginal);
      if (await srcFile.exists()) {
        await srcFile.copy(newPath);
      } else {
        final bytes = await srcFile.readAsBytes();
        await File(newPath).writeAsBytes(bytes);
      }
    } catch (e) {
      try {
        final bytes = await File(resolvedOriginal).readAsBytes();
        await File(newPath).writeAsBytes(bytes);
      } catch (err) {
        return originalPath;
      }
    }

    return '$prefix$relativePath';
  }

  /// Escribe un archivo directamente desde memoria (ej. al extraer o importar).
  static Future<String> importAudioBytes(
    String originalName,
    List<int> bytes, {
    String? namespace,
  }) async {
    final ext = p.extension(originalName).isEmpty
        ? '.mp3'
        : p.extension(originalName);
    final baseName = p.basenameWithoutExtension(originalName);

    final audiosDir = await _getAudiosDir();
    final relativePath = await _resolveUniqueFilePath(
      audiosDir,
      namespace,
      baseName,
      ext,
    );
    final newPath = p.join(audiosDir.path, relativePath);
    await Directory(p.dirname(newPath)).create(recursive: true);
    await File(newPath).writeAsBytes(bytes);

    return '$prefix$relativePath';
  }

  /// Resuelve la ruta para reproducirla en SoLoud.
  /// Si empieza con `app_local://`, retorna la ruta absoluta en la PC actual.
  /// De lo contrario, asume que es una ruta antigua absoluta y la devuelve tal cual.
  static Future<String> resolvePath(String pathOrUri) async {
    if (pathOrUri.startsWith(prefix)) {
      final relativePath = pathOrUri.substring(prefix.length);
      final audiosDir = await _getAudiosDir();
      return p.join(audiosDir.path, relativePath);
    }
    return pathOrUri;
  }

  /// Elimina los archivos de audio del disco que coincidan con las rutas dadas.
  /// También elimina sus waveforms cacheadas.
  static Future<int> deleteAudioFiles(List<String> samplePaths) async {
    final audiosDir = await _getAudiosDir();
    final waveDir = await _getWaveformDir();
    var deleted = 0;

    for (final path in samplePaths.toSet()) {
      final managed = await _managedFileForPath(path, audiosDir);
      if (managed == null) continue;
      final file = managed.file;
      if (await file.exists()) {
        await file.delete();
        deleted++;
        await _deleteEmptyParentDirectories(file.parent, managed.root);
      }
      await _deleteRelatedWaveforms(waveDir, p.basename(file.path));
    }
    return deleted;
  }

  /// Devuelve un archivo solo si pertenece a la carpeta administrada por BDJ.
  /// Resolver enlaces simbolicos evita que una ruta aparentemente local escape
  /// de la biblioteca y borre un archivo ajeno.
  static Future<_ManagedAudioFile?> _managedFileForPath(
    String samplePath,
    Directory audiosDir,
  ) async {
    final candidate = samplePath.startsWith(prefix)
        ? File(p.join(audiosDir.path, samplePath.substring(prefix.length)))
        : File(samplePath);
    if (!await candidate.exists()) return null;

    final canonicalFile = await candidate.resolveSymbolicLinks();
    if (await audiosDir.exists()) {
      final canonicalRoot = await audiosDir.resolveSymbolicLinks();
      if (p.isWithin(canonicalRoot, canonicalFile)) {
        return _ManagedAudioFile(File(canonicalFile), Directory(canonicalRoot));
      }
    }
    return null;
  }

  static Future<void> _deleteEmptyParentDirectories(
    Directory directory,
    Directory root,
  ) async {
    var current = directory;
    while (p.normalize(current.path) != p.normalize(root.path)) {
      if (!await current.exists() || !await current.list().isEmpty) return;
      final parent = current.parent;
      await current.delete();
      current = parent;
    }
  }

  /// Elimina los waveforms cacheados que correspondan al archivo de audio dado.
  static Future<void> _deleteRelatedWaveforms(
    Directory waveDir,
    String audioFileName,
  ) async {
    try {
      if (!await waveDir.exists()) return;
      final prefix = '${audioFileName}_';
      final entities = await waveDir.list(recursive: false).toList();
      for (final entity in entities) {
        if (entity is File && p.basename(entity.path).startsWith(prefix)) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }

  /// Elimina todos los waveforms cacheados.
  static Future<void> deleteAllWaveforms() async {
    try {
      final waveDir = await _getWaveformDir();
      if (!await waveDir.exists()) return;
      await waveDir.delete(recursive: true);
    } catch (_) {}
  }

  /// Elimina los archivos de audio huérfanos del directorio interno
  /// que ya no estén siendo utilizados por ningún pad en la base de datos.
  /// También limpia los waveforms huérfanos.
  static Future<int> cleanUnusedAudioFiles(
    List<String> activeSamplePaths,
  ) async {
    try {
      final audiosDir = await _getAudiosDir();
      final waveDir = await _getWaveformDir();
      if (!await audiosDir.exists()) return 0;

      // Un pad puede referenciar su audio con la URI `app_local://` o, si viene
      // de una versión anterior, con la ruta absoluta en disco. Descartar las
      // segundas hacía que sus archivos se vieran como huérfanos y se borraran
      // con el pad todavía usándolos, así que ambas formas se reducen aquí a la
      // misma ruta relativa antes de comparar.
      final activeFileNames = <String>{};
      for (final path in activeSamplePaths) {
        if (path.isEmpty) continue;
        if (path.startsWith(prefix)) {
          activeFileNames.add(_toPosixRelative(path.substring(prefix.length)));
          continue;
        }
        if (p.isWithin(audiosDir.path, path)) {
          activeFileNames.add(
            _toPosixRelative(p.relative(path, from: audiosDir.path)),
          );
        }
      }

      int deletedCount = 0;
      final entities = await audiosDir.list(recursive: true).toList();
      for (final entity in entities) {
        if (entity is File) {
          final relativePath = p
              .relative(entity.path, from: audiosDir.path)
              .replaceAll('\\', '/');
          if (!activeFileNames.contains(relativePath)) {
            await entity.delete();
            deletedCount++;
            await _deleteRelatedWaveforms(waveDir, p.basename(relativePath));
          }
        }
      }

      if (await waveDir.exists()) {
        final waveEntities = await waveDir.list(recursive: false).toList();
        for (final entity in waveEntities) {
          if (entity is File) {
            final waveName = p.basename(entity.path);
            var matched = false;
            for (final activeName in activeFileNames) {
              if (waveName.startsWith('${activeName}_')) {
                matched = true;
                break;
              }
            }
            if (!matched) {
              await entity.delete();
              deletedCount++;
            }
          }
        }
      }

      return deletedCount;
    } catch (_) {
      return 0;
    }
  }

  /// Ejecuta la limpieza de archivos huérfanos en disco comparando contra todos los pads activos de Isar.
  static Future<int> autoCleanOrphans(Isar isar) async {
    final allPads = await isar.padModels.where().findAll();
    final activePaths = allPads
        .map((p) => p.samplePath)
        .whereType<String>()
        .toList();
    return await cleanUnusedAudioFiles(activePaths);
  }

  /// Garantiza la creación física en tiempo real de la carpeta raíz de un Workspace en disco.
  static Future<void> ensureWorkspaceDir(String workspaceName) async {
    try {
      final audiosDir = await _getAudiosDir();
      final folderName = _sanitizeSegment(workspaceName);
      if (folderName.isNotEmpty) {
        final dir = Directory(p.join(audiosDir.path, folderName));
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }
    } catch (e) {
      debugPrint('Error creando carpeta física de Workspace: $e');
    }
  }

  /// Renombra la carpeta física de un Workspace al editar su nombre en la consola.
  static Future<void> renameWorkspaceDir(String oldName, String newName) async {
    try {
      final audiosDir = await _getAudiosDir();
      final oldDir = Directory(
        p.join(audiosDir.path, _sanitizeSegment(oldName)),
      );
      final newDir = Directory(
        p.join(audiosDir.path, _sanitizeSegment(newName)),
      );
      if (await oldDir.exists() && !await newDir.exists()) {
        await oldDir.rename(newDir.path);
      }
    } catch (e) {
      debugPrint('Error renombrando carpeta física de Workspace: $e');
    }
  }

   /// Elimina en tiempo real la carpeta física de un Workspace al eliminarlo del sistema.
  static Future<void> deleteWorkspaceDir(String workspaceName) async {
    try {
      final audiosDir = await _getAudiosDir();
      final dir = Directory(
        p.join(audiosDir.path, _sanitizeSegment(workspaceName)),
      );
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error eliminando carpeta física de Workspace: $e');
    }
  }

  /// Normaliza a `/` los `samplePath` que quedaron con separador de Windows.
  ///
  /// Las versiones anteriores construían la ruta con `p.join`, de modo que en
  /// Windows quedaba `app_local://Set A\kick.wav`. Ese formato resuelve bien en
  /// disco pero rompe toda comparación por texto: renombrar el workspace no
  /// encontraba esos pads y los dejaba apuntando al nombre viejo (sin sonido).
  /// Se ejecuta una vez al abrir la base; si no hay nada que migrar es un no-op.
  static Future<int> normalizeLegacySamplePaths(Isar isar) async {
    final pads = await isar.padModels
        .filter()
        .samplePathContains('\\')
        .findAll();
    if (pads.isEmpty) return 0;

    await isar.writeTxn(() async {
      for (final pad in pads) {
        pad.samplePath = _toPosixRelative(pad.samplePath!);
        await isar.padModels.put(pad);
      }
    });
    debugPrint(
      '[LocalAudioStorage] samplePath normalizados a "/": ${pads.length}',
    );
    return pads.length;
  }

  /// Reescribe el prefijo de `samplePath` (`app_local://<oldName>/...`) de todos los
  /// pads cuyo workspace cambió de nombre, de modo que sigan resolviéndose al
  /// directorio físico recién renombrado. El segmento se sanitiza igual que
  /// [_resolveUniqueFilePath] para coincidir con el formato real almacenado. El
  /// prefijo incluye el nombre del workspace (único), lote así no se necesita
  /// filtrar por workspace y no se tocan pads de otro workspace.
  static Future<int> migrateWorkspaceSamplePaths(
    Isar isar,
    String oldName,
    String newName,
  ) async {
    final oldSegment = _sanitizeSegment(oldName);
    final newSegment = _sanitizeSegment(newName);
    if (oldSegment == newSegment) return 0;

    final oldPrefix = '$prefix$oldSegment/';
    final newPrefix = '$prefix$newSegment/';

    int migrated = 0;
    await isar.writeTxn(() async {
      final pads = await isar.padModels
          .filter()
          .samplePathStartsWith(oldPrefix)
          .findAll();
      for (final pad in pads) {
        pad.samplePath = pad.samplePath!.replaceFirst(oldPrefix, newPrefix);
        await isar.padModels.put(pad);
        migrated++;
      }
    });
    return migrated;
  }

  /// Garantiza la creación física en tiempo real de una carpeta o subcarpeta interna en disco.
  static Future<void> ensureSubfolderDir(
    String workspaceName,
    List<String> folderPath,
  ) async {
    try {
      final audiosDir = await _getAudiosDir();
      final segments = [
        _sanitizeSegment(workspaceName),
        ...folderPath.map((s) => _sanitizeSegment(s)),
      ].where((s) => s.isNotEmpty).toList();
      final dir = Directory(p.join(audiosDir.path, p.joinAll(segments)));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      debugPrint('Error creando subcarpeta física: $e');
    }
  }

  /// Renombra una subcarpeta física en el disco duro en tiempo real.
  static Future<void> renameSubfolderDir(
    String workspaceName,
    List<String> parentPath,
    String oldName,
    String newName,
  ) async {
    try {
      final audiosDir = await _getAudiosDir();
      final baseSegments = [
        _sanitizeSegment(workspaceName),
        ...parentPath.map((s) => _sanitizeSegment(s)),
      ].where((s) => s.isNotEmpty).toList();
      final baseDir = baseSegments.isEmpty
          ? audiosDir
          : Directory(p.join(audiosDir.path, p.joinAll(baseSegments)));
      final oldDir = Directory(p.join(baseDir.path, _sanitizeSegment(oldName)));
      final newDir = Directory(p.join(baseDir.path, _sanitizeSegment(newName)));
      if (await oldDir.exists() && !await newDir.exists()) {
        await oldDir.rename(newDir.path);
      }
    } catch (e) {
      debugPrint('Error renombrando subcarpeta física: $e');
    }
  }

  /// Elimina una subcarpeta física del disco en tiempo real al eliminarla de un pad.
  static Future<void> deleteSubfolderDir(
    String workspaceName,
    List<String> folderPath,
  ) async {
    try {
      final audiosDir = await _getAudiosDir();
      final segments = [
        _sanitizeSegment(workspaceName),
        ...folderPath.map((s) => _sanitizeSegment(s)),
      ].where((s) => s.isNotEmpty).toList();
      final dir = Directory(p.join(audiosDir.path, p.joinAll(segments)));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error eliminando subcarpeta física: $e');
    }
  }
}

class _ManagedAudioFile {
  const _ManagedAudioFile(this.file, this.root);

  final File file;
  final Directory root;
}
