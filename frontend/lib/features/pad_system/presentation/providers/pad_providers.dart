import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../domain/entities/pad_entity.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/audio/trigger_mode.dart';
import '../../../../core/audio/pad_trigger_resolver.dart';
import '../../../../core/services/local_audio_storage_service.dart';
import '../../data/models/pad_model.dart';
import '../../data/services/folder_transfer_service.dart';
import '../../../macros/domain/entities/macro_entity.dart';
import '../../../workspace/data/models/page_model.dart';
import '../../../workspace/data/models/workspace_model.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../../../midi/presentation/providers/midi_providers.dart';
import '../../../midi/domain/entities/midi_mapping_entity.dart';
import '../../../midi/data/models/midi_mapping_model.dart';
import '../../../macros/presentation/providers/macro_providers.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/utils/audio_log.dart';
import '../../../../core/theme/app_colors.dart';

/// Nodo jerárquico para representación de carpetas y subcarpetas de audios.
class AudioFolderNode {
  final String name;
  final List<File> audioFiles;
  final List<AudioFolderNode> subfolders;

  AudioFolderNode({
    required this.name,
    required this.audioFiles,
    required this.subfolders,
  });

  int get totalAudioCount {
    int count = audioFiles.length;
    for (var sub in subfolders) {
      count += sub.totalAudioCount;
    }
    return count;
  }
}

class PreparedAudioFile {
  final File originalFile;
  final String localPath;
  final String name;

  PreparedAudioFile({
    required this.originalFile,
    required this.localPath,
    required this.name,
  });
}

class PreparedFolderNode {
  final String name;
  final List<PreparedAudioFile> audioFiles;
  final List<PreparedFolderNode> subfolders;

  PreparedFolderNode({
    required this.name,
    required this.audioFiles,
    required this.subfolders,
  });
}

/// Pila de navegación de carpetas: guarda el pageIndex desde el que se
/// entró a cada carpeta, para poder volver con el botón atrás.
final folderBackStackProvider = StateProvider<List<int>>((ref) => []);

/// Pad seleccionado para intercambiar posicion (modo Mover en edicion).
final padMoveSourceProvider = StateProvider<String?>((ref) => null);

/// Intensidad (0.2-1.0) del ultimo golpe por pad, para el brillo por velocity.
final padVelocityProvider = StateProvider<Map<String, double>>((ref) => {});

/// Selección múltiple de pads en modo edición
final selectedPadsProvider = StateProvider<Set<String>>((ref) => {});

/// Previene duplicación de pila por doble clic rápido y aplica estricta idempotencia sin desincronizar caché.
class SafeFolderNavigator {
  /// Navega de forma segura a una carpeta o página evitando duplicados en la pila de navegación.
  static void openFolder(
    dynamic ref,
    int currentPageIndex,
    int targetPageIndex,
  ) {
    final current = ref.read(currentPageIndexProvider);
    if (current == targetPageIndex) return; // Idempotent check

    final stack = List<int>.from(ref.read(folderBackStackProvider));
    if (stack.contains(targetPageIndex)) {
      final idx = stack.indexOf(targetPageIndex);
      final newStack = stack.sublist(0, idx);
      if (!listEquals(stack, newStack)) {
        ref.read(folderBackStackProvider.notifier).state = newStack;
      }
    } else {
      if (stack.isEmpty || stack.last != currentPageIndex) {
        stack.add(currentPageIndex);
        ref.read(folderBackStackProvider.notifier).state = stack;
      }
    }
    ref.read(currentPageIndexProvider.notifier).state = targetPageIndex;
  }

  /// Retrocede una carpeta o regresa a la raíz sin romper la pila.
  static void goBack(dynamic ref) {
    final stack = List<int>.from(ref.read(folderBackStackProvider));
    final current = ref.read(currentPageIndexProvider);
    if (stack.isNotEmpty) {
      final previous = stack.removeLast();
      ref.read(folderBackStackProvider.notifier).state = stack;
      if (current != previous) {
        ref.read(currentPageIndexProvider.notifier).state = previous;
      }
    } else {
      if (current == 0) return; // Idempotent check: ya en raíz
      ref.read(folderBackStackProvider.notifier).state = <int>[];
      ref.read(currentPageIndexProvider.notifier).state = 0;
    }
  }

  /// Ir directo a la raíz del workspace (Principal)
  static void goToRoot(dynamic ref) {
    final current = ref.read(currentPageIndexProvider);
    final stack = ref.read(folderBackStackProvider);
    if (current == 0 && stack.isEmpty) return; // Idempotency check
    ref.read(folderBackStackProvider.notifier).state = <int>[];
    ref.read(currentPageIndexProvider.notifier).state = 0;
  }

  /// Navegar a una posición específica de la barra breadcrumb
  static void navigateToBreadcrumbIndex(
    dynamic ref,
    int targetPageIndex,
    int pathPosition,
  ) {
    final current = ref.read(currentPageIndexProvider);
    if (current == targetPageIndex) return; // Idempotency check
    if (pathPosition == 0 || targetPageIndex == 0) {
      goToRoot(ref);
      return;
    }
    final stack = List<int>.from(ref.read(folderBackStackProvider));
    final targetIdxInStack = stack.indexOf(targetPageIndex);
    if (targetIdxInStack != -1) {
      ref.read(folderBackStackProvider.notifier).state = stack.sublist(
        0,
        targetIdxInStack,
      );
    } else {
      if (pathPosition <= stack.length) {
        ref.read(folderBackStackProvider.notifier).state = stack.sublist(
          0,
          pathPosition,
        );
      }
    }
    ref.read(currentPageIndexProvider.notifier).state = targetPageIndex;
  }
}

/// Notifier principal que gestiona los pads de una página específica
/// (raíz o carpeta oculta). Cada pageIndex tiene su propia instancia.
class PadPageNotifier extends AsyncNotifier<List<PadEntity>> {
  PadPageNotifier(this.arg);

  final int arg;
  StreamSubscription? _sub;
  final Map<String, PadState> _runtimeStates = {};

  @override
  Future<List<PadEntity>> build() async {
    final prevEntities = state.value ?? [];
    for (final e in prevEntities) {
      if (e.state != PadState.idle) {
        _runtimeStates[e.id] = e.state;
      }
    }

    final isar = await ref.read(isarProvider.future);
    final workspace = await ref.watch(currentWorkspaceProvider.future);
    if (workspace == null) return [];

    // Consulta indexada ultra-rápida en Isar DB (1-2ms)
    final page = await isar.pageModels
        .filter()
        .workspace((q) => q.idEqualTo(workspace.id))
        .and()
        .pageIndexEqualTo(arg)
        .findFirst();

    if (page == null) return [];

    final padModels = await isar.padModels
        .filter()
        .page((q) => q.idEqualTo(page.id))
        .sortByPadId()
        .findAll();

    var entities = padModels.map(_mapToEntity).toList();

    for (var e in entities) {
      var savedState = _runtimeStates.remove(e.id);
      if (savedState != null && savedState != PadState.idle) {
        var idx = entities.indexOf(e);
        entities[idx] = e.copyWith(state: savedState);
      }
    }
    _runtimeStates.removeWhere((id, _) => !entities.any((e) => e.id == id));

    var audioEngine = ref.read(audioEngineProvider);
    _sub?.cancel();
    _sub = audioEngine.onSoundFinished.listen((padId) {
      _runtimeStates.remove(padId);
      _setPadState(padId, PadState.idle);
    });

    ref.onDispose(() {
      _sub?.cancel();
    });

    // Cargar audios en segundo plano de forma asíncrona sin bloquear la UI.
    // Solo los que aún no están cargados: evita recargar todo en cada rebuild.
    Future.microtask(() {
      for (var pad in entities) {
        if (pad.sampleId != null && !audioEngine.isLoaded(pad.id)) {
          audioEngine.loadAudio(pad.id, pad.sampleId!);
        }
      }
    });

    return entities;
  }

  PadEntity _mapToEntity(PadModel m) {
    return PadEntity(
      id: m.id.toString(),
      index: m.padId,
      type: (m.padTypeIndex >= 0 && m.padTypeIndex < PadType.values.length)
          ? PadType.values[m.padTypeIndex]
          : PadType.audio,
      targetPageIndex: m.targetPageIndex,
      targetMacroId: m.targetMacroId,
      label: m.label,
      colorHex: m.colorHex,
      sampleId: m.samplePath,
      playMode:
          (m.triggerModeIndex >= 0 &&
              m.triggerModeIndex < TriggerMode.values.length)
          ? TriggerMode.values[m.triggerModeIndex]
          : TriggerMode.oneShot,
      chokeGroup: m.chokeGroup,
      pan: m.pan,
      pitch: m.pitch,
      volume: m.volume,
      isProtected: m.isProtected,
      reverse: m.reverse,
      fadeIn: Duration(milliseconds: m.fadeInMs),
      fadeOut: Duration(milliseconds: m.fadeOutMs),
      startPoint: Duration(milliseconds: m.startPointMs),
      endPoint: m.endPointMs != null
          ? Duration(milliseconds: m.endPointMs!)
          : null,
      loopPoint: Duration(milliseconds: m.loopPointMs),
      backgroundImagePath: m.backgroundImagePath,
    );
  }

  Future<void> createNewPad() async {
    var isar = await ref.read(isarProvider.future);
    var workspace = await ref.read(currentWorkspaceProvider.future);
    if (workspace == null) return;

    await workspace.pages.load();
    PageModel? page;
    for (final candidate in workspace.pages) {
      if (candidate.pageIndex == arg) {
        page = candidate;
        break;
      }
    }
    if (page == null) return;
    await page.pads.load();
    final targetPage = page;

    int newId = 0;
    if (page.pads.isNotEmpty) {
      newId = page.pads.map((p) => p.padId).reduce((a, b) => a > b ? a : b) + 1;
    }

    var colors = AppColors.padPalette;

    var newModel = PadModel()
      ..padId = newId
      ..label = 'PAD ${newId + 1}'
      ..colorHex = colors[newId % colors.length]
      ..triggerModeIndex = 0
      ..page.value = targetPage;

    await isar.writeTxn(() async {
      await isar.padModels.put(newModel);
      targetPage.pads.add(newModel);
      await targetPage.pads.save();
    });

    // Localized update: append the new pad without invalidating the whole page.
    final current = state.value ?? [];
    state = AsyncData([...current, _mapToEntity(newModel)]);
  }

  Future<void> assignSampleToPad(
    String padIdString,
    String samplePath,
    String sampleName,
  ) async {
    var padId = int.parse(padIdString);
    var isar = await ref.read(isarProvider.future);

    var model = await isar.padModels.get(padId);
    if (model == null) return;

    // Stop pre-existing playback using the stable pad ID.
    ref.read(audioEngineProvider).stop(padIdString);

    await isar.writeTxn(() async {
      model.samplePath = samplePath;
      model.label = sampleName;
      await isar.padModels.put(model);
    });

    // Update only the affected pad in state — never invalidateSelf.
    final current = state.value ?? [];
    final updated = <PadEntity>[
      for (final e in current)
        if (e.id == padIdString) _mapToEntity(model) else e,
    ];
    state = AsyncData(updated);

    // Precargar el nuevo audio asociado al pad.
    final audioEngine = ref.read(audioEngineProvider);
    Future.microtask(() {
      audioEngine.loadAudio(padIdString, samplePath);
    });
  }

  Future<void> updatePadAudioSettings(
    int padId, {
    int? chokeGroup,
    double? pan,
    double? pitch,
    double? volume,
    bool? isProtected,
    bool? reverse,
    int? fadeInMs,
    int? fadeOutMs,
    int? startPointMs,
    int? endPointMs,
    int? loopPointMs,
  }) async {
    var isar = await ref.read(isarProvider.future);
    var model = await isar.padModels.get(padId);
    if (model == null) return;

    await isar.writeTxn(() async {
      if (chokeGroup != null) model.chokeGroup = chokeGroup;
      if (pan != null) model.pan = pan;
      if (pitch != null) model.pitch = pitch;
      if (volume != null) model.volume = volume;
      if (isProtected != null) model.isProtected = isProtected;
      if (reverse != null) model.reverse = reverse;
      if (fadeInMs != null) model.fadeInMs = fadeInMs;
      if (fadeOutMs != null) model.fadeOutMs = fadeOutMs;
      if (startPointMs != null) model.startPointMs = startPointMs;
      if (endPointMs != null) model.endPointMs = endPointMs;
      if (loopPointMs != null) model.loopPointMs = loopPointMs;
      await isar.padModels.put(model);
    });

    final current = state.value ?? [];
    state = AsyncData([
      for (final e in current)
        if (e.id == '$padId') _mapToEntity(model) else e,
    ]);
  }

  Future<void> updatePadVisual(
    int padId, {
    int? colorHex,
    String? label,
    int? triggerModeIndex,
    String? backgroundImagePath,
    int? padTypeIndex,
    int? targetPageIndex,
    int? targetMacroId,
  }) async {
    var isar = await ref.read(isarProvider.future);
    var model = await isar.padModels.get(padId);
    if (model == null) return;

    await isar.writeTxn(() async {
      if (colorHex != null) model.colorHex = colorHex;
      if (label != null) model.label = label;
      if (triggerModeIndex != null) model.triggerModeIndex = triggerModeIndex;
      if (backgroundImagePath != null)
        model.backgroundImagePath = backgroundImagePath;
      if (padTypeIndex != null) model.padTypeIndex = padTypeIndex;
      if (targetPageIndex != null) model.targetPageIndex = targetPageIndex;
      if (targetMacroId != null) model.targetMacroId = targetMacroId;
      await isar.padModels.put(model);
    });

    final current = state.value ?? [];
    state = AsyncData([
      for (final e in current)
        if (e.id == '$padId') _mapToEntity(model) else e,
    ]);
  }

  Future<void> clearPadBackground(int padId) async {
    var isar = await ref.read(isarProvider.future);
    var model = await isar.padModels.get(padId);
    if (model == null) return;

    await isar.writeTxn(() async {
      model.backgroundImagePath = null;
      await isar.padModels.put(model);
    });

    final current = state.value ?? [];
    state = AsyncData([
      for (final e in current)
        if (e.id == '$padId') _mapToEntity(model) else e,
    ]);
  }

  /// Recopila las rutas de audio de un pad y sus hijos (si es carpeta) recursivamente SIN tocar la DB.
  Future<List<String>> _collectAudioPaths(
    Isar isar,
    WorkspaceModel? workspace,
    int padId,
  ) async {
    var paths = <String>[];
    var model = await isar.padModels.get(padId);
    if (model == null) return paths;
    if (model.padTypeIndex == 1 &&
        model.targetPageIndex != null &&
        workspace != null) {
      final childPage = await isar.pageModels
          .filter()
          .pageIndexEqualTo(model.targetPageIndex!)
          .workspace((q) => q.idEqualTo(workspace.id))
          .findFirst();
      if (childPage != null) {
        await childPage.pads.load();
        for (var child in childPage.pads) {
          paths.addAll(await _collectAudioPaths(isar, workspace, child.id));
        }
      }
    }
    if (model.samplePath != null && model.samplePath!.isNotEmpty) {
      paths.add(model.samplePath!);
    }
    return paths;
  }

  Future<Set<int>> _collectPadIdsForDeletion(
    Isar isar,
    WorkspaceModel? workspace,
    int padId,
  ) async {
    final ids = <int>{padId};
    final model = await isar.padModels.get(padId);
    if (model == null ||
        model.padTypeIndex != 1 ||
        model.targetPageIndex == null ||
        workspace == null) {
      return ids;
    }
    final childPage = await isar.pageModels
        .filter()
        .pageIndexEqualTo(model.targetPageIndex!)
        .workspace((q) => q.idEqualTo(workspace.id))
        .findFirst();
    if (childPage == null) return ids;
    await childPage.pads.load();
    for (final child in childPage.pads) {
      ids.addAll(await _collectPadIdsForDeletion(isar, workspace, child.id));
    }
    return ids;
  }

  /// Evita borrar un audio si otro pad que permanece en la base lo comparte.
  Future<List<String>> _unsharedAudioPaths(
    Isar isar,
    Iterable<String> candidates,
    Set<int> deletingPadIds,
  ) async {
    final pathsInUse = (await isar.padModels.where().findAll())
        .where((pad) => !deletingPadIds.contains(pad.id))
        .map((pad) => pad.samplePath)
        .whereType<String>()
        .toSet();
    return candidates.where((path) => !pathsInUse.contains(path)).toList();
  }

  /// Elimina un pad y su contenido (si es carpeta) recursivamente de la DB.
  /// audioPaths ya debe haberse borrado del disco ANTES de llamar esto.
  Future<void> _deletePadCascadeDB(
    Isar isar,
    WorkspaceModel? workspace,
    int padId,
  ) async {
    var model = await isar.padModels.get(padId);
    if (model == null) return;
    if (model.padTypeIndex == 1 &&
        model.targetPageIndex != null &&
        workspace != null) {
      final childPage = await isar.pageModels
          .filter()
          .pageIndexEqualTo(model.targetPageIndex!)
          .workspace((q) => q.idEqualTo(workspace.id))
          .findFirst();
      if (childPage != null) {
        await _deletePageTree(isar, childPage.id, workspace.id);
      }
    }
    await isar.padModels.delete(padId);
  }

  /// Elimina los mappings MIDI que apuntan a los pads borrados para no dejar
  /// referencias huérfanas en la base de datos.
  Future<void> _deleteMidiMappingsForPads(Isar isar, Set<int> padIds) async {
    if (padIds.isEmpty) return;
    final idStrings = padIds.map((id) => id.toString()).toSet();
    final mappings = await isar.midiMappingModels
        .filter()
        .actionTypeEqualTo(MidiActionType.triggerPad.name)
        .findAll();
    final toDelete = <int>[];
    for (final m in mappings) {
      if (idStrings.contains(m.actionValue)) {
        toDelete.add(m.id);
      }
    }
    if (toDelete.isNotEmpty) {
      await isar.midiMappingModels.deleteAll(toDelete);
      ref.read(midiControllerProvider).invalidateFeedbackCache();
    }
  }

  Future<void> deletePad(String padIdString) async {
    var padId = int.parse(padIdString);
    var isar = await ref.read(isarProvider.future);
    if (!ref.mounted) return;
    var workspace = await ref.read(currentWorkspaceProvider.future);

    var audioPaths = await _collectAudioPaths(isar, workspace, padId);
    // Collect IDs of the pad and its children (if folder) so we can remove
    // them from the in-memory state without a full workspace reload.
    final deletingIds = (await _collectPadIdsForDeletion(
      isar,
      workspace,
      padId,
    ))
        .map((id) => id.toString())
        .toSet();
    await LocalAudioStorageService.deleteAudioFiles(
      await _unsharedAudioPaths(
        isar,
        audioPaths,
        deletingIds.map(int.parse).toSet(),
      ),
    );

    await isar.writeTxn(() async {
      await _deletePadCascadeDB(isar, workspace, padId);
      await _deleteMidiMappingsForPads(
        isar,
        deletingIds.map(int.parse).toSet(),
      );
    });
    await LocalAudioStorageService.autoCleanOrphans(isar);
    if (!ref.mounted) return;

    ref.read(audioEngineProvider).stop(padIdString);
    var selected = ref.read(selectedPadsProvider);
    if (selected.contains(padIdString)) {
      ref.read(selectedPadsProvider.notifier).state = {...selected}
        ..remove(padIdString);
    }
    // Localized update: drop deleted pads from state instead of reloading the
    // whole workspace.
    final current = state.value ?? [];
    state = AsyncData([
      for (final e in current) if (!deletingIds.contains(e.id)) e,
    ]);
  }

  Future<void> deleteSelectedPads(Set<String> padIds) async {
    var isar = await ref.read(isarProvider.future);
    if (!ref.mounted) return;
    var workspace = await ref.read(currentWorkspaceProvider.future);

    var allAudioPaths = <String>[];
    final deletingIds = <String>{};
    for (var padIdString in padIds) {
      var padId = int.tryParse(padIdString);
      if (padId == null) continue;
      allAudioPaths.addAll(await _collectAudioPaths(isar, workspace, padId));
      deletingIds.addAll(
        (await _collectPadIdsForDeletion(isar, workspace, padId))
            .map((id) => id.toString()),
      );
    }
    await LocalAudioStorageService.deleteAudioFiles(
      await _unsharedAudioPaths(
        isar,
        allAudioPaths,
        deletingIds.map(int.parse).toSet(),
      ),
    );

    await isar.writeTxn(() async {
      for (var padIdString in padIds) {
        var padId = int.tryParse(padIdString);
        if (padId == null) continue;
        await _deletePadCascadeDB(isar, workspace, padId);
      }
      await _deleteMidiMappingsForPads(
        isar,
        deletingIds.map(int.parse).toSet(),
      );
    });
    await LocalAudioStorageService.autoCleanOrphans(isar);
    if (!ref.mounted) return;

    final audioEngine = ref.read(audioEngineProvider);
    for (final pid in padIds) {
      audioEngine.stop(pid);
    }

    var currentSelection = Set<String>.from(ref.read(selectedPadsProvider));
    currentSelection.removeAll(padIds);
    ref.read(selectedPadsProvider.notifier).state = currentSelection;

    var currentVel = Map<String, double>.from(ref.read(padVelocityProvider));
    currentVel.removeWhere((k, v) => padIds.contains(k));
    ref.read(padVelocityProvider.notifier).state = currentVel;

    // Localized update: drop deleted pads (incl. folder children) from state
    // instead of reloading the whole workspace.
    final current = state.value ?? [];
    state = AsyncData([
      for (final e in current) if (!deletingIds.contains(e.id)) e,
    ]);
  }

  Future<PageModel?> _pageForIndex(int index) async {
    var workspace = await ref.read(currentWorkspaceProvider.future);
    if (workspace == null) return null;
    await workspace.pages.load();
    for (var pg in workspace.pages) {
      if (pg.pageIndex == index) return pg;
    }
    return ref
        .read(workspaceRepositoryProvider)
        .createPage(workspace.id, index);
  }

  Future<int> _nextHiddenPageIndex() async {
    var workspace = await ref.read(currentWorkspaceProvider.future);
    if (workspace == null) return 1000;
    await workspace.pages.load();
    var hidden = workspace.pages
        .map((p) => p.pageIndex)
        .where((i) => i >= 1000);
    return hidden.isEmpty ? 1000 : hidden.reduce((a, b) => a > b ? a : b) + 1;
  }

  PadModel _copyModel(
    PadModel src,
    int padId, {
    int? targetPageIndex,
    String? label,
  }) {
    return PadModel()
      ..padId = padId
      ..label = label ?? src.label
      ..colorHex = src.colorHex
      ..samplePath = src.samplePath
      ..triggerModeIndex = src.triggerModeIndex
      ..padTypeIndex = src.padTypeIndex
      ..targetPageIndex = targetPageIndex ?? src.targetPageIndex
      ..chokeGroup = src.chokeGroup
      ..pan = src.pan
      ..pitch = src.pitch
      ..isProtected = src.isProtected
      ..reverse = src.reverse
      ..fadeInMs = src.fadeInMs
      ..fadeOutMs = src.fadeOutMs
      ..startPointMs = src.startPointMs
      ..endPointMs = src.endPointMs
      ..loopPointMs = src.loopPointMs
      ..backgroundImagePath = src.backgroundImagePath;
  }

  Future<void> _deletePageTree(Isar isar, int pageId, int workspaceId) async {
    final page = await isar.pageModels.get(pageId);
    if (page == null) return;
    await page.pads.load();
    // Las paginas de una carpeta no son hijas directas en Isar: estan
    // enlazadas desde sus pads carpeta. Eliminar solo la pagina actual dejaba
    // subpaginas y sus audios marcados como activos, impidiendo la limpieza.
    for (final pad in page.pads) {
      if (pad.padTypeIndex != 1 || pad.targetPageIndex == null) {
        continue;
      }
      final child = await isar.pageModels
          .filter()
          .pageIndexEqualTo(pad.targetPageIndex!)
          .workspace((query) => query.idEqualTo(workspaceId))
          .findFirst();
      if (child != null && child.id != page.id) {
        await _deletePageTree(isar, child.id, workspaceId);
      }
    }
    await isar.padModels.deleteAll(page.pads.map((pad) => pad.id).toList());
    await isar.pageModels.delete(page.id);
  }

  /// Duplica un pad. Si es carpeta, copia TAMBIEN su contenido interno
  /// (duplicacion profunda) para poder editarla sin alterar la original.
  Future<void> duplicatePad(PadEntity sourcePad) async {
    var sourceId = int.parse(sourcePad.id);
    var isar = await ref.read(isarProvider.future);
    var page = await _pageForIndex(arg);
    if (page == null) return;
    var workspace = await ref.read(currentWorkspaceProvider.future);
    if (workspace == null) return;

    var sourceModel = await isar.padModels.get(sourceId);
    if (sourceModel == null) return;

    final int? newTarget =
        (sourceModel.padTypeIndex == 1 && sourceModel.targetPageIndex != null)
            ? await _nextHiddenPageIndex()
            : null;

    await isar.writeTxn(() async {
      if (newTarget != null) {
        final sourceChildPage = await isar.pageModels
            .filter()
            .pageIndexEqualTo(sourceModel.targetPageIndex!)
            .workspace((query) => query.idEqualTo(workspace.id))
            .findFirst();
        if (sourceChildPage != null) {
          // Duplicar contenido de la carpeta (solo pads, no sub-páginas)
          final newHiddenPage = PageModel()
            ..pageIndex = newTarget
            ..columns = sourceChildPage.columns
            ..rows = sourceChildPage.rows
            ..parentPageId = page.id
            ..workspace.value = workspace;
          await isar.pageModels.put(newHiddenPage);
          await newHiddenPage.workspace.save();

          await sourceChildPage.pads.load();
          for (final pad in sourceChildPage.pads) {
            final copiedPad = _copyModel(pad, pad.padId)
              ..page.value = newHiddenPage;
            await isar.padModels.put(copiedPad);
            await copiedPad.page.save();
          }
        }
      }

      await page.pads.load();
      var nextPadId = page.pads.isEmpty
          ? 0
          : page.pads.map((c) => c.padId).reduce((a, b) => a > b ? a : b) + 1;
      var label = sourceModel.padTypeIndex == 1
          ? '${sourceModel.label} (copia)'
          : sourceModel.label;
      var newModel = _copyModel(
        sourceModel,
        nextPadId,
        targetPageIndex: newTarget,
        label: label,
      )..page.value = page;
      await isar.padModels.put(newModel);
      await newModel.page.save();
      // Localized update: append the duplicated pad only.
      final current = state.value ?? [];
      state = AsyncData([...current, _mapToEntity(newModel)]);
    });
  }

  /// Agrega [count] pads al final de la pagina (boton [+]). Si se pasan
  /// [samplePaths], cada pad nuevo queda con su sonido ya asignado.
  Future<void> addPads(
    int count, {
    List<String>? samplePaths,
    List<String>? sampleNames,
  }) async {
    var isar = await ref.read(isarProvider.future);
    var page = await _pageForIndex(arg);
    if (page == null) return;
    var colors = AppColors.audioPadPalette;

    await isar.writeTxn(() async {
      await page.pads.load();
      var nextPadId = page.pads.isEmpty
          ? 0
          : page.pads.map((c) => c.padId).reduce((a, b) => a > b ? a : b) + 1;
      var models = <PadModel>[];
      for (var i = 0; i < count; i++) {
        var path = (samplePaths != null && i < samplePaths.length)
            ? samplePaths[i]
            : null;
        var name = (sampleNames != null && i < sampleNames.length)
            ? sampleNames[i]
            : 'PAD ${nextPadId + i + 1}';
        var m = PadModel()
          ..padId = nextPadId + i
          ..label = name
          ..colorHex = colors[(nextPadId + i) % colors.length]
          ..triggerModeIndex = 0
          ..samplePath = path
          ..page.value = page;
        models.add(m);
      }
      await isar.padModels.putAll(models);
      for (var m in models) {
        await m.page.save();
      }
      // Localized update: append only the new pads instead of invalidating the
      // whole workspace (avoids reloading every page + the active workspace).
      final current = state.value ?? [];
      state = AsyncData([...current, for (final m in models) _mapToEntity(m)]);
    });
  }

  /// Crea un pad-carpeta con su pagina interna oculta (indice >= 1000).
  Future<void> addFolderPad(String name) async {
    var isar = await ref.read(isarProvider.future);
    var page = await _pageForIndex(arg);
    var workspace = await ref.read(currentWorkspaceProvider.future);
    if (page == null || workspace == null) return;
    var hiddenIndex = await _nextHiddenPageIndex();

    final addedModels = <PadModel>[];
    await isar.writeTxn(() async {
      var hidden = PageModel()
        ..pageIndex = hiddenIndex
        ..columns = page.columns
        ..rows = page.rows
        ..parentPageId = page.id
        ..workspace.value = workspace;
      await isar.pageModels.put(hidden);
      await hidden.workspace.save();

      await page.pads.load();
      var nextPadId = page.pads.isEmpty
          ? 0
          : page.pads.map((c) => c.padId).reduce((a, b) => a > b ? a : b) + 1;
      var m = PadModel()
        ..padId = nextPadId
        ..label = name
        ..colorHex = AppColors.folderPadColor
        ..padTypeIndex = 1
        ..targetPageIndex = hiddenIndex
        ..triggerModeIndex = 0
        ..page.value = page;
      await isar.padModels.put(m);
      await m.page.save();
      addedModels.add(m);
    });
    final parentPath = await _getFolderPath(isar, arg);
    await LocalAudioStorageService.ensureSubfolderDir(workspace.name, [
      ...parentPath,
      name,
    ]);
    // Localized update: append the new folder pad only.
    final current = state.value ?? [];
    state = AsyncData([...current, for (final m in addedModels) _mapToEntity(m)]);
  }

  Future<List<String>> _getFolderPath(Isar isar, int currentIdx) async {
    final workspace = await ref.read(currentWorkspaceProvider.future);
    if (workspace == null) return [];
    final path = <String>[];
    var idx = currentIdx;
    while (idx >= 1000) {
      final pad = await isar.padModels
          .filter()
          .targetPageIndexEqualTo(idx)
          .page((q) => q.workspace((w) => w.idEqualTo(workspace.id)))
          .findFirst();
      if (pad != null) {
        final label = pad.label.trim().isEmpty ? 'Carpeta' : pad.label.trim();
        path.insert(0, label);
        await pad.page.load();
        final parentPage = pad.page.value;
        idx = parentPage?.pageIndex ?? 0;
      } else {
        break;
      }
    }
    return path;
  }

  /// Crea un pad tipo Macro asignado a una macro existente.
  Future<void> addMacroPad(int macroId, String name) async {
    var isar = await ref.read(isarProvider.future);
    var page = await _pageForIndex(arg);
    if (page == null) return;

    final addedModels = <PadModel>[];
    await isar.writeTxn(() async {
      await page.pads.load();
      var nextPadId = page.pads.isEmpty
          ? 0
          : page.pads.map((c) => c.padId).reduce((a, b) => a > b ? a : b) + 1;
      var m = PadModel()
        ..padId = nextPadId
        ..label = name
        ..colorHex = 0xFF00E5FF
        ..padTypeIndex =
            2 // PadType.macro
        ..targetMacroId = macroId
        ..page.value = page;
      await isar.padModels.put(m);
      await m.page.save();
      addedModels.add(m);
    });
    // Localized update: append the new macro pad only.
    final current = state.value ?? [];
    state = AsyncData([...current, for (final m in addedModels) _mapToEntity(m)]);
  }

  /// Importa una carpeta completa (con sus pads y audios) desde un archivo.
  Future<void> importFolder(ImportedFolder data) async {
    var isar = await ref.read(isarProvider.future);
    var page = await _pageForIndex(arg);
    var workspace = await ref.read(currentWorkspaceProvider.future);
    if (page == null || workspace == null) return;
    var nextHiddenIndex = await _nextHiddenPageIndexFromDatabase(
      isar,
      workspace.id,
    );
    int allocateHiddenIndex() => nextHiddenIndex++;

    final addedModels = <PadModel>[];
    await isar.writeTxn(() async {
      final hidden = await _createHiddenChildPage(
        isar,
        workspace,
        page,
        allocateHiddenIndex,
      );
      await _importFolderContentsIntoPage(
        isar,
        workspace,
        data,
        hidden,
        allocateHiddenIndex,
      );

      await page.pads.load();
      var nextPadId = page.pads.isEmpty
          ? 0
          : page.pads.map((c) => c.padId).reduce((a, b) => a > b ? a : b) + 1;
      var folderPad = PadModel()
        ..padId = nextPadId
        ..label = data.name
        ..colorHex = data.colorHex
        ..padTypeIndex = 1
        ..targetPageIndex = hidden.pageIndex
        ..page.value = page;
      await isar.padModels.put(folderPad);
      await folderPad.page.save();
      addedModels.add(folderPad);
    });
    // Contraparte física del folder pad: crear la subcarpeta real dentro del
    // workspace para que la reconciliación la reconozca (el audio importado
    // vive en folder_imports/, pero la estructura en disco debe existir).
    await LocalAudioStorageService.ensureSubfolderDir(workspace.name, [data.name]);
    // Localized update: append the new folder pad only.
    final current = state.value ?? [];
    state = AsyncData([...current, for (final m in addedModels) _mapToEntity(m)]);
  }

  Future<PageModel> _createHiddenChildPage(
    Isar isar,
    WorkspaceModel workspace,
    PageModel parentPage,
    int Function() allocateHiddenIndex,
  ) async {
    final hiddenIndex = allocateHiddenIndex();
    final hidden = PageModel()
      ..pageIndex = hiddenIndex
      ..columns = parentPage.columns
      ..rows = parentPage.rows
      ..parentPageId = parentPage.id
      ..workspace.value = workspace;
    await isar.pageModels.put(hidden);
    await hidden.workspace.save();
    return hidden;
  }

  Future<void> _importFolderContentsIntoPage(
    Isar isar,
    WorkspaceModel workspace,
    ImportedFolder data,
    PageModel targetPage,
    int Function() allocateHiddenIndex,
  ) async {
    await targetPage.pads.load();
    final padModels = <PadModel>[];

    for (var i = 0; i < data.pads.length; i++) {
      final pd = data.pads[i];
      if (pd.padTypeIndex == 1) {
        final childPage = await _createHiddenChildPage(
          isar,
          workspace,
          targetPage,
          allocateHiddenIndex,
        );
        final m = PadModel()
          ..padId = i
          ..label = pd.label
          ..colorHex = pd.colorHex
          ..triggerModeIndex = pd.triggerModeIndex
          ..padTypeIndex = 1
          ..targetPageIndex = childPage.pageIndex
          ..chokeGroup = pd.chokeGroup
          ..pan = pd.pan
          ..pitch = pd.pitch
          ..isProtected = pd.isProtected
          ..reverse = pd.reverse
          ..targetMacroId = pd.targetMacroId
          ..fadeInMs = pd.fadeInMs
          ..fadeOutMs = pd.fadeOutMs
          ..startPointMs = pd.startPointMs
          ..endPointMs = pd.endPointMs
          ..loopPointMs = pd.loopPointMs
          ..backgroundImagePath = pd.backgroundImagePath
          ..page.value = targetPage;
        padModels.add(m);
        if (pd.childFolder != null) {
          await _importFolderContentsIntoPage(
            isar,
            workspace,
            pd.childFolder!,
            childPage,
            allocateHiddenIndex,
          );
        }
      } else {
        final m = PadModel()
          ..padId = i
          ..label = pd.label
          ..colorHex = pd.colorHex
          ..samplePath = pd.samplePath
          ..triggerModeIndex = pd.triggerModeIndex
          ..padTypeIndex = pd.padTypeIndex
          ..targetMacroId = pd.targetMacroId
          ..chokeGroup = pd.chokeGroup
          ..pan = pd.pan
          ..pitch = pd.pitch
          ..isProtected = pd.isProtected
          ..reverse = pd.reverse
          ..fadeInMs = pd.fadeInMs
          ..fadeOutMs = pd.fadeOutMs
          ..startPointMs = pd.startPointMs
          ..endPointMs = pd.endPointMs
          ..loopPointMs = pd.loopPointMs
          ..backgroundImagePath = pd.backgroundImagePath
          ..page.value = targetPage;
        padModels.add(m);
      }
    }

    await isar.padModels.putAll(padModels);
    for (var m in padModels) {
      await m.page.save();
    }
  }

  /// Pre-copia los archivos de audio fuera de la transacción de Isar conservando la estructura de carpetas.
  Future<PreparedFolderNode> _prepareFolderNode(
    AudioFolderNode node, {
    String? parentNamespace,
  }) async {
    final currentNamespace = parentNamespace == null || parentNamespace.isEmpty
        ? node.name
        : '$parentNamespace/${node.name}';

    var preparedFiles = <PreparedAudioFile>[];
    const batchSize = 4;
    for (var start = 0; start < node.audioFiles.length; start += batchSize) {
      final end = (start + batchSize).clamp(0, node.audioFiles.length);
      final batch = node.audioFiles.sublist(start, end);
      final preparedBatch = await Future.wait(
        batch.map(
          (file) => _prepareAudioFile(file, namespace: currentNamespace),
        ),
      );
      preparedFiles.addAll(preparedBatch);
      await Future<void>.delayed(Duration.zero);
    }

    var preparedSubfolders = <PreparedFolderNode>[];
    for (var sub in node.subfolders) {
      var preparedSub = await _prepareFolderNode(
        sub,
        parentNamespace: currentNamespace,
      );
      preparedSubfolders.add(preparedSub);
    }

    return PreparedFolderNode(
      name: node.name,
      audioFiles: preparedFiles,
      subfolders: preparedSubfolders,
    );
  }

  Future<PreparedAudioFile> _prepareAudioFile(
    File file, {
    String? namespace,
  }) async {
    // Extraer nombre legible del archivo, quitando extensión
    var rawName = file.path
        .split(RegExp(r'[/\\]'))
        .last
        .replaceAll(RegExp(r'\.[^.]+$'), '');

    // Decodificar nombres con encoding URI (Android SAF)
    rawName = Uri.decodeFull(rawName);

    // Quitar sufijo UUID que agrega importAudioBytes/importAudioFile
    // Patrón: _XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX al final
    rawName = rawName.replaceAll(
      RegExp(
        r'_[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ),
      '',
    );

    // Reemplazar underscores solitarios por espacios para nombres más legibles
    // pero solo si el nombre original no tenía underscores intencionales
    final name = rawName.trim().isEmpty ? 'Audio' : rawName.trim();

    try {
      final localPath = await LocalAudioStorageService.importAudioFile(
        file.path,
        namespace: namespace,
      );
      return PreparedAudioFile(
        originalFile: file,
        localPath: localPath,
        name: name,
      );
    } on FileSystemException {
      return PreparedAudioFile(
        originalFile: file,
        localPath: file.path,
        name: name,
      );
    }
  }

  /// Importa una estructura jerárquica de carpetas y subcarpetas de audios,
  /// recreando la estructura completa como Carpetas de Pads tipo Explorador de Archivos.
  Future<void> importAudioDirectoryTree(AudioFolderNode rootNode) async {
    var isar = await ref.read(isarProvider.future);
    var workspace = await ref.read(currentWorkspaceProvider.future);
    if (workspace == null) return;

    var preparedRoot = await _prepareFolderNode(
      rootNode,
      parentNamespace: workspace.name,
    );
    // Reserva los indices antes de abrir la transaccion. Consultar el
    // Workspace cacheado dentro de cada recursion devolvia siempre el mismo
    // indice (1000), por lo que una segunda carpeta podia apuntar a una pagina
    // equivocada o sobrescribir la navegacion de la primera.
    var targetPage = await _pageForIndex(arg);
    if (targetPage == null) return;
    var nextHiddenIndex = await _nextHiddenPageIndexFromDatabase(
      isar,
      workspace.id,
    );
    int allocateHiddenIndex() => nextHiddenIndex++;

    await isar.writeTxn(() async {
      await _importPreparedNodeRecursive(
        isar,
        workspace,
        preparedRoot,
        targetPage,
        allocateHiddenIndex,
      );
    });

    // Localized refresh: only this page recomputes. Sub-pages refresh lazily
    // when navigated into, avoiding a full workspace + all-page reload.
    ref.invalidateSelf();
  }

  Future<void> _importPreparedNodeRecursive(
    Isar isar,
    WorkspaceModel workspace,
    PreparedFolderNode node,
    PageModel page,
    int Function() allocateHiddenIndex,
  ) async {
    var nextHiddenIndex = allocateHiddenIndex();

    var hiddenPage = PageModel()
      ..pageIndex = nextHiddenIndex
      ..columns = page.columns
      ..rows = page.rows
      ..parentPageId = page.id
      ..workspace.value = workspace;
    await isar.pageModels.put(hiddenPage);
    await hiddenPage.workspace.save();

    var colors = AppColors.padPalette;
    var padModels = <PadModel>[];
    for (var i = 0; i < node.audioFiles.length; i++) {
      var pf = node.audioFiles[i];
      var m = PadModel()
        ..padId = i
        ..label = pf.name
        ..colorHex = colors[i % colors.length]
        ..triggerModeIndex = 0
        ..samplePath = pf.localPath
        ..page.value = hiddenPage;
      padModels.add(m);
    }
    await isar.padModels.putAll(padModels);
    for (var m in padModels) {
      await m.page.save();
    }

    for (var sub in node.subfolders) {
      await _importPreparedNodeAsChildFolder(
        isar,
        workspace,
        sub,
        hiddenPage,
        allocateHiddenIndex,
      );
    }

    await page.pads.load();
    var nextPadId = page.pads.isEmpty
        ? 0
        : page.pads.map((c) => c.padId).reduce((a, b) => a > b ? a : b) + 1;
    var folderPad = PadModel()
      ..padId = nextPadId
      ..label = node.name
      ..colorHex = AppColors.folderPadColor
      ..padTypeIndex = 1
      ..targetPageIndex = nextHiddenIndex
      ..page.value = page;
    await isar.padModels.put(folderPad);
    await folderPad.page.save();
  }

  Future<void> _importPreparedNodeAsChildFolder(
    Isar isar,
    WorkspaceModel workspace,
    PreparedFolderNode node,
    PageModel parentPage,
    int Function() allocateHiddenIndex,
  ) async {
    var nextHiddenIndex = allocateHiddenIndex();

    var hiddenPage = PageModel()
      ..pageIndex = nextHiddenIndex
      ..columns = parentPage.columns
      ..rows = parentPage.rows
      ..parentPageId = parentPage.id
      ..workspace.value = workspace;
    await isar.pageModels.put(hiddenPage);
    await hiddenPage.workspace.save();

    var colors = AppColors.audioPadPalette;
    var childPadModels = <PadModel>[];
    for (var i = 0; i < node.audioFiles.length; i++) {
      var pf = node.audioFiles[i];
      var m = PadModel()
        ..padId = i
        ..label = pf.name
        ..colorHex = colors[i % colors.length]
        ..triggerModeIndex = 0
        ..samplePath = pf.localPath
        ..page.value = hiddenPage;
      childPadModels.add(m);
    }
    await isar.padModels.putAll(childPadModels);
    for (var m in childPadModels) {
      await m.page.save();
    }

    for (var sub in node.subfolders) {
      await _importPreparedNodeAsChildFolder(
        isar,
        workspace,
        sub,
        hiddenPage,
        allocateHiddenIndex,
      );
    }

    await parentPage.pads.load();
    var nextPadId = parentPage.pads.isEmpty
        ? 0
        : parentPage.pads.map((c) => c.padId).reduce((a, b) => a > b ? a : b) +
              1;
    var folderPad = PadModel()
      ..padId = nextPadId
      ..label = node.name
      ..colorHex = AppColors.folderPadColor
      ..padTypeIndex = 1
      ..targetPageIndex = nextHiddenIndex
      ..page.value = parentPage;
    await isar.padModels.put(folderPad);
    await folderPad.page.save();
  }

  Future<int> _nextHiddenPageIndexFromDatabase(
    Isar isar,
    int workspaceId,
  ) async {
    final pages = await isar.pageModels
        .filter()
        .workspace((q) => q.idEqualTo(workspaceId))
        .findAll();
    final hidden = pages
        .map((page) => page.pageIndex)
        .where((index) => index >= 1000);
    return hidden.isEmpty
        ? 1000
        : hidden.reduce((left, right) => left > right ? left : right) + 1;
  }

  /// Intercambia la POSICION de dos pads (sin arrastrar): se intercambian
  /// sus padId, por lo que en la cuadricula quedan en lugares opuestos.
  Future<void> swapPads(String idA, String idB) async {
    if (idA == idB) return;
    var a = int.tryParse(idA);
    var b = int.tryParse(idB);
    if (a == null || b == null) return;

    var isar = await ref.read(isarProvider.future);
    await isar.writeTxn(() async {
      var ma = await isar.padModels.get(a);
      var mb = await isar.padModels.get(b);
      if (ma == null || mb == null) return;
      var tmp = ma.padId;
      ma.padId = mb.padId;
      mb.padId = tmp;
      await isar.padModels.putAll([ma, mb]);
    });

    // swapPads changes padId (grid order) — refresh only this page.
    ref.invalidateSelf();
  }

  void _setPadState(String id, PadState newState) {
    if (!state.hasValue) return;
    var currentPads = state.value!;
    var index = currentPads.indexWhere((pad) => pad.id == id);
    if (index != -1 && currentPads[index].state != newState) {
      AudioLog.log('[Pad] _setPadState: id=$id ${currentPads[index].state}→$newState');
      var updatedPad = currentPads[index].copyWith(state: newState);
      var newStateList = [...currentPads];
      newStateList[index] = updatedPad;
      state = AsyncData(newStateList);
    }
  }

  Future<void> onPadDown(String id) async {
    if (!state.hasValue) {
      AudioLog.log('[Pad] onPadDown: NO STATE for id=$id');
      return;
    }
    if (ref.read(padMoveSourceProvider) != null) {
      AudioLog.log('[Pad] onPadDown: MOVE MODE, skipping id=$id');
      return;
    }
    var index = state.value!.indexWhere((pad) => pad.id == id);
    if (index != -1) {
      var pad = state.value![index];
      AudioLog.log('[Pad] onPadDown: id=$id type=${pad.type} mode=${pad.playMode} state=${pad.state} sample=${pad.sampleId} startPoint=${pad.startPoint} endPoint=${pad.endPoint} loopPoint=${pad.loopPoint}');

      // Carpeta: la navegación se maneja externamente (Navigator.push).
      // Este método NO navega; solo retorna para que el widget haga push.
      if (pad.type == PadType.folder) {
        return;
      }

      // Macro: ejecuta la secuencia de macros configurada
      if (pad.type == PadType.macro && pad.targetMacroId != null) {
        var macrosAsync = ref.read(macroListProvider);
        var macros = macrosAsync.value ?? [];
        MacroEntity? macro;
        for (final candidate in macros) {
          if (candidate.id == pad.targetMacroId) {
            macro = candidate;
            break;
          }
        }
        if (macro != null) {
          _setPadState(id, PadState.playing);
          ref.read(macroExecutorProvider).execute(macro);
          Future.delayed(const Duration(milliseconds: 400), () {
            _setPadState(id, PadState.idle);
          });
        }
        return;
      }

      // Pad VACIO (sin sonido): no hace nada, no se queda encendido.
       if (pad.sampleId == null || pad.sampleId!.isEmpty) {
        AudioLog.log('[Pad] onPadDown: EMPTY SAMPLE id=$id');
        return;
      }

      var action = PadTriggerResolver.onDown(pad.playMode, pad.state);
      AudioLog.log('[Pad] onPadDown: resolver action=$action for id=$id padId=${pad.index}');

      if (action == PadAction.stop) {
        AudioLog.log('[Pad] onPadDown: STOP id=$id');
        ref.read(audioEngineProvider).stop(id);
        ref.read(midiControllerProvider).sendPadFeedback(id, on: false);
        _setPadState(id, PadState.idle);
      } else {
        var audioEngine = ref.read(audioEngineProvider);
        if (!audioEngine.isLoaded(id)) {
          AudioLog.log('[Pad] onPadDown: NOT LOADED, loading id=$id path=${pad.sampleId}');
          await audioEngine.loadAudio(id, pad.sampleId!);
        } else {
          AudioLog.log('[Pad] onPadDown: already loaded id=$id');
        }

        if (pad.playMode == TriggerMode.oneShot &&
            pad.state == PadState.playing) {
          audioEngine.stop(id, notify: false);
        }
        _setPadState(id, PadState.playing);
        ref.read(midiControllerProvider).sendPadFeedback(id, on: true);
        AudioLog.log('[Pad] onPadDown: PLAY id=$id mode=${pad.playMode} startPoint=${pad.startPoint} endPoint=${pad.endPoint} loopPoint=${pad.loopPoint}');
        audioEngine.play(
          id,
          pad.playMode,
          chokeGroup: pad.chokeGroup,
          pan: pad.pan,
          pitch: pad.pitch,
          volume: pad.volume,
          isProtected: pad.isProtected,
          reverse: pad.reverse,
          fadeIn: pad.fadeIn,
          fadeOut: pad.fadeOut,
          startPoint: pad.startPoint,
          endPoint: pad.endPoint,
          loopPoint: pad.loopPoint,
        );
      }
    }
  }

  /// Fuerza el stop de un pad individual sin importar su TriggerMode.
  /// Llamado desde el botón de stop del pad.
  Future<void> forceStop(String id) async {
    ref.read(audioEngineProvider).stop(id);
    _setPadState(id, PadState.idle);
    ref.read(midiControllerProvider).sendPadFeedback(id, on: false);
  }

  /// PANIC / ESC: calla el audio de todos los pads, apaga el feedback MIDI de
  /// los que estaban encendidos y limpia la brillantez por velocity. Los pads
  /// vuelven a `idle` directamente (y de forma idempotente con el stream
  /// `onSoundFinished` que también emite `stopAll()` por cada id activo).
  Future<void> forceStopAll() async {
    if (!state.hasValue) return;
    var playing = state.value!
        .where((pad) => pad.state != PadState.idle)
        .toList();
    ref.read(audioEngineProvider).stopAll();
    if (playing.isEmpty) return;
    var vels = Map<String, double>.from(ref.read(padVelocityProvider));
    for (var pad in playing) {
      _setPadState(pad.id, PadState.idle);
      vels.remove(pad.id);
      ref.read(midiControllerProvider).sendPadFeedback(pad.id, on: false);
    }
    ref.read(padVelocityProvider.notifier).state = vels;
  }

  void onPadUp(String id) {
    if (!state.hasValue) return;
    var index = state.value!.indexWhere((pad) => pad.id == id);
    if (index != -1) {
      var pad = state.value![index];
      if (PadTriggerResolver.onUp(pad.playMode) == PadAction.stop) {
        ref.read(audioEngineProvider).stop(id);
        _setPadState(id, PadState.idle);
      }
    }
  }
}

/// Provider de pads para una página específica (raíz o carpeta oculta).
/// Al mantener en memoria sin autoDispose, la navegación atrás/adelante entre carpetas es 0.00ms.
final padPageProvider =
    AsyncNotifierProvider.family<PadPageNotifier, List<PadEntity>, int>(
      PadPageNotifier.new,
    );

/// Resuelve el nombre de una carpeta (hidden page) por su pageIndex.
final folderNameProvider = FutureProvider.family<String?, int>((
  ref,
  pageIndex,
) async {
  if (pageIndex < 1000) return null;
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return null;
  var isar = await ref.read(isarProvider.future);
  var pad = await isar.padModels
      .filter()
      .targetPageIndexEqualTo(pageIndex)
      .page((q) => q.workspace((w) => w.idEqualTo(workspace.id)))
      .findFirst();
  if (pad == null || pad.label.trim().isEmpty) return null;
  var cleanName = Uri.decodeFull(pad.label);
  cleanName = cleanName.replaceAll('_', ' ').trim();
  return cleanName.isEmpty ? 'Carpeta' : cleanName;
});

final searchQueryProvider = StateProvider<String>((ref) => '');
