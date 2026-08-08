import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/macro_providers.dart';
import '../widgets/destination_picker.dart';
import '../../domain/entities/macro_entity.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';

class MacroBuilderScreen extends ConsumerStatefulWidget {
  final MacroEntity? existingMacro;
  final String? initialName;
  final List<MacroAction>? initialActions;

  const MacroBuilderScreen({
    super.key,
    this.existingMacro,
    this.initialName,
    this.initialActions,
  });

  @override
  ConsumerState<MacroBuilderScreen> createState() => _MacroBuilderScreenState();
}

class _MacroBuilderScreenState extends ConsumerState<MacroBuilderScreen> {
  late TextEditingController _nameController;
  late List<MacroAction> _actions;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingMacro?.name ?? widget.initialName ?? '',
    );
    _actions = List.from(
      widget.existingMacro?.actions ?? widget.initialActions ?? [],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addAction(MacroActionType type) {
    var defaultParams = switch (type) {
      MacroActionType.changeWorkspace => <String, dynamic>{'workspaceId': 0},
      MacroActionType.changePage => <String, dynamic>{'pageIndex': 0},
      MacroActionType.setVolume => <String, dynamic>{'volume': 0.8},
      MacroActionType.triggerPad => <String, dynamic>{'padId': ''},
      MacroActionType.sendMidiNote => <String, dynamic>{
        'note': 60,
        'velocity': 127,
        'channel': 0,
      },
      MacroActionType.setLimiter => <String, dynamic>{'value': 0.5},
      MacroActionType.delay => <String, dynamic>{'milliseconds': 100},
    };
    setState(() {
      _actions.add(MacroAction(type: type, params: defaultParams));
    });
  }

  void _removeAction(int index) {
    setState(() => _actions.removeAt(index));
  }

  void _updateActionParam(int index, String key, dynamic value) {
    setState(() {
      var old = _actions[index];
      var newParams = Map<String, dynamic>.from(old.params)..[key] = value;
      _actions[index] = MacroAction(type: old.type, params: newParams);
    });
  }

  Future<void> _save() async {
    var name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(duration: const Duration(seconds: 2), content: Text('Escribe un nombre para la macro')),
      );
      return;
    }
    if (_actions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(duration: const Duration(seconds: 2), content: Text('Agrega al menos una acción')),
      );
      return;
    }

    if (widget.existingMacro != null) {
      var updated = widget.existingMacro!.copyWith(
        name: name,
        actions: _actions,
      );
      await ref.read(macroListProvider.notifier).updateMacro(updated);
    } else {
      await ref.read(macroListProvider.notifier).create(name, _actions);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.existingMacro != null ? 'Editar Macro' : 'Nueva Macro',
        ),
        backgroundColor: Colors.grey[900],
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'GUARDAR',
              style: TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Nombre de la Macro',
              labelStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Acciones',
            style: TextStyle(
              color: Colors.blueAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (_actions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sin acciones. Toca + para agregar.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ...List.generate(_actions.length, (i) => _buildActionCard(i)),
          const SizedBox(height: 16),
          _buildAddActionMenu(),
        ],
      ),
    );
  }

  Widget _buildActionCard(int index) {
    var action = _actions[index];
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _iconForType(action.type),
                  color: Colors.blueAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _labelForType(action.type),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  onPressed: () => _removeAction(index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildParamEditor(index, action),
          ],
        ),
      ),
    );
  }

  Widget _buildParamEditor(int index, MacroAction action) {
    switch (action.type) {
      case MacroActionType.setVolume:
        var val = (action.params['volume'] as num?)?.toDouble() ?? 0.8;
        return Row(
          children: [
            const Text('Volumen: ', style: TextStyle(color: Colors.grey)),
            Expanded(
              child: Slider(
                value: val,
                onChanged: (v) => _updateActionParam(index, 'volume', v),
              ),
            ),
            Text(
              '${(val * 100).round()}%',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        );
      case MacroActionType.setLimiter:
        var val = (action.params['value'] as num?)?.toDouble() ?? 0.5;
        return Row(
          children: [
            const Text('Limiter: ', style: TextStyle(color: Colors.grey)),
            Expanded(
              child: Slider(
                value: val,
                onChanged: (v) => _updateActionParam(index, 'value', v),
              ),
            ),
            Text(
              '${(val * 100).round()}%',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        );
      case MacroActionType.delay:
        var val = action.params['milliseconds'] as int? ?? 100;
        return Row(
          children: [
            const Text('Ms: ', style: TextStyle(color: Colors.grey)),
            SizedBox(
              width: 80,
              child: TextField(
                controller: TextEditingController(text: val.toString()),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(isDense: true),
                onChanged: (v) {
                  var parsed = int.tryParse(v);
                  if (parsed != null)
                    _updateActionParam(index, 'milliseconds', parsed);
                },
              ),
            ),
          ],
        );
      case MacroActionType.changeWorkspace:
        return _workspaceDropdown(index, action);
      case MacroActionType.changePage:
        var wsId =
            ((action.params['workspaceId'] ??
                action.params['targetWorkspaceId']) as num?)
                ?.toInt() ??
            (ref.watch(currentWorkspaceIdProvider) ?? 0);
        var pageIndex =
            ((action.params['pageIndex'] ??
                action.params['targetPageIndex']) as num?)
                ?.toInt() ??
            0;
        final display = ref
            .watch(macroDestinationDisplayProvider((
              workspaceId: wsId,
              pageIndex: pageIndex,
              padId: null,
            )))
            .when(
              data: (v) => v,
              loading: () => 'Cargando...',
              error: (_, __) => 'Destino no disponible',
            );
        return _destinationTile(
          icon: Icons.near_me,
          title: 'Ir a (destino exacto)',
          value: display,
          onTap: () => _pickDestination(
            index,
            wsId,
            pageIndex,
            pickPad: false,
          ),
        );
      case MacroActionType.triggerPad:
        var wsId =
            ((action.params['targetWorkspaceId'] ??
                action.params['workspaceId']) as num?)
                ?.toInt() ??
            (ref.watch(currentWorkspaceIdProvider) ?? 0);
        var pageIndex =
            ((action.params['targetPageIndex'] ??
                action.params['pageIndex']) as num?)
                ?.toInt() ??
            (ref.watch(currentPageIndexProvider) ?? 0);
        var padId = (action.params['targetPadId'] ??
                action.params['padId']) as String? ??
            '';
        final display = ref
            .watch(macroDestinationDisplayProvider((
              workspaceId: wsId,
              pageIndex: pageIndex,
              padId: padId.isNotEmpty ? padId : null,
            )))
            .when(
              data: (v) => v,
              loading: () => 'Cargando...',
              error: (_, __) => 'Destino no disponible',
            );
        return _destinationTile(
          icon: Icons.touch_app,
          title: 'Pad objetivo (página y pad)',
          value: display,
          onTap: () => _pickDestination(
            index,
            wsId,
            pageIndex,
            pickPad: true,
            padId: padId.isNotEmpty ? padId : null,
          ),
        );
      case MacroActionType.sendMidiNote:
        var note = action.params['note'] as int? ?? 60;
        var vel = action.params['velocity'] as int? ?? 127;
        return Row(
          children: [
            const Text('Note: ', style: TextStyle(color: Colors.grey)),
            SizedBox(
              width: 60,
              child: TextField(
                controller: TextEditingController(text: note.toString()),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(isDense: true),
                onChanged: (v) {
                  var parsed = int.tryParse(v);
                  if (parsed != null) _updateActionParam(index, 'note', parsed);
                },
              ),
            ),
            const SizedBox(width: 12),
            const Text('Vel: ', style: TextStyle(color: Colors.grey)),
            SizedBox(
              width: 60,
              child: TextField(
                controller: TextEditingController(text: vel.toString()),
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(isDense: true),
                onChanged: (v) {
                  var parsed = int.tryParse(v);
                  if (parsed != null)
                    _updateActionParam(index, 'velocity', parsed);
                },
              ),
            ),
          ],
        );
    }
  }

  Widget _workspaceDropdown(int index, MacroAction action) {
    var wsAsync = ref.watch(workspaceListProvider);
    var currentId = action.params['workspaceId'] as int? ?? 0;

    return wsAsync.when(
      data: (wsList) {
        if (wsList.isEmpty) {
          return const Text(
            'No hay workspaces',
            style: TextStyle(color: Colors.white54),
          );
        }

        var seen = <int>{};
        var items = <DropdownMenuItem<int>>[];
        for (var w in wsList) {
          if (seen.add(w.id)) {
            items.add(DropdownMenuItem(value: w.id, child: Text(w.name)));
          }
        }

        var validValue = seen.contains(currentId)
            ? currentId
            : items.first.value!;

        return Row(
          children: [
            const Text('Workspace: ', style: TextStyle(color: Colors.grey)),
            Flexible(
              child: DropdownButton<int>(
                isExpanded: true,
                dropdownColor: Colors.grey[800],
                value: validValue,
                style: const TextStyle(color: Colors.white),
                items: items,
                onChanged: (v) {
                  if (v != null) _updateActionParam(index, 'workspaceId', v);
                },
              ),
            ),
          ],
        );
      },
      loading: () =>
          const Text('Cargando...', style: TextStyle(color: Colors.grey)),
      error: (_, _) => const Text('Error', style: TextStyle(color: Colors.red)),
    );
  }

  Future<void> _pickDestination(
    int index,
    int wsId,
    int pageIndex, {
    required bool pickPad,
    String? padId,
  }) async {
    final workspaces = ref.read(workspaceListProvider).value ?? [];
    if (workspaces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('Cargando workspaces...'),
        ),
      );
      return;
    }
    ref.invalidate(macroWorkspaceStructureProvider(wsId));
    final result = await showMacroDestinationPicker(
      context: context,
      ref: ref,
      workspaces: [
        for (final w in workspaces) (id: w.id, name: w.name),
      ],
      workspaceId: wsId,
      pageIndex: pageIndex,
      pickPad: pickPad,
      padId: padId,
      title: pickPad
          ? 'Disparar Pad — Elegir destino'
          : 'Cambiar Página — Elegir destino',
    );
    if (result == null || !mounted) return;

    _updateActionParam(index, 'workspaceId', result.workspaceId);
    _updateActionParam(index, 'targetWorkspaceId', result.workspaceId);
    _updateActionParam(index, 'pageIndex', result.pageIndex);
    _updateActionParam(index, 'targetPageIndex', result.pageIndex);
    if (pickPad && result.padId != null) {
      _updateActionParam(index, 'targetPadId', result.padId);
      _updateActionParam(index, 'padId', result.padId);
    }
    ref.invalidate(macroDestinationDisplayProvider((
      workspaceId: result.workspaceId,
      pageIndex: result.pageIndex,
      padId: result.padId,
    )));
  }

  Widget _destinationTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: const Color(0xFF1C2230),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: Colors.blueAccent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.edit_location_alt,
                  color: Colors.white38,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddActionMenu() {
    return PopupMenuButton<MacroActionType>(
      color: Colors.grey[900],
      icon: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_circle, color: Colors.blueAccent),
          SizedBox(width: 4),
          Text('Agregar Acción', style: TextStyle(color: Colors.blueAccent)),
        ],
      ),
      onSelected: _addAction,
      itemBuilder: (context) => [
        for (final type in MacroActionType.values)
          PopupMenuItem(
            value: type,
            child: Row(
              children: [
                Icon(_iconForType(type), color: Colors.blueAccent, size: 18),
                const SizedBox(width: 8),
                Text(
                  _labelForType(type),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
      ],
    );
  }

  IconData _iconForType(MacroActionType type) => switch (type) {
    MacroActionType.changeWorkspace => Icons.swap_horiz,
    MacroActionType.changePage => Icons.tab,
    MacroActionType.setVolume => Icons.volume_up,
    MacroActionType.triggerPad => Icons.touch_app,
    MacroActionType.sendMidiNote => Icons.piano,
    MacroActionType.setLimiter => Icons.speed,
    MacroActionType.delay => Icons.timer,
  };

  String _labelForType(MacroActionType type) => switch (type) {
    MacroActionType.changeWorkspace => 'Cambiar Workspace',
    MacroActionType.changePage => 'Cambiar Página',
    MacroActionType.setVolume => 'Ajustar Volumen',
    MacroActionType.triggerPad => 'Disparar Pad',
    MacroActionType.sendMidiNote => 'Enviar Nota MIDI',
    MacroActionType.setLimiter => 'Ajustar Limiter',
    MacroActionType.delay => 'Esperar (Delay)',
  };
}
