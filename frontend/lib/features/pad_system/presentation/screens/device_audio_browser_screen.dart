import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../../core/services/app_storage_service.dart';
import '../../../../core/services/mediastore_audio_service.dart';
import '../../../../core/services/saf_folder_import_service.dart';
import '../../../../core/widgets/blocking_progress_dialog.dart';
import '../providers/pad_providers.dart' show AudioFolderNode;

/// Resultado de la selección en el explorador de audios de MediaStore.
class DeviceAudioBrowserResult {
  const DeviceAudioBrowserResult({
    required this.folderNode,
    required this.stagingDirectory,
    required this.totalAudioCount,
  });

  /// Estructura jerárquica lista para importar en pads.
  final AudioFolderNode folderNode;

  /// Directorio temporal que contiene los audios copiados.
  /// Debe limpiarse al finalizar la importación.
  final Directory stagingDirectory;

  /// Cantidad total de audios contenidos.
  final int totalAudioCount;
}

/// Pantalla / Explorador "Desde el dispositivo" que utiliza MediaStore para descubrir
/// y agrupar carpetas con audios en Android (incluida la raíz de Descargas y WhatsApp).
class DeviceAudioBrowserScreen extends StatefulWidget {
  const DeviceAudioBrowserScreen({
    super.key,
    this.title = 'Audios en el dispositivo',
    this.actionLabel = 'Importar',
  });

  final String title;
  final String actionLabel;

  /// Abre el explorador y devuelve los audios copiados listos para importar.
  static Future<DeviceAudioBrowserResult?> open(
    BuildContext context, {
    String title = 'Audios en el dispositivo',
    String actionLabel = 'Importar',
  }) {
    return Navigator.of(context).push<DeviceAudioBrowserResult>(
      MaterialPageRoute(
        builder: (_) => DeviceAudioBrowserScreen(
          title: title,
          actionLabel: actionLabel,
        ),
      ),
    );
  }

  @override
  State<DeviceAudioBrowserScreen> createState() =>
      _DeviceAudioBrowserScreenState();
}

class _DeviceAudioBrowserScreenState extends State<DeviceAudioBrowserScreen> {
  bool _isLoading = true;
  bool _permissionDenied = false;
  String _searchQuery = '';
  bool _includeSubfolders = true;
  List<AudioFolderEntry> _allFolders = [];
  final Set<String> _selectedFolderPaths = {};

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFolders() async {
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
    });

    final hasPermission =
        await SafFolderImportService.isDirectStorageAccessGranted();
    if (!hasPermission) {
      await SafFolderImportService.requestDirectStorageAccess();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final granted =
          await SafFolderImportService.isDirectStorageAccessGranted();
      if (!granted) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _permissionDenied = true;
          });
        }
        return;
      }
    }

    final folders = await MediaStoreAudioService.listAudioFolders();
    if (mounted) {
      setState(() {
        _allFolders = folders;
        _isLoading = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  List<AudioFolderEntry> get _filteredFolders {
    if (_searchQuery.trim().isEmpty) return _allFolders;
    final q = _searchQuery.trim().toLowerCase();
    return _allFolders.where((f) {
      return f.path.toLowerCase().contains(q) ||
          f.displayName.toLowerCase().contains(q);
    }).toList();
  }

  int get _selectedAudioCount {
    var count = 0;
    for (final f in _allFolders) {
      if (_selectedFolderPaths.contains(f.path)) {
        count += f.count;
      }
    }
    return count;
  }

  int get _selectedBytes {
    var bytes = 0;
    for (final f in _allFolders) {
      if (_selectedFolderPaths.contains(f.path)) {
        bytes += f.totalBytes;
      }
    }
    return bytes;
  }

  Future<void> _importSelected() async {
    if (_selectedFolderPaths.isEmpty) return;

    final selectedFolders = _allFolders
        .where((f) => _selectedFolderPaths.contains(f.path))
        .toList();

    Directory? stagingDir;
    try {
      final cacheDir = await AppStorageService.cacheDirectory();
      final stagingName =
          'mediastore_import_${DateTime.now().millisecondsSinceEpoch}';
      stagingDir = Directory(p.join(cacheDir.path, stagingName));
      await stagingDir.create(recursive: true);

      final progress = BlockingProgressController(
        initialMessage: 'Recopilando archivos de audio...',
      );

      final copyFuture = () async {
        final allItems = <AudioFileEntry>[];
        for (final folder in selectedFolders) {
          final files = await MediaStoreAudioService.listAudioFiles(
            folder.path,
            recursive: _includeSubfolders,
          );
          // Si se seleccionaron varias carpetas, prefijar el nombre de la carpeta
          final prefixFolder = selectedFolders.length > 1 ? folder.displayName : '';
          for (final file in files) {
            final rel = prefixFolder.isEmpty
                ? file.relativeSubPath
                : (file.relativeSubPath.isEmpty
                    ? prefixFolder
                    : '$prefixFolder/${file.relativeSubPath}');
            allItems.add(
              AudioFileEntry(
                uri: file.uri,
                name: file.name,
                relativeSubPath: rel,
                size: file.size,
              ),
            );
          }
        }

        if (allItems.isEmpty) {
          throw Exception('No se encontraron archivos de audio legibles en las carpetas seleccionadas.');
        }

        progress.updateCount(allItems.length, 'Copiando audios al almacenamiento local...');

        final copied = await MediaStoreAudioService.copyAudioFiles(
          allItems,
          stagingDir!.path,
          onProgress: (done) {
            progress.updateProgress(done, allItems.length, 'Copiando audios ($done/${allItems.length})...');
          },
        );

        if (copied.isEmpty) {
          throw Exception('No se pudo copiar ningún archivo de audio.');
        }

        final rootName = selectedFolders.length == 1
            ? selectedFolders.first.displayName
            : 'Audios Importados';

        final tree = MediaStoreAudioService.buildFolderTree(rootName, copied);
        return tree;
      }();

      final tree = await BlockingProgressDialog.run(
        context,
        title: 'Importando desde el dispositivo...',
        initialMessage: 'Analizando carpetas seleccionadas...',
        task: (_) => copyFuture,
      );

      if (mounted) {
        Navigator.of(context).pop(
          DeviceAudioBrowserResult(
            folderNode: tree,
            stagingDirectory: stagingDir,
            totalAudioCount: tree.totalAudioCount,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (dCtx) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('Error al importar', style: TextStyle(color: Colors.white)),
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dCtx).pop(),
                child: const Text('Entendido', style: TextStyle(color: Colors.cyanAccent)),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Text(widget.title, style: const TextStyle(fontSize: 18, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Actualizar lista',
            onPressed: _loadFolders,
          ),
        ],
      ),
      body: Column(
        children: [
          // Buscador y toggle de subcarpetas
          Container(
            color: Colors.grey[900],
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Buscar carpeta (Download, WhatsApp, Música...)',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.black45,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.cyanAccent),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: _includeSubfolders,
                      activeColor: Colors.cyanAccent,
                      checkColor: Colors.black,
                      onChanged: (val) {
                        setState(() => _includeSubfolders = val ?? true);
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'Incluir subcarpetas (recursivo)',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                    if (_allFolders.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (_selectedFolderPaths.length == _allFolders.length) {
                              _selectedFolderPaths.clear();
                            } else {
                              _selectedFolderPaths.addAll(_allFolders.map((f) => f.path));
                            }
                          });
                        },
                        child: Text(
                          _selectedFolderPaths.length == _allFolders.length
                              ? 'Deseleccionar todas'
                              : 'Seleccionar todas',
                          style: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Contenido principal
          Expanded(
            child: _buildBody(),
          ),

          // Barra inferior de confirmación
          if (_selectedFolderPaths.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: const Border(top: BorderSide(color: Colors.white12)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_selectedFolderPaths.length} carpeta(s) seleccionada(s)',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '$_selectedAudioCount audios (${_formatBytes(_selectedBytes)})',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.download_rounded),
                      label: Text(
                        widget.actionLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _importSelected,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      );
    }

    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, color: Colors.orangeAccent, size: 54),
              const SizedBox(height: 16),
              const Text(
                'Permiso de Música y audio necesario',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Sin el permiso de Música y audio la app no puede listar tus carpetas con audios. '
                'Puedes conceder el permiso en Ajustes o utilizar el selector de carpetas del sistema.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                onPressed: _loadFolders,
                child: const Text('Conceder permiso', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    final folders = _filteredFolders;
    if (folders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_off_outlined, color: Colors.white38, size: 54),
              const SizedBox(height: 16),
              const Text(
                'No se encontraron carpetas con audios',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No hay carpetas que coincidan con "$_searchQuery".'
                    : 'No encontré audios en tu dispositivo. Si acabas de copiarlos, espera unos segundos a que Android los indexe o usa "Elegir carpeta…" con el selector del sistema.',
                style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: folders.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
      itemBuilder: (context, index) {
        final folder = folders[index];
        final isSelected = _selectedFolderPaths.contains(folder.path);

        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.cyanAccent.withValues(alpha: 0.2) : Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_rounded,
              color: isSelected ? Colors.cyanAccent : Colors.amberAccent,
              size: 22,
            ),
          ),
          title: Text(
            folder.displayName,
            style: TextStyle(
              color: isSelected ? Colors.cyanAccent : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            '${folder.path} · ${folder.count} audios (${_formatBytes(folder.totalBytes)})',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          trailing: Checkbox(
            value: isSelected,
            activeColor: Colors.cyanAccent,
            checkColor: Colors.black,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedFolderPaths.add(folder.path);
                } else {
                  _selectedFolderPaths.remove(folder.path);
                }
              });
            },
          ),
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedFolderPaths.remove(folder.path);
              } else {
                _selectedFolderPaths.add(folder.path);
              }
            });
          },
        );
      },
    );
  }
}
