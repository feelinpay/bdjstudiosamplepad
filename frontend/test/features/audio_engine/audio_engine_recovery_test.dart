import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/core/audio/audio_engine_state.dart';
import 'package:bdj_studio_sample_pad/core/audio/audio_output_device.dart';
import 'package:bdj_studio_sample_pad/core/audio/audio_initialization_result.dart';
import 'package:bdj_studio_sample_pad/core/utils/concurrency_shield.dart';

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
}
