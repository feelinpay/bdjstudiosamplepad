import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/core/licensing/license_manager.dart';
import 'package:bdj_studio_sample_pad/core/licensing/licensing_port.dart';
import 'package:bdj_studio_sample_pad/core/security/device_fingerprint.dart';
import 'package:bdj_studio_sample_pad/core/security/security_port.dart';
import 'package:bdj_studio_sample_pad/core/errors/failures.dart';
import 'package:bdj_studio_sample_pad/features/licensing/presentation/providers/license_providers.dart';

class _FakeSecurityPort implements SecurityPort {
  @override
  Future<Result<void>> storeSecure(String key, String value) async => const Right(null);
  @override
  Future<Result<String?>> readSecure(String key) async => const Right(null);
  @override
  Future<Result<void>> deleteSecure(String key) async => const Right(null);
  @override
  Future<Result<bool>> containsSecure(String key) async => const Right(false);
  @override
  Future<Result<bool>> performSelfTest() async => const Right(true);
}

class _FakeFingerprint extends DeviceFingerprint {
  @override
  Future<String> generate() async => '1111-2222-3333-4444';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LicenseManager manager;

  setUp(() {
    manager = LicenseManager(
      secureStorage: _FakeSecurityPort(),
      fingerprint: _FakeFingerprint(),
    );
  });

  test('LicenseNotifier con un preloaded que termina pasa a licensed', () async {
    final completer = Completer<Result<LicenseInfo>>();
    final notifier = LicenseNotifier(manager, preloaded: completer.future);

    expect(notifier.state.loadingState, LicenseLoadingState.loading);

    final info = LicenseInfo(
      status: LicenseStatus.active,
      licenseKey: 'TEST-KEY',
      deviceId: '1111-2222-3333-4444',
      activatedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 365)),
      remainingOfflineDays: 30,
    );
    completer.complete(Right(info));

    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.loadingState, LicenseLoadingState.licensed);
    expect(notifier.state.licenseKey, 'TEST-KEY');
  });

  test('LicenseNotifier con un preloaded que vence pasa a timeout, no a unlicensed', () async {
    final completer = Completer<Result<LicenseInfo>>();
    final notifier = LicenseNotifier(manager, preloaded: completer.future);

    completer.completeError(TimeoutException('Timed out'));

    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.loadingState, LicenseLoadingState.timeout);
    expect(notifier.state.error, contains('tardó demasiado'));
  });
}
