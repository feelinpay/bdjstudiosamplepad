import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('No existen operaciones síncronas de archivo (dart:io *Sync) en lib/ fuera de isolates', () async {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'El directorio lib/ debe existir');

    // Métodos síncronos de E/S de archivos en dart:io
    final syncIoPattern = RegExp(
      r'\b(existsSync|readAsStringSync|readAsBytesSync|readAsLinesSync|writeAsStringSync|writeAsBytesSync|listSync|statSync|createSync|deleteSync|renameSync|copySync)\b',
    );

    // Archivos permitidos si fueran isolates dedicados de segundo plano (ninguno por ahora)
    final allowedFiles = <String>{};

    final violations = <String>[];

    final files = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));

    for (final file in files) {
      final relativePath = p.relative(file.path, from: libDir.path).replaceAll('\\', '/');
      if (allowedFiles.contains(relativePath)) continue;

      final lines = await file.readAsLines();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trim();
        // Omitir líneas de comentario
        if (trimmed.startsWith('//') || trimmed.startsWith('/*') || trimmed.startsWith('*')) {
          continue;
        }

        if (syncIoPattern.hasMatch(line)) {
          violations.add('$relativePath:${i + 1} -> $trimmed');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Se encontraron operaciones de archivo síncronas que pueden congelar la interfaz:\n${violations.join('\n')}',
    );
  });
}
