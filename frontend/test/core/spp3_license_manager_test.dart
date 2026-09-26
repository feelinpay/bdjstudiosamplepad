import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:bdj_license_core/bdj_license_core.dart';
import '../../lib/core/licensing/license_manager.dart';
import '../../lib/core/licensing/licensing_port.dart';
import '../../lib/core/security/device_fingerprint.dart';
import '../../lib/core/security/security_port.dart';
import '../../lib/core/errors/failures.dart';

class MemorySecurityPort implements SecurityPort {
  final Map<String, String> storage = {};
  final List<String> writtenKeys = [];
  bool simulateSelfTestFailure = false;

  @override
  Future<Result<void>> storeSecure(String key, String value) async {
    storage[key] = value;
    writtenKeys.add(key);
    return const Right(null);
  }

  @override
  Future<Result<String?>> readSecure(String key) async {
    return Right(storage[key]);
  }

  @override
  Future<Result<void>> deleteSecure(String key) async {
    storage.remove(key);
    return const Right(null);
  }

  @override
  Future<Result<bool>> containsSecure(String key) async {
    return Right(storage.containsKey(key));
  }

  @override
  Future<Result<bool>> performSelfTest() async {
    if (simulateSelfTestFailure) {
      return Left(SecurityFailure('Fallo simulado en prueba de autodiagnostico del almacen nativo.'));
    }
    return const Right(true);
  }
}

class MockDeviceFingerprint extends DeviceFingerprint {
  @override
  Future<String> generate() async => '1111-2222-3333-4444';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SPP3 LicenseManager Integrado (BDJ Studio Sample Pad)', () {
    late MemorySecurityPort securityPort;
    late MockDeviceFingerprint fingerprint;
    late LicenseManager licenseManager;
    late AdminCertificate adminCert;
    late SimpleKeyPair operatorKeyPair;

    setUp(() async {
      securityPort = MemorySecurityPort();
      fingerprint = MockDeviceFingerprint();
      licenseManager = LicenseManager(
        secureStorage: securityPort,
        fingerprint: fingerprint,
        productCode: 'bdj_studio_sample_pad',
        defaultAppVersion: '1.0.3',
      );

      // Preparar jerarquia oficial de claves para emitir tokens SPP3 de prueba
      final rootSeedBytes = base64Url.decode('QkRKX1NUVURJT19TUFAzX1JPT1RfU0VDUkVUXzIwMjY=');
      final rootKeyPair = await KeyHierarchy.generateKeyPairFromSeed(rootSeedBytes);
      operatorKeyPair = await KeyHierarchy.generateKeyPair();
      final opPub = base64UrlEncode((await operatorKeyPair.extractPublicKey()).bytes);

      adminCert = await KeyHierarchy.issueAdminCertificate(
        adminId: 'test_admin@bdjstudio.com',
        operatorPublicKeyBase64: opPub,
        rootKeyPair: rootKeyPair,
        validityDuration: const Duration(days: 30),
      );
    });

    test('1. Falla activacion inmediatamente si el self-test del almacen seguro es incorrecto', () async {
      securityPort.simulateSelfTestFailure = true;
      final result = await licenseManager.activateLicense('SPP3.cualquier.clave.valida');
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, contains('almac')),
        (_) => fail('Deberia haber fallado el self-test'),
      );
    });

    test('2. Rechaza licencias con formato SPP2 obsoleto por seguridad fail-closed con mensaje específico', () async {
      final result = await licenseManager.activateLicense('SPP2.antigua.clave.obsoleta');
      expect(result.isLeft(), isTrue);
      expect(licenseManager.currentStatus, equals(LicenseStatus.invalid));
      result.fold(
        (failure) => expect(
          failure.message,
          equals('Las licencias SPP2 están obsoletas y desactivadas. Solicita una nueva licencia SPP3.'),
        ),
        (_) => fail('Deberia ser rechazada'),
      );
    });

    test('3. Activa y valida exitosamente una licencia SPP3 autentica con coincidencia de version exacta', () async {
      final hwidHash = KeyHierarchy.hashHwid('1111-2222-3333-4444');
      final payload = Spp3Payload(
        licenseId: 'LIC-PAD-1001',
        customerId: 'CLIENT-PAD',
        deviceId: '1111-2222-3333-4444',
        hwidHash: hwidHash,
        productCode: 'bdj_studio_sample_pad',
        exactVersion: '1.0.3+4', // Emision con build
        plan: 'pro',
        issuedAtUtc: DateTime.now().toUtc(),
        expiresAtUtc: DateTime.now().toUtc().add(const Duration(days: 365)),
      );

      final token = await Spp3Token.issue(
        payload: payload,
        signerCertificate: adminCert,
        operatorKeyPair: operatorKeyPair,
      );

      final actResult = await licenseManager.activateLicense(token);
      expect(actResult.isRight(), isTrue);
      expect(licenseManager.isLicensed, isTrue);
      expect(licenseManager.currentStatus, equals(LicenseStatus.active));

      // Verificar persistencia en almacen seguro y validacion en siguiente arranque
      final valResult = await licenseManager.validateLicense();
      expect(valResult.isRight(), isTrue);
      expect(licenseManager.isLicensed, isTrue);
    });

    test('4. Rechaza activacion SPP3 si hay discrepancia de version exacta (Version Mismatch)', () async {
      final hwidHash = KeyHierarchy.hashHwid('1111-2222-3333-4444');
      final payload = Spp3Payload(
        licenseId: 'LIC-PAD-2002',
        customerId: 'CLIENT-PAD-2',
        deviceId: '1111-2222-3333-4444',
        hwidHash: hwidHash,
        productCode: 'bdj_studio_sample_pad',
        exactVersion: '2.0.0', // Diferente a la app que es 1.0.3
        plan: 'pro',
        issuedAtUtc: DateTime.now().toUtc(),
        expiresAtUtc: DateTime.now().toUtc().add(const Duration(days: 365)),
      );

      final token = await Spp3Token.issue(
        payload: payload,
        signerCertificate: adminCert,
        operatorKeyPair: operatorKeyPair,
      );

      final result = await licenseManager.activateLicense(token);
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, contains('vers')),
        (_) => fail('Deberia rechazar por version mismatch'),
      );
      expect(licenseManager.isLicensed, isFalse);
    });

    test('5. Rechaza cadena sin prefijo y rechaza token SPP3 corrupto', () async {
      final resNoPrefix = await licenseManager.activateLicense('CADENASINPREFIJO.1234.5678');
      expect(resNoPrefix.isLeft(), isTrue);
      resNoPrefix.fold(
        (l) => expect(l.message, contains('no corresponde al formato oficial')),
        (r) => fail('No debe aceptar sin prefijo'),
      );

      final resCorrupt = await licenseManager.activateLicense('SPP3.datoscorruptos.firmafalsa');
      expect(resCorrupt.isLeft(), isTrue);
    });

    test('6. Rechaza token SPP3 de otro producto', () async {
      final hwidHash = KeyHierarchy.hashHwid('1111-2222-3333-4444');
      final payload = Spp3Payload(
        licenseId: 'LIC-OTHER-3001',
        customerId: 'CLIENT-OTHER',
        deviceId: '1111-2222-3333-4444',
        hwidHash: hwidHash,
        productCode: 'bdj_studio_synth_pro', // Producto incorrecto
        exactVersion: '1.0.3',
        plan: 'pro',
        issuedAtUtc: DateTime.now().toUtc(),
        expiresAtUtc: DateTime.now().toUtc().add(const Duration(days: 365)),
      );

      final token = await Spp3Token.issue(
        payload: payload,
        signerCertificate: adminCert,
        operatorKeyPair: operatorKeyPair,
      );

      final result = await licenseManager.activateLicense(token);
      expect(result.isLeft(), isTrue);
      result.fold(
        (l) => expect(l.message, isNot(contains('producto')), reason: 'Por seguridad fail-closed no debe revelar que el token pertenece a otro producto.'),
        (r) => fail('No debe aceptar otro producto'),
      );
    });

    test('7. Rechaza token SPP3 de otro HWID', () async {
      final wrongHwidHash = KeyHierarchy.hashHwid('9999-9999-9999-9999');
      final payload = Spp3Payload(
        licenseId: 'LIC-HWID-4001',
        customerId: 'CLIENT-HWID',
        deviceId: '9999-9999-9999-9999',
        hwidHash: wrongHwidHash, // HWID incorrecto
        productCode: 'bdj_studio_sample_pad',
        exactVersion: '1.0.3',
        plan: 'pro',
        issuedAtUtc: DateTime.now().toUtc(),
        expiresAtUtc: DateTime.now().toUtc().add(const Duration(days: 365)),
      );

      final token = await Spp3Token.issue(
        payload: payload,
        signerCertificate: adminCert,
        operatorKeyPair: operatorKeyPair,
      );

      final result = await licenseManager.activateLicense(token);
      expect(result.isLeft(), isTrue);
    });

    test('8. Escritura segura diferencial y registro de lastLicenseCheckUtc', () async {
      final hwidHash = KeyHierarchy.hashHwid('1111-2222-3333-4444');
      final payload = Spp3Payload(
        licenseId: 'LIC-DIFF-8001',
        customerId: 'CLIENT-DIFF',
        deviceId: '1111-2222-3333-4444',
        hwidHash: hwidHash,
        productCode: 'bdj_studio_sample_pad',
        exactVersion: '1.0.3',
        plan: 'pro',
        issuedAtUtc: DateTime.now().toUtc(),
        expiresAtUtc: DateTime.now().toUtc().add(const Duration(days: 365)),
      );

      final token = await Spp3Token.issue(
        payload: payload,
        signerCertificate: adminCert,
        operatorKeyPair: operatorKeyPair,
      );

      // 1. Primera activación: debe escribir todas las llaves requeridas
      securityPort.writtenKeys.clear();
      final actResult = await licenseManager.activateLicense(token);
      expect(actResult.isRight(), isTrue);
      expect(securityPort.writtenKeys, contains(LicenseStorageKeys.licenseKey));
      expect(securityPort.writtenKeys, contains(LicenseStorageKeys.licenseStatus));
      expect(securityPort.writtenKeys, contains(LicenseStorageKeys.deviceId));
      expect(securityPort.writtenKeys, contains(LicenseStorageKeys.lastSyncAt));
      expect(securityPort.writtenKeys, contains(LicenseStorageKeys.lastLicenseCheckUtc));

      final firstCheck = await licenseManager.getLastLicenseCheckUtc();
      expect(firstCheck, isNotNull);

      // 2. Revalidación con datos idénticos: solo escribe lastSyncAt y lastLicenseCheckUtc
      securityPort.writtenKeys.clear();
      final valResult = await licenseManager.validateLicense();
      expect(valResult.isRight(), isTrue);

      expect(securityPort.writtenKeys, isNot(contains(LicenseStorageKeys.licenseKey)));
      expect(securityPort.writtenKeys, isNot(contains(LicenseStorageKeys.licenseStatus)));
      expect(securityPort.writtenKeys, isNot(contains(LicenseStorageKeys.deviceId)));
      expect(securityPort.writtenKeys, contains(LicenseStorageKeys.lastSyncAt));
      expect(securityPort.writtenKeys, contains(LicenseStorageKeys.lastLicenseCheckUtc));
    });

    test('9. Deteccion de retroceso de reloj retorna ClockFailure solo para licencias con caducidad', () async {
      final hwidHash = KeyHierarchy.hashHwid('1111-2222-3333-4444');
      final payload = Spp3Payload(
        licenseId: 'LIC-CLOCK-9001',
        customerId: 'CLIENT-CLOCK',
        deviceId: '1111-2222-3333-4444',
        hwidHash: hwidHash,
        productCode: 'bdj_studio_sample_pad',
        exactVersion: '1.0.3',
        plan: 'pro',
        issuedAtUtc: DateTime.now().toUtc(),
        expiresAtUtc: DateTime.now().toUtc().add(const Duration(days: 30)),
      );

      final token = await Spp3Token.issue(
        payload: payload,
        signerCertificate: adminCert,
        operatorKeyPair: operatorKeyPair,
      );

      final actResult = await licenseManager.activateLicense(token);
      expect(actResult.isRight(), isTrue);

      // Simulamos que el reloj retrocedió colocando lastLicenseCheckUtc 1 hora en el futuro
      securityPort.storage[LicenseStorageKeys.lastLicenseCheckUtc] =
          DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String();

      final valResult = await licenseManager.validateLicense();
      expect(valResult.isLeft(), isTrue);
      valResult.fold(
        (failure) {
          expect(failure, isA<ClockFailure>());
          expect(failure.message, contains('retrocedió de forma anormal'));
        },
        (_) => fail('Deberia haber fallado por retroceso de reloj'),
      );
    });

    test('10. Ausencia de 7 dias: lastLicenseCheckUtc avanza con trinquete de 48h y no queda congelado', () async {
      var simulatedTime = DateTime.now().toUtc();
      final timedManager = LicenseManager(
        secureStorage: securityPort,
        fingerprint: fingerprint,
        clock: () => simulatedTime,
      );

      final hwidHash = KeyHierarchy.hashHwid('1111-2222-3333-4444');
      final payload = Spp3Payload(
        licenseId: 'LIC-ABSENCE-1001',
        customerId: 'CLIENT-ABSENCE',
        deviceId: '1111-2222-3333-4444',
        hwidHash: hwidHash,
        productCode: 'bdj_studio_sample_pad',
        exactVersion: '1.0.3',
        plan: 'pro',
        issuedAtUtc: simulatedTime,
        expiresAtUtc: simulatedTime.add(const Duration(days: 365)),
      );

      final token = await Spp3Token.issue(
        payload: payload,
        signerCertificate: adminCert,
        operatorKeyPair: operatorKeyPair,
      );

      final actResult = await timedManager.activateLicense(token);
      expect(actResult.isRight(), isTrue);
      expect(securityPort.storage[LicenseStorageKeys.lastLicenseCheckUtc], equals(simulatedTime.toIso8601String()));

      // Simular ausencia de 7 días sin abrir la app
      final initialCheck = simulatedTime;
      simulatedTime = simulatedTime.add(const Duration(days: 7));
      securityPort.writtenKeys.clear();

      final valResult = await timedManager.validateLicense();
      expect(valResult.isRight(), isTrue);

      // El trinquete no debe dejar congelado lastLicenseCheckUtc en el día 0,
      // sino que debe haber avanzado un máximo de 48h desde la última comprobación
      final expectedCapped = initialCheck.add(const Duration(hours: 48));
      expect(securityPort.writtenKeys, contains(LicenseStorageKeys.lastLicenseCheckUtc));
      expect(securityPort.storage[LicenseStorageKeys.lastLicenseCheckUtc], equals(expectedCapped.toIso8601String()));
    });

    test('11. Salto de +5 anos y correccion: no envenena el trinquete y la app no se bloquea al corregir la hora', () async {
      var simulatedTime = DateTime.now().toUtc();
      final timedManager = LicenseManager(
        secureStorage: securityPort,
        fingerprint: fingerprint,
        clock: () => simulatedTime,
      );

      final hwidHash = KeyHierarchy.hashHwid('1111-2222-3333-4444');
      final payload = Spp3Payload(
        licenseId: 'LIC-FUTURE-1101',
        customerId: 'CLIENT-FUTURE',
        deviceId: '1111-2222-3333-4444',
        hwidHash: hwidHash,
        productCode: 'bdj_studio_sample_pad',
        exactVersion: '1.0.3',
        plan: 'pro',
        issuedAtUtc: simulatedTime,
        // Expira en 10 años para que el token siga siendo criptográficamente válido durante el salto
        expiresAtUtc: simulatedTime.add(const Duration(days: 3650)),
      );

      final token = await Spp3Token.issue(
        payload: payload,
        signerCertificate: adminCert,
        operatorKeyPair: operatorKeyPair,
      );

      final actResult = await timedManager.activateLicense(token);
      expect(actResult.isRight(), isTrue);
      final initialCheck = simulatedTime;

      // 1. Reloj salta 5 años hacia el futuro (ej. error de BIOS o ajuste manual erróneo)
      simulatedTime = simulatedTime.add(const Duration(days: 365 * 5));
      final valResultFuture = await timedManager.validateLicense();
      expect(valResultFuture.isRight(), isTrue);

      // Se guarda lastCheck + 48h, NO la fecha de dentro de 5 años
      final cappedDate = initialCheck.add(const Duration(hours: 48));
      expect(securityPort.storage[LicenseStorageKeys.lastLicenseCheckUtc], equals(cappedDate.toIso8601String()));

      // 2. El usuario corrige la hora inmediatamente a la fecha real (initialCheck + 10m).
      // Al ser now < cappedDate (lastCheck + 48h), el sistema bloquea con ClockFailure
      // acotado a un máximo de ~48 horas (pantalla clockError informativa).
      simulatedTime = initialCheck.add(const Duration(minutes: 10));
      final valResultBlocked = await timedManager.validateLicense();
      expect(valResultBlocked.isLeft(), isTrue);
      valResultBlocked.fold(
        (failure) {
          expect(failure, isA<ClockFailure>());
          expect(failure.message, contains('retrocedió de forma anormal'));
        },
        (_) => fail('Deberia fallar con ClockFailure durante la ventana acotada de 48h'),
      );

      // 3. Cuando el tiempo real alcanza now >= lastCheck + 48h - 5m, la licencia se desbloquea:
      simulatedTime = cappedDate;
      final valResultUnlocked = await timedManager.validateLicense();
      expect(valResultUnlocked.isRight(), isTrue);
      expect(valResultUnlocked.toOption().toNullable()?.status, equals(LicenseStatus.active));
    });
  });
}

