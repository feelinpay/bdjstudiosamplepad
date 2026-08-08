import 'package:dartz/dartz.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:bdj_license_core/bdj_license_core.dart';
import '../security/security_port.dart';
import '../security/device_fingerprint.dart';
import '../errors/failures.dart';
import 'licensing_port.dart';

class LicenseStorageKeys {
  static const String licenseKey = 'bdj.sample_pad.license_key';
  static const String licenseStatus = 'bdj.sample_pad.license_status';
  static const String accessToken = 'bdj.sample_pad.access_token';
  static const String refreshToken = 'bdj.sample_pad.refresh_token';
  static const String tokenExpiresAt = 'bdj.sample_pad.token_expires_at';
  static const String lastSyncAt = 'bdj.sample_pad.last_sync_at';
  static const String deviceId = 'bdj.sample_pad.device_id';
  static const String hardwareFingerprint = 'bdj.sample_pad.hardware_fingerprint';
  static const String lastLicenseCheckUtc = 'bdj.sample_pad.last_license_check_utc';
  static const String installId = 'bdj.sample_pad.install_id';

  // Llaves legadas para migración transaccional y sin colisiones
  static const String legacyLicenseKey = 'spp_license_key';
  static const String legacyLicenseStatus = 'spp_license_status';
}

class LicenseManager implements LicensingPort {
  final SecurityPort _secureStorage;
  final DeviceFingerprint _fingerprint;
  final String productCode;
  final String defaultAppVersion;

  LicenseStatus _currentStatus = LicenseStatus.none;
  String? _cachedFingerprint;
  String? _cachedAppVersion;

  LicenseManager({
    required SecurityPort secureStorage,
    required DeviceFingerprint fingerprint,
    this.productCode = 'bdj_studio_sample_pad',
    this.defaultAppVersion = '1.0.3',
  }) : _secureStorage = secureStorage,
       _fingerprint = fingerprint;

  @override
  LicenseStatus get currentStatus => _currentStatus;

  @override
  bool get isLicensed => _currentStatus == LicenseStatus.active;

  Future<String> _getAppVersion() async {
    if (_cachedAppVersion != null) return _cachedAppVersion!;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (packageInfo.version.isNotEmpty && packageInfo.version != 'Cargando...') {
        _cachedAppVersion = packageInfo.version;
        return _cachedAppVersion!;
      }
    } catch (_) {}
    _cachedAppVersion = defaultAppVersion;
    return _cachedAppVersion!;
  }

  Future<String> getHardwareFingerprint() async {
    if (_cachedFingerprint != null) return _cachedFingerprint!;
    _cachedFingerprint = await _fingerprint.generate();
    await _secureStorage.storeSecure(
      LicenseStorageKeys.hardwareFingerprint,
      _cachedFingerprint!,
    );
    return _cachedFingerprint!;
  }

  Future<void> _migrateLegacyStorageIfNeeded() async {
    var result = await _secureStorage.readSecure(LicenseStorageKeys.licenseKey);
    final currentKey = result.getOrElse(() => null);
    if (currentKey == null || currentKey.isEmpty) {
      final legacyKey = (await _secureStorage.readSecure(LicenseStorageKeys.legacyLicenseKey)).getOrElse(() => null);
      if (legacyKey != null && legacyKey.isNotEmpty) {
        final legacyStatus = (await _secureStorage.readSecure(LicenseStorageKeys.legacyLicenseStatus)).getOrElse(() => null) ?? LicenseStatus.active.name;
        await _secureStorage.storeSecure(LicenseStorageKeys.licenseKey, legacyKey);
        await _secureStorage.storeSecure(LicenseStorageKeys.licenseStatus, legacyStatus);
        final verifiedKey = (await _secureStorage.readSecure(LicenseStorageKeys.licenseKey)).getOrElse(() => null);
        if (verifiedKey == legacyKey) {
          await _secureStorage.deleteSecure(LicenseStorageKeys.legacyLicenseKey);
          await _secureStorage.deleteSecure(LicenseStorageKeys.legacyLicenseStatus);
        }
      }
    }
  }

  Future<String?> _readStoredKey() async {
    await _migrateLegacyStorageIfNeeded();
    var result = await _secureStorage.readSecure(LicenseStorageKeys.licenseKey);
    return result.getOrElse(() => null);
  }

  Future<String?> _readStoredStatus() async {
    await _migrateLegacyStorageIfNeeded();
    var result = await _secureStorage.readSecure(LicenseStorageKeys.licenseStatus);
    return result.getOrElse(() => null);
  }


  @override
  Future<Result<LicenseInfo>> activateLicense(String licenseKey) async {
    // 1. Self-test obligatorio de almacenamiento seguro antes de activar
    final selfTest = await _secureStorage.performSelfTest();
    if (selfTest.isLeft()) {
      return Left(
        selfTest.fold(
          (l) => l,
          (r) => const SecurityFailure('Error verificando almacén seguro nativo del sistema.'),
        ),
      );
    }

    licenseKey = licenseKey.replaceAll(RegExp(r'\s+'), '');
    final fingerprint = await getHardwareFingerprint();
    final appVersion = await _getAppVersion();

    if (licenseKey.startsWith('SPP2.')) {
      _currentStatus = LicenseStatus.invalid;
      return const Left(
        LicenseFailure('Las licencias SPP2 están obsoletas y desactivadas. Solicita una nueva licencia SPP3.'),
      );
    }

    if (!licenseKey.startsWith('SPP3.')) {
      _currentStatus = LicenseStatus.invalid;
      return const Left(
        LicenseFailure('El código ingresado no corresponde al formato oficial de licencia segura SPP3.'),
      );
    }

    return _activateAndVerifySpp3(licenseKey, fingerprint, appVersion);
  }

  @override
  Future<Result<LicenseInfo>> validateLicense() async {
    final storedKey = await _readStoredKey();
    final storedStatus = await _readStoredStatus();

    if (storedKey == null || storedKey.isEmpty) {
      _currentStatus = LicenseStatus.none;
      return const Left(LicenseFailure('No hay una licencia activa en este dispositivo.'));
    }

    if (storedKey.startsWith('SPP2.')) {
      await deactivateLicense();
      _currentStatus = LicenseStatus.invalid;
      return const Left(
        LicenseFailure('Las licencias SPP2 están obsoletas y desactivadas. Solicita una nueva licencia SPP3.'),
      );
    }

    if (storedStatus == LicenseStatus.active.name && storedKey.startsWith('SPP3.')) {
      final fingerprint = await getHardwareFingerprint();
      final appVersion = await _getAppVersion();
      final verification = await _activateAndVerifySpp3(storedKey, fingerprint, appVersion);
      if (verification.isLeft()) {
        _currentStatus = LicenseStatus.invalid;
        return verification;
      }
      _currentStatus = LicenseStatus.active;
      return verification;
    }

    _currentStatus = LicenseStatus.invalid;
    return const Left(LicenseFailure('Estado de licencia inválido. Intenta reactivar tu clave SPP3.'));
  }

  Future<Result<LicenseInfo>> _activateAndVerifySpp3(
    String licenseKey,
    String fingerprint,
    String appVersion,
  ) async {
    try {
      final hwidHash = KeyHierarchy.hashHwid(fingerprint);
      final result = await Spp3Token.verify(
        token: licenseKey,
        rootPublicKeyBase64: KeyHierarchy.ecosystemRootPublicKey,
        expectedProductCode: productCode,
        expectedVersion: appVersion,
        currentHwidHash: hwidHash,
      );

      if (!result.isValid) {
        _currentStatus = LicenseStatus.invalid;
        return Left(LicenseFailure(result.errorMessage ?? 'Validación criptográfica SPP3 rechazada por el sistema.'));
      }

      final payload = result.payload!;
      final now = DateTime.now().toUtc();

      // Protección contra retroceso de reloj (Anti-Tamper / Time Travel Protection)
      final lastCheckResult = await _secureStorage.readSecure(LicenseStorageKeys.lastLicenseCheckUtc);
      final lastCheck = DateTime.tryParse(lastCheckResult.getOrElse(() => null) ?? '')?.toUtc();
      if (payload.expiresAtUtc != null &&
          lastCheck != null &&
          now.isBefore(lastCheck.subtract(const Duration(minutes: 5)))) {
        return const Left(
          LicenseFailure('La fecha y hora del sistema retrocedió de forma anormal. Ajusta tu reloj a la hora real.'),
        );
      }

      final remainingDays = payload.expiresAtUtc == null
          ? 3650
          : (payload.expiresAtUtc!.difference(now).inHours / 24).ceil();

      await _saveActivationData(
        licenseKey: licenseKey,
        status: LicenseStatus.active.name,
        deviceId: fingerprint,
      );

      await _secureStorage.storeSecure(
        LicenseStorageKeys.lastLicenseCheckUtc,
        now.toIso8601String(),
      );

      _currentStatus = LicenseStatus.active;
      return Right(
        LicenseInfo(
          licenseKey: licenseKey,
          status: LicenseStatus.active,
          activatedAt: payload.issuedAtUtc,
          expiresAt: payload.expiresAtUtc,
          deviceId: fingerprint,
          remainingOfflineDays: remainingDays > 0 ? remainingDays : 0,
        ),
      );
    } catch (e) {
      return Left(LicenseFailure('Error interno durante la verificación criptográfica SPP3: $e'));
    }
  }

  @override
  Future<Result<void>> deactivateLicense() async {
    await _secureStorage.deleteSecure(LicenseStorageKeys.licenseKey);
    await _secureStorage.deleteSecure(LicenseStorageKeys.licenseStatus);
    await _secureStorage.deleteSecure(LicenseStorageKeys.accessToken);
    await _secureStorage.deleteSecure(LicenseStorageKeys.refreshToken);
    await _secureStorage.deleteSecure(LicenseStorageKeys.tokenExpiresAt);
    await _secureStorage.deleteSecure(LicenseStorageKeys.lastSyncAt);
    await _secureStorage.deleteSecure(LicenseStorageKeys.lastLicenseCheckUtc);
    _currentStatus = LicenseStatus.none;
    return const Right(null);
  }

  @override
  Future<Result<LicenseInfo>> syncLicense() async {
    return validateLicense();
  }

  Future<void> _saveActivationData({
    required String licenseKey,
    required String status,
    required String deviceId,
  }) async {
    await _secureStorage.storeSecure(LicenseStorageKeys.licenseKey, licenseKey);
    await _secureStorage.storeSecure(LicenseStorageKeys.licenseStatus, status);
    await _secureStorage.storeSecure(LicenseStorageKeys.deviceId, deviceId);
    await _secureStorage.storeSecure(
      LicenseStorageKeys.lastSyncAt,
      DateTime.now().toIso8601String(),
    );
  }
}
