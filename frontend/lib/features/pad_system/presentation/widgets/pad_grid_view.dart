import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pad_providers.dart';
import '../../../../core/providers/ui_providers.dart';
import '../../../../core/utils/concurrency_shield.dart';
import '../../../desktop/presentation/providers/desktop_providers.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../domain/entities/pad_entity.dart';
import 'pad_button.dart';
import 'pad_add_actions.dart';
import 'pad_settings_dialog.dart';

/// Grid ESTATICO tipo "cajon de apps" (rediseño Stream Deck):
/// - El dispositivo fija el maximo de columnas automaticamente.
/// - El DJ puede elegir pads mas grandes (menos columnas) desde Ajustes.
/// - Lo que no cabe en pantalla fluye a la siguiente pagina (swipe lateral).
/// - Sin coordenadas libres, sin drag, sin resize: nunca se desacomoda.
class PadGridView extends ConsumerWidget {
  final int pageIndex;

  const PadGridView({super.key, required this.pageIndex});

  Widget _buildGrid(
    BuildContext context,
    WidgetRef ref,
    List<PadEntity> pads, {
    bool isEditMode = false,
    int padSize = 0,
    String searchQuery = '',
    int pageIndex = 0,
  }) {
    var allPads = searchQuery.isEmpty
        ? pads
        : pads
              .where((p) => p.label.toLowerCase().contains(searchQuery))
              .toList();
    if (allPads.isEmpty) {
      return _EmptyState(isEditMode: isEditMode);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        int cross = 4;
        double ratio = 1.05;
        double padding = 10;
        double spacing = 10;

        if (padSize == 1) {
          // Grandes (1 a 8 columnas)
          cross = (constraints.maxWidth / 220.0).floor().clamp(1, 8);
          padding = 12;
          spacing = 12;
        } else if (padSize == 2) {
          // Medianos (1 a 12 columnas)
          cross = (constraints.maxWidth / 160.0).floor().clamp(1, 12);
          padding = 8;
          spacing = 8;
        } else if (padSize == 3) {
          // Pequeños (1 a 16 columnas)
          cross = (constraints.maxWidth / 96.0).floor().clamp(1, 16);
          padding = 6;
          spacing = 6;
        } else if (padSize == 4) {
          // Ultra Denso (2 a 20 columnas)
          cross = (constraints.maxWidth / 82.0).floor().clamp(2, 20);
          padding = 5;
          spacing = 5;
        } else if (padSize == 5) {
          // Extra Pequeño (2 a 26 columnas, máxima densidad)
          cross = (constraints.maxWidth / 70.0).floor().clamp(2, 26);
          padding = 4;
          spacing = 4;
        } else {
          // Auto / Medianos Adaptativo a Resolucion (TOTALMENTE RESPONSIVO)
          if (constraints.maxWidth < 320) {
            cross = 1;
            ratio = 1.35;
          } else if (constraints.maxWidth < 500) {
            cross = 2;
            ratio = 1.25;
          } else if (constraints.maxWidth < 750) {
            cross = 3;
            ratio = 1.15;
          } else if (constraints.maxWidth < 1050) {
            cross = 4;
          } else if (constraints.maxWidth < 1400) {
            cross = 6;
          } else if (constraints.maxWidth < 1750) {
            cross = 8;
          } else {
            cross = 10;
          }
        }

        return GridView.builder(
          key: PageStorageKey<int>(pageIndex),
          physics: const BouncingScrollPhysics(),
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          padding: EdgeInsets.all(padding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            childAspectRatio: ratio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: allPads.length,
          itemBuilder: (context, i) => _PadCell(
            key: ValueKey<String>(allPads[i].id),
            pad: allPads[i],
            pageIndex: pageIndex,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var padsAsync = ref.watch(padPageProvider(pageIndex));
    var isEditMode = ref.watch(isEditModeProvider);
    var padSize = ref.watch(settingsProvider.select((s) => s.padSize));
    var searchQuery = ref.watch(searchQueryProvider).toLowerCase();

    final previousData = padsAsync.value;

    return padsAsync.when(
      loading: () => previousData != null
          ? _buildGrid(
              context,
              ref,
              previousData,
              isEditMode: isEditMode,
              padSize: padSize,
              searchQuery: searchQuery,
              pageIndex: pageIndex,
            )
          : const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Error: $err')),
      data: (pads) => _buildGrid(
        context,
        ref,
        pads,
        isEditMode: isEditMode,
        padSize: padSize,
        searchQuery: searchQuery,
        pageIndex: pageIndex,
      ),
    );
  }
}

/// Celda individual del grid con overlays de foco (desktop) y edicion.
class _PadCell extends ConsumerWidget {
  final PadEntity pad;
  final int pageIndex;

  const _PadCell({super.key, required this.pad, required this.pageIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var isEditMode = ref.watch(isEditModeProvider);
    var moveSource = ref.watch(padMoveSourceProvider);
    var isMoving = moveSource == pad.id;
    var selectedPads = ref.watch(selectedPadsProvider);
    var isSelected = selectedPads.contains(pad.id);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        var moveSource = ref.read(padMoveSourceProvider);
        if (moveSource != null) {
          if (moveSource == pad.id) {
            ref.read(padMoveSourceProvider.notifier).state = null;
          } else {
            ref
                .read(padPageProvider(pageIndex).notifier)
                .swapPads(moveSource, pad.id);
            ref.read(padMoveSourceProvider.notifier).state = null;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pads intercambiados correctamente'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }

        if (isEditMode) {
          final set = Set<String>.from(ref.read(selectedPadsProvider));
          if (set.contains(pad.id)) {
            set.remove(pad.id);
          } else {
            set.add(pad.id);
          }
          ref.read(selectedPadsProvider.notifier).state = set;
        }
      },
      onSecondaryTap: () {
        _showQuickActions(context, ref);
      },
      onLongPress: () {
        _showQuickActions(context, ref);
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: PadButton(
              key: ValueKey(pad.id),
              pad: pad,
              pageIndex: pageIndex,
            ),
          ),
          if (isEditMode) ...[
            Positioned(
              top: 4,
              left: 4,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final set = Set<String>.from(ref.read(selectedPadsProvider));
                  if (set.contains(pad.id)) {
                    set.remove(pad.id);
                  } else {
                    set.add(pad.id);
                  }
                  ref.read(selectedPadsProvider.notifier).state = set;
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.cyanAccent : Colors.black87,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.cyanAccent : Colors.white70,
                      width: 1.5,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: Colors.cyanAccent.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                    ],
                  ),
                  child: Icon(
                    isSelected ? Icons.check_rounded : Icons.circle_outlined,
                    color: isSelected ? Colors.black : Colors.white70,
                    size: 14,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _showQuickActions(context, ref);
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.edit, color: Colors.black, size: 14),
                ),
              ),
            ),
          ],
          if (isMoving || isSelected)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: isMoving
                      ? Colors.orange.withValues(alpha: 0.25)
                      : Colors.cyan.withValues(alpha: 0.25),
                  border: Border.all(
                    color: isMoving ? Colors.orangeAccent : Colors.cyanAccent,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(
                    isMoving ? Icons.swap_horiz : Icons.check_circle,
                    color: isMoving ? Colors.orangeAccent : Colors.cyanAccent,
                    size: 28,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Hoja unica de edicion por pad: todo en un solo lugar.
  void _showQuickActions(BuildContext context, WidgetRef ref) {
    var container = ProviderScope.containerOf(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  pad.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  pad.isFolder ? 'Carpeta' : (pad.sampleId ?? 'Sin sonido'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Color rápido del Pad (1-Clic):',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        [
                          0xFF880E4F, // Guinda / Borgoña Vino (Como en la foto del usuario)
                          0xFF9C27B0, // Morado / Púrpura
                          0xFFE91E63, // Rosa / Magenta
                          0xFFF44336, // Rojo Pánico / FX
                          0xFFFF9800, // Naranja Drop
                          0xFFFFEB3B, // Amarillo Jingle
                          0xFF4CAF50, // Verde Base
                          0xFF00BCD4, // Cian Lead
                          0xFF2196F3, // Azul Voz
                          0xFF795548, // Marrón / Moka
                          0xFFE0E0E0, // Blanco / Plata
                        ].map((colorInt) {
                          final isSelectedColor = pad.colorHex == colorInt;
                          return GestureDetector(
                            onTap: () {
                              ConcurrencyShield.safePop(ctx);
                              var padIdInt = int.tryParse(pad.id);
                              if (padIdInt != null) {
                                container
                                    .read(padPageProvider(pageIndex).notifier)
                                    .updatePadVisual(
                                      padIdInt,
                                      colorHex: colorInt,
                                    );
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Color(colorInt),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelectedColor
                                      ? Colors.cyanAccent
                                      : Colors.white24,
                                  width: isSelectedColor ? 3.0 : 1.0,
                                ),
                                boxShadow: [
                                  if (isSelectedColor)
                                    BoxShadow(
                                      color: Color(
                                        colorInt,
                                      ).withValues(alpha: 0.8),
                                      blurRadius: 8,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Divider(color: Colors.white24, height: 1),
              if (pad.isFolder)
                ListTile(
                  leading: const Icon(
                    Icons.folder_open,
                    color: Colors.yellowAccent,
                  ),
                  title: const Text(
                    'Abrir carpeta',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Entrar para editar el contenido',
                    style: TextStyle(color: Colors.grey),
                  ),
                  onTap: () {
                    if (!ConcurrencyShield.throttle(
                      'open_folder_${pad.id}',
                      cooldown: const Duration(milliseconds: 350),
                    ))
                      return;
                    ConcurrencyShield.safePop(ctx);
                    if (pad.targetPageIndex != null) {
                      SafeFolderNavigator.openFolder(
                        container,
                        pageIndex,
                        pad.targetPageIndex!,
                      );
                    }
                  },
                ),
              if (!pad.isFolder) ...[
                ListTile(
                  leading: const Icon(
                    Icons.audio_file,
                    color: Colors.greenAccent,
                  ),
                  title: const Text(
                    'Asignar sonido',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    ConcurrencyShield.safePop(ctx);
                    await PadAddActions.assignAudioToPad(container, pad.id);
                  },
                ),
              ],
              ListTile(
                leading: const Icon(
                  Icons.drive_file_rename_outline,
                  color: Colors.tealAccent,
                ),
                title: const Text(
                  'Renombrar',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  ConcurrencyShield.safePop(ctx);
                  var controller = TextEditingController(text: pad.label);
                  try {
                    var name = await showDialog<String>(
                      context: context,
                      builder: (dctx) => AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: Text(
                          pad.isFolder ? 'Renombrar carpeta' : 'Renombrar pad',
                          style: const TextStyle(color: Colors.white),
                        ),
                        content: TextField(
                          controller: controller,
                          autofocus: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Nuevo nombre',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => ConcurrencyShield.safePop(dctx),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => ConcurrencyShield.safePop(
                              dctx,
                              controller.text,
                            ),
                            child: const Text('Guardar'),
                          ),
                        ],
                      ),
                    );
                    if (name != null && name.trim().isNotEmpty) {
                      await container
                          .read(padPageProvider(pageIndex).notifier)
                          .updatePadVisual(
                            int.parse(pad.id),
                            label: name.trim(),
                          );
                    }
                  } finally {
                    Future<void>.delayed(
                      const Duration(milliseconds: 300),
                      controller.dispose,
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune, color: Colors.blueAccent),
                title: const Text(
                  'Editar (nombre, color, modo...)',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  ConcurrencyShield.safePop(ctx);
                  showDialog(
                    context: context,
                    builder: (dctx) =>
                        PadSettingsDialog(pad: pad, pageIndex: pageIndex),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.keyboard, color: Colors.cyanAccent),
                title: Text(
                  container
                          .read(keyBindingsProvider.notifier)
                          .hasBinding(
                            pad.id,
                            workspaceId:
                                container.read(currentWorkspaceIdProvider) ?? 0,
                            pageIndex: pageIndex,
                          )
                      ? 'Reasignar / quitar tecla'
                      : 'Asignar tecla (teclado)',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  pad.isFolder
                      ? 'Presiona la tecla para abrir esta carpeta'
                      : 'El usuario decide el atajo; no hay defaults',
                  style: const TextStyle(color: Colors.grey),
                ),
                onTap: () {
                  // Capturar el messenger ANTES del safePop: el bottom sheet que
                  // se cierra lleva su propio Scaffold, y un showSnackBar posterior
                  // con ese context se pierde con el desmontaje.
                  final messenger = ScaffoldMessenger.of(context);
                  ConcurrencyShield.safePop(ctx);
                  final enableShortcuts = container
                      .read(settingsProvider)
                      .enablePadShortcuts;
                  if (!enableShortcuts) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Debes activar "Atajos de teclado en los pads" para poder asignar teclas.',
                        ),
                        duration: const Duration(seconds: 4),
                        action: SnackBarAction(
                          label: 'Activar',
                          onPressed: () {
                            container
                                .read(settingsProvider.notifier)
                                .setEnablePadShortcuts(true);
                            container.read(keyLearnPadProvider.notifier).state =
                                pad.id;
                            messenger.hideCurrentSnackBar();
                          },
                        ),
                      ),
                    );
                    return;
                  }
                  var hasIt = container
                      .read(keyBindingsProvider.notifier)
                      .hasBinding(
                        pad.id,
                        workspaceId:
                            container.read(currentWorkspaceIdProvider) ?? 0,
                        pageIndex: container.read(currentPageIndexProvider),
                      );
                  if (hasIt) {
                    container
                        .read(keyBindingsProvider.notifier)
                        .unbindPad(
                          pad.id,
                          workspaceId:
                              container.read(currentWorkspaceIdProvider) ?? 0,
                          pageIndex: container.read(currentPageIndexProvider),
                        );
                    messenger.showSnackBar(
                      const SnackBar(
                        duration: const Duration(seconds: 2),
                        content: Text('Atajo de teclado quitado'),
                      ),
                    );
                  } else {
                    container.read(keyLearnPadProvider.notifier).state = pad.id;
                    messenger.showSnackBar(
                      const SnackBar(
                        duration: const Duration(seconds: 2),
                        content: Text(
                          'Presiona una tecla para asignarla a este pad',
                        ),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.open_with,
                  color: Colors.orangeAccent,
                ),
                title: const Text(
                  'Mover / Intercambiar posicion',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  ConcurrencyShield.safePop(ctx);
                  container.read(padMoveSourceProvider.notifier).state = pad.id;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      duration: const Duration(seconds: 2),
                      content: Text(
                        'Toca otro pad para intercambiar (o el mismo para cancelar)',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.purpleAccent),
                title: Text(
                  pad.isFolder
                      ? 'Duplicar carpeta (con contenido)'
                      : 'Duplicar pad',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  ConcurrencyShield.safePop(ctx);
                  await container
                      .read(padPageProvider(pageIndex).notifier)
                      .duplicatePad(pad);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  ConcurrencyShield.safePop(ctx);
                  var ok = await showDialog<bool>(
                    context: context,
                    builder: (dctx) => AlertDialog(
                      backgroundColor: Colors.grey[900],
                      title: const Text(
                        'Eliminar pad?',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: Text(
                        pad.isFolder
                            ? 'Se eliminara la carpeta "${pad.label}" y TODO su contenido.'
                            : 'Se eliminara el pad "${pad.label}".',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              ConcurrencyShield.safePop(dctx, false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () =>
                              ConcurrencyShield.safePop(dctx, true),
                          child: const Text(
                            'Eliminar',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await container
                        .read(padPageProvider(pageIndex).notifier)
                        .deletePad(pad.id);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  final bool isEditMode;
  const _EmptyState({required this.isEditMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.grid_view_rounded, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Este espacio esta vacio',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Agrega pads, carpetas o importa tus audios',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Agregar'),
            onPressed: () => PadAddActions.showAddMenu(context, ref),
          ),
        ],
      ),
    );
  }
}
