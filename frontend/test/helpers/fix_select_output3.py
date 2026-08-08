import os

path = r'C:\Users\DAVIDZ~1\Desktop\APLICA~1\BDJ_ST~3\frontend\lib\features\audio_engine\data\soloud_audio_engine.dart'

with open(path, 'rb') as f:
    content = f.read()

# Variable is _soloud (with 'd' like the library name)
old = b"  @override\r\n  Future<void> selectOutputDevice(int? deviceId) async {\r\n    await initialize();\r\n    if (_soloud == null) return;\r\n    if (deviceId == null) {\r\n      _soloud!.changeDevice();\r\n      return;\r\n    }\r\n    final device = _soloud!\r\n        .listPlaybackDevices()\r\n        .where((candidate) => candidate.id == deviceId)\r\n        .firstOrNull;\r\n    if (device == null) {\r\n      throw StateError('El dispositivo de audio seleccionado ya no existe.');\r\n    }\r\n    _soloud!.changeDevice(newDevice: device);\r\n  }"

new = b"  @override\r\n  Future<void> selectOutputDevice(int? deviceId) async {\r\n    if (_isChangingDevice) {\r\n      throw StateError('Cambio de dispositivo en curso.');\r\n    }\r\n    _isChangingDevice = true;\r\n    _engineState = AudioEngineState.changingDevice;\r\n    try {\r\n      await initialize();\r\n      if (_audioDisabled ||\r\n          _soloud == null ||\r\n          _engineState == AudioEngineState.noDevice) {\r\n        _engineState = AudioEngineState.noDevice;\r\n        return;\r\n      }\r\n      final devices = _soloud!.listPlaybackDevices();\r\n      if (deviceId == null || deviceId == -1) {\r\n        _soloud!.changeDevice();\r\n        _engineState = AudioEngineState.ready;\r\n        return;\r\n      }\r\n      final device = devices\r\n          .where((candidate) => candidate.id == deviceId)\r\n          .firstOrNull;\r\n      if (device == null) {\r\n        _soloud!.changeDevice();\r\n        _engineState = AudioEngineState.ready;\r\n        return;\r\n      }\r\n      _soloud!.changeDevice(newDevice: device);\r\n      _engineState = AudioEngineState.ready;\r\n    } catch (e, st) {\r\n      debugPrint('Error selecting output device: $e\\n$st');\r\n      _engineState = AudioEngineState.error;\r\n      rethrow;\r\n    } finally {\r\n      _isChangingDevice = false;\r\n    }\r\n  }"

if old in content:
    content = content.replace(old, new)
    with open(path, 'wb') as f:
        f.write(content)
    print("Replacement successful!")
else:
    print("OLD NOT FOUND!")
    # Try to find the exact old text by searching for fragments
    idx = content.find(b'selectOutputDevice(int? deviceId)')
    print(f"Function starts at byte {idx}")
    print(repr(content[idx-20:idx+600]))
