import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Archivo de audio copiado desde el árbol SAF al cache interno.
class SafImportedAudio {
  const SafImportedAudio({required this.name, required this.file});

  final String name;
  final File file;
}

/// Carpeta (y subcarpetas) copiada desde el árbol SAF al cache interno.
class SafImportedFolder {
  const SafImportedFolder({
    required this.name,
    required this.audioFiles,
    required this.subfolders,
  });

  final String name;
  final List<SafImportedAudio> audioFiles;
  final List<SafImportedFolder> subfolders;

  int get totalAudioCount {
    var count = audioFiles.length;
    for (final sub in subfolders) {
      count += sub.totalAudioCount;
    }
    return count;
  }
}

/// Resultado de [SafFolderImportService.copyTreeToLocalCache].
class SafImportResult {
  const SafImportResult({required this.root, required this.cacheDirectory});

  final SafImportedFolder root;

  /// Directorio temporal con la copia completa; debe eliminarse con
  /// [SafFolderImportService.deleteCachedCopy] cuando ya no se necesite.
  final Directory cacheDirectory;
}

/// Copia un árbol de carpetas seleccionado con el picker de Android
/// (`FilePicker.getDirectoryPath` → URI SAF `content://.../tree/...`) al
/// cache interno de la app preservando la jerarquía completa.
///
/// Scoped Storage impide recorrer el almacenamiento compartido con dart:io,
/// así que la enumeración y lectura se hacen vía DocumentsContract en el lado
/// nativo; los audios quedan como archivos locales normales que Dart sí puede
/// mover a la biblioteca de medios.
class SafFolderImportService {
  SafFolderImportService._();

  static const MethodChannel _channel = MethodChannel('bdj_studio/saf_import');

  static void Function(int copiedFiles)? _onProgress;

  /// Solo Android soporta árboles SAF; en otras plataformas no aplica.
  static bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Verdadero si [path] es un URI de árbol SAF (content://... o el docId
  /// URL-encoded que devuelven algunos proveedores, ej. primary%3AMusic).
  /// Esas rutas NO pueden leerse con dart:io y requieren este servicio.
  static bool looksLikeTreeUri(String path) {
    if (path.startsWith('content://')) return true;
    return path.contains('%3A') || path.contains('%2F');
  }

  /// Verdadero si la app puede leer almacenamiento compartido con dart:io
  /// (All-Files-Access en Android 11+, READ_EXTERNAL_STORAGE en versiones
  /// anteriores). Con este acceso la importación funciona igual que en PC.
  static Future<bool> isDirectStorageAccessGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isAllFilesAccessGranted') ?? false;
    } on PlatformException catch (error) {
      debugPrint('[SafFolderImport] isAllFilesAccessGranted falló: ${error.message}');
      return false;
    } on Object catch (error) {
      // En escritorio el canal no existe (MissingPluginException): no aplica.
      debugPrint('[SafFolderImport] isAllFilesAccessGranted no disponible: $error');
      return false;
    }
  }

  /// Abre ajustes (Android 11+) o lanza el diálogo runtime (Android 10-).
  /// El resultado real se consulta después con [isDirectStorageAccessGranted].
  static Future<void> requestDirectStorageAccess() async {
    try {
      await _channel.invokeMethod<dynamic>('requestAllFilesAccess');
    } on PlatformException catch (error) {
      debugPrint('[SafFolderImport] requestAllFilesAccess falló: ${error.message}');
    } on Object catch (error) {
      debugPrint('[SafFolderImport] requestAllFilesAccess no disponible: $error');
    }
  }

  static Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onProgress') {
      final progress = _onProgress;
      if (progress != null) {
        final value = call.arguments;
        if (value is int) progress(value);
      }
    }
    return null;
  }

  /// Copia el árbol [treeUri] al cache. Devuelve `null` si el URI no es
  /// válido, el proveedor falla o no hay audios dentro.
  static Future<SafImportResult?> copyTreeToLocalCache(
    String treeUri, {
    String destName = 'import',
    void Function(int copiedFiles)? onProgress,
  }) async {
    _onProgress = onProgress;
    try {
      _channel.setMethodCallHandler(_handleNativeCall);
      final raw = await _channel.invokeMethod<String>('copyTreeToCache', {
        'treeUri': treeUri,
        'destName': destName,
      });
      if (raw == null || raw.isEmpty) return null;

      final payload = jsonDecode(raw) as Map<String, dynamic>;
      final cacheRootPath = payload['cacheRoot'] as String?;
      final tree = payload['tree'];
      if (cacheRootPath == null || tree is! Map<String, dynamic>) return null;

      final root = _folderFromJson(tree);
      return SafImportResult(root: root, cacheDirectory: Directory(cacheRootPath));
    } on PlatformException catch (error) {
      debugPrint(
        '[SafFolderImport] No se pudo copiar el árbol seleccionado: '
        '${error.code} ${error.message}',
      );
      return null;
    } on FormatException catch (error) {
      debugPrint('[SafFolderImport] Respuesta inválida del canal SAF: $error');
      return null;
    } finally {
      _onProgress = null;
    }
  }

  /// Elimina la copia temporal del cache tras importarla a la biblioteca.
  static Future<void> deleteCachedCopy(Directory? cacheDirectory) async {
    if (cacheDirectory == null) return;
    try {
      if (await cacheDirectory.exists()) {
        await cacheDirectory.delete(recursive: true);
      }
    } catch (error) {
      debugPrint('[SafFolderImport] No se pudo limpiar el cache temporal: $error');
    }
  }

  static SafImportedFolder _folderFromJson(Map<String, dynamic> json) {
    final files = <SafImportedAudio>[];
    final rawFiles = json['files'];
    if (rawFiles is List) {
      for (final entry in rawFiles) {
        if (entry is! Map<String, dynamic>) continue;
        final path = entry['path'];
        if (path is! String || path.isEmpty) continue;
        files.add(SafImportedAudio(name: entry['name'] as String? ?? '', file: File(path)));
      }
    }

    final subfolders = <SafImportedFolder>[];
    final rawSubfolders = json['subfolders'];
    if (rawSubfolders is List) {
      for (final entry in rawSubfolders) {
        if (entry is! Map<String, dynamic>) continue;
        subfolders.add(_folderFromJson(entry));
      }
    }

    files.sort((a, b) => a.file.path.toLowerCase().compareTo(b.file.path.toLowerCase()));
    subfolders.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return SafImportedFolder(
      name: json['name'] as String? ?? 'Carpeta',
      audioFiles: files,
      subfolders: subfolders,
    );
  }
}
