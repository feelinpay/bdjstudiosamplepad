import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../workspace/data/models/workspace_model.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';

/// Destino elegido por el selector: un workspace, una página y (opcionalmente)
/// un pad para disparar.
class MacroDestination {
  final int workspaceId;
  final int pageIndex;
  final String? padId;

  const MacroDestination({
    required this.workspaceId,
    required this.pageIndex,
    this.padId,
  });
}

class MacroFolderLink {
  final String label;
  final int targetPageIndex;
  const MacroFolderLink({required this.label, required this.targetPageIndex});
}

class MacroPadInfo {
  final String id;
  final String label;
  const MacroPadInfo({required this.id, required this.label});
}

/// Snapshot de un workspace para navegar como explorador de archivos:
/// páginas raíz (bancos), subcarpetas (pads de carpeta con target) y los
/// pads disparables de cada página.
class MacroWorkspaceStructure {
  final int workspaceId;
  final String name;

  /// pageIndex -> nombre legible de cada página raíz (banco).
  final Map<int, String> rootPageNames;

  /// pageIndex de la página origen -> enlaces a subcarpetas (folder pads).
  final Map<int, List<MacroFolderLink>> foldersBySourcePage;

  /// pageIndex -> pads disparables (excluye pads de carpeta).
  final Map<int, List<MacroPadInfo>> padsByPage;

  const MacroWorkspaceStructure({
    required this.workspaceId,
    required this.name,
    required this.rootPageNames,
    required this.foldersBySourcePage,
    required this.padsByPage,
  });

  static Future<MacroWorkspaceStructure> load(WorkspaceModel ws) async {
    await ws.pages.load();
    final rootPageNames = <int, String>{};
    final foldersBySourcePage = <int, List<MacroFolderLink>>{};
    final padsByPage = <int, List<MacroPadInfo>>{};

    for (final page in ws.pages) {
      await page.pads.load();
      final pads = page.pads.toList()
        ..sort((a, b) => a.padId.compareTo(b.padId));

      if (page.parentPageId == null) {
        rootPageNames[page.pageIndex] =
            (page.name != null && page.name!.isNotEmpty)
            ? page.name!
            : 'Página ${page.pageIndex + 1}';
      }

      final folderLinks = <MacroFolderLink>[
        for (final m in pads)
          if (m.targetPageIndex != null)
            MacroFolderLink(
              label: m.label,
              targetPageIndex: m.targetPageIndex!,
            ),
      ];
      if (folderLinks.isNotEmpty) {
        foldersBySourcePage[page.pageIndex] = folderLinks;
      }

      final regular = <MacroPadInfo>[
        for (final m in pads)
          if (m.padTypeIndex != 1)
            MacroPadInfo(
              id: m.id.toString(),
              label: m.label.isEmpty ? 'Pad ${m.padId + 1}' : m.label,
            ),
      ];
      if (regular.isNotEmpty) {
        padsByPage[page.pageIndex] = regular;
      }
    }

    return MacroWorkspaceStructure(
      workspaceId: ws.id,
      name: ws.name,
      rootPageNames: rootPageNames,
      foldersBySourcePage: foldersBySourcePage,
      padsByPage: padsByPage,
    );
  }

  List<int> rootPagesSorted() {
    final keys = rootPageNames.keys.toList()..sort();
    return keys;
  }

  bool hasFoldersOn(int pageIndex) =>
      (foldersBySourcePage[pageIndex]?.isNotEmpty ?? false);

  List<MacroFolderLink> foldersOn(int pageIndex) =>
      foldersBySourcePage[pageIndex] ?? const [];

  List<MacroPadInfo> padsOn(int pageIndex) => padsByPage[pageIndex] ?? const [];

  /// Ruta legible hasta la página [pageIndex]: ['Página 1', 'Carpeta X', ...]
  /// (sin incluir el nombre del workspace).
  List<String> pathNamesFor(int pageIndex, [Set<int>? visited]) {
    visited ??= <int>{};
    if (visited.contains(pageIndex)) return ['Página ${pageIndex + 1}'];
    visited.add(pageIndex);
    if (pageIndex < 1000) {
      return [rootPageNames[pageIndex] ?? 'Página ${pageIndex + 1}'];
    }
    for (final entry in foldersBySourcePage.entries) {
      for (final link in entry.value) {
        if (link.targetPageIndex == pageIndex) {
          final label =
              link.label.trim().isEmpty ? 'Carpeta' : link.label.trim();
          return [...pathNamesFor(entry.key, Set<int>.from(visited)), label];
        }
      }
    }
    return ['Página ${pageIndex + 1}'];
  }

  /// Cadena de pageIndexes desde la raíz hasta [pageIndex], incluyendo el
  /// banco raíz que contiene las carpetas. Usado para pre-seleccionar.
  List<int> pathIndexesFor(int pageIndex, [Set<int>? visited]) {
    visited ??= <int>{};
    if (visited.contains(pageIndex)) return [pageIndex];
    visited.add(pageIndex);
    if (pageIndex < 1000) return [pageIndex];
    for (final entry in foldersBySourcePage.entries) {
      for (final link in entry.value) {
        if (link.targetPageIndex == pageIndex) {
          return [
            ...pathIndexesFor(entry.key, Set<int>.from(visited)),
            pageIndex,
          ];
        }
      }
    }
    return [pageIndex];
  }
}

/// Estructura (páginas, carpetas y pads) de un workspace.
final macroWorkspaceStructureProvider =
    FutureProvider.family<MacroWorkspaceStructure?, int>((
      ref,
      workspaceId,
    ) async {
      final repo = ref.watch(workspaceRepositoryProvider);
      final ws = await repo.getWorkspace(workspaceId);
      if (ws == null) return null;
      return MacroWorkspaceStructure.load(ws);
    });

/// Texto legible de un destino para mostrarlo en las tarjetas del builder:
/// "Mi Set › Página 1" o "Mi Set › Página 1 › Batería › Kick".
final macroDestinationDisplayProvider = FutureProvider.family<
    String,
    ({int workspaceId, int pageIndex, String? padId})>((ref, args) async {
  final structure = await ref
      .watch(macroWorkspaceStructureProvider(args.workspaceId).future);
  if (structure == null) return 'Destino no encontrado';
  final parts = structure.pathNamesFor(args.pageIndex);
  var text = [structure.name, ...parts].join(' › ');
  final padId = args.padId;
  if (padId != null && padId.isNotEmpty) {
    final matches = structure
        .padsOn(args.pageIndex)
        .where((p) => p.id == padId)
        .toList();
    final padLabel = matches.isNotEmpty ? matches.first.label : 'Pad';
    text = '$text › $padLabel';
  }
  return text;
});

/// Abre el selector tipo explorador. Devuelve el destino elegido o null si
/// el usuario cancela.
Future<MacroDestination?> showMacroDestinationPicker({
  required BuildContext context,
  required WidgetRef ref,
  required List<({int id, String name})> workspaces,
  required int workspaceId,
  required int pageIndex,
  bool pickPad = false,
  String? padId,
  String title = 'Elegir destino',
}) {
  return showDialog<MacroDestination>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => _DestinationPickerDialog(
      workspaces: workspaces,
      initialWorkspaceId: workspaceId,
      initialPageIndex: pageIndex,
      initialPadId: padId,
      pickPad: pickPad,
      title: title,
    ),
  );
}

class _DestinationPickerDialog extends ConsumerStatefulWidget {
  final List<({int id, String name})> workspaces;
  final int initialWorkspaceId;
  final int initialPageIndex;
  final String? initialPadId;
  final bool pickPad;
  final String title;

  const _DestinationPickerDialog({
    required this.workspaces,
    required this.initialWorkspaceId,
    required this.initialPageIndex,
    required this.initialPadId,
    required this.pickPad,
    required this.title,
  });

  @override
  ConsumerState<_DestinationPickerDialog> createState() =>
      _DestinationPickerDialogState();
}

class _DestinationPickerDialogState
    extends ConsumerState<_DestinationPickerDialog> {
  late int _workspaceId;
  List<({int pageIndex, String name})> _path = [];
  int? _padPage;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _workspaceId = widget.workspaces.any((w) => w.id == widget.initialWorkspaceId)
        ? widget.initialWorkspaceId
        : (widget.workspaces.isNotEmpty ? widget.workspaces.first.id : 0);
  }

  void _selectWorkspace(int id) {
    setState(() {
      _workspaceId = id;
      _path = [];
      _padPage = null;
      _seeded = false;
    });
  }

  void _enter(int pageIndex, String name) {
    setState(() => _path = [..._path, (pageIndex: pageIndex, name: name)]);
  }

  void _jumpTo(int depth) {
    setState(() {
      _path = _path.sublist(0, depth);
      _padPage = null;
    });
  }

  void _seedPath(MacroWorkspaceStructure structure) {
    if (_seeded) return;
    _seeded = true;
    final chain = structure.pathIndexesFor(widget.initialPageIndex);
    if (chain.length <= 1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _path = [
          for (final idx in chain)
            (pageIndex: idx, name: structure.pathNamesFor(idx).last),
        ];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final structureAsync =
        ref.watch(macroWorkspaceStructureProvider(_workspaceId));

    return Dialog(
      backgroundColor: const Color(0xFF141822),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: structureAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No se pudo cargar el workspace',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ),
          data: (structure) {
            if (structure == null) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Workspace no encontrado',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              );
            }
            _seedPath(structure);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(),
                if (widget.workspaces.length > 1) _workspaceSelector(),
                _breadcrumb(structure),
                const Divider(height: 1, color: Colors.white12),
                Expanded(
                  child: _padPage != null
                      ? _padList(structure, _padPage!)
                      : _dirList(structure),
                ),
                _footer(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _workspaceSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          const Text(
            'Workspace: ',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Expanded(
            child: DropdownButton<int>(
              isExpanded: true,
              value: _workspaceId,
              dropdownColor: const Color(0xFF1C2230),
              style: const TextStyle(color: Colors.white),
              items: [
                for (final w in widget.workspaces)
                  DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
              onChanged: (v) {
                if (v != null) _selectWorkspace(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _breadcrumb(MacroWorkspaceStructure structure) {
    final names = [
      structure.name,
      for (final p in _path) p.name,
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: names.length,
        separatorBuilder: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Icon(Icons.chevron_right, size: 15, color: Colors.white38),
        ),
        itemBuilder: (context, i) {
          final isLast = i == names.length - 1;
          return GestureDetector(
            onTap: () => _jumpTo(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isLast
                    ? Colors.cyanAccent.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isLast ? Colors.cyanAccent : Colors.white12,
                  width: 0.8,
                ),
              ),
              child: Text(
                names[i],
                style: TextStyle(
                  color: isLast ? Colors.cyanAccent : Colors.white54,
                  fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dirList(MacroWorkspaceStructure structure) {
    final isRoot = _path.isEmpty;
    final entries = <Widget>[];

    if (isRoot) {
      for (final idx in structure.rootPagesSorted()) {
        final name = structure.rootPageNames[idx]!;
        final hasFolders = structure.hasFoldersOn(idx);
        entries.add(
          _entryTile(
            icon: Icons.audiotrack,
            title: name,
            subtitle: hasFolders ? 'Banco con carpetas' : 'Banco de pads',
            onTap: () {
              if (!widget.pickPad && !hasFolders) {
                Navigator.pop(
                  context,
                  MacroDestination(
                    workspaceId: _workspaceId,
                    pageIndex: idx,
                  ),
                );
              } else {
                _enter(idx, name);
              }
            },
          ),
        );
      }
    } else {
      final current = _path.last;
      entries.add(
        _entryTile(
          icon: Icons.audiotrack,
          title: current.name,
          subtitle: 'Banco de esta carpeta — toca para elegir',
          accent: true,
          onTap: () {
            if (!widget.pickPad) {
              Navigator.pop(
                context,
                MacroDestination(
                  workspaceId: _workspaceId,
                  pageIndex: current.pageIndex,
                ),
              );
            } else {
              setState(() => _padPage = current.pageIndex);
            }
          },
        ),
      );
      for (final link in structure.foldersOn(current.pageIndex)) {
        final label = link.label.trim().isEmpty ? 'Carpeta' : link.label.trim();
        entries.add(
          _entryTile(
            icon: Icons.folder_rounded,
            title: label,
            subtitle: 'Abrir carpeta',
            onTap: () => _enter(link.targetPageIndex, label),
          ),
        );
      }
    }

    if (entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No hay elementos en esta carpeta',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }
    return ListView(padding: const EdgeInsets.all(16), children: entries);
  }

  Widget _padList(MacroWorkspaceStructure structure, int pageIndex) {
    final pads = structure.padsOn(pageIndex);
    if (pads.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: Colors.white38, size: 40),
            const SizedBox(height: 8),
            const Text(
              'Este banco no tiene pads',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _padPage = null),
              child: const Text('Volver'),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final pad in pads)
          _entryTile(
            icon: Icons.music_note,
            title: pad.label,
            subtitle: 'Disparar este pad',
            onTap: () {
              Navigator.pop(
                context,
                MacroDestination(
                  workspaceId: _workspaceId,
                  pageIndex: pageIndex,
                  padId: pad.id,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _entryTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool accent = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
                Icon(
                  icon,
                  color: accent ? Colors.cyanAccent : Colors.blueAccent,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: accent ? Colors.cyanAccent : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}
