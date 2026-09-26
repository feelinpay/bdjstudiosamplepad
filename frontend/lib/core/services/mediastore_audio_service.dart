import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../features/pad_system/presentation/providers/pad_providers.dart' show AudioFolderNode;

/// Representa una carpeta con audios encontrada en la biblioteca de Android (MediaStore).
class AudioFolderEntry {
  const AudioFolderEntry({
    required this.path,
    required this.volume,
    required this.count,
    required this.totalBytes,
  });

  final String path;
  final String volume;
  final int count;
  final int totalBytes;

  /// Nombre visible de la carpeta (último segmento).
  String get displayName {
    final clean = path.replaceAll('\\', '/').trim();
    final segments = clean.split('/').where((s) => s.isNotEmpty).toList();
    return segments.isEmpty ? path : segments.last;
  }

  factory AudioFolderEntry.fromMap(Map<dynamic, dynamic> map) {
    return AudioFolderEntry(
      path: map['path'] as String? ?? '',
      volume: map['volume'] as String? ?? '',
      count: (map['count'] as num?)?.toInt() ?? 0,
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Representa un archivo de audio en MediaStore.
class AudioFileEntry {
  const AudioFileEntry({
    required this.uri,
    required this.name,
    required this.relativeSubPath,
    required this.size,
  });

  final String uri;
  final String name;
  final String relativeSubPath;
  final int size;

  factory AudioFileEntry.fromMap(Map<dynamic, dynamic> map) {
    return AudioFileEntry(
      uri: map['uri'] as String? ?? '',
      name: map['name'] as String? ?? '',
      relativeSubPath: map['relativeSubPath'] as String? ?? '',
      size: (map['size'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'uri': uri,
    'name': name,
    'relativeSubPath': relativeSubPath,
    'size': size,
  };
}

/// Archivo copiado físicamente a la carpeta de la app.
class CopiedAudioFile {
  const CopiedAudioFile({
    required this.name,
    required this.path,
    required this.relativeSubPath,
  });

  final String name;
  final String path;
  final String relativeSubPath;

  factory CopiedAudioFile.fromMap(Map<dynamic, dynamic> map) {
    return CopiedAudioFile(
      name: map['name'] as String? ?? '',
      path: map['path'] as String? ?? '',
      relativeSubPath: map['relativeSubPath'] as String? ?? '',
    );
  }
}

/// Servicio para consultar MediaStore en Android y copiar audios directamente.
class MediaStoreAudioService {
  MediaStoreAudioService._();

  static const MethodChannel _channel = MethodChannel('bdj_studio/saf_import');
  static void Function(int count)? _onProgress;

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onProgress') {
      final val = call.arguments;
      if (val is int) _onProgress?.call(val);
    }
    return null;
  }

  /// Lista las carpetas con audios registradas en MediaStore.
  static Future<List<AudioFolderEntry>> listAudioFolders() async {
    if (!isSupported) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('listAudioFolders');
      if (raw == null) return const [];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => AudioFolderEntry.fromMap(m))
          .toList();
    } catch (e) {
      debugPrint('[MediaStoreAudioService] listAudioFolders error: $e');
      return const [];
    }
  }

  /// Lista los archivos de audio dentro de [folderPath].
  static Future<List<AudioFileEntry>> listAudioFiles(
    String folderPath, {
    bool recursive = true,
  }) async {
    if (!isSupported) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('listAudioFiles', {
        'folderPath': folderPath,
        'recursive': recursive,
      });
      if (raw == null) return const [];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => AudioFileEntry.fromMap(m))
          .toList();
    } catch (e) {
      debugPrint('[MediaStoreAudioService] listAudioFiles error: $e');
      return const [];
    }
  }

  /// Copia los archivos seleccionados directamente a [destDir].
  static Future<List<CopiedAudioFile>> copyAudioFiles(
    List<AudioFileEntry> items,
    String destDir, {
    void Function(int count)? onProgress,
  }) async {
    if (!isSupported || items.isEmpty) return const [];
    _onProgress = onProgress;
    try {
      _channel.setMethodCallHandler(_handleNativeCall);
      final raw = await _channel.invokeMethod<List<dynamic>>('copyAudioFiles', {
        'items': items.map((i) => i.toMap()).toList(),
        'destDir': destDir,
      });
      if (raw == null) return const [];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => CopiedAudioFile.fromMap(m))
          .toList();
    } finally {
      _onProgress = null;
    }
  }

  /// Construye un árbol jerárquico [AudioFolderNode] a partir de los archivos copiados.
  static AudioFolderNode buildFolderTree(
    String rootName,
    List<CopiedAudioFile> files,
  ) {
    final rootFiles = <File>[];
    final subfolderFiles = <String, List<CopiedAudioFile>>{};

    for (final item in files) {
      final rel = item.relativeSubPath.trim().replaceAll('\\', '/');
      if (rel.isEmpty) {
        rootFiles.add(File(item.path));
      } else {
        final segments = rel.split('/');
        final topSegment = segments.first;
        final remaining = segments.length > 1
            ? segments.sublist(1).join('/')
            : '';
        subfolderFiles
            .putIfAbsent(topSegment, () => [])
            .add(
              CopiedAudioFile(
                name: item.name,
                path: item.path,
                relativeSubPath: remaining,
              ),
            );
      }
    }

    final subnodes = <AudioFolderNode>[];
    for (final entry in subfolderFiles.entries) {
      subnodes.add(buildFolderTree(entry.key, entry.value));
    }

    rootFiles.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    subnodes.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return AudioFolderNode(
      name: rootName,
      audioFiles: rootFiles,
      subfolders: subnodes,
    );
  }
}
