// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('macOS Hosted Runner — App Launch + Native Keychain Smoke Test', () {
    testWidgets('Verify write, read, overwrite, persist, and fail-closed delete on Keychain', (WidgetTester tester) async {
      print('[CI_TEST_HOST] Booting minimal UI host for Keychain test...');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('BDJ Keychain CI Test Host'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      print('[CI_TEST_HOST] Minimal Flutter UI mounted successfully! Connection established.');

      const macOsOptions = SafeMacOsOptions(
        accessibility: KeychainAccessibility.first_unlock,
        synchronizable: false,
        groupId: null,
        usesDataProtectionKeychain: false,
      );
      const androidOptions = AndroidOptions();
      const iOsOptions = IOSOptions(accessibility: KeychainAccessibility.first_unlock);
      const windowsOptions = WindowsOptions();
      const linuxOptions = LinuxOptions();

      FlutterSecureStorage storage = const FlutterSecureStorage(
        aOptions: androidOptions,
        iOptions: iOsOptions,
        mOptions: macOsOptions,
        wOptions: windowsOptions,
        lOptions: linuxOptions,
      );

      final testKey = 'bdj.sample_pad.ci_test.${DateTime.now().microsecondsSinceEpoch}';
      final initialVal = 'ci_val_init_${DateTime.now().millisecondsSinceEpoch}';
      final updatedVal = 'ci_val_upd_${DateTime.now().millisecondsSinceEpoch}';

      void logStep(String step, String result) {
        print('[KEYCHAIN_TEST] Step $step: $result');
      }

      void logDiagnostics(dynamic e, String op, String statusToken) {
        print('=== ERROR DIAGNOSTICS FOR KEYCHAIN OPERATION: $op ===');
        print('Status code: $statusToken');
        print('Operation failed: $op');
        print('MacOsOptions configured: accessibility=${macOsOptions.accessibility}, synchronizable=${macOsOptions.synchronizable}, groupId=${macOsOptions.groupId}');
        if (e is PlatformException) {
          print('PlatformException.code: ${e.code}');
          print('PlatformException.message: ${e.message}');
          print('PlatformException.details: ${e.details}');
          final detailsStr = e.details?.toString() ?? '';
          final match = RegExp(r'(-?\d+)').firstMatch(detailsStr);
          if (match != null) {
            print('OSStatus (extracted): ${match.group(1)}');
          }
        } else {
          print('Exception type: ${e.runtimeType}');
          print('Exception content (sanitized): ${e.toString().replaceAll(RegExp(r"ci_val_[A-Za-z0-9_]+"), "[REDACTED]")}');
        }
        print('=====================================================');
      }

      // 1. delete de una clave temporal anterior (no debe fallar si no existe)
      try {
        await storage.delete(
          key: testKey,
          aOptions: androidOptions,
          iOptions: iOsOptions,
          mOptions: macOsOptions,
          wOptions: windowsOptions,
          lOptions: linuxOptions,
        );
        logStep('1. delete previo', 'ÉXITO (semántica correcta, sin excepción en clave inexistente)');
      } catch (e) {
        final str = e.toString();
        if (str.contains('-34018') || str.contains('-25300') || str.contains('item not found') || str.contains('MissingEntitlement')) {
          logStep('1. delete previo', 'ÉXITO (semántica correcta, ignorado error -34018/no existe en CI)');
        } else {
          logDiagnostics(e, '1. delete previo', 'KEYCHAIN_DELETE_FAILED');
          rethrow;
        }
      }

      // 2. write de un valor aleatorio no sensible
      try {
        await storage.write(
          key: testKey,
          value: initialVal,
          aOptions: androidOptions,
          iOptions: iOsOptions,
          mOptions: macOsOptions,
          wOptions: windowsOptions,
          lOptions: linuxOptions,
        );
        logStep('2. write', 'ÉXITO');
      } catch (e) {
        logDiagnostics(e, '2. write inicial', 'KEYCHAIN_WRITE_FAILED');
        rethrow;
      }

      // 3. read & 4. comparación
      try {
        final read1 = await storage.read(
          key: testKey,
          aOptions: androidOptions,
          iOptions: iOsOptions,
          mOptions: macOsOptions,
          wOptions: windowsOptions,
          lOptions: linuxOptions,
        );
        logStep('3. read', read1 != null ? 'ÉXITO (valor recuperado)' : 'FALLO (null)');
        expect(read1, equals(initialVal), reason: 'El valor leído del Keychain debe coincidir con el escrito inicialmente.');
        logStep('4. comparación', 'ÉXITO (integridad verificada sin imprimir secreto)');
      } catch (e) {
        logDiagnostics(e, '3/4. read inicial y comparación', 'KEYCHAIN_READ_FAILED');
        rethrow;
      }

      // 5. overwrite
      try {
        await storage.write(
          key: testKey,
          value: updatedVal,
          aOptions: androidOptions,
          iOptions: iOsOptions,
          mOptions: macOsOptions,
          wOptions: windowsOptions,
          lOptions: linuxOptions,
        );
        logStep('5. overwrite', 'ÉXITO');
      } catch (e) {
        logDiagnostics(e, '5. overwrite', 'KEYCHAIN_WRITE_FAILED');
        rethrow;
      }

      // 6. read actualizado
      try {
        final read2 = await storage.read(
          key: testKey,
          aOptions: androidOptions,
          iOptions: iOsOptions,
          mOptions: macOsOptions,
          wOptions: windowsOptions,
          lOptions: linuxOptions,
        );
        expect(read2, equals(updatedVal), reason: 'El valor recuperado tras overwrite debe coincidir con la actualización.');
        logStep('6. read actualizado', 'ÉXITO (valor modificado correctamente en Keychain)');
      } catch (e) {
        logDiagnostics(e, '6. read actualizado', 'KEYCHAIN_READ_FAILED');
        rethrow;
      }

      // 7. recrear FlutterSecureStorage & 8. comprobar persistencia
      try {
        storage = const FlutterSecureStorage(
          aOptions: androidOptions,
          iOptions: iOsOptions,
          mOptions: macOsOptions,
          wOptions: windowsOptions,
          lOptions: linuxOptions,
        );
        logStep('7. recrear FlutterSecureStorage', 'ÉXITO (nueva instancia en memoria)');

        final read3 = await storage.read(
          key: testKey,
          aOptions: androidOptions,
          iOptions: iOsOptions,
          mOptions: macOsOptions,
          wOptions: windowsOptions,
          lOptions: linuxOptions,
        );
        expect(read3, equals(updatedVal), reason: 'El valor debe persistir en el Keychain independientemente de la instancia en memoria.');
        logStep('8. persistencia tras recreación', 'ÉXITO (persiste en llavero nativo)');
      } catch (e) {
        logDiagnostics(e, '7/8. persistencia tras recrear instancia', 'KEYCHAIN_PERSISTENCE_FAILED');
        rethrow;
      }

      // 9. delete & 10. confirmar null
      try {
        await storage.delete(
          key: testKey,
          aOptions: androidOptions,
          iOptions: iOsOptions,
          mOptions: macOsOptions,
          wOptions: windowsOptions,
          lOptions: linuxOptions,
        );
        logStep('9. delete final', 'ÉXITO (sin excepciones lanzadas por delete)');
      } catch (e) {
        final str = e.toString();
        if (str.contains('-34018') || str.contains('MissingEntitlement')) {
          logStep('9. delete final', 'ÉXITO (-34018 capturado por consulta synchronizable del plugin, borrado real local verificado a continuación)');
        } else {
          logDiagnostics(e, '9. delete final', 'KEYCHAIN_DELETE_FAILED');
          rethrow;
        }
      }

      try {
        final checkNull = await storage.read(
          key: testKey,
          aOptions: androidOptions,
          iOptions: iOsOptions,
          mOptions: macOsOptions,
          wOptions: windowsOptions,
          lOptions: linuxOptions,
        );
        expect(checkNull, isNull, reason: 'El valor debe haber sido eliminado completamente; read debe devolver null.');
        logStep('10. read tras delete', 'ÉXITO (confirmado null tras borrado real)');
      } catch (e) {
        logDiagnostics(e, '10. comprobación null tras delete', 'KEYCHAIN_DELETE_FAILED');
        rethrow;
      }

      print('\n========================================');
      print('KEYCHAIN_TEST_PASSED');
      print('========================================\n');
    });
  });
}
