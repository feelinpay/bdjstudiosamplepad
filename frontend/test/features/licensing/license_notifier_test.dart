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
  final Map<String, String> data = {};

  @override
  Future<Result<void>> storeSecure(String key, String value) async {
    data[key] = value;
    return const Right(null);
  }

  @override
  Future<Result<String?>> readSecure(String key) async => Right(data[key]);

  @override
  Future<Result<void>> deleteSecure(String key) async {
    data.remove(key);
    return const Right(null);
  }

  @override
  Future<Result<bool>> containsSecure(String key) async => Right(data.containsKey(key));

  @override
  Future<Result<bool>> performSelfTest() async => const Right(true);
}

class _FakeFingerprint extends DeviceFingerprint {
  @override
  Future<String> generate() async => '1111-2222-3333-4444';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSecurityPort fakeStorage;
  late LicenseManager manager;

  setUp(() {
    fakeStorage = _FakeSecurityPort();
    manager = LicenseManager(
      secureStorage: fakeStorage,
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

  test('LicenseNotifier retry revalida tras un timeout', () async {
    final completer = Completer<Result<LicenseInfo>>();
    final notifier = LicenseNotifier(manager, preloaded: completer.future);

    completer.completeError(TimeoutException('Timed out'));
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.loadingState, LicenseLoadingState.timeout);

    await notifier.retry();
    expect(notifier.state.loadingState, LicenseLoadingState.unlicensed);
  });

  test('LicenseNotifier sync con LicenseFailure pasa a unlicensed', () async {
    final completer = Completer<Result<LicenseInfo>>();
    final notifier = LicenseNotifier(manager, preloaded: completer.future);

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

    // Al llamar a sync() en manager con storage vacío, valida y devuelve Left(LicenseFailure)
    await notifier.sync();
    expect(notifier.state.loadingState, LicenseLoadingState.unlicensed);
    expect(notifier.state.error, contains('No hay una licencia activa'));
  });

  test('LicenseNotifier generacion tardia no pisa el resultado de retry()', () async {
    final firstCompleter = Completer<Result<LicenseInfo>>();
    final notifier = LicenseNotifier(manager, preloaded: firstCompleter.future);

    // Simular que el primer chequeo entra en timeout
    notifier.state = notifier.state.copyWith(
      loadingState: LicenseLoadingState.timeout,
      error: 'Timeout',
    );

    // Usuario pulsa retry() antes de que llegue la respuesta tardía
    final retryFuture = notifier.retry();
    await retryFuture;
    expect(notifier.state.loadingState, LicenseLoadingState.unlicensed);

    // Ahora llega la respuesta original tardía con una licencia válida
    final info = LicenseInfo(
      status: LicenseStatus.active,
      licenseKey: 'STALE-KEY',
      deviceId: '1111-2222-3333-4444',
      activatedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 365)),
      remainingOfflineDays: 30,
    );
    firstCompleter.complete(Right(info));
    await Future<void>.delayed(Duration.zero);

    // NO debe haber pisado el resultado del retry
    expect(notifier.state.loadingState, LicenseLoadingState.unlicensed);
    expect(notifier.state.licenseKey, isNull);
  });

  test('LicenseNotifier sync ignora la llamada si pasaron menos de 30 minutos', () async {
    final completer = Completer<Result<LicenseInfo>>();
    final notifier = LicenseNotifier(manager, preloaded: completer.future);

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

    // Simulamos que la última verificación fue hace 10 minutos
    fakeStorage.data[LicenseStorageKeys.lastLicenseCheckUtc] =
        DateTime.now().toUtc().subtract(const Duration(minutes: 10)).toIso8601String();

    // sync() no debe hacer nada: debe mantenerse en licensed aunque el storage no tenga clave activa
    await notifier.sync();
    expect(notifier.state.loadingState, LicenseLoadingState.licensed);
    expect(notifier.state.licenseKey, 'TEST-KEY');
  });

  test('LicenseNotifier sync revalida si pasaron más de 30 minutos', () async {
    final completer = Completer<Result<LicenseInfo>>();
    final notifier = LicenseNotifier(manager, preloaded: completer.future);

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

    // Simulamos que la última verificación fue hace 35 minutos
    fakeStorage.data[LicenseStorageKeys.lastLicenseCheckUtc] =
        DateTime.now().toUtc().subtract(const Duration(minutes: 35)).toIso8601String();

    // Al llamar a sync() revalida y, como no hay token en storage, pasa a unlicensed
    await notifier.sync();
    expect(notifier.state.loadingState, LicenseLoadingState.unlicensed);
    expect(notifier.state.error, contains('No hay una licencia activa'));
  });

  test('LicenseNotifier sync con force: true revalida aunque pasaran menos de 30 minutos', () async {
    final completer = Completer<Result<LicenseInfo>>();
    final notifier = LicenseNotifier(manager, preloaded: completer.future);

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

    // Simulamos que la última verificación fue hace 5 minutos
    fakeStorage.data[LicenseStorageKeys.lastLicenseCheckUtc] =
        DateTime.now().toUtc().subtract(const Duration(minutes: 5)).toIso8601String();

    // Sin force: no revalida
    await notifier.sync();
    expect(notifier.state.loadingState, LicenseLoadingState.licensed);

    // Con force: true: revalida de inmediato (pasa a unlicensed por storage vacío)
    await notifier.sync(force: true);
    expect(notifier.state.loadingState, LicenseLoadingState.unlicensed);
  });

  test('LicenseNotifier pasa a clockError ante ClockFailure sin degradar a unlicensed', () async {
    final clockManager = _MockClockFailureManager();
    final clockNotifier = LicenseNotifier(clockManager);
    await Future<void>.delayed(Duration.zero);
    expect(clockNotifier.state.loadingState, LicenseLoadingState.clockError);
    expect(clockNotifier.state.error, contains('reloj'));
  });
}

class _MockClockFailureManager extends LicenseManager {
  _MockClockFailureManager()
      : super(secureStorage: _FakeSecurityPort(), fingerprint: _FakeFingerprint());

  @override
  Future<Result<LicenseInfo>> validateLicense() async {
    return const Left(ClockFailure('La fecha y hora del sistema retrocedió de forma anormal. Ajusta tu reloj a la hora y fecha real de hoy e inténtalo de nuevo.'));
  }
}
