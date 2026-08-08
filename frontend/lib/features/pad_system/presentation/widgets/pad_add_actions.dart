import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../providers/pad_providers.dart';
import '../../../../core/services/local_audio_storage_service.dart';
import '../../../../core/utils/concurrency_shield.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../../../workspace/data/models/workspace_model.dart';

/// Acciones compartidas del boton [+]: agregar N pads, crear carpeta,
/// o importar varios audios de golpe (cada archivo crea su pad).
class PadAddActions {
  const PadAddActions._();

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

    var options = [1, 2, 4, 8, 12, 16];
    var count = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Cuantos pads quieres agregar?',
          style: TextStyle(color: Colors.white),
        ),
        children: options
            .map(
              (n) => SimpleDialogOption(
                onPressed: () => ConcurrencyShield.safePop(ctx, n),
                child: Text(
                  '$n pads',
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 16,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (count != null) {
      await notifier.addPads(count);
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

      final paths = <String>[];
      final names = <String>[];

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
                final path =
                    await LocalAudioStorageService.importAudioFile(f.path!);
                return (
                  path,
                  f.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
                );
              } else if (f.bytes != null && f.bytes!.isNotEmpty) {
                final path =
                    await LocalAudioStorageService.importAudioBytes(
                  f.name,
                  f.bytes!,
                );
                return (
                  path,
                  f.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
                );
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
        await Future<void>.delayed(Duration.zero);
      }

      if (paths.isEmpty) return;

      await notifier.addPads(
        paths.length,
        samplePaths: paths,
        sampleNames: names,
      );
    });
  }

  static Future<void> assignAudioToPad(dynamic ref, String padId) async {
    await ConcurrencyShield.run('assign_audio_$padId', () async {
      final pageIndex = ref.read(currentPageIndexProvider);
      final result = await FilePicker.pickFiles(type: FileType.audio);
      if (result == null || result.files.single.path == null) return;
      final f = result.files.single;

      final notifier = ref.read(padPageProvider(pageIndex).notifier);

      final localPath = await LocalAudioStorageService.importAudioFile(f.path!);
      final name = f.name.replaceAll(RegExp(r'\.[^.]+$'), '');

      await notifier.assignSampleToPad(padId, localPath, name);
    });
  }

  /// Abre un selector de carpeta del sistema y escanea la estructura
  /// completa de subcarpetas para recrearla jerárquicamente como carpetas de pads.
  /// En Android solicita MANAGE_EXTERNAL_STORAGE para poder usar Directory.list().
  static Future<void> _importAudioFolder(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await ConcurrencyShield.run('import_audio_folder', () async {
    // En Android, solicitar permiso de almacenamiento completo para poder
    // listar carpetas con Directory.list() (Scoped Storage lo bloquea sin esto).
    if (Platform.isAndroid) {
      debugPrint(
        'BDJ Import Log: Android detected → requesting storage permission',
      );
      final hasPermission = await _requestStoragePermission(context);
      if (!hasPermission) {
        debugPrint(
          'BDJ Import Log: Storage permission denied → fallback to file picker',
        );
        if (context.mounted) {
          await _importMobileFolder(context, ref);
        }
        return;
      }
      debugPrint('BDJ Import Log: Storage permission granted ✅');
    }

    // En iOS, getDirectoryPath funciona con security-scoped access.
    // Si falla, caer al file picker.
    if (Platform.isIOS) {
      debugPrint(
        'BDJ Import Log: iOS detected → trying getDirectoryPath first',
      );
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
          if (!context.mounted) break;
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
              content: Text(
                infoText,
                style: const TextStyle(color: Colors.white70),
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

          if (confirm == true) {
            if (!context.mounted) break;
            _showImportingDialog(context);
            try {
              var pageIndex = ref.read(currentPageIndexProvider);
              await ref
                  .read(padPageProvider(pageIndex).notifier)
                  .importAudioDirectoryTree(rootNode);
              debugPrint('BDJ Import Log: Tree import succeeded!');
            } catch (e, st) {
              debugPrint(
                'BDJ Import Log ERROR in importAudioDirectoryTree: $e\n$st',
              );
            } finally {
              if (context.mounted) {
                ConcurrencyShield.safeRootPop(context);
              }
            }
            break;
          } else {
            break;
          }
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

  /// El selector de archivos del sistema concede acceso temporal al contenido
  /// seleccionado. Los audios se copian inmediatamente al sandbox privado de
  /// la aplicación, por lo que no se solicita acceso global al almacenamiento.
  static Future<bool> _requestStoragePermission(BuildContext context) async {
    return true;
  }

  static void _showScanningDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Expanded(child: Text('Analizando carpeta de audios...')),
            ],
          ),
        ),
      ),
    );
  }

  /// La importación cambia Isar y copia archivos. Durante esa transacción la
  /// interfaz no debe permitir navegar ni editar un estado intermedio.
  static void _showImportingDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Expanded(child: Text('Importando carpeta y guardando audios...')),
            ],
          ),
        ),
      ),
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
                content: Text('Ya existe un workspace llamado "$requestedName".'),
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
          debugPrint(
            '[PadAddActions] Fallo al crear workspace: $error\n$st',
          );
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

  /// Importación de carpeta optimizada para móviles (Android/iOS) usando el selector nativo
  static Future<void> _importMobileFolder(
    BuildContext context,
    WidgetRef ref,
  ) async {
    debugPrint('BDJ Import Log: _importMobileFolder() started');
    var pageIndex = ref.read(currentPageIndexProvider);
    var notifier = ref.read(padPageProvider(pageIndex).notifier);

    // Usar FileType.audio para que Android no grise archivos por MIME
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
        withData: true,
      );
      debugPrint(
        'BDJ Import Log: FilePicker result = ${result?.files.length ?? 0} files',
      );
    } catch (e) {
      debugPrint(
        'BDJ Import Log: FileType.audio failed ($e), trying FileType.any...',
      );
      // Fallback: algunos dispositivos no soportan FileType.audio
      try {
        result = await FilePicker.pickFiles(
          type: FileType.any,
          allowMultiple: true,
          withData: true,
        );
        debugPrint(
          'BDJ Import Log: FileType.any result = ${result?.files.length ?? 0} files',
        );
      } catch (e2) {
        debugPrint('BDJ Import Log: FileType.any also failed: $e2');
      }
    }

    if (result == null || result.files.isEmpty) {
      debugPrint('BDJ Import Log: No files selected, returning');
      return;
    }

    if (!context.mounted) return;

    // Mostrar diálogo de procesamiento
    _showImportingDialog(context);

    final audioFiles = <File>[];
    int savedCount = 0;
    int failedCount = 0;

    for (final f in result.files) {
      debugPrint(
        'BDJ Import Log: Processing file "${f.name}" '
        'path=${f.path ?? "null"} '
        'size=${f.size} '
        'bytes=${f.bytes != null ? "${f.bytes!.length}B" : "null"}',
      );

      try {
        // Estrategia 1: Si tiene bytes (withData: true), guardar directamente
        if (f.bytes != null && f.bytes!.isNotEmpty) {
          final savedPath = await LocalAudioStorageService.importAudioBytes(
            f.name,
            f.bytes!,
          );
          final actualPath = await LocalAudioStorageService.resolvePath(
            savedPath,
          );
          audioFiles.add(File(actualPath));
          savedCount++;
          debugPrint('BDJ Import Log: ✅ Saved via bytes → $actualPath');
          continue;
        }

        // Estrategia 2: Si tiene path válido, intentar copiar el archivo
        if (f.path != null && f.path!.isNotEmpty) {
          var resolvedPath = LocalAudioStorageService.resolveContentUriToPath(
            f.path!,
          );
          final resolvedFile = File(resolvedPath);
          if (resolvedFile.existsSync()) {
            // Leer bytes del archivo resuelto y guardarlo en almacenamiento interno
            final bytes = await resolvedFile.readAsBytes();
            if (bytes.isNotEmpty) {
              final savedPath = await LocalAudioStorageService.importAudioBytes(
                f.name,
                bytes,
              );
              final actualPath = await LocalAudioStorageService.resolvePath(
                savedPath,
              );
              audioFiles.add(File(actualPath));
              savedCount++;
              debugPrint(
                'BDJ Import Log: ✅ Saved via resolved path → $actualPath',
              );
              continue;
            }
          }

          // Estrategia 3: Intentar leer bytes del path original (cache de FilePicker)
          final originalFile = File(f.path!);
          if (originalFile.existsSync()) {
            final bytes = await originalFile.readAsBytes();
            if (bytes.isNotEmpty) {
              final savedPath = await LocalAudioStorageService.importAudioBytes(
                f.name,
                bytes,
              );
              final actualPath = await LocalAudioStorageService.resolvePath(
                savedPath,
              );
              audioFiles.add(File(actualPath));
              savedCount++;
              debugPrint(
                'BDJ Import Log: ✅ Saved via original path → $actualPath',
              );
              continue;
            }
          }
        }

        failedCount++;
        debugPrint(
          'BDJ Import Log: ❌ Failed to import "${f.name}" - no bytes and no readable path',
        );
      } catch (e, st) {
        failedCount++;
        debugPrint(
          'BDJ Import Log: ❌ Exception importing "${f.name}": $e\n$st',
        );
      }
    }

    debugPrint(
      'BDJ Import Log: Import summary: $savedCount saved, $failedCount failed, ${audioFiles.length} total files',
    );

    if (audioFiles.isEmpty) {
      if (context.mounted) {
        ConcurrencyShield.safeRootPop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron importar los archivos de audio.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final node = _buildTreeFromFiles(audioFiles, 'Carpeta de Audios');

    try {
      await notifier.importAudioDirectoryTree(node);
      debugPrint('BDJ Import Log: ✅ importAudioDirectoryTree succeeded!');
    } catch (e, st) {
      debugPrint('BDJ Import Log: ❌ importAudioDirectoryTree error: $e\n$st');
    } finally {
      if (context.mounted) {
        ConcurrencyShield.safeRootPop(context);
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$savedCount audio(s) importado(s) correctamente.'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

/// Construye una estructura de arbol AudioFolderNode completa preservando carpetas y subcarpetas
/// a partir de una lista de archivos de audio seleccionados.
AudioFolderNode _buildTreeFromFiles(List<File> files, String fallbackRootName) {
  if (files.isEmpty) {
    return AudioFolderNode(
      name: fallbackRootName,
      audioFiles: [],
      subfolders: [],
    );
  }

  final normalizedPaths = files.map((f) => p.normalize(f.path)).toList();
  String rootDirPath = p.dirname(normalizedPaths.first);

  for (final path in normalizedPaths) {
    while (!p.isWithin(rootDirPath, path) &&
        rootDirPath != p.dirname(rootDirPath)) {
      rootDirPath = p.dirname(rootDirPath);
    }
  }

  String rootName = p.basename(rootDirPath);
  if (rootName.isEmpty ||
      rootName == '.' ||
      rootName == '/' ||
      rootName.contains(':')) {
    rootName = fallbackRootName;
  } else {
    rootName = Uri.decodeFull(rootName);
  }

  final Map<String, List<File>> relativeSubfolders = {};
  final List<File> directRootFiles = [];

  for (final file in files) {
    final normPath = p.normalize(file.path);
    final dirPath = p.dirname(normPath);
    if (dirPath == rootDirPath) {
      directRootFiles.add(file);
    } else {
      final relDir = p.relative(dirPath, from: rootDirPath);
      relativeSubfolders.putIfAbsent(relDir, () => []).add(file);
    }
  }

  final Map<String, _FolderBuilderNode> builderNodes = {};

  relativeSubfolders.forEach((relPath, subFiles) {
    final segments = p.split(relPath);
    String currentKey = '';
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final parentKey = currentKey;
      currentKey = currentKey.isEmpty ? segment : p.join(currentKey, segment);

      builderNodes.putIfAbsent(
        currentKey,
        () => _FolderBuilderNode(
          name: Uri.decodeFull(segment),
          parentKey: parentKey,
        ),
      );

      if (i == segments.length - 1) {
        builderNodes[currentKey]!.files.addAll(subFiles);
      }
    }
  });

  AudioFolderNode assembleNode(String key, _FolderBuilderNode builder) {
    final children =
        builderNodes.entries
            .where((e) => e.value.parentKey == key)
            .map((e) => assembleNode(e.key, e.value))
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    final sortedFiles = [...builder.files]
      ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));

    return AudioFolderNode(
      name: builder.name,
      audioFiles: sortedFiles,
      subfolders: children,
    );
  }

  final topLevelSubfolders =
      builderNodes.entries
          .where((e) => e.value.parentKey.isEmpty)
          .map((e) => assembleNode(e.key, e.value))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  directRootFiles.sort(
    (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
  );

  return AudioFolderNode(
    name: rootName,
    audioFiles: directRootFiles,
    subfolders: topLevelSubfolders,
  );
}

class _FolderBuilderNode {
  final String name;
  final String parentKey;
  final List<File> files = [];

  _FolderBuilderNode({required this.name, required this.parentKey});
}

/// Escaneo asíncrono de carpetas (usa dir.list() en vez de listSync para no
/// bloquear el hilo de UI).
Future<AudioFolderNode> _scanAudioFolderTreeAsync(Directory rawDir) async {
  final resolvedPath = LocalAudioStorageService.resolveContentUriToPath(
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

  // Recopilar TODAS las entradas primero, con tolerancia a errores: si una
  // subcarpeta no se puede listar (permisos/SAF), no se pierde el resto del
  // árbol. El fallback listSync evita que un error a mitad del stream deje
  // el contenido incompleto.
  var entities = <FileSystemEntity>[];
  try {
    await for (final entity in dir.list(
      recursive: false,
      followLinks: false,
    )) {
      entities.add(entity);
      await Future<void>.delayed(Duration.zero);
    }
  } catch (e) {
    debugPrint(
      'Error listando ${dir.path}: $e → fallback listSync',
    );
    try {
      entities = dir.listSync(recursive: false, followLinks: false);
    } catch (_) {}
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
