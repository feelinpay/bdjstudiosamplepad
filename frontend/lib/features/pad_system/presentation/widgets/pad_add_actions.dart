import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pad_providers.dart';
import '../../../../core/services/filesystem_sync_service.dart';
import '../../../../core/services/local_audio_storage_service.dart';
import '../../../../core/services/saf_folder_import_service.dart';
import '../../../../core/utils/concurrency_shield.dart';
import '../../../../core/widgets/blocking_progress_dialog.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../../../workspace/data/models/workspace_model.dart';

/// Acciones compartidas del boton [+]: agregar N pads, crear carpeta,
/// o importar varios audios de golpe (cada archivo crea su pad).
class PadAddActions {
  const PadAddActions._();

  /// Marca para no repetir el diálogo de "Todos los archivos" más de una
  /// vez por sesión de la app.
  static bool _askedFullAccessThisSession = false;

  static Future<void> showAddMenu(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ESTRUCTURA',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.create_new_folder_rounded,
                  color: Colors.purpleAccent,
                ),
                title: const Text(
                  'Crear nuevo Workspace (Proyecto)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'Crea un proyecto totalmente nuevo e independiente',
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () {
                  ConcurrencyShield.safePop(ctx);
                  _createWorkspace(context, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder, color: Colors.orangeAccent),
                title: const Text(
                  'Crear carpeta vacía',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Agrega un pad carpeta para agrupar otros pads dentro',
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () {
                  ConcurrencyShield.safePop(ctx);
                  _askFolderName(context, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.grid_on, color: Colors.blueAccent),
                title: const Text(
                  'Agregar pads vacíos',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Elige la cantidad de pads vacíos a añadir',
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () {
                  ConcurrencyShield.safePop(ctx);
                  _askPadCount(context, ref);
                },
              ),

              const Divider(color: Colors.white12, height: 16),

              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'IMPORTACIÓN Y ARCHIVOS',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.audio_file,
                  color: Colors.greenAccent,
                ),
                title: const Text(
                  'Importar archivos de audio',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Selecciona archivos MP3, WAV, FLAC, OGG...',
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () {
                  ConcurrencyShield.safePop(ctx);
                  importAudios(context, ref);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.folder_copy_rounded,
                  color: Colors.amberAccent,
                ),
                title: const Text(
                  'Importar carpeta de audios',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'Escanea e importa una carpeta completa con subcarpetas',
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () {
                  ConcurrencyShield.safePop(ctx);
                  _importAudioFolder(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _askPadCount(BuildContext context, WidgetRef ref) async {
    var pageIndex = ref.read(currentPageIndexProvider);
    var notifier = ref.read(padPageProvider(pageIndex).notifier);
    final textController = TextEditingController();

    try {
      final count = await showDialog<int>(
        context: context,
        builder: (ctx) {
          int? selectedPreset;
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                backgroundColor: Colors.grey[900],
                title: const Row(
                  children: [
                    Icon(Icons.grid_on, color: Colors.cyanAccent, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Agregar pads vacíos',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selecciona una cantidad rápida:',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [4, 8, 16, 24, 32, 64].map((n) {
                          final isSelected = selectedPreset == n;
                          return ActionChip(
                            backgroundColor: isSelected
                                ? Colors.cyanAccent
                                : Colors.grey[850],
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.cyanAccent
                                  : Colors.white24,
                            ),
                            label: Text(
                              '+$n pads',
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                selectedPreset = n;
                                textController.text = n.toString();
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'O escribe cualquier cantidad (sin límites):',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: textController,
                        keyboardType: TextInputType.number,
                        autofocus: false,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Ej. 20, 50, 100...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.black26,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.cyanAccent),
                          ),
                          suffixText: 'pads',
                          suffixStyle: const TextStyle(color: Colors.white54),
                        ),
                        onChanged: (val) {
                          setState(() {
                            selectedPreset = int.tryParse(val);
                          });
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => ConcurrencyShield.safePop(ctx, null),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () {
                      final val = int.tryParse(textController.text.trim());
                      if (val != null && val > 0) {
                        ConcurrencyShield.safePop(ctx, val);
                      }
                    },
                    child: const Text(
                      'Agregar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (count != null && count > 0) {
        await notifier.addPads(count);
      }
    } finally {
      Future<void>.delayed(
        const Duration(milliseconds: 300),
        textController.dispose,
      );
    }
  }

  static Future<void> _askFolderName(
    BuildContext context,
    WidgetRef ref,
  ) async {
    var pageIndex = ref.read(currentPageIndexProvider);
    var notifier = ref.read(padPageProvider(pageIndex).notifier);

    var controller = TextEditingController();
    try {
      var ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Nombre de la carpeta',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            onSubmitted: (_) => ConcurrencyShield.safePop(ctx, true),
            decoration: const InputDecoration(hintText: 'Ej. Drum Kit'),
          ),
          actions: [
            TextButton(
              onPressed: () => ConcurrencyShield.safePop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => ConcurrencyShield.safePop(ctx, true),
              child: const Text('Crear'),
            ),
          ],
        ),
      );
      if (ok == true && controller.text.trim().isNotEmpty) {
        await notifier.addFolderPad(controller.text.trim());
      }
    } finally {
      // showDialog resuelve antes de que termine su animacion de salida.
      // Diferir la liberacion evita que TextField se reconstruya con un
      // controlador ya descartado.
      Future<void>.delayed(
        const Duration(milliseconds: 300),
        controller.dispose,
      );
    }
  }

  /// Importa varios archivos de audio (cualquier formato de musica del
  /// sistema) y crea un pad por cada uno, con el sonido ya asignado.
  static Future<void> importAudios(BuildContext context, WidgetRef ref) async {
    await ConcurrencyShield.run('import_audios', () async {
      var pageIndex = ref.read(currentPageIndexProvider);
      var notifier = ref.read(padPageProvider(pageIndex).notifier);

      var result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;

      FilesystemSyncService.suspend();
      try {
        final paths = <String>[];
        final names = <String>[];
        final totalFiles = result.files.length;

        await BlockingProgressDialog.run(
          context,
          title: 'Importando audios...',
          initialMessage: 'Preparando $totalFiles archivo(s)...',
          task: (progress) async {
            // Copiar en lotes paralelos (no 1 a 1) para que la importación de
            // muchos archivos no tarde tanto: 4 copias concurrentes por tanda.
            const batchSize = 4;
            for (var start = 0; start < result.files.length; start += batchSize) {
              final end = (start + batchSize).clamp(0, result.files.length);
              final batch = result.files.sublist(start, end);
              final batchResults = await Future.wait(
                batch.map((f) async {
                  try {
                    if (f.path != null && f.path!.isNotEmpty) {
                      final path = await LocalAudioStorageService.importAudioFile(
                        f.path!,
                      );
                      return (path, f.name.replaceAll(RegExp(r'\.[^.]+$'), ''));
                    } else if (f.bytes != null && f.bytes!.isNotEmpty) {
                      final path = await LocalAudioStorageService.importAudioBytes(
                        f.name,
                        f.bytes!,
                      );
                      return (path, f.name.replaceAll(RegExp(r'\.[^.]+$'), ''));
                    }
                  } catch (error, st) {
                    debugPrint(
                      '[PadAddActions] Fallo al importar "${f.name}": $error\n$st',
                    );
                  }
                  return null;
                }),
              );
              for (final r in batchResults) {
                if (r != null) {
                  paths.add(r.$1);
                  names.add(r.$2);
                }
              }
              progress.updateProgress(
                paths.length,
                totalFiles,
                'Copiando audios...',
              );
              await Future<void>.delayed(Duration.zero);
            }

            if (paths.isEmpty) return;

            progress.update(
              message: 'Creando pads para ${paths.length} audio(s)...',
            );
            await notifier.addPads(
              paths.length,
              samplePaths: paths,
              sampleNames: names,
            );
          },
        );
      } finally {
        final isar = await ref.read(isarProvider.future);
        await FilesystemSyncService.resume(isar);
      }
    });
  }

  static Future<void> assignAudioToPad(dynamic ref, String padId) async {
    await ConcurrencyShield.run('assign_audio_$padId', () async {
      final pageIndex = ref.read(currentPageIndexProvider);
      final result = await FilePicker.pickFiles(type: FileType.audio);
      if (result == null || result.files.single.path == null) return;
      final f = result.files.single;

      final notifier = ref.read(padPageProvider(pageIndex).notifier);

      FilesystemSyncService.suspend();
      try {
        final localPath = await LocalAudioStorageService.importAudioFile(f.path!);
        final name = f.name.replaceAll(RegExp(r'\.[^.]+$'), '');

        await notifier.assignSampleToPad(padId, localPath, name);
      } finally {
        final isar = await ref.read(isarProvider.future);
        await FilesystemSyncService.resume(isar);
      }
    });
  }

  /// Abre un selector de carpeta del sistema y escanea la estructura
  /// completa de subcarpetas para recrearla jerárquicamente como carpetas de pads.
  /// En Android el árbol SAF se copia al cache vía DocumentsContract porque
  /// Scoped Storage bloquea Directory.list() sobre almacenamiento compartido.
  static Future<void> _importAudioFolder(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Aviso VISIBLE si una importación anterior dejó el mutex ocupado
    // (antes estos toques se ignoraban en silencio).
    if (ConcurrencyShield.isMutexLocked('import_audio_folder')) {
      debugPrint('BDJ Import Log: import_audio_folder ya en curso → aviso');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ya hay una importación en curso. Espera a que termine.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    await ConcurrencyShield.run('import_audio_folder', () async {
      // En iOS, getDirectoryPath funciona con security-scoped access.
      // Si falla, caer al file picker.
      if (Platform.isIOS) {
        debugPrint(
          'BDJ Import Log: iOS detected → trying getDirectoryPath first',
        );
      }

      // === Android: importar vía árbol SAF (misma jerarquía que PC) ===
      if (Platform.isAndroid) {
        debugPrint('BDJ Import Log: Android detected → import via SAF tree');
        await _importAndroidFolder(context, ref);
        return;
      }

      // === Desktop (Windows/macOS/Linux): usar selector de carpeta + scan ===
      while (true) {
        if (!context.mounted) return;
        final scaffold = ScaffoldMessenger.of(context);
        String? dirPath;
        try {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          await WidgetsBinding.instance.endOfFrame;
          if (!context.mounted) return;
          dirPath = await FilePicker.getDirectoryPath(
            dialogTitle: 'Selecciona una carpeta de audios',
            lockParentWindow: true,
          );
          debugPrint('BDJ Import Log: getDirectoryPath result = $dirPath');
        } on Object catch (error) {
          debugPrint('BDJ Import Log Error in getDirectoryPath: $error');
          dirPath = null;
        }

        if (dirPath == null || dirPath.isEmpty) {
          break;
        }

        if (!context.mounted) break;
        debugPrint('BDJ import: carpeta seleccionada: $dirPath');
        scaffold.showSnackBar(
          const SnackBar(
            content: Text('Carpeta seleccionada. Analizando audios...'),
            duration: Duration(seconds: 2),
          ),
        );
        var scanningDialogOpen = true;
        _showScanningDialog(context);

        try {
          var dir = Directory(dirPath);
          var rootNode = await _scanAudioFolderTreeAsync(dir);
          debugPrint(
            'BDJ Import Log: Scan finished. Total audios = ${rootNode.totalAudioCount}',
          );

          if (context.mounted && scanningDialogOpen) {
            ConcurrencyShield.safeRootPop(context);
            scanningDialogOpen = false;
          }

          if (rootNode.totalAudioCount == 0) {
            if (!context.mounted) break;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No se encontraron archivos de audio en esta carpeta.',
                ),
                duration: Duration(seconds: 3),
              ),
            );
            break;
          } else {
            await _confirmAndImportTree(context, ref, rootNode);
            break;
          }
        } catch (e, st) {
          debugPrint('BDJ Import Log Exception during scan: $e\n$st');
          if (context.mounted && scanningDialogOpen) {
            ConcurrencyShield.safeRootPop(context);
          }
          break;
        }
      }
    });
  }

  /// Diálogo de confirmación + importación jerárquica del árbol escaneado
  /// (compartido por el flujo de PC y el flujo Android/SAF).
  static Future<bool> _confirmAndImportTree(
    BuildContext context,
    WidgetRef ref,
    AudioFolderNode rootNode,
  ) async {
    if (!context.mounted) return false;
    var subCount = rootNode.subfolders.length;
    var infoText = subCount > 0
        ? 'Se detectó la carpeta "${rootNode.name}" con $subCount subcarpeta(s) y ${rootNode.totalAudioCount} archivo(s) de audio.\n\nSe creará la estructura jerárquica tipo Explorador de Archivos.\n¿Deseas continuar?'
        : 'Se encontraron ${rootNode.totalAudioCount} archivo(s) de audio en "${rootNode.name}".\n\nSe creará una carpeta de pads con su contenido.\n¿Deseas continuar?';

    var confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Importar estructura de carpeta',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(infoText, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => ConcurrencyShield.safePop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            onPressed: () => ConcurrencyShield.safePop(ctx, true),
            child: const Text(
              'Importar Estructura',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return false;
    _showImportingDialog(context);
    try {
      var pageIndex = ref.read(currentPageIndexProvider);
      await ref
          .read(padPageProvider(pageIndex).notifier)
          .importAudioDirectoryTree(rootNode);
      debugPrint('BDJ Import Log: Tree import succeeded!');
      return true;
    } catch (e, st) {
      debugPrint('BDJ Import Log ERROR in importAudioDirectoryTree: $e\n$st');
      return false;
    } finally {
      if (context.mounted) {
        ConcurrencyShield.safeRootPop(context);
      }
    }
  }

  /// Importación en Android con estrategias en cascada:
  /// 1. Escaneo directo con dart:io (requiere "Todos los archivos"; igual que PC).
  /// 2. Copia del árbol SAF al cache vía DocumentsContract (sin permisos).
  /// Ambas se intentan hasta que una encuentre audios; el acceso completo se
  /// solicita una vez por sesión antes de abrir el picker.
  static Future<void> _importAndroidFolder(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // NOTA: el mutex 'import_audio_folder' YA lo tomó el llamador
    // (_importAudioFolder). Anidar ConcurrencyShield.run con el mismo tag
    // aquí hacía que el escudo rechazara la operación al instante y la
    // importación de carpeta muriera en silencio en Android.
    Directory? cacheRoot;
    ValueNotifier<int>? progressNotifier;

    Future<AudioFolderNode?> copyViaSaf(String uri) async {
      progressNotifier = ValueNotifier<int>(0);
      _showScanningDialog(context, progressNotifier);
      try {
        final copied = await SafFolderImportService.copyTreeToLocalCache(
          uri,
          destName: 'folder',
          onProgress: (n) => progressNotifier?.value = n,
        );
        if (copied == null) return null;
        cacheRoot = copied.cacheDirectory;
        return _toAudioFolderNode(copied.root);
      } catch (error, st) {
        debugPrint('BDJ Import Log SAF copy exception: $error\n$st');
        return null;
      } finally {
        if (context.mounted) ConcurrencyShield.safeRootPop(context);
      }
    }

    Future<AudioFolderNode?> scanDirect(String physicalPath) async {
      if (!await Directory(physicalPath).exists()) return null;
      if (!context.mounted) return null;
      _showScanningDialog(context);
      try {
        return await _scanAudioFolderTreeAsync(Directory(physicalPath));
      } catch (error, st) {
        debugPrint('BDJ Import Log direct scan exception: $error\n$st');
        return null;
      } finally {
        if (context.mounted) ConcurrencyShield.safeRootPop(context);
      }
    }

    try {
      // Paso 0: pedir acceso completo una vez por sesión (paridad con PC).
      final directGranted = await ensureAndroidStorageAccess(context);

      String? pickedPath;
      try {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await WidgetsBinding.instance.endOfFrame;
        if (!context.mounted) return;
        debugPrint('BDJ Import Log: abriendo selector de carpeta...');
        pickedPath =
            await FilePicker.getDirectoryPath(
              dialogTitle: 'Selecciona una carpeta de audios',
            ).timeout(
              // Evita que un resultado de actividad perdido deje el mutex
              // trabado para siempre (los toques siguientes morían en silencio).
              const Duration(minutes: 5),
              onTimeout: () {
                debugPrint('BDJ Import Log: selector timeout (5 min) → null');
                return null;
              },
            );
      } on Object catch (error) {
        debugPrint('BDJ Import Log Error in getDirectoryPath: $error');
        pickedPath = null;
      }
      debugPrint('BDJ Import Log: getDirectoryPath result = $pickedPath');
      if (pickedPath == null || pickedPath.isEmpty || !context.mounted) return;

      final treeLike = SafFolderImportService.looksLikeTreeUri(pickedPath);
      final resolved = await LocalAudioStorageService.resolveContentUriToPath(
        pickedPath,
      );
      debugPrint(
        'BDJ Import Log: resolved=$resolved treeLike=$treeLike directGranted=$directGranted',
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Carpeta seleccionada. Analizando audios...'),
          duration: Duration(seconds: 2),
        ),
      );

      AudioFolderNode? rootNode;
      if (directGranted) {
        rootNode = await scanDirect(
          resolved == pickedPath ? pickedPath : resolved,
        );
        if ((rootNode?.totalAudioCount ?? 0) == 0 && treeLike) {
          rootNode = await copyViaSaf(pickedPath);
        }
      } else if (treeLike) {
        rootNode = await copyViaSaf(pickedPath);
        if ((rootNode?.totalAudioCount ?? 0) == 0 &&
            resolved != pickedPath &&
            await Directory(resolved).exists()) {
          if (!context.mounted) return;
          // SAF no encontró nada; por si el dispositivo permite File I/O.
          rootNode = await scanDirect(resolved);
        }
      } else {
        rootNode = await scanDirect(pickedPath);
      }

      final totalAudios = rootNode?.totalAudioCount ?? 0;
      debugPrint('BDJ Import Log: Scan finished. Total audios = $totalAudios');

      if (totalAudios == 0 || rootNode == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se encontraron archivos de audio compatibles (MP3, WAV, FLAC, OGG...) '
              'en la carpeta ni en sus subcarpetas.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
      await _confirmAndImportTree(context, ref, rootNode);
    } finally {
      progressNotifier?.dispose();
      await SafFolderImportService.deleteCachedCopy(cacheRoot);
    }
  }

  /// Solicita acceso completo al almacenamiento ("Todos los archivos") una vez
  /// por sesión para que la importación funcione igual que en PC. Devuelve
  /// true si ya está concedido o si el usuario lo activó en Ajustes.
  static Future<bool> ensureAndroidStorageAccess(BuildContext context) async {
    try {
      if (await SafFolderImportService.isDirectStorageAccessGranted())
        return true;
      if (_askedFullAccessThisSession) return false;
      _askedFullAccessThisSession = true;
      if (!context.mounted) return false;

      final accept = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Acceso a archivos',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Para importar carpetas completas con subcarpetas igual que en PC, '
            'BDJ Studio necesita el permiso "Todos los archivos".\n\n'
            'Se abrirán los ajustes del sistema: activa el interruptor de BDJ Studio '
            'y regresa a la app.\n\nTambién puedes continuar sin el permiso; la app '
            'intentará importar de todas formas.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => ConcurrencyShield.safePop(ctx, false),
              child: const Text('Continuar sin permiso'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
              ),
              onPressed: () => ConcurrencyShield.safePop(ctx, true),
              child: const Text(
                'Permitir',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      if (accept != true || !context.mounted) return false;

      await SafFolderImportService.requestDirectStorageAccess();
      final granted = await _waitForAppResumeAndCheckAccess();
      debugPrint('BDJ Import Log: acceso directo tras ajustes = $granted');
      return granted;
    } catch (error, st) {
      debugPrint(
        'BDJ Import Log: ensureAndroidStorageAccess error: $error\n$st',
      );
      return false;
    }
  }

  /// Espera el regreso desde Ajustes (o el cierre del diálogo runtime en
  /// Android 10-) y re-verifica el estado del permiso.
  static Future<bool> _waitForAppResumeAndCheckAccess() async {
    final completer = Completer<void>();
    late final AppLifecycleListener listener;
    listener = AppLifecycleListener(
      onShow: () {
        if (!completer.isCompleted) completer.complete();
      },
    );
    try {
      final binding = WidgetsBinding.instance;
      final alreadyResumed =
          binding.lifecycleState == AppLifecycleState.resumed;
      if (alreadyResumed) {
        // Permiso runtime en Android 10-: el diálogo se cierra sin salir de la app.
        await Future<void>.delayed(const Duration(milliseconds: 1800));
      } else {
        await completer.future.timeout(
          const Duration(seconds: 90),
          onTimeout: () {},
        );
      }
    } finally {
      listener.dispose();
    }
    return SafFolderImportService.isDirectStorageAccessGranted();
  }

  /// Convierte el árbol copiado por SAF al modelo jerárquico usado por PC.
  static AudioFolderNode _toAudioFolderNode(SafImportedFolder folder) {
    return AudioFolderNode(
      name: folder.name,
      audioFiles: folder.audioFiles.map((a) => a.file).toList(),
      subfolders: [
        for (final sub in folder.subfolders) _toAudioFolderNode(sub),
      ],
    );
  }

  /// Diálogo de análisis/copia reutilizado por la importación de Workspace
  /// en móvil (mismo avance de copiado SAF).
  static void showScanningDialog(
    BuildContext context, [
    ValueListenable<int>? copiedFiles,
  ]) {
    _showScanningDialog(context, copiedFiles);
  }

  /// Diálogo de análisis/copia. En Android muestra el avance del copiado SAF.
  static void _showScanningDialog(
    BuildContext context, [
    ValueListenable<int>? copiedFiles,
  ]) {
    final controller = BlockingProgressController(
      initialMessage: 'Analizando carpeta de audios...',
    );
    if (copiedFiles != null) {
      copiedFiles.addListener(() {
        final count = copiedFiles.value;
        controller.updateCount(
          count,
          count > 0 ? 'Copiando audios...' : 'Analizando carpeta...',
        );
      });
    }
    BlockingProgressDialog.show(
      context,
      title: 'Analizando carpeta de audios...',
      controller: controller,
    );
  }

  /// La importación cambia Isar y copia archivos. Durante esa transacción la
  /// interfaz no debe permitir navegar ni editar un estado intermedio.
  static void _showImportingDialog(BuildContext context) {
    final controller = BlockingProgressController(
      initialMessage: 'Guardando audios y configurando pads...',
    );
    BlockingProgressDialog.show(
      context,
      title: 'Importando carpeta...',
      controller: controller,
    );
  }

  static Future<void> _createWorkspace(
    BuildContext context,
    WidgetRef ref,
  ) async {
    var controller = TextEditingController();
    try {
      var ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Nombre del nuevo Workspace',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            onSubmitted: (_) => ConcurrencyShield.safePop(ctx, true),
            decoration: const InputDecoration(
              hintText: 'Ej. Show Reggaeton, Set Discoteca',
              hintStyle: TextStyle(color: Colors.white38),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => ConcurrencyShield.safePop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
              ),
              onPressed: () => ConcurrencyShield.safePop(ctx, true),
              child: const Text(
                'Crear',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

      if (ok == true && controller.text.trim().isNotEmpty) {
        final requestedName = controller.text.trim();
        final existing = ref.read(workspaceListProvider).value ?? [];
        if (existing.any(
          (ws) => ws.name.toLowerCase() == requestedName.toLowerCase(),
        )) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Ya existe un workspace llamado "$requestedName".',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        }
        var repo = ref.read(workspaceRepositoryProvider);
        WorkspaceModel? ws;
        try {
          ws = await repo.createWorkspace(requestedName);
        } catch (error, st) {
          debugPrint('[PadAddActions] Fallo al crear workspace: $error\n$st');
        }
        if (ws == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se pudo crear el workspace.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }
        ref.invalidate(workspaceListProvider);
        // Use safe workspace switching with request ID
        await switchWorkspaceWithRequestId(ref, ws.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Workspace "${ws.name}" creado correctamente'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } finally {
      controller.dispose();
    }
  }
}

/// Escaneo asíncrono de carpetas (usa dir.list() en vez de listSync para no
/// bloquear el hilo de UI).
Future<AudioFolderNode> _scanAudioFolderTreeAsync(Directory rawDir) async {
  final resolvedPath = await LocalAudioStorageService.resolveContentUriToPath(
    rawDir.path,
  );
  final dir = Directory(resolvedPath);
  final audioExts = LocalAudioStorageService.supportedAudioExtensionsNoDot;
  var segments = dir.path
      .split(RegExp(r'[/\\]'))
      .where((s) => s.isNotEmpty)
      .toList();
  var dirName = segments.isNotEmpty ? segments.last : 'Carpeta';
  if (dirName.contains(':')) {
    final parts = dirName.split(':');
    if (parts.length > 1 && parts.last.isNotEmpty) {
      dirName = Uri.decodeFull(parts.last);
    }
  }

  var audioFiles = <File>[];
  var subfolders = <AudioFolderNode>[];

  // Recopilar entradas de forma asíncrona tolerante a fallos: handleError evita
  // que un error individual en permisos o enlace simbólico aborte el resto del árbol.
  var entities = <FileSystemEntity>[];
  try {
    await for (final entity in dir
        .list(recursive: false, followLinks: false)
        .handleError((e) {
      debugPrint('Error listando elemento en ${dir.path}: $e');
    })) {
      entities.add(entity);
      await Future<void>.delayed(Duration.zero);
    }
  } catch (e) {
    debugPrint('Error listando ${dir.path}: $e');
  }

  for (final entity in entities) {
    try {
      if (entity is File) {
        var ext = entity.path.split('.').last.toLowerCase();
        if (audioExts.contains(ext)) {
          audioFiles.add(entity);
        }
      } else if (entity is Directory) {
        var subNode = await _scanAudioFolderTreeAsync(entity);
        if (subNode.totalAudioCount > 0) {
          subfolders.add(subNode);
        }
      }
    } catch (e) {
      debugPrint('Entrada omitida en ${dir.path}: $e');
    }
    await Future<void>.delayed(Duration.zero);
  }

  audioFiles.sort(
    (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
  );
  subfolders.sort(
    (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );

  return AudioFolderNode(
    name: dirName,
    audioFiles: audioFiles,
    subfolders: subfolders,
  );
}
