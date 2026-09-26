import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/app_storage_service.dart';

class ZipHelperArgs {
  final String metadataPath;
  final String mediaDirPath;
  final String outputPath;
  ZipHelperArgs({
    required this.metadataPath,
    required this.mediaDirPath,
    required this.outputPath,
  });
}

/// Comprime `metadata.json` + la carpeta `media/` en el `.sppworkspace` final.
///
/// `addFile`, `addDirectory` y `close` son asíncronas en archive 4.x: sin
/// esperarlas el encoder devuelve el control antes de haber escrito nada y el
/// archivo exportado queda vacío (sin metadata y sin un solo audio).
Future<void> zipDirectoryInIsolate(ZipHelperArgs args) async {
  var encoder = ZipFileEncoder();
  encoder.create(args.outputPath);
  await encoder.addFile(File(args.metadataPath));
  var mediaDir = Directory(args.mediaDirPath);
  if (!await mediaDir.list().isEmpty) await encoder.addDirectory(mediaDir);
  await encoder.close();
}

Archive decodeZipInIsolate(Uint8List bytes) {
  return ZipDecoder().decodeBytes(bytes);
}

class ExtractZipArgs {
  final String zipPath;
  final String targetDir;
  ExtractZipArgs({
    required this.zipPath,
    required this.targetDir,
  });
}

Future<void> extractZipInIsolate(ExtractZipArgs args) async {
  final inputStream = InputFileStream(args.zipPath);
  try {
    final archive = ZipDecoder().decodeStream(inputStream);
    await extractArchiveToDisk(archive, args.targetDir);
  } finally {
    await inputStream.close();
  }
}

/// Resuelve un [PlatformFile] a una ruta física en disco sin saturar la memoria RAM.
///
/// Si [file.path] no es nulo ni vacío, se devuelve directamente.
/// Si [file.path] es nulo (por ejemplo, en proveedores SAF de Android),
/// consume [file.readStream] en streaming volcándolo a un archivo temporal en
/// [AppStorageService.workDirectory(workSubdir)].
/// Si solo existen [file.bytes], los escribe a disco como respaldo de compatibilidad.
Future<String?> resolvePickedFilePath(
  PlatformFile file, {
  String workSubdir = 'import',
}) async {
  if (file.path != null && file.path!.isNotEmpty) {
    return file.path;
  }
  if (file.readStream != null) {
    final work = await AppStorageService.workDirectory(workSubdir);
    final sanitizedName = file.name.isNotEmpty
        ? file.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        : 'import_${DateTime.now().microsecondsSinceEpoch}.zip';
    final tempFile = File(
      p.join(work.path, '${DateTime.now().microsecondsSinceEpoch}_$sanitizedName'),
    );
    final sink = tempFile.openWrite();
    try {
      await file.readStream!.pipe(sink);
      return tempFile.path;
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {}
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      return null;
    }
  }
  if (file.bytes != null && file.bytes!.isNotEmpty) {
    final work = await AppStorageService.workDirectory(workSubdir);
    final sanitizedName = file.name.isNotEmpty
        ? file.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        : 'import_${DateTime.now().microsecondsSinceEpoch}.zip';
    final tempFile = File(
      p.join(work.path, '${DateTime.now().microsecondsSinceEpoch}_$sanitizedName'),
    );
    await tempFile.writeAsBytes(file.bytes!);
    return tempFile.path;
  }
  return null;
}
