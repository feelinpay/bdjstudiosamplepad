import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdj_studio_sample_pad/core/audio/audio_engine_state.dart';
import 'package:bdj_studio_sample_pad/core/audio/audio_output_device.dart';
import 'package:bdj_studio_sample_pad/core/audio/audio_initialization_result.dart';
import 'package:bdj_studio_sample_pad/core/utils/concurrency_shield.dart';
import 'package:bdj_studio_sample_pad/features/settings/data/services/settings_service.dart';

import '../../helpers/mock_audio_engine.dart';
import '../../../lib/features/settings/domain/audio_change_result.dart';

void main() {
  group('AudioInitializationResult model', () {
    test('ready result has correct state and flags', () {
      const result = AudioInitializationResult.ready(
        devices: [AudioOutputDevice(id: 1, name: 'Speaker', isDefault: true)],
        appliedDeviceId: 1,
      );
      expect(result.state, AudioEngineState.ready);
      expect(result.appliedDeviceId, 1);
      expect(result.savedDeviceInvalid, isFalse);
    });

    test('noDevice result has correct state', () {
      const result = AudioInitializationResult.noDevice();
      expect(result.state, AudioEngineState.noDevice);
      expect(result.devices, isEmpty);
    });

    test('error result has correct state', () {
      const result = AudioInitializationResult.error(userMessage: 'fail');
      expect(result.state, AudioEngineState.error);
      expect(result.userMessage, 'fail');
    });
  });

  group('AudioChangeResult model', () {
    test('failure is recoverable and not noDevice', () {
      const r = AudioChangeResult.failure('fail');
      expect(r.isRecoverable, isTrue);
      expect(r.isNoDevice, isFalse);
    });

    test('noDevice is recoverable and noDevice', () {
      const r = AudioChangeResult.noDevice('none');
      expect(r.isRecoverable, isTrue);
      expect(r.isNoDevice, isTrue);
    });
  });

  group('CASO 1: Engine initializes and finds devices', () {
    test('State becomes ready, no error message', () async {
      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: -1, name: 'Default', isDefault: true),
        AudioOutputDevice(id: 0, name: 'Speakers', isDefault: false),
      ];

      final result = await engine.initializeAndRestoreDevice(null);
      expect(result.state, AudioEngineState.ready);
      expect(result.devices, isNotEmpty);
      expect(result.savedDeviceInvalid, isFalse);
      expect(result.userMessage, isNull);
      engine.dispose();
    });

    test('Saved device is validated and applied', () async {
      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: -1, name: 'Default', isDefault: true),
        AudioOutputDevice(id: 5, name: 'Headphones', isDefault: false),
      ];

      final result = await engine.initializeAndRestoreDevice(5);
      expect(result.state, AudioEngineState.ready);
      expect(result.appliedDeviceId, 5);
      expect(result.savedDeviceInvalid, isFalse);
      engine.dispose();
    });
  });

  group('CASO 2: Engine no encuentra dispositivos', () {
    test('State becomes noDevice, app does not crash', () async {
      final engine = MockAudioEngine();
      engine.simulateNoDevices = true;

      final result = await engine.initializeAndRestoreDevice(null);
      expect(result.state, AudioEngineState.noDevice);
      expect(result.devices, isEmpty);
      expect(result.userMessage, isNotNull);
      engine.dispose();
    });

    test('C++ exception is NOT exposed to the user', () async {
      final engine = MockAudioEngine();
      engine.simulateNoDevices = true;

      final result = await engine.initializeAndRestoreDevice(null);
      // The user message must not contain C++ exception strings
      expect(
        result.userMessage,
        isNot(contains('SoLoudNoPlaybackDevicesFoundCppException')),
      );
      expect(
        result.userMessage,
        isNot(contains('C++ side')),
      );
      engine.dispose();
    });

    test('Engine remains usable (dispose works without error)', () async {
      final engine = MockAudioEngine();
      engine.simulateNoDevices = true;

      await engine.initializeAndRestoreDevice(null);
      expect(engine.engineState, AudioEngineState.noDevice);
      // Should not throw
      engine.dispose();
      expect(engine.disposed, isTrue);
    });
  });

  group('CASO 3: Dispositivo guardado ya no existe', () {
    test('Falls back to default, savedDeviceInvalid is true', () async {
      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: -1, name: 'Default', isDefault: true),
        AudioOutputDevice(id: 3, name: 'Speakers', isDefault: false),
      ];

      // Saved device ID 99 does not exist in the list
      final result = await engine.initializeAndRestoreDevice(99);
      expect(result.state, AudioEngineState.ready);
      expect(result.savedDeviceInvalid, isTrue);
      expect(result.appliedDeviceId, -1); // Default device
      engine.dispose();
    });

    test('No exception thrown for invalid saved device', () async {
      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: -1, name: 'Default', isDefault: true),
      ];

      // Should not throw
      final result = await engine.initializeAndRestoreDevice(-999);
      expect(result.state, AudioEngineState.ready);
      engine.dispose();
    });
  });

  group('CASO 4: Cambiar dispositivo correctamente', () {
    test('selectOutputDevice completes and returns to ready', () async {
      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: -1, name: 'Default', isDefault: true),
        AudioOutputDevice(id: 7, name: 'HDMI', isDefault: false),
      ];

      await engine.initializeAndRestoreDevice(null);
      expect(engine.engineState, AudioEngineState.ready);

      await engine.selectOutputDevice(7);
      expect(engine.engineState, AudioEngineState.ready);
      engine.dispose();
    });

    test('Selecting null device uses default', () async {
      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: -1, name: 'Default', isDefault: true),
        AudioOutputDevice(id: 7, name: 'HDMI', isDefault: false),
      ];

      await engine.initializeAndRestoreDevice(7);
      expect(engine.engineState, AudioEngineState.ready);

      await engine.selectOutputDevice(null);
      expect(engine.engineState, AudioEngineState.ready);
      engine.dispose();
    });
  });

  group('CASO 5: Cambiar dispositivo falla', () {
    test('Previous device is preserved (state does not degrade to ready incorrectly)', () async {
      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: -1, name: 'Default', isDefault: true),
      ];
      engine.simulateSelectionError = true;

      await engine.initializeAndRestoreDevice(null);
      expect(engine.engineState, AudioEngineState.ready);

      // selectOutputDevice throws
      expect(
        () => engine.selectOutputDevice(999),
        throwsA(isA<StateError>()),
      );

      engine.simulateSelectionError = false;
      engine.dispose();
    });

    test('Lock is released after failure', () async {
      final engine = MockAudioEngine();
      engine.simulateSelectionError = true;

      final future1 = engine.selectOutputDevice(1);
      expect(future1, throwsA(isA<StateError>()));

      // After the error, the lock should be released
      engine.simulateSelectionError = false;
      engine.mockDevices = const [
        AudioOutputDevice(id: -1, name: 'Default', isDefault: true),
      ];
      await engine.selectOutputDevice(null);
      expect(engine.engineState, AudioEngineState.ready);
      engine.dispose();
    });
  });

  group('CASO 6: Doble clic en cambiar salida (concurrency protection)', () {
    test('ConcurrencyShield.run rejects duplicate concurrent calls', () async {
      var callCount = 0;
      final results = <int>[];

      // Launch two concurrent calls with the same tag
      final f1 = ConcurrencyShield.run('test_dual_click', () async {
        callCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        results.add(1);
        return 'result1';
      });

      final f2 = ConcurrencyShield.run('test_dual_click', () async {
        callCount++;
        results.add(2);
        return 'result2';
      });

      final r1 = await f1;
      final r2 = await f2;

      // Only one should have executed
      expect(callCount, 1);
      expect(r1, 'result1');
      expect(r2, isNull); // Rejected because mutex was locked
    });

    test('Second call after first completes executes normally', () async {
      var callCount = 0;

      await ConcurrencyShield.run('test_sequential', () async {
        callCount++;
        return 'first';
      });

      final r2 = await ConcurrencyShield.run('test_sequential', () async {
        callCount++;
        return 'second';
      });

      expect(callCount, 2);
      expect(r2, 'second');
    });
  });

  group('CASO 7: Reintento después de conectar un dispositivo', () {
    test('State transitions from noDevice to ready on retry', () async {
      final engine = MockAudioEngine();
      engine.simulateNoDevices = true;

      final result1 = await engine.retryAudioInitialization(null);
      expect(result1.state, AudioEngineState.noDevice);

      // Simulate device now connected
      engine.simulateNoDevices = false;
      engine.mockDevices = const [
        AudioOutputDevice(id: -1, name: 'Default', isDefault: true),
      ];

      final result2 = await engine.retryAudioInitialization(null);
      expect(result2.state, AudioEngineState.ready);
      expect(result2.devices, isNotEmpty);
      engine.dispose();
    });

    test('Message disappears after successful retry', () async {
      final engine = MockAudioEngine();
      engine.simulateNoDevices = true;

      final result1 = await engine.retryAudioInitialization(null);
      expect(result1.state, AudioEngineState.noDevice);
      expect(result1.userMessage, isNotNull);

      engine.simulateNoDevices = false;
      engine.mockDevices = const [
        AudioOutputDevice(id: -1, name: 'Default', isDefault: true),
      ];

      final result2 = await engine.retryAudioInitialization(null);
      expect(result2.state, AudioEngineState.ready);
      expect(result2.userMessage, isNull);
      engine.dispose();
    });
  });

  group('CASO 8: Cerrar pantalla mientras cambia la salida', () {
    test('No setState after dispose — engine is properly cleaned up', () async {
      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: -1, name: 'Default', isDefault: true),
      ];

      await engine.initializeAndRestoreDevice(null);
      engine.dispose();

      expect(engine.disposed, isTrue);
      expect(engine.engineState, AudioEngineState.uninitialized);

      // Operations on disposed engine should not throw
      final devices = await engine.listOutputDevices();
      expect(devices, isEmpty);
    });
  });

  group('CASO 9: Reinicio con dispositivo inválido guardado', () {
    test('Does not repeat the error on each start', () async {
      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: -1, name: 'Default', isDefault: true),
        AudioOutputDevice(id: 3, name: 'USB', isDefault: false),
      ];

      // Simulate app restart with a stale device ID
      final result1 = await engine.retryAudioInitialization(999);
      expect(result1.state, AudioEngineState.ready);
      expect(result1.savedDeviceInvalid, isTrue);
      expect(result1.appliedDeviceId, -1); // Falls back to default

      // Restart again — same stale ID should still work without error
      final result2 = await engine.retryAudioInitialization(999);
      expect(result2.state, AudioEngineState.ready);
      expect(result2.savedDeviceInvalid, isTrue);
      expect(result2.appliedDeviceId, -1);

      engine.dispose();
    });

    test('Valid saved device is preserved across restarts', () async {
      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: -1, name: 'Default', isDefault: true),
        AudioOutputDevice(id: 3, name: 'USB', isDefault: false),
      ];

      final result1 = await engine.retryAudioInitialization(3);
      expect(result1.appliedDeviceId, 3);
      expect(result1.savedDeviceInvalid, isFalse);

      final result2 = await engine.retryAudioInitialization(3);
      expect(result2.appliedDeviceId, 3);
      expect(result2.savedDeviceInvalid, isFalse);

      engine.dispose();
    });
  });

  group('EngineState transitions', () {
    test('Starts as uninitialized', () {
      final engine = MockAudioEngine();
      expect(engine.engineState, AudioEngineState.uninitialized);
    });

    test('After initialize: state becomes ready', () async {
      final engine = MockAudioEngine();
      await engine.initialize();
      expect(engine.engineState, AudioEngineState.ready);
      engine.dispose();
    });

    test('After dispose: state is disposed', () {
      final engine = MockAudioEngine();
      engine.dispose();
      expect(engine.disposed, isTrue);
    });
  });

  group('Device ID persistence after selection', () {
    test('selectOutputDevice with null uses default', () async {
      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: -1, name: 'Default', isDefault: true),
        AudioOutputDevice(id: 2, name: 'Headphones', isDefault: false),
      ];

      await engine.initializeAndRestoreDevice(null);
      await engine.selectOutputDevice(null);
      expect(engine.engineState, AudioEngineState.ready);
      engine.dispose();
    });

    test('selectOutputDevice with -1 uses default', () async {
      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: -1, name: 'Default', isDefault: true),
      ];

      await engine.initializeAndRestoreDevice(null);
      await engine.selectOutputDevice(-1);
      expect(engine.engineState, AudioEngineState.ready);
      engine.dispose();
    });

    test('selectOutputDevice with nonexistent ID falls back to default', () async {
      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: -1, name: 'Default', isDefault: true),
      ];

      await engine.initializeAndRestoreDevice(null);
      await engine.selectOutputDevice(888);
      expect(engine.engineState, AudioEngineState.ready);
      engine.dispose();
    });
  });

  group('Diagnostic logging format', () {
    test('userMessage is user-friendly and never contains C++ exception names', () async {
      final engine = MockAudioEngine();
      engine.simulateNoDevices = true;

      final result = await engine.initializeAndRestoreDevice(999);
      expect(result.userMessage, isNotNull);
      expect(result.userMessage!.toLowerCase(), isNot(contains('cpp')));
      expect(result.userMessage!.toLowerCase(), isNot(contains('exception')));
      expect(result.userMessage!.toLowerCase(), isNot(contains('soloud')));
      engine.dispose();
    });
  });

  group('Exclusive Mode (deviceBusy) and Name Persistence', () {
    test('deviceBusy during selectOutputDevice preserves active device and sets descriptive error', () async {
      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: 0, name: 'Speakers (Realtek)', isDefault: true),
        AudioOutputDevice(id: 1, name: 'DDJ-FLX4', isDefault: false),
      ];

      await engine.initializeAndRestoreDevice(0);
      expect(engine.mockCurrentDeviceId, 0);

      // Simulate device is busy (e.g. Rekordbox using exclusive mode)
      engine.simulateDeviceBusy = true;
      await engine.selectOutputDevice(1);

      // Active device must NOT change to 1
      expect(engine.mockCurrentDeviceId, 0);
      // Engine must remain ready (not broken/dead)
      expect(engine.engineState, AudioEngineState.ready);
      // Error message informs user about exclusive use with exact expected text
      expect(
        engine.lastErrorMessage,
        '«DDJ-FLX4» está en uso exclusivo por otra aplicación (rekordbox, Serato, VirtualDJ). Se mantiene la salida anterior.',
      );
      engine.dispose();
    });

    test('deviceBusy during boot falls back to default device without leaving app mute', () async {
      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: 0, name: 'Speakers (Realtek)', isDefault: true),
        AudioOutputDevice(id: 1, name: 'DDJ-FLX4', isDefault: false),
      ];
      engine.simulateDeviceBusy = true;

      final result = await engine.initializeAndRestoreDevice(1, savedDeviceName: 'DDJ-FLX4');
      expect(result.state, AudioEngineState.ready);
      expect(result.appliedDeviceId, 0);
      expect(result.savedDeviceInvalid, isTrue);
      expect(
        result.userMessage,
        '«DDJ-FLX4» está en uso exclusivo por otra aplicación (rekordbox, Serato, VirtualDJ). Se utiliza la salida predeterminada.',
      );
      engine.dispose();
    });

    test('device resolves correctly by name even if device IDs reorder', () async {
      final engine = MockAudioEngine();
      // Previously, DDJ-FLX4 had id 1. Now it is enumerated with id 3.
      engine.mockDevices = const [
        AudioOutputDevice(id: 0, name: 'Speakers (Realtek)', isDefault: true),
        AudioOutputDevice(id: 2, name: 'Headphones', isDefault: false),
        AudioOutputDevice(id: 3, name: 'DDJ-FLX4 WASAPI', isDefault: false),
      ];

      final result = await engine.initializeAndRestoreDevice(1, savedDeviceName: 'DDJ-FLX4 WASAPI');
      expect(result.state, AudioEngineState.ready);
      expect(result.appliedDeviceId, 3);
      expect(result.savedDeviceInvalid, isFalse);
      engine.dispose();
    });

    test('SettingsService migrates legacy device ID to device name', () async {
      SharedPreferences.setMockInitialValues({
        'audio_output_device_id': 2,
      });
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService.withPrefs(prefs);

      expect(settings.audioOutputDeviceName, isNull);
      expect(settings.audioOutputDeviceId, 2);

      const devices = [
        AudioOutputDevice(id: 0, name: 'Speakers', isDefault: true),
        AudioOutputDevice(id: 2, name: 'DDJ-FLX4 WASAPI', isDefault: false),
      ];

      await settings.migrateLegacyAudioDevice(devices);

      expect(settings.audioOutputDeviceName, 'DDJ-FLX4 WASAPI');
      expect(settings.audioOutputDeviceId, isNull);
    });

    test('Windows USB port renumbering: (2- DDJ-FLX4) matches (3- DDJ-FLX4)', () async {
      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: 0, name: 'Speakers (Realtek)', isDefault: true),
        AudioOutputDevice(id: 4, name: 'Línea (3- DDJ-FLX4)', isDefault: false),
      ];

      // El usuario guardó "Línea (2- DDJ-FLX4)", pero Windows cambió el puerto a 3-
      final result = await engine.initializeAndRestoreDevice(
        1,
        savedDeviceName: 'Línea (2- DDJ-FLX4)',
      );
      expect(result.state, AudioEngineState.ready);
      expect(result.appliedDeviceId, 4);
      expect(result.savedDeviceInvalid, isFalse);
      expect(result.userMessage, isNull);
      engine.dispose();
    });

    test('AudioOutputDevice.normalizeName strips Windows USB port prefixes and extra spaces', () {
      expect(
        AudioOutputDevice.normalizeName('Línea (2- DDJ-FLX4)'),
        AudioOutputDevice.normalizeName('Línea (3- DDJ-FLX4)'),
      );
      expect(
        AudioOutputDevice.normalizeName('Línea (2- DDJ-FLX4)'),
        AudioOutputDevice.normalizeName('Línea (DDJ-FLX4)'),
      );
      expect(
        AudioOutputDevice.normalizeName('2- DDJ-FLX4'),
        AudioOutputDevice.normalizeName('3- DDJ-FLX4'),
      );
    });
  });

  group('PUNTO 1: Recuperación de arranque ante fallo o ocupación del dispositivo', () {
    test('Dispositivo guardado que falla con un error genérico -> arranca con el predeterminado', () async {
      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: 0, name: 'Altavoces Realtek', isDefault: true),
        AudioOutputDevice(id: 2, name: 'DDJ-FLX4', isDefault: false),
      ];
      engine.simulateDeviceGenericError = true;

      final result = await engine.initializeAndRestoreDevice(
        2,
        savedDeviceName: 'DDJ-FLX4',
      );

      expect(result.state, AudioEngineState.ready);
      expect(result.appliedDeviceId, 0); // Arranca con el predeterminado
      expect(result.savedDeviceInvalid, isTrue);
      expect(result.userMessage, contains('No se pudo conectar a «DDJ-FLX4»'));
      expect(result.userMessage, contains('Se utiliza la salida predeterminada'));
      expect(engine.activeDeviceId, 0); // En memoria está el predeterminado
      engine.dispose();
    });

    test('Dispositivo guardado ocupado (deviceBusy) -> arranca con predeterminado y aviso "está en uso exclusivo"', () async {
      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: 0, name: 'Altavoces Realtek', isDefault: true),
        AudioOutputDevice(id: 2, name: 'DDJ-FLX4', isDefault: false),
      ];
      engine.simulateDeviceBusy = true;

      final result = await engine.initializeAndRestoreDevice(
        2,
        savedDeviceName: 'DDJ-FLX4',
      );

      expect(result.state, AudioEngineState.ready);
      expect(result.appliedDeviceId, 0);
      expect(result.savedDeviceInvalid, isTrue);
      expect(result.userMessage, contains('«DDJ-FLX4» está en uso exclusivo por otra aplicación'));
      expect(result.userMessage, contains('Se utiliza la salida predeterminada'));
      expect(engine.activeDeviceId, 0);
      engine.dispose();
    });

    test('Fallan ambos dispositivos (guardado y predeterminado) -> estado noDevice', () async {
      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: 0, name: 'Altavoces Realtek', isDefault: true),
        AudioOutputDevice(id: 2, name: 'DDJ-FLX4', isDefault: false),
      ];
      engine.simulateDeviceBusy = true;
      engine.simulateDefaultDeviceFails = true;

      final result = await engine.initializeAndRestoreDevice(
        2,
        savedDeviceName: 'DDJ-FLX4',
      );

      expect(result.state, AudioEngineState.noDevice);
      expect(engine.engineState, AudioEngineState.noDevice);
      expect(result.userMessage, isNotNull);
      engine.dispose();
    });

    test('FLX4 da deviceBusy, fallback a predeterminado; siguiente reintento libre no arrastra mensaje de ocupado', () async {
      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: 0, name: 'Altavoces Realtek', isDefault: true),
        AudioOutputDevice(id: 2, name: 'DDJ-FLX4', isDefault: false),
      ];
      engine.simulateDeviceBusy = true;

      // Intento 1: FLX4 ocupado -> fallback al predeterminado
      final result1 = await engine.initializeAndRestoreDevice(
        2,
        savedDeviceName: 'DDJ-FLX4',
      );
      expect(result1.state, AudioEngineState.ready);
      expect(result1.appliedDeviceId, 0);
      expect(result1.userMessage, contains('«DDJ-FLX4» está en uso exclusivo por otra aplicación'));

      // Se libera el dispositivo
      engine.simulateDeviceBusy = false;

      // Intento 2: retry o nuevo inicio -> abre el FLX4 directamente sin mensaje de ocupado
      final result2 = await engine.retryAudioInitialization(
        2,
        savedDeviceName: 'DDJ-FLX4',
      );
      expect(result2.state, AudioEngineState.ready);
      expect(result2.appliedDeviceId, 2);
      expect(result2.savedDeviceInvalid, isFalse);
      expect(result2.userMessage, isNull);
      engine.dispose();
    });
  });

  group('PUNTO 4: Recuperación de changeDevice (código 33 y fallback a default)', () {
    test('Un fallo que restaura el dispositivo anterior deja el motor en ready y no guarda la preferencia', () async {
      SharedPreferences.setMockInitialValues({
        'audio_output_device_id': 0,
        'audio_output_device_name': 'Altavoces Realtek',
      });
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService.withPrefs(prefs);

      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: 0, name: 'Altavoces Realtek', isDefault: true),
        AudioOutputDevice(id: 2, name: 'DDJ-FLX4', isDefault: false),
      ];

      await engine.initializeAndRestoreDevice(0, savedDeviceName: 'Altavoces Realtek');
      expect(engine.activeDeviceId, 0);
      expect(engine.engineState, AudioEngineState.ready);

      // Simular que el intento de cambiar a DDJ-FLX4 falla pero C++ restaura el anterior (código 33)
      engine.simulateDeviceChangeFailedRestored = true;
      await engine.selectOutputDevice(2);

      // Motor sigue en ready
      expect(engine.engineState, AudioEngineState.ready);
      // activeDeviceId vuelve / se mantiene en el dispositivo anterior (0)
      expect(engine.activeDeviceId, 0);
      // Mensaje de aviso al usuario
      expect(engine.lastErrorMessage, 'No se pudo cambiar a «DDJ-FLX4». Se mantiene la salida anterior.');

      // Simulamos la lógica de SettingsScreen: si lastErrorMessage != null, NO se guarda la preferencia
      if (engine.lastErrorMessage == null) {
        await settings.setAudioOutputDeviceId(2);
        await settings.setAudioOutputDeviceName('DDJ-FLX4');
      }

      // La preferencia guardada no debe haber cambiado a DDJ-FLX4
      expect(settings.audioOutputDeviceId, 0);
      expect(settings.audioOutputDeviceName, 'Altavoces Realtek');
      engine.dispose();
    });

    test('Un fallo que termina en el predeterminado muestra el aviso correcto', () async {
      SharedPreferences.setMockInitialValues({
        'audio_output_device_id': 2,
        'audio_output_device_name': 'Interfaz Externa',
      });
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsService.withPrefs(prefs);

      final engine = MockAudioEngine();
      engine.mockDevices = const [
        AudioOutputDevice(id: 0, name: 'Altavoces Realtek', isDefault: true),
        AudioOutputDevice(id: 2, name: 'Interfaz Externa', isDefault: false),
        AudioOutputDevice(id: 3, name: 'DDJ-FLX4', isDefault: false),
      ];

      await engine.initializeAndRestoreDevice(2, savedDeviceName: 'Interfaz Externa');
      expect(engine.activeDeviceId, 2);

      // Simular que al intentar cambiar a DDJ-FLX4 falla y tampoco puede volver a la Interfaz,
      // por lo que entra el predeterminado (Altavoces Realtek, id 0)
      engine.simulateDeviceChangeFallbackToDefault = true;
      await engine.selectOutputDevice(3);

      // Motor sigue en ready
      expect(engine.engineState, AudioEngineState.ready);
      // activeDeviceId pasa al predeterminado
      expect(engine.activeDeviceId, 0);
      // El aviso indica que no se pudo mantener la anterior y se activó la predeterminada
      expect(
        engine.lastErrorMessage,
        'No se pudo cambiar a «DDJ-FLX4» ni mantener la salida anterior. Se activó la salida predeterminada.',
      );

      // Simulamos la lógica de SettingsScreen: como hubo error, no se guarda DDJ-FLX4
      if (engine.lastErrorMessage == null) {
        await settings.setAudioOutputDeviceId(3);
        await settings.setAudioOutputDeviceName('DDJ-FLX4');
      }
      expect(settings.audioOutputDeviceId, 2);
      expect(settings.audioOutputDeviceName, 'Interfaz Externa');
      engine.dispose();
    });
  });
}
