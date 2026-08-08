import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../services/app_storage_service.dart';
import '../../features/pad_system/data/models/pad_model.dart';
import '../../features/sample_library/data/models/genre_model.dart';
import '../../features/sample_library/data/models/folder_model.dart';
import '../../features/sample_library/data/models/sample_model.dart';
import '../../features/workspace/data/models/workspace_model.dart';
import '../../features/workspace/data/models/page_model.dart';
import '../../features/midi/data/models/midi_mapping_model.dart';
import '../../features/macros/data/models/macro_model.dart';
import '../../features/settings/data/services/config_backup_service.dart';
import '../services/filesystem_sync_service.dart';
import '../services/local_audio_storage_service.dart';
import '../../features/workspace/data/repositories/isar_workspace_repository.dart';

/// Base de datos Isar (unica instancia) de la app.
final isarProvider = FutureProvider<Isar>((ref) async {
  if (Isar.instanceNames.isEmpty) {
    // applyPendingRestore() ya se ejecuta en main.dart antes de crear ProviderScope.
    final dir = await AppStorageService.databaseDirectory();
    var isar = await Isar.open(
      [
        PadModelSchema,
        SampleModelSchema,
        FolderModelSchema,
        GenreModelSchema,
        WorkspaceModelSchema,
        PageModelSchema,
        MidiMappingModelSchema,
        MacroModelSchema,
      ],
      directory: dir.path,
      inspector: false,
    );

    await ConfigBackupService.finalizePendingRestore(isar);

    // Unifica el separador de `samplePath` antes de que nadie compare rutas.
    await LocalAudioStorageService.normalizeLegacySamplePaths(isar);

    // Reconciliar en tiempo real cualquier cambio hecho externamente (explorador de Windows/macOS)
    await FilesystemSyncService.reconcileOnStartup(isar);
    await IsarWorkspaceRepository(Future.value(isar))
        .reconcileAllPageIndexIntegrity();
    FilesystemSyncService.startLiveWatcher(isar);

    return isar;
  }
  return Isar.getInstance()!;
});
