import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:bdj_license_core/bdj_license_core.dart';
import '../../lib/core/errors/failures.dart';
import '../../lib/core/licensing/license_manager.dart';
import '../../lib/core/licensing/licensing_port.dart';
import '../../lib/core/security/device_fingerprint.dart';
import '../../lib/core/security/security_port.dart';

class MemorySecurityPort implements SecurityPort {
  final Map<String, String> storage = {};

  @override
  Future<Result<void>> storeSecure(String key, String value) async {
    storage[key] = value;
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
  Future<Result<bool>> performSelfTest() async => const Right(true);
}

class MockDeviceFingerprint extends DeviceFingerprint {
  @override
  Future<String> generate() async => '1111-2222-3333-4444';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sample Pad - Validación Estricta major.minor.patch (10 Escenarios)', () {
    late MemorySecurityPort securityPort;
    late MockDeviceFingerprint fingerprint;
    late AdminCertificate adminCert;
    late SimpleKeyPair operatorKeyPair;

    setUp(() async {
      securityPort = MemorySecurityPort();
      fingerprint = MockDeviceFingerprint();

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

    Future<String> createToken(String version) async {
      return Spp3Token.issue(
        payload: Spp3Payload(
          licenseId: 'LIC-SAM-VER-01',
          customerId: 'CUST-01',
          deviceId: 'DEV-01',
          hwidHash: KeyHierarchy.hashHwid('1111-2222-3333-4444'),
          productCode: 'bdj_studio_sample_pad',
          exactVersion: version,
          plan: 'pro',
          issuedAtUtc: DateTime.now().toUtc(),
        ),
        signerCertificate: adminCert,
        operatorKeyPair: operatorKeyPair,
      );
    }

    Future<LicenseManager> createManager(String appVer) async {
      return LicenseManager(
        secureStorage: securityPort,
        fingerprint: fingerprint,
        productCode: 'bdj_studio_sample_pad',
        defaultAppVersion: appVer,
      );
    }

    test('1. 1.0.3 contra 1.0.3 (Acepta)', () async {
      final token = await createToken('1.0.3');
      final mgr = await createManager('1.0.3');
      final result = await mgr.activateLicense(token);
      expect(result.isRight(), isTrue);
      expect(mgr.currentStatus, equals(LicenseStatus.active));
    });

    test('2. 1.0.3 contra 1.0.3+1 (Acepta - ignora +build)', () async {
      final token = await createToken('1.0.3');
      final mgr = await createManager('1.0.3+1');
      final result = await mgr.activateLicense(token);
      expect(result.isRight(), isTrue);
    });

    test('3. 1.0.3 contra 1.0.3+25 (Acepta)', () async {
      final token = await createToken('1.0.3+5');
      final mgr = await createManager('1.0.3+25');
      final result = await mgr.activateLicense(token);
      expect(result.isRight(), isTrue);
    });

    test('4. 1.0.3 contra 1.0.2 (RECHAZA)', () async {
      final token = await createToken('1.0.3');
      final mgr = await createManager('1.0.2');
      final result = await mgr.activateLicense(token);
      expect(result.isLeft(), isTrue);
    });

    test('5. 1.0.3 contra 1.0.4 (RECHAZA)', () async {
      final token = await createToken('1.0.3');
      final mgr = await createManager('1.0.4');
      final result = await mgr.activateLicense(token);
      expect(result.isLeft(), isTrue);
    });

    test('6. 1.0.3 contra 1.1.0 (RECHAZA)', () async {
      final token = await createToken('1.0.3');
      final mgr = await createManager('1.1.0');
      final result = await mgr.activateLicense(token);
      expect(result.isLeft(), isTrue);
    });

    test('7. 1.0.3 contra 2.0.0 (RECHAZA)', () async {
      final token = await createToken('1.0.3');
      final mgr = await createManager('2.0.0');
      final result = await mgr.activateLicense(token);
      expect(result.isLeft(), isTrue);
    });

    test('8. Prerelease (RECHAZA 1.0.3-beta.1 en app 1.0.3)', () async {
      final token = await createToken('1.0.3');
      final mgr = await createManager('1.0.3-beta.1');
      final result = await mgr.activateLicense(token);
      expect(result.isLeft(), isTrue);
    });

    test('9. Versión vacía (RECHAZA)', () async {
      final token = await createToken('1.0.3');
      final mgr = await createManager('  ');
      final result = await mgr.activateLicense(token);
      expect(result.isLeft(), isTrue);
    });

    test('10. Versión corrupta o no major.minor.patch (RECHAZA)', () async {
      final token = await createToken('1.0.3');
      final mgr = await createManager('1.0');
      final result = await mgr.activateLicense(token);
      expect(result.isLeft(), isTrue);
    });
  });
}
