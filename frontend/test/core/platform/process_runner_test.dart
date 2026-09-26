import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/core/platform/process_runner.dart';

/// Comando que imprime [text] y termina al instante, según el SO del runner.
(String, List<String>) _echo(String text) => Platform.isWindows
    ? ('cmd', ['/c', 'echo', text])
    : ('/bin/sh', ['-c', 'echo $text']);

/// Comando que tarda ~5 s en terminar, según el SO del runner.
(String, List<String>) _sleep5() => Platform.isWindows
    ? ('powershell', ['-NoProfile', '-Command', 'Start-Sleep -Seconds 5'])
    : ('/bin/sh', ['-c', 'sleep 5']);

void main() {
  test('runProcessWithTimeout con un ejecutable inexistente devuelve null', () async {
    final result = await runProcessWithTimeout(
      'non_existent_executable_12345_xyz',
      [],
      const Duration(seconds: 1),
    );
    expect(result, isNull);
  });

  test('runProcessWithTimeout con comando rápido devuelve ProcessResult', () async {
    final (exe, args) = _echo('hello_world');
    final result = await runProcessWithTimeout(
      exe,
      args,
      const Duration(seconds: 3),
    );
    expect(result, isNotNull);
    expect(result!.exitCode, 0);
    expect(result.stdout.toString().trim(), 'hello_world');
  });

  test('runProcessWithTimeout con timeout vence y devuelve null', () async {
    final (exe, args) = _sleep5();
    final sw = Stopwatch()..start();
    final result = await runProcessWithTimeout(
      exe,
      args,
      const Duration(milliseconds: 200),
    );
    sw.stop();
    expect(result, isNull);
    // Debe cortar por timeout, no esperar a que el proceso termine solo.
    expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
  });
}
