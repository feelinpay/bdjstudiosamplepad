import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:bdj_license_core/bdj_license_core.dart';

class DeviceFingerprint {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static String? _cachedFingerprint;

  Future<String> generate() async {
    if (_cachedFingerprint != null) return _cachedFingerprint!;
    final result = await generateResult();
    _cachedFingerprint = result.visibleHwid;
    return _cachedFingerprint!;
  }

  Future<HwidResult> generateResult() async {
    if (Platform.isAndroid) {
      var android = await _deviceInfo.androidInfo;
      // ANDROID: Usar Android ID como elemento principal. No incluir model, brand, device ni versión como parte vinculante.
      return HwidEngine.canonicalize(
        platform: 'android',
        components: {
          'id': android.id,
        },
      );
    } else if (Platform.isIOS) {
      var ios = await _deviceInfo.iosInfo;
      // IOS: Usar identifierForVendor como identificador de plataforma. No incluir name, systemVersion ni systemName.
      // Nota de documentación: identifierForVendor puede cambiar cuando el usuario elimina todas las aplicaciones
      // del mismo vendor del dispositivo. No se promete persistencia absoluta tras desinstalación completa.
      return HwidEngine.canonicalize(
        platform: 'ios',
        components: {
          'id': ios.identifierForVendor,
        },
      );
    } else if (Platform.isWindows) {
      var windows = await _deviceInfo.windowsInfo;
      // WINDOWS: MachineGuid o deviceId estable. No incluir RAM, MAC ni nombre de equipo o usuario.
      return HwidEngine.canonicalize(
        platform: 'windows',
        components: {
          'deviceId': windows.deviceId,
        },
      );
    } else if (Platform.isMacOS) {
      var macos = await _deviceInfo.macOsInfo;
      // MACOS: systemGUID / platform UUID. No incluir computerName ni usuario.
      return HwidEngine.canonicalize(
        platform: 'macos',
        components: {
          'systemGUID': macos.systemGUID,
        },
      );
    } else if (Platform.isLinux) {
      var linux = await _deviceInfo.linuxInfo;
      // LINUX: /etc/machine-id y /sys/class/dmi/id/product_uuid cuando esté disponible. No incluir prettyName ni interfaces de red.
      String? dmiUuid;
      try {
        final dmiFile = File('/sys/class/dmi/id/product_uuid');
        if (dmiFile.existsSync()) {
          dmiUuid = dmiFile.readAsStringSync().trim();
        }
      } catch (_) {}

      String? machineId = linux.machineId;
      if (machineId == null || machineId.isEmpty) {
        try {
          final midFile = File('/etc/machine-id');
          if (midFile.existsSync()) {
            machineId = midFile.readAsStringSync().trim();
          }
        } catch (_) {}
      }

      return HwidEngine.canonicalize(
        platform: 'linux',
        components: {
          'machineId': machineId,
          'productUuid': dmiUuid,
        },
      );
    }

    throw const DeviceFingerprintFailure('Plataforma desconocida o no compatible (unknown_platform).');
  }
}
