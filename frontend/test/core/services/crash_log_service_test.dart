import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/path_provider_test_helper.dart';
import 'package:bdj_studio_sample_pad/core/services/app_storage_service.dart';
import 'package:bdj_studio_sample_pad/core/services/crash_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('crash_log_test_');
    mockPathProviderForAllPlatforms(tempRoot);
    AppStorageService.resetCacheForTesting();
    CrashLogService.resetForTesting();
  });

  tearDown(() async {
    await CrashLogService.closeSinkForTesting();
    CrashLogService.resetForTesting();
    tearDownPathProviderMocks();
    try {
      await tempRoot.delete(recursive: true);
    } catch (_) {}
  });

  group('CrashLogService', () {
    test('installHandlers sets up synchronous logging without crashing', () {
      CrashLogService.installHandlers();
      CrashLogService.log('Memory log entry 1');
      CrashLogService.log('Memory log entry 2');
    });

    test('attachLogFile flushes pending logs and appends subsequent logs in order', () async {
      CrashLogService.installHandlers();
      CrashLogService.log('Pre-attachment message 1');
      CrashLogService.log('Pre-attachment message 2');

      await CrashLogService.attachLogFile();

      CrashLogService.log('Post-attachment message 3');

      await CrashLogService.closeSinkForTesting();

      final logsDir = await AppStorageService.logsDirectory();
      final logFile = File('${logsDir.path}/app_runtime.log');
      expect(await logFile.exists(), isTrue);

      final content = await logFile.readAsString();
      expect(content, contains('=== BDJ Studio App Inició ==='));
      expect(content, contains('Pre-attachment message 1'));
      expect(content, contains('Pre-attachment message 2'));
      expect(content, contains('Post-attachment message 3'));

      final pos1 = content.indexOf('Pre-attachment message 1');
      final pos2 = content.indexOf('Pre-attachment message 2');
      final pos3 = content.indexOf('Post-attachment message 3');

      expect(pos1 < pos2, isTrue);
      expect(pos2 < pos3, isTrue);
    });
  });
}
