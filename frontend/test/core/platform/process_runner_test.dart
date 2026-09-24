import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/core/platform/process_runner.dart';

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
    final result = await runProcessWithTimeout(
      'cmd',
      ['/c', 'echo', 'hello_world'],
      const Duration(seconds: 3),
    );
    expect(result, isNotNull);
    expect(result!.exitCode, 0);
    expect(result.stdout.toString().trim(), 'hello_world');
  });

  test('runProcessWithTimeout con timeout vence y devuelve null', () async {
    final result = await runProcessWithTimeout(
      'powershell',
      ['-NoProfile', '-Command', 'Start-Sleep -Seconds 5'],
      const Duration(milliseconds: 200),
    );
    expect(result, isNull);
  });
}
