import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/macro_providers.dart';
import '../widgets/destination_picker.dart';
import '../../domain/entities/macro_entity.dart';
import 'macro_builder_screen.dart';
import '../../../midi/domain/entities/midi_mapping_entity.dart';
import '../../../midi/presentation/providers/midi_providers.dart';

class MacroListScreen extends ConsumerWidget {
  const MacroListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var macrosAsync = ref.watch(macroListProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Macros'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.cyanAccent),
            tooltip: 'Plantillas de DJ',
            onPressed: () => _showPresetsSheet(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Exportar Macros',
            onPressed: () async {
              var path = await ref
                  .read(macroListProvider.notifier)
                  .exportMacros();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 2),
                    content: Text(
                      path != null
                          ? 'Exportado: $path'
                          : 'No hay macros para exportar',
                    ),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Importar Macros',
            onPressed: () async {
              var count = await ref
                  .read(macroListProvider.notifier)
                  .importMacros();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(duration: const Duration(seconds: 2), content: Text('$count macros importadas')),
                );
              }
            },
          ),
        ],
      ),
      body: macrosAsync.when(
        data: (macros) {
          if (macros.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.speed, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay macros creadas',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
                      foregroundColor: Colors.cyanAccent,
                    ),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Usar Plantillas de DJ'),
                    onPressed: () => _showPresetsSheet(context, ref),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: macros.length,
            itemBuilder: (context, index) {
              var macro = macros[index];
              return _MacroTile(macro: macro);
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
        error: (e, st) => Center(
          child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MacroBuilderScreen()),
          );
        },
      ),
    );
  }

  void _showPresetsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E222D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.auto_awesome, color: Colors.cyanAccent),
                  SizedBox(width: 10),
                  Text(
                    'Plantillas de DJ (Macros Rápidas)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Selecciona una plantilla para crear una macro pre-configurada que puedes personalizar:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _PresetItem(
                      title: '⚡ Transición & Ir a Página',
                      subtitle:
                          'Dispara sonido de cortina/grito y navega a la primera página (ajusta el destino en el editor).',
                      icon: Icons.swap_horizontal_circle_outlined,
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MacroBuilderScreen(
                              initialName: 'Transición & Ir a Página',
                              initialActions: [
                                MacroAction(
                                  type: MacroActionType.triggerPad,
                                  params: {'padId': 'pad_0_0'},
                                ),
                                MacroAction(
                                  type: MacroActionType.delay,
                                  params: {'milliseconds': 300},
                                ),
                                MacroAction(
                                  type: MacroActionType.changePage,
                                  params: {'pageIndex': 0},
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    _PresetItem(
                      title: '🔥 Drop & Control de Volumen',
                      subtitle:
                          'Regula levemente el máster al lanzar un remate o voz.',
                      icon: Icons.volume_down_outlined,
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MacroBuilderScreen(
                              initialName: 'Drop & Combo de Volumen',
                              initialActions: [
                                MacroAction(
                                  type: MacroActionType.setVolume,
                                  params: {'volume': 0.75},
                                ),
                                MacroAction(
                                  type: MacroActionType.triggerPad,
                                  params: {'padId': 'pad_0_0'},
                                ),
                                MacroAction(
                                  type: MacroActionType.delay,
                                  params: {'milliseconds': 500},
                                ),
                                MacroAction(
                                  type: MacroActionType.setVolume,
                                  params: {'volume': 1.0},
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    _PresetItem(
                      title: '🥁 Doble Sound FX (Secuencia)',
                      subtitle:
                          'Dispara 2 sonidos en cadena con pausa intermedia.',
                      icon: Icons.dynamic_feed_outlined,
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MacroBuilderScreen(
                              initialName: 'Doble Sound FX',
                              initialActions: [
                                MacroAction(
                                  type: MacroActionType.triggerPad,
                                  params: {'padId': 'pad_0_0'},
                                ),
                                MacroAction(
                                  type: MacroActionType.delay,
                                  params: {'milliseconds': 250},
                                ),
                                MacroAction(
                                  type: MacroActionType.triggerPad,
                                  params: {'padId': 'pad_0_1'},
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    _PresetItem(
                      title: '↩️ Regreso al Menú Principal',
                      subtitle:
                          'Vuelve a la página principal (raíz del workspace) y restablece el Limiter.',
                      icon: Icons.home_outlined,
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MacroBuilderScreen(
                              initialName: 'Regresar al Menú Principal',
                              initialActions: [
                                MacroAction(
                                  type: MacroActionType.changePage,
                                  params: {'pageIndex': 0},
                                ),
                                MacroAction(
                                  type: MacroActionType.setLimiter,
                                  params: {'value': 1.0},
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PresetItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _PresetItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFF2B313E),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: ListTile(
            leading: Icon(icon, color: Colors.cyanAccent),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white38,
              size: 14,
            ),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

class _MacroTile extends ConsumerWidget {
  final MacroEntity macro;
  const _MacroTile({required this.macro});

  List<String> _actionLabels(WidgetRef ref) {
    return [
      for (final a in macro.actions) _actionLabel(ref, a),
    ];
  }

  String _actionLabel(WidgetRef ref, MacroAction a) {
    switch (a.type) {
      case MacroActionType.changePage:
        return _changePageLabel(ref, a);
      case MacroActionType.changeWorkspace:
        return 'Cambiar Workspace';
      case MacroActionType.setVolume:
        return 'Volumen';
      case MacroActionType.triggerPad:
        return 'Disparar Pad';
      case MacroActionType.sendMidiNote:
        return 'Nota MIDI';
      case MacroActionType.setLimiter:
        return 'Limiter';
      case MacroActionType.delay:
        return 'Esperar ${a.params['milliseconds'] ?? 100}ms';
    }
  }

  String _changePageLabel(WidgetRef ref, MacroAction a) {
    final wsId = (a.params['workspaceId'] ??
        a.params['targetWorkspaceId']) as num?;
    final pg = (a.params['pageIndex'] ??
        a.params['targetPageIndex']) as num?;
    if (pg == null) return 'Ir a Página 1';
    if (wsId != null) {
      final display = ref
          .watch(macroDestinationDisplayProvider((
            workspaceId: wsId.toInt(),
            pageIndex: pg.toInt(),
            padId: null,
          )))
          .value;
      if (display != null) return display;
    }
    final p = pg.toInt();
    return p >= 1000 ? 'Ir a Carpeta' : 'Ir a Página ${p + 1}';
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) async {
    var confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Eliminar Macro',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Eliminar "${macro.name}"?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(macroListProvider.notifier).delete(macro.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: ListTile(
        leading: const Icon(Icons.speed, color: Colors.blueAccent),
        title: Text(
          macro.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          macro.actions.isEmpty
              ? 'Sin acciones configuradas'
              : _actionLabels(ref).join(' ➔ '),
          style: const TextStyle(color: Colors.cyanAccent, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white54),
          color: const Color(0xFF1E222D),
          onSelected: (value) {
            switch (value) {
              case 'play':
                ref.read(macroExecutorProvider).execute(macro);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(duration: const Duration(seconds: 2), content: Text('Macro "${macro.name}" ejecutada')),
                );
                break;
              case 'midi':
                ref.read(midiLearnModeProvider.notifier).state = true;
                ref
                    .read(midiLearnActionProvider.notifier)
                    .state = MidiMappingEntity(
                  id: 'macro_${macro.id}',
                  noteOrCC: 0,
                  statusByte: 0,
                  actionType: MidiActionType.executeMacro,
                  actionValue: macro.id.toString(),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Toca un botón en tu controlador MIDI para asignar la Macro "${macro.name}"...',
                    ),
                    duration: const Duration(seconds: 4),
                  ),
                );
                break;
              case 'edit':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MacroBuilderScreen(existingMacro: macro),
                  ),
                );
                break;
              case 'delete':
                _confirmDelete(context, ref);
                break;
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'play',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, color: Colors.greenAccent, size: 18),
                  SizedBox(width: 8),
                  Text('Ejecutar', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'midi',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.piano, color: Colors.purpleAccent, size: 18),
                  SizedBox(width: 8),
                  Text('Asignar MIDI', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Text('Editar', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete, color: Colors.redAccent, size: 18),
                  SizedBox(width: 8),
                  Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
