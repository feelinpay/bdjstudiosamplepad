import 'dart:async';
import 'dart:io';

/// Ejecuta un proceso con límite de tiempo REAL: si vence, lo mata.
/// Devuelve null en timeout o si el ejecutable no existe.
Future<ProcessResult?> runProcessWithTimeout(
  String executable,
  List<String> args,
  Duration timeout,
) async {
  final Process proc;
  try {
    proc = await Process.start(executable, args);
  } on ProcessException {
    return null;
  }
  final stdout = proc.stdout.transform(systemEncoding.decoder).join();
  final stderr = proc.stderr.transform(systemEncoding.decoder).join();
  try {
    final code = await proc.exitCode.timeout(timeout);
    return ProcessResult(proc.pid, code, await stdout, await stderr);
  } on TimeoutException {
    proc.kill();
    return null;
  }
}
