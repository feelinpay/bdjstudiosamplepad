import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/pad_grid_view.dart';
import '../widgets/pad_add_actions.dart';
import '../widgets/pad_delete_actions.dart';
import '../widgets/search_bar_widget.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../../../../core/providers/ui_providers.dart';
import '../../../../core/utils/concurrency_shield.dart';
import '../../../../core/services/local_audio_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../performance_mode/presentation/widgets/live_control_bar.dart';
import '../providers/pad_providers.dart';
import '../widgets/master_mixer_panel.dart';
import '../../../midi/presentation/widgets/midi_status_icon.dart';
import '../../../metronome/presentation/widgets/metronome_button.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../desktop/presentation/widgets/desktop_shortcuts.dart';
import '../../../workspace/data/models/workspace_model.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/audio_providers.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/audio/audio_initialization_result.dart';
import '../../../../core/audio/audio_engine_state.dart';

class MainPadPage extends ConsumerStatefulWidget {
  const MainPadPage({super.key});

  @override
  ConsumerState<MainPadPage> createState() => _MainPadPageState();
}

class _MainPadPageState extends ConsumerState<MainPadPage> {
  @override
  Widget build(BuildContext context) {
    var isLoading = ref.watch(globalLoadingProvider);

    return DesktopShortcuts(child: _ExplorerBody(isLoading: isLoading));
  }
}

/// Reintenta la inicialización del motor de audio. El nuevo resultado se escribe en
/// [audioInitializationCacheProvider], por lo que [audioInitializationProvider] y
/// [isAudioReadyProvider] se refrescan automáticamente y el overlay desaparece.
Future<AudioInitializationResult> retryAudioInitialization(WidgetRef ref) async {
  final engine = ref.read(audioEngineProvider);
  final savedDeviceId =
      ref.read(settingsServiceProvider).audioOutputDeviceId;
  final result = await engine.retryAudioInitialization(savedDeviceId);
  ref.read(audioInitializationCacheProvider.notifier).state = result;
  return result;
}

/// Cuerpo principal del explorador: muestra el grid de pads de la página actual.
/// La navegación entre carpetas se hace con Navigator.push (pantalla nueva).
class _ExplorerBody extends ConsumerWidget {
  final bool isLoading;
  const _ExplorerBody({required this.isLoading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var workspaceAsync = ref.watch(currentWorkspaceProvider);
    var currentPageIndex = ref.watch(currentPageIndexProvider);
    var highContrast = ref.watch(
      settingsProvider.select((s) => s.highContrast),
    );
    var isEditMode = ref.watch(isEditModeProvider);

    // Gatear pads hasta que el motor de audio esté ready: evita tocar pads
    // ciegos mientras el arranque asíncrono no ha finalizado o falló.
    final audioResult = ref.watch(audioInitializationProvider);
    final isAudioReady = audioResult.state == AudioEngineState.ready;

    final pageIndex = currentPageIndex;

    final appBar = _buildAppBar(
      context,
      ref,
      workspaceAsync,
      currentPageIndex,
      isEditMode,
      highContrast,
    );

    return Scaffold(
      backgroundColor: highContrast
          ? const Color(0xFF000000)
          : const Color(0xFF0A0C10),
      appBar: appBar,
      endDrawer: const MasterMixerPanel(),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      if (isEditMode)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _GridBackgroundPainter(
                              highContrast: highContrast,
                            ),
                          ),
                        ),
                      Column(
                        children: [
                          Expanded(child: PadGridView(pageIndex: pageIndex)),
                          if (ref.watch(padMoveSourceProvider) != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              color: Color(AppColors.folderPadColor).withValues(alpha: 0.25),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.swap_horiz_rounded,
                                    color: Colors.orangeAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Toca otro pad o carpeta para intercambiar su posición.',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.redAccent
                                          .withValues(alpha: 0.3),
                                      foregroundColor: Colors.redAccent,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Cancelar Mover',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onPressed: () {
                                      ref
                                              .read(
                                                padMoveSourceProvider.notifier,
                                              )
                                              .state =
                                          null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const LiveControlBar(),
              ],
            ),
          ),
          if (isLoading)
            const ModalBarrier(dismissible: false, color: Colors.black54),
          if (isLoading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.cyanAccent),
                  SizedBox(height: 16),
                  Text(
                    'Procesando...',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          if (!isAudioReady)
            const ModalBarrier(dismissible: false, color: Colors.black54),
          if (!isAudioReady)
            Center(
              child: _AudioNotReadyOverlay(
                result: audioResult,
                onRetry: () => retryAudioInitialization(ref),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<WorkspaceModel?> workspaceAsync,
    int currentPageIndex,
    bool isEditMode,
    bool highContrast,
  ) {
    final isFolder = currentPageIndex >= 1000;
    final accentColor = highContrast ? Colors.yellowAccent : Colors.cyanAccent;
    const appBarBg = Color(0xFF0E121B);

    // AppBar con selección de pads
    if (ref.watch(selectedPadsProvider).isNotEmpty) {
      return AppBar(
        backgroundColor: appBarBg,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          tooltip: 'Cancelar selección',
          onPressed: () => ref.read(selectedPadsProvider.notifier).state = {},
        ),
        title: Text(
          '${ref.watch(selectedPadsProvider).length} pads seleccionados',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.select_all_rounded,
              color: Colors.cyanAccent,
            ),
            tooltip: 'Seleccionar / Deseleccionar todos',
            onPressed: () {
              var pads =
                  ref.read(padPageProvider(currentPageIndex)).value ?? [];
              var currentSelected = ref.read(selectedPadsProvider);
              var allIds = pads.map((p) => p.id).toSet();
              if (currentSelected.length >= allIds.length &&
                  allIds.isNotEmpty) {
                ref.read(selectedPadsProvider.notifier).state = {};
              } else {
                ref.read(selectedPadsProvider.notifier).state = allIds;
              }
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_forever_rounded,
              color: Colors.redAccent,
            ),
            tooltip: 'Eliminar pads seleccionados',
            onPressed: () async {
              var selectedPads = ref.read(selectedPadsProvider);
              var count = selectedPads.length;
              var ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: Text(
                    'Eliminar $count pad(s)',
                    style: const TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    '¿Estás seguro de eliminar los pads seleccionados?',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => ConcurrencyShield.safePop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: () => ConcurrencyShield.safePop(ctx, true),
                      child: const Text(
                        'Eliminar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                if (!context.mounted) return;
                await ref
                    .read(padPageProvider(currentPageIndex).notifier)
                    .deleteSelectedPads(ref.read(selectedPadsProvider));
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      );
    }

    // AppBar normal (con breadcrumb si estamos en carpeta)
    return AppBar(
      backgroundColor: appBarBg,
      elevation: 4,
      titleSpacing: 8,
      leading: isFolder
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              tooltip: 'Volver',
              onPressed: () => SafeFolderNavigator.goBack(ref),
            )
          : null,
      centerTitle: true,
      title: isFolder
          ? _FolderBreadcrumb(
              pageIndex: currentPageIndex,
              onNavigate: (pageIndex, pathPosition) {
                SafeFolderNavigator.navigateToBreadcrumbIndex(
                  ref,
                  pageIndex,
                  pathPosition,
                );
              },
            )
          : _buildWorkspaceBar(context, ref, workspaceAsync, accentColor),
      bottom: null,
      actions: [
        if (!isEditMode) ...[
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.tune_rounded, color: Colors.cyanAccent),
              tooltip: 'Master Mixer & FX',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
          const PadSearchBarWidget(),
        ],
        if (isEditMode) ...[
          TextButton.icon(
            onPressed: () => PadAddActions.showAddMenu(context, ref),
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: Colors.greenAccent,
              size: 18,
            ),
            label: const Text('Crear', style: TextStyle(color: Colors.white)),
          ),
          TextButton.icon(
            onPressed: () => PadDeleteActions.showDeleteMenu(context, ref),
            icon: const Icon(
              Icons.remove_circle_outline_rounded,
              color: Colors.redAccent,
              size: 18,
            ),
            label: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const MidiStatusIcon(),
          const MetronomeButton(),
        ],
        IconButton(
          icon: Icon(
            isEditMode ? Icons.close_rounded : Icons.edit_rounded,
            color: isEditMode ? Colors.cyanAccent : Colors.white70,
          ),
          tooltip: isEditMode ? 'Salir de Modo Edición' : 'Modo Edición',
          onPressed: () {
            final nextEditMode = !isEditMode;
            ref.read(isEditModeProvider.notifier).state = nextEditMode;
            ref.read(padMoveSourceProvider.notifier).state = null;
            if (!nextEditMode)
              ref.read(selectedPadsProvider.notifier).state = {};
          },
        ),
        if (!isEditMode)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            tooltip: 'Opciones y Ajustes',
            color: const Color(0xFF141822),
            onSelected: (value) async {
              if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                return;
              }
              if (value == 'create') {
                await _createWorkspace(context, ref);
                return;
              }
              if (value == 'import') {
                await _importWorkspace(context, ref);
                return;
              }
              var ws = await ref.read(currentWorkspaceProvider.future);
              if (ws == null) return;
              var repo = ref.read(workspaceRepositoryProvider);
              if (value == 'duplicate') {
                var copy = await repo.duplicateWorkspace(ws.id);
                if (!context.mounted) return;
                ref.invalidate(workspaceListProvider);
                ref.read(currentPageIndexProvider.notifier).state = 0;
                ref.read(folderBackStackProvider.notifier).state = [];
                // Use safe workspace switching with request ID
                await switchWorkspaceWithRequestId(ref, copy.id);
                ref.invalidate(padPageProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 2),
                    content: Text('Workspace duplicado: "${copy.name}"'),
                  ),
                );
              } else if (value == 'rename') {
                await _renameWorkspace(context, ref, ws);
              } else if (value == 'reorder') {
                await _reorderWorkspaces(context, ref);
              } else if (value == 'delete') {
                // deleteWorkspace ya invalida la lista, detiene el audio y
                // conmuta al workspace restante de forma segura (request-id).
                await PadDeleteActions.deleteWorkspace(
                  context,
                  ref,
                  ws.id,
                  ws.name,
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.settings_rounded,
                      color: Colors.cyanAccent,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Configuración / Ajustes',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              const PopupMenuItem(
                value: 'create',
                child: Text(
                  'Crear nuevo workspace',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Text(
                  'Importar workspace',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                value: 'rename',
                child: Text(
                  'Renombrar workspace',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                value: 'reorder',
                child: Text(
                  'Ordenar workspaces',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const PopupMenuItem(
                value: 'duplicate',
                child: Text('Duplicar workspace'),
              ),
              const PopupMenuDivider(height: 1),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Eliminar workspace',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _renameWorkspace(
    BuildContext context,
    WidgetRef ref,
    WorkspaceModel workspace,
  ) async {
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (_) => _RenameWorkspaceDialog(initialName: workspace.name),
      );
      final normalized = name?.trim();
      if (normalized == null ||
          normalized.isEmpty ||
          normalized == workspace.name)
        return;
      final all = await ref
          .read(workspaceRepositoryProvider)
          .getAllWorkspaces();
      if (all.any(
        (item) =>
            item.id != workspace.id &&
            item.name.toLowerCase() == normalized.toLowerCase(),
      )) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              duration: const Duration(seconds: 2),
              content: Text('Ya existe un workspace con ese nombre.'),
            ),
          );
        }
        return;
      }
      final oldName = workspace.name;
      workspace.name = normalized;
      await ref.read(workspaceManagerProvider.notifier).renameWorkspace(workspace, normalized);
      await LocalAudioStorageService.renameWorkspaceDir(oldName, normalized);
      final isar = await ref.read(isarProvider.future);
      await LocalAudioStorageService.migrateWorkspaceSamplePaths(
        isar,
        oldName,
        normalized,
      );
      ref.invalidate(workspaceListProvider);
      ref.invalidate(currentWorkspaceProvider);
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(duration: const Duration(seconds: 2), content: Text('No se pudo renombrar el workspace: $error')),
        );
      }
    }
  }

  Future<void> _createWorkspace(BuildContext context, WidgetRef ref) async {
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (_) => const _CreateWorkspaceDialog(),
      );
      final normalized = name?.trim();
      if (normalized == null || normalized.isEmpty) return;
      final manager = ref.read(workspaceManagerProvider.notifier);
      final ws = await manager.createWorkspace(normalized);
      if (ws == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(duration: const Duration(seconds: 2), content: Text('No se pudo crear el workspace.')),
          );
        }
        return;
      }
      if (!context.mounted) return;
      ref.invalidate(workspaceListProvider);
      ref.invalidate(currentWorkspaceProvider);
      ref.read(currentPageIndexProvider.notifier).state = 0;
      ref.read(folderBackStackProvider.notifier).state = [];
      // Use safe workspace switching with request ID
      await switchWorkspaceWithRequestId(ref, ws.id);
      ref.invalidate(padPageProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(duration: const Duration(seconds: 2), content: Text('Workspace creado: "${ws.name}"')));
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(duration: const Duration(seconds: 2), content: Text('No se pudo crear el workspace: $error')),
        );
      }
    }
  }

  Future<void> _importWorkspace(BuildContext context, WidgetRef ref) async {
    try {
      final folderPath = await FilePicker.getDirectoryPath();
      if (folderPath == null || folderPath.isEmpty) return;
      final importer = ref.read(workspaceImporterProvider);
      final workspaceName = await importer.importWorkspace(folderPath);
      if (!context.mounted) return;
      if (workspaceName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: const Duration(seconds: 2),
            content: Text('La carpeta no contiene archivos de audio.'),
          ),
        );
        return;
      }
      ref.invalidate(workspaceListProvider);
      ref.invalidate(currentWorkspaceProvider);
      final wsId = workspaceName.id;
      // Use safe workspace switching with request ID
      await switchWorkspaceWithRequestId(ref, wsId);
      ref.invalidate(padPageProvider);
      ref.read(currentPageIndexProvider.notifier).state = 0;
      ref.read(folderBackStackProvider.notifier).state = <int>[];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(duration: const Duration(seconds: 2), content: Text('Workspace "${workspaceName.name}" importado.')),
      );
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(duration: const Duration(seconds: 2), content: Text('Error al importar el workspace: $error')),
        );
      }
    }
  }

  Future<void> _reorderWorkspaces(BuildContext context, WidgetRef ref) async {
    final items = [
      ...(await ref.read(workspaceRepositoryProvider).getAllWorkspaces()),
    ];
    final currentOrder = ref.read(settingsServiceProvider).workspaceOrder;
    items.sort((a, b) {
      final left = currentOrder.indexOf(a.id);
      final right = currentOrder.indexOf(b.id);
      return (left == -1 ? items.length : left).compareTo(
        right == -1 ? items.length : right,
      );
    });
    var save = false;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ordenar workspaces'),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.sizeOf(context).height * .48,
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  key: ValueKey(item.id),
                  leading: const Icon(
                    Icons.folder_rounded,
                    color: Colors.cyanAccent,
                  ),
                  title: Text(item.name, overflow: TextOverflow.ellipsis),
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle_rounded),
                  ),
                );
              },
              onReorderItem: (oldIndex, newIndex) => setDialogState(() {
                items.insert(newIndex, items.removeAt(oldIndex));
              }),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => ConcurrencyShield.safePop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                save = true;
                ConcurrencyShield.safePop(dialogContext);
              },
              child: const Text('Guardar orden'),
            ),
          ],
        ),
      ),
    );
    if (!save) return;
    await ref
        .read(settingsServiceProvider)
        .setWorkspaceOrder(items.map((item) => item.id).toList());
    ref.invalidate(workspaceListProvider);
  }

  Widget _buildWorkspaceBar(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<WorkspaceModel?> workspaceAsync,
    Color accent,
  ) {
    final wsListAsync = ref.watch(workspaceListProvider);
    return wsListAsync.when(
      loading: () => const SizedBox(height: 40),
      error: (e, st) => const SizedBox(height: 40),
      data: (wsList) {
        final ws = workspaceAsync.value;
        final validId = wsList.any((w) => w.id == ws?.id)
            ? ws?.id
            : (wsList.isNotEmpty ? wsList.first.id : null);
        return Container(
          height: 36,
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF141822),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Icon(Icons.folder_copy_rounded, color: accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: validId,
                    dropdownColor: const Color(0xFF141822),
                    style: TextStyle(
                      color: accent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    items: wsList
                        .map(
                          (w) => DropdownMenuItem(
                            value: w.id,
                            child: Text(
                              w.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                      onChanged: (id) {
                        if (id != null &&
                            id != ref.read(currentWorkspaceIdProvider)) {
                          if (!ConcurrencyShield.throttle(
                            'switch_workspace',
                            cooldown: const Duration(milliseconds: 500),
                          ))
                            return;
                        ConcurrencyShield.runNavigation(() async {
                           await ref.read(workspaceManagerProvider.notifier)
                               .switchWorkspace(id);
                           // Use safe workspace switching with request ID
                           await switchWorkspaceWithRequestId(ref, id);
                           ref.read(currentPageIndexProvider.notifier).state = 0;
                           ref.read(folderBackStackProvider.notifier).state =
                               <int>[];
                           ref.invalidate(padPageProvider);
                         });
                        }
                      },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CreateWorkspaceDialog extends StatefulWidget {
  const _CreateWorkspaceDialog();

  @override
  State<_CreateWorkspaceDialog> createState() => _CreateWorkspaceDialogState();
}

class _CreateWorkspaceDialogState extends State<_CreateWorkspaceDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: 'Mi nuevo set');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Crear nuevo workspace'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 80,
      textInputAction: TextInputAction.done,
      onSubmitted: (value) => ConcurrencyShield.safePop(context, value),
      decoration: const InputDecoration(hintText: 'Ej. Set de boda'),
    ),
    actions: [
      TextButton(
        onPressed: () => ConcurrencyShield.safePop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => ConcurrencyShield.safePop(context, _controller.text),
        child: const Text('Crear'),
      ),
    ],
  );
}

class _RenameWorkspaceDialog extends StatefulWidget {
  const _RenameWorkspaceDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameWorkspaceDialog> createState() => _RenameWorkspaceDialogState();
}

class _RenameWorkspaceDialogState extends State<_RenameWorkspaceDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Renombrar workspace'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 80,
      textInputAction: TextInputAction.done,
      onSubmitted: (value) => ConcurrencyShield.safePop(context, value),
      decoration: const InputDecoration(hintText: 'Ej. Set principal'),
    ),
    actions: [
      TextButton(
        onPressed: () => ConcurrencyShield.safePop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => ConcurrencyShield.safePop(context, _controller.text),
        child: const Text('Guardar'),
      ),
    ],
  );
}

/// Breadcrumb tipo explorador de archivos: muestra la ruta completa
/// con nombres reales de cada carpeta, scrollable horizontalmente.
class _FolderBreadcrumb extends ConsumerWidget {
  final int pageIndex;
  final Function(int pageIndex, int pathPosition) onNavigate;

  const _FolderBreadcrumb({required this.pageIndex, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderStack = ref.watch(folderBackStackProvider);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final accent = ref.watch(settingsProvider.select((s) => s.highContrast))
        ? Colors.yellowAccent
        : Colors.cyanAccent;

    final List<String> pathNames = [workspace?.name ?? 'Principal'];
    final List<int> pathIndices = [0];

    for (var idx in folderStack) {
      if (idx != 0) {
        var name = ref.watch(folderNameProvider(idx)).value;
        pathNames.add(name ?? 'Carpeta');
        pathIndices.add(idx);
      }
    }

    if (pageIndex != 0 && !pathIndices.contains(pageIndex)) {
      var currentName = ref.watch(folderNameProvider(pageIndex)).value;
      pathNames.add(currentName ?? 'Carpeta');
      pathIndices.add(pageIndex);
    }

    return GestureDetector(
      onTap: () {
        if (!ConcurrencyShield.throttle(
          'breadcrumb_menu',
          cooldown: const Duration(milliseconds: 400),
        ))
          return;
        _showBreadcrumbMenu(context, pathNames, pathIndices);
      },
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < pathNames.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.chevron_right,
                    color: Colors.white38,
                    size: 14,
                  ),
                ),
              _BreadcrumbChip(
                label: pathNames[i],
                isLast: i == pathNames.length - 1,
                isFirst: i == 0,
                accent: accent,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showBreadcrumbMenu(
    BuildContext context,
    List<String> names,
    List<int> indices,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141822),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Navegar a...',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            for (int i = 0; i < names.length; i++)
              ListTile(
                dense: true,
                leading: Icon(
                  i == 0 ? Icons.home_rounded : Icons.folder_rounded,
                  color: i == names.length - 1
                      ? Colors.cyanAccent
                      : Colors.white54,
                  size: 20,
                ),
                title: Text(
                  names[i],
                  style: TextStyle(
                    color: i == names.length - 1
                        ? Colors.cyanAccent
                        : Colors.white,
                    fontWeight: i == names.length - 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
                trailing: i < names.length - 1
                    ? const Icon(
                        Icons.chevron_right,
                        color: Colors.white24,
                        size: 18,
                      )
                    : null,
                onTap: () {
                  ConcurrencyShield.safePop(ctx);
                  onNavigate(indices[i], i);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _BreadcrumbChip extends StatelessWidget {
  final String label;
  final bool isLast;
  final bool isFirst;
  final Color accent;

  const _BreadcrumbChip({
    required this.label,
    required this.isLast,
    required this.isFirst,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = isLast ? accent : Colors.white54;
    final weight = isLast ? FontWeight.bold : FontWeight.normal;
    final bg = isLast ? accent.withValues(alpha: 0.15) : Colors.transparent;
    final border = isLast ? accent.withValues(alpha: 0.3) : Colors.white12;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFirst)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.home_rounded, color: color, size: 12),
            ),
          if (!isFirst)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.folder_rounded, color: color, size: 12),
            ),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(color: color, fontSize: 12, fontWeight: weight),
          ),
        ],
      ),
    );
  }
}

class _GridBackgroundPainter extends CustomPainter {
  final bool highContrast;
  const _GridBackgroundPainter({this.highContrast = false});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = highContrast
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    const double spacing = 20.0;
    const double radius = 1.5;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Overlay que comunica al usuario el estado del motor de audio mientras está
/// inicializándose o ha fallado. Mientras el motor no esté `ready`, el
/// [ModalBarrier] ermezado en el Scaffold bloquea los toques a los pads.
class _AudioNotReadyOverlay extends StatelessWidget {
  final AudioInitializationResult result;
  final VoidCallback onRetry;

  const _AudioNotReadyOverlay({required this.result, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final bool showRetry =
        result.state == AudioEngineState.noDevice ||
        result.state == AudioEngineState.error;
    final String message = switch (result.state) {
      AudioEngineState.initializing => 'Inicializando motor de audio...',
      AudioEngineState.noDevice =>
        result.userMessage ??
        'No se detectó dispositivo de salida.\nSelecciona uno en Configuración.',
      AudioEngineState.error =>
        result.userMessage ?? 'Error al iniciar el motor de audio.',
      _ => 'Motor de audio no disponible.',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: const Color(0xFF141822),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!showRetry)
            const SizedBox(
              height: 36,
              child: Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              ),
            )
          else
            const Icon(
              Icons.volume_up,
              color: Colors.deepOrangeAccent,
              size: 36,
            ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (showRetry) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }
}
