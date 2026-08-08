import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dartz/dartz.dart';
import '../errors/failures.dart';
import 'security_port.dart';

class SafeMacOsOptions extends MacOsOptions {
  const SafeMacOsOptions({
    super.accessibility = KeychainAccessibility.first_unlock,
    super.synchronizable = false,
    super.groupId,
    super.usesDataProtectionKeychain = false,
  });

  @override
  Map<String, String> toMap() {
    final map = <String, String>{
      ...super.toMap(),
      'usesDataProtectionKeychain': '$usesDataProtectionKeychain',
      'useDataProtectionKeyChain': '$usesDataProtectionKeychain',
    };
    if (!usesDataProtectionKeychain) {
      map.remove('accessibility');
      map.remove('synchronizable');
      map.remove('groupId');
    }
    return map;
  }
}

class SecureStorageImpl implements SecurityPort {
  final FlutterSecureStorage _storage;

  static const androidOptions = AndroidOptions();
  static const iOsOptions = IOSOptions(accessibility: KeychainAccessibility.first_unlock);
  static const macOsOptions = SafeMacOsOptions(
    accessibility: KeychainAccessibility.first_unlock,
    synchronizable: false,
    groupId: null,
    usesDataProtectionKeychain: false,
  );
  static const windowsOptions = WindowsOptions();
  static const linuxOptions = LinuxOptions();

  SecureStorageImpl({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(
        aOptions: androidOptions,
        iOptions: iOsOptions,
        mOptions: macOsOptions,
        wOptions: windowsOptions,
        lOptions: linuxOptions,
      );

  SecurityFailure _handleError(dynamic e, [String operation = 'unknown']) {
    final msg = e.toString().toLowerCase();
    if (Platform.isLinux || msg.contains('libsecret') || msg.contains('secret service') || msg.contains('g_dbus') || msg.contains('freedesktop')) {
      return const SecurityFailure(
        'LIBSECRET_UNAVAILABLE: El servicio de almacenamiento seguro libsecret/Secret Service no estÃ¡ disponible o accesible en Linux. Se bloquea la activaciÃ³n por seguridad Fail-Closed.',
      );
    }
    if (Platform.isMacOS || msg.contains('keychain') || msg.contains('osstatus') || msg.contains('errsec')) {
      final sanitizedErr = e.toString().replaceAll(RegExp(r'\b([A-Za-z0-9-_]{24,})\b'), '[REDACTED_SECRET]');
      return SecurityFailure(
        'No se puede guardar la validaciÃ³n segura local: error al ejecutar [$operation] en llavero nativo macOS (accessibility: first_unlock, synchronizable: false, groupId: null). Detalle nativo/OSStatus: $sanitizedErr. Fail-Closed activo.',
      );
    }
    return SecurityFailure('No se pudo guardar la validaciÃ³n segura local: error al interactuar con almacÃ©n del sistema ($e)');
  }

  @override
  Future<Result<void>> storeSecure(String key, String value) async {
    try {
      await _storage.write(
        key: key,
        value: value,
        aOptions: androidOptions,
        iOptions: iOsOptions,
        mOptions: macOsOptions,
        wOptions: windowsOptions,
        lOptions: linuxOptions,
      );
      return const Right(null);
    } catch (e) {
      return Left(_handleError(e, 'write'));
    }
  }

  @override
  Future<Result<String?>> readSecure(String key) async {
    try {
      var value = await _storage.read(
        key: key,
        aOptions: androidOptions,
        iOptions: iOsOptions,
        mOptions: macOsOptions,
        wOptions: windowsOptions,
        lOptions: linuxOptions,
      );
      return Right(value);
    } catch (e) {
      return Left(_handleError(e, 'read'));
    }
  }

  @override
  Future<Result<void>> deleteSecure(String key) async {
    try {
      await _storage.delete(
        key: key,
        aOptions: androidOptions,
        iOptions: iOsOptions,
        mOptions: macOsOptions,
        wOptions: windowsOptions,
        lOptions: linuxOptions,
      );
      return const Right(null);
    } catch (e) {
      return Left(_handleError(e, 'delete'));
    }
  }

  @override
  Future<Result<bool>> containsSecure(String key) async {
    try {
      var contains = await _storage.containsKey(
        key: key,
        aOptions: androidOptions,
        iOptions: iOsOptions,
        mOptions: macOsOptions,
        wOptions: windowsOptions,
        lOptions: linuxOptions,
      );
      return Right(contains);
    } catch (e) {
      return Left(_handleError(e, 'contains'));
    }
  }

  @override
  Future<Result<bool>> performSelfTest() async {
    final testKey = 'bdj_selftest_${DateTime.now().millisecondsSinceEpoch}';
    // Usar clave dinÃ¡mica evita bloqueos errSecDuplicateItem (-25299) de Keychain por firmas previas
    final testValue = 'selftest_${DateTime.now().millisecondsSinceEpoch}';
    try {
      await _storage.write(
        key: testKey,
        value: testValue,
        aOptions: androidOptions,
        iOptions: iOsOptions,
        mOptions: macOsOptions,
        wOptions: windowsOptions,
        lOptions: linuxOptions,
      );
      final readBack = await _storage.read(
        key: testKey,
        aOptions: androidOptions,
        iOptions: iOsOptions,
        mOptions: macOsOptions,
        wOptions: windowsOptions,
        lOptions: linuxOptions,
      );
      await _storage.delete(
        key: testKey,
        aOptions: androidOptions,
        iOptions: iOsOptions,
        mOptions: macOsOptions,
        wOptions: windowsOptions,
        lOptions: linuxOptions,
      );
      if (readBack != testValue) {
        return const Left(SecurityFailure('No se pudo guardar la validaciÃ³n segura local: lectura posterior en llavero nativo discordante.'));
      }
      final checkDeleted = await _storage.read(
        key: testKey,
        aOptions: androidOptions,
        iOptions: iOsOptions,
        mOptions: macOsOptions,
        wOptions: windowsOptions,
        lOptions: linuxOptions,
      );
      if (checkDeleted != null) {
        return const Left(SecurityFailure('No se pudo guardar la validaciÃ³n segura local: error al verificar borrado en llavero nativo.'));
      }
      return const Right(true);
    } catch (e) {
      return Left(_handleError(e, 'self_test'));
    }
  }
}




