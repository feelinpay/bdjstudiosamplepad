// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

Future<void> runKeychainCiSmokeTest() async {
  print('KEYCHAIN_SMOKE_STARTED');

  const macOsOptions = SafeMacOsOptions(
    accessibility: KeychainAccessibility.first_unlock,
    synchronizable: false,
    groupId: null,
    usesDataProtectionKeychain: false,
  );
  const iOsOptions = IOSOptions(accessibility: KeychainAccessibility.first_unlock);
  const androidOptions = AndroidOptions();
  const windowsOptions = WindowsOptions();
  const linuxOptions = LinuxOptions();

  FlutterSecureStorage storage = const FlutterSecureStorage(
    aOptions: androidOptions,
    iOptions: iOsOptions,
    mOptions: macOsOptions,
    wOptions: windowsOptions,
    lOptions: linuxOptions,
  );

  final random = Random();
  final uuid = '${DateTime.now().microsecondsSinceEpoch}_${random.nextInt(100000)}';
  final testKey = 'bdj.sample_pad.ci_test.$uuid';
  final initialValue = 'val_samplepad_${random.nextInt(1000000)}_${DateTime.now().millisecondsSinceEpoch}';
  final updatedValue = 'val_samplepad_upd_${random.nextInt(1000000)}_${DateTime.now().millisecondsSinceEpoch}';

  void logFailure(String statusToken, String operation, dynamic e) {
    print(statusToken);
    print('--- DIAGNÓSTICO DE FALLO EN KEYCHAIN (SANITY CHECK) ---');
    print('Operación: $operation');
    print('Bundle Identifier: com.bdjstudio.samplepadpro');
    print('Arquitectura: ${Platform.version} (${Platform.operatingSystemVersion})');
    print('Configuración MacOsOptions:');
    print('  groupId: null');
    print('  synchronizable: false');
    print('  accessibility: first_unlock');
    if (e is PlatformException) {
      print('PlatformException.code: ${e.code}');
      final detailsStr = e.details?.toString() ?? '';
      final match = RegExp(r'(-?\d+)').firstMatch(detailsStr);
      print('OSStatus sanitizado: ${match?.group(1) ?? e.message ?? "N/A"}');
    } else {
      print('Error tipo: ${e.runtimeType}');
      print('Mensaje sanitizado: ${e.toString().replaceAll(RegExp(r"val_[A-Za-z0-9_]+"), "[REDACTED]")}');
    }
    print('====================================================');
    exit(1);
  }

  // 1. Eliminar una clave temporal anterior
  try {
    await storage.delete(
      key: testKey,
      aOptions: androidOptions,
      iOptions: iOsOptions,
      mOptions: macOsOptions,
      wOptions: windowsOptions,
      lOptions: linuxOptions,
    );
    print('KEYCHAIN_DELETE_PREVIOUS_OK');
  } catch (e) {
    final str = e.toString();
    if (str.contains('-34018') || str.contains('-25300') || str.contains('item not found') || str.contains('MissingEntitlement')) {
      print('KEYCHAIN_DELETE_PREVIOUS_OK');
    } else {
      logFailure('KEYCHAIN_DELETE_FAILED', '1. Eliminar clave temporal anterior', e);
    }
  }

  // 2. Escribir un valor temporal aleatorio
  try {
    await storage.write(
      key: testKey,
      value: initialValue,
      aOptions: androidOptions,
      iOptions: iOsOptions,
      mOptions: macOsOptions,
      wOptions: windowsOptions,
      lOptions: linuxOptions,
    );
    print('KEYCHAIN_WRITE_OK');
  } catch (e) {
    logFailure('KEYCHAIN_WRITE_FAILED', '2. Escribir valor temporal aleatorio', e);
  }

  // 3. Leerlo y 4. Compararlo
  try {
    final readVal = await storage.read(
      key: testKey,
      aOptions: androidOptions,
      iOptions: iOsOptions,
      mOptions: macOsOptions,
      wOptions: windowsOptions,
      lOptions: linuxOptions,
    );
    if (readVal != initialValue) {
      throw PlatformException(code: 'INTEGRITY_MISMATCH', message: 'El valor leído no coincide con el original.');
    }
    print('KEYCHAIN_READ_OK');
  } catch (e) {
    logFailure('KEYCHAIN_READ_FAILED', '3/4. Leer y comparar valor inicial', e);
  }

  // 5. Sobrescribirlo
  try {
    await storage.write(
      key: testKey,
      value: updatedValue,
      aOptions: androidOptions,
      iOptions: iOsOptions,
      mOptions: macOsOptions,
      wOptions: windowsOptions,
      lOptions: linuxOptions,
    );
    print('KEYCHAIN_OVERWRITE_OK');
  } catch (e) {
    logFailure('KEYCHAIN_WRITE_FAILED', '5. Sobrescribir valor temporal', e);
  }

  // 6. Leer el nuevo valor
  try {
    final readUpd = await storage.read(
      key: testKey,
      aOptions: androidOptions,
      iOptions: iOsOptions,
      mOptions: macOsOptions,
      wOptions: windowsOptions,
      lOptions: linuxOptions,
    );
    if (readUpd != updatedValue) {
      throw PlatformException(code: 'OVERWRITE_MISMATCH', message: 'El valor leído tras overwrite no coincide.');
    }
    // El paso 6 se valida dentro de la secuencia hacia la persistencia
  } catch (e) {
    logFailure('KEYCHAIN_READ_FAILED', '6. Leer nuevo valor sobrescrito', e);
  }

  // 7. Recrear FlutterSecureStorage o el servicio
  try {
    storage = const FlutterSecureStorage(
      aOptions: androidOptions,
      iOptions: iOsOptions,
      mOptions: macOsOptions,
      wOptions: windowsOptions,
      lOptions: linuxOptions,
    );
    print('KEYCHAIN_RECREATE_STORAGE_OK');
  } catch (e) {
    logFailure('KEYCHAIN_PERSISTENCE_FAILED', '7. Recrear instancia de almacenamiento', e);
  }

  // 8. Volver a leer para comprobar persistencia
  try {
    final readPersisted = await storage.read(
      key: testKey,
      aOptions: androidOptions,
      iOptions: iOsOptions,
      mOptions: macOsOptions,
      wOptions: windowsOptions,
      lOptions: linuxOptions,
    );
    if (readPersisted != updatedValue) {
      throw PlatformException(code: 'PERSISTENCE_MISMATCH', message: 'Fallo de persistencia al recrear instancia.');
    }
    print('KEYCHAIN_PERSISTENCE_OK');
  } catch (e) {
    logFailure('KEYCHAIN_PERSISTENCE_FAILED', '8. Comprobar persistencia tras recreación', e);
  }

  // 9. Eliminar la clave
  try {
    await storage.delete(
      key: testKey,
      aOptions: androidOptions,
      iOptions: iOsOptions,
      mOptions: macOsOptions,
      wOptions: windowsOptions,
      lOptions: linuxOptions,
    );
    print('KEYCHAIN_DELETE_OK');
  } catch (e) {
    final str = e.toString();
    if (str.contains('-34018') || str.contains('MissingEntitlement')) {
      print('KEYCHAIN_DELETE_OK');
    } else {
      logFailure('KEYCHAIN_DELETE_FAILED', '9. Eliminar clave tras persistencia', e);
    }
  }

  // 10. Confirmar que una lectura posterior devuelve null
  try {
    final checkNull = await storage.read(
      key: testKey,
      aOptions: androidOptions,
      iOptions: iOsOptions,
      mOptions: macOsOptions,
      wOptions: windowsOptions,
      lOptions: linuxOptions,
    );
    if (checkNull != null) {
      throw PlatformException(code: 'DELETE_INCOMPLETE', message: 'La clave sigue devolviendo contenido tras delete.');
    }
    print('KEYCHAIN_READ_AFTER_DELETE_NULL');
  } catch (e) {
    logFailure('KEYCHAIN_DELETE_FAILED', '10. Confirmar null en lectura posterior', e);
  }

  print('KEYCHAIN_TEST_PASSED');
  exit(0);
}
