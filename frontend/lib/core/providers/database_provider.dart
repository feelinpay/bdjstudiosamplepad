import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
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

/// Error de arranque de la base de datos con causa legible.
///
/// Se expone en vez de dejar escapar el `IsarError` crudo para que la capa de
/// UI (y `logcat` / la consola) muestren de inmediato *por que* no arranco la
/// base, en lugar de una pantalla en blanco.
class DatabaseUnavailableException implements Exception {
  const DatabaseUnavailableException(this.message, this.cause);

  final String message;
  final Object cause;

  @override
  String toString() => 'DatabaseUnavailableException: $message (causa: $cause)';
}

/// Traduce un fallo de `Isar.open` a un mensaje accionable.
///
/// El caso mas comun en Android es que el enlazador rechace `libisar.so`
/// porque no esta alineada a 16 KB: ocurre solo en dispositivos que arrancan
/// con paginas de 16 KB (Android 15+), asi que se manifiesta como "la app no
/// abre en unos moviles si y en otros no".
String _describeOpenFailure(Object error) {
  final text = error.toString().toLowerCase();
  final looksLikeNativeLoadFailure = text.contains('dlopen') ||
      text.contains('not 16 kb aligned') ||
      text.contains('16-kb') ||
      text.contains('failed to load dynamic library') ||
      text.contains('unable to load');

  if (Platform.isAndroid && looksLikeNativeLoadFailure) {
    return 'No se pudo cargar la libreria nativa de Isar (libisar.so). '
        'Si el dispositivo usa paginas de memoria de 16 KB, la libreria debe '
        'estar alineada a 16 KB: verifica el APK con '
        '`zipalign -c -P 16 -v 4 app-release.apk`.';
  }
  if (looksLikeNativeLoadFailure) {
    return 'No se pudo cargar la libreria nativa de Isar en esta plataforma.';
  }
  return 'No se pudo abrir la base de datos local.';
}

/// Abre la base de datos y deja la biblioteca lista para usarse.
///
/// Es idempotente: si la instancia ya existe la devuelve tal cual, de modo que
/// da igual quien llegue primero, el arranque de `main.dart` o el provider.
///
/// Se expone como funcion (y no solo como cuerpo del provider) porque la base
/// de datos es una dependencia dura de toda la app: si falla, no hay nada que
/// mostrar. Abrirla durante el arranque permite que el fallo llegue a la
/// pantalla de inicio -- con su mensaje y su boton de reintentar -- en lugar de
/// propagarse a cada consumidor, donde hoy se absorbe en silencio y deja la app
/// girando indefinidamente sobre el logo.
Future<Isar> openAppDatabase() async {
  if (Isar.instanceNames.isNotEmpty) return Isar.getInstance()!;

  // applyPendingRestore() ya se ejecuta en main.dart antes de abrir la base.
  final dir = await AppStorageService.databaseDirectory();

  final Isar isar;
  try {
    isar = await Isar.open(
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
  } catch (e, st) {
    final message = _describeOpenFailure(e);
    debugPrint('[Database] $message\n$e\n$st');
    throw DatabaseUnavailableException(message, e);
  }

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

/// Base de datos Isar (unica instancia) de la app.
///
/// Normalmente `main.dart` ya la abrio durante el arranque y esto devuelve la
/// instancia existente sin coste.
final isarProvider = FutureProvider<Isar>((ref) => openAppDatabase());
