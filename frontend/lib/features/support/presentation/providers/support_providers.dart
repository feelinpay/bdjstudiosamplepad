import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/diagnostic_service.dart';
import '../../domain/diagnostic_report.dart';
import '../../../midi/presentation/providers/midi_providers.dart';
import '../../../licensing/presentation/providers/license_providers.dart';

final diagnosticProvider = FutureProvider<DiagnosticReport>((ref) async {
  var devices = await ref.read(midiEngineProvider).getDevices();
  var license = ref.read(licenseProvider);
  var status = license.loadingState == LicenseLoadingState.licensed
      ? 'Licencia activa'
      : 'Sin licencia';

  return DiagnosticService.gather(
    midiCount: devices.length,
    licenseStatus: status,
  );
});
