import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';

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
  if (mediaDir.listSync().isNotEmpty) await encoder.addDirectory(mediaDir);
  await encoder.close();
}

Archive decodeZipInIsolate(Uint8List bytes) {
  return ZipDecoder().decodeBytes(bytes);
}
