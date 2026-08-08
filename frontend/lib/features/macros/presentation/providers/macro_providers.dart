import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../../data/repositories/macro_repository.dart';
import '../../domain/entities/macro_entity.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../pad_system/presentation/providers/pad_providers.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/utils/concurrency_shield.dart';

final macroRepositoryProvider = Provider<MacroRepository>((ref) {
  return MacroRepository(ref.watch(isarProvider.future));
});

final macroListProvider =
    StateNotifierProvider<MacroListNotifier, AsyncValue<List<MacroEntity>>>((
      ref,
    ) {
      return MacroListNotifier(ref);
    });

class MacroListNotifier extends StateNotifier<AsyncValue<List<MacroEntity>>> {
  final Ref ref;

  MacroListNotifier(this.ref) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      var repo = ref.read(macroRepositoryProvider);
      var macros = await repo.getAll();
      state = AsyncValue.data(macros);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<MacroEntity> create(String name, List<MacroAction> actions) async {
    var repo = ref.read(macroRepositoryProvider);
    var macro = MacroEntity(
      id: 0,
      name: name,
      actions: actions,
      createdAt: DateTime.now(),
    );
    var savedId = await repo.save(macro);
    var saved = macro.copyWith(id: savedId);
    state = AsyncValue.data([...state.value ?? [], saved]);
    return saved;
  }

  Future<void> updateMacro(MacroEntity macro) async {
    var repo = ref.read(macroRepositoryProvider);
    var updated = macro.copyWith(updatedAt: DateTime.now());
    await repo.save(updated);
    state = AsyncValue.data([
      for (final m in state.value ?? [])
        if (m.id == updated.id) updated else m,
    ]);
  }

  Future<void> delete(int id) async {
    var repo = ref.read(macroRepositoryProvider);
    await repo.delete(id);
    state = AsyncValue.data([
      for (final m in state.value ?? [])
        if (m.id != id) m,
    ]);
  }

  Future<String?> exportMacros() async {
    var macros = state.value ?? [];
    if (macros.isEmpty) return null;

    var jsonList = macros.map((m) => m.toJson()).toList();
    var jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

    var outputPath = await FilePicker.saveFile(
      dialogTitle: 'Exportar Macros',
      fileName: 'mis_macros.bdjmacro',
      type: FileType.custom,
      allowedExtensions: ['bdjmacro'],
    );

    if (outputPath != null) {
      await File(outputPath).writeAsString(jsonString);
      return outputPath;
    }
    return null;
  }

  Future<int> importMacros() async {
    var result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['bdjmacro'],
    );

    if (result != null && result.files.single.path != null) {
      var jsonString = await File(result.files.single.path!).readAsString();
      final List<dynamic> jsonList;
      try {
        jsonList = jsonDecode(jsonString) as List;
      } on FormatException {
        debugPrint('[MacroImport] El archivo no contiene JSON válido.');
        return 0;
      } on TypeError {
        debugPrint('[MacroImport] El JSON raíz no es una lista.');
        return 0;
      }
      var repo = ref.read(macroRepositoryProvider);
      int count = 0;

      for (var item in jsonList) {
        try {
          var macro = MacroEntity.fromJson(item as Map<String, dynamic>);
          await repo.save(macro);
          count++;
        } catch (e) {
          debugPrint('[MacroImport] Entrada inválida omitida: $e');
        }
      }

      await load();
      return count;
    }
    return 0;
  }

  /// Retorna las macros que hacen referencia a un workspace, pagina o pad especifico.
  List<MacroEntity> getReferencingMacros({
    int? workspaceId,
    int? pageIndex,
    String? padId,
  }) {
    final list = state.value ?? [];
    return list.where((m) {
      return m.actions.any((a) {
        if (workspaceId != null &&
            (a.params['workspaceId'] == workspaceId ||
                a.params['targetWorkspaceId'] == workspaceId)) {
          return true;
        }
        if (pageIndex != null &&
            (a.params['pageIndex'] == pageIndex ||
                a.params['targetPageIndex'] == pageIndex)) {
          return true;
        }
        if (padId != null &&
            (a.params['padId'] == padId || a.params['targetPadId'] == padId)) {
          return true;
        }
        return false;
      });
    }).toList();
  }
}

class MacroExecutor {
  final Ref ref;

  /// Conjunto de IDs de macros actualmente en ejecución. Previene la
  /// recursión infinita cuando una macro dispara a otra (o a sí misma)
  /// a través de un pad de tipo macro.
  final Set<int> _executingMacroIds = {};

  MacroExecutor(this.ref);

  Future<void> execute(MacroEntity macro) async {
    if (!_executingMacroIds.add(macro.id)) {
      debugPrint(
        '[MacroExecutor] Recursión detectada: macro ${macro.id} ya está en ejecución.',
      );
      return;
    }
    try {
      for (var action in macro.actions) {
        await _executeAction(action);
      }
    } finally {
      _executingMacroIds.remove(macro.id);
    }
  }

  Future<void> _executeAction(MacroAction action) async {
    switch (action.type) {
      case MacroActionType.changeWorkspace:
        var wsId = _paramInt(action.params, 'workspaceId') ??
            _paramInt(action.params, 'targetWorkspaceId');
        if (wsId != null) {
          // Safe workspace switching with request ID. Inlined here because a
          // StateNotifier's `Ref` and a widget's `WidgetRef` are disjoint in
          // Riverpod 3, so the notifier cannot pass `ref` to the
          // `switchWorkspaceWithRequestId(WidgetRef)` helper.
          ref.read(currentWorkspaceRequestIdProvider.notifier).state =
              ConcurrencyShield.nextRequestId().toString();
          ref.read(currentWorkspaceIdProvider.notifier).state = wsId;
          ref.read(currentPageIndexProvider.notifier).state = 0;
          ref.read(folderBackStackProvider.notifier).state = <int>[];
          await ref.read(settingsServiceProvider).setLastWorkspaceId(wsId);
        }
      case MacroActionType.changePage:
        var wsId = _paramInt(action.params, 'workspaceId') ??
            _paramInt(action.params, 'targetWorkspaceId');
        if (wsId != null && wsId != ref.read(currentWorkspaceIdProvider)) {
          // Cambio de workspace seguro (misma lógica inlined que
          // changeWorkspace: un StateNotifier Ref y un WidgetRef son
          // disjuntos en Riverpod 3).
          ref.read(currentWorkspaceRequestIdProvider.notifier).state =
              ConcurrencyShield.nextRequestId().toString();
          ref.read(currentWorkspaceIdProvider.notifier).state = wsId;
          ref.read(currentPageIndexProvider.notifier).state = 0;
          ref.read(folderBackStackProvider.notifier).state = <int>[];
          await ref.read(settingsServiceProvider).setLastWorkspaceId(wsId);
        }
        var destType =
            _paramString(action.params, 'destinationType') ?? 'main_page';
        var pageIndex =
            (_paramInt(action.params, 'pageIndex') ??
                _paramInt(action.params, 'targetPageIndex')) ??
            0;
        var current = ref.read(currentPageIndexProvider);

        if (destType == 'next' || pageIndex == -1) {
          final pages =
              ref
                  .read(currentWorkspaceProvider)
                  .value
                  ?.pages
                  .where((pg) => pg.parentPageId == null)
                  .toList() ??
              [];
          pages.sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
          final idx = pages.indexWhere((page) => page.pageIndex == current);
          if (idx != -1 && idx < pages.length - 1) {
            ref.read(currentPageIndexProvider.notifier).state =
                pages[idx + 1].pageIndex;
          }
        } else if (destType == 'prev' || pageIndex == -2) {
          final pages =
              ref
                  .read(currentWorkspaceProvider)
                  .value
                  ?.pages
                  .where((pg) => pg.parentPageId == null)
                  .toList() ??
              [];
          pages.sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
          final idx = pages.indexWhere((page) => page.pageIndex == current);
          if (idx > 0) {
            ref.read(currentPageIndexProvider.notifier).state =
                pages[idx - 1].pageIndex;
          }
        } else if (destType == 'exit_folder' || pageIndex == -3) {
          var stack = ref.read(folderBackStackProvider);
          if (stack.isNotEmpty) {
            var prev = stack.last;
            ref.read(folderBackStackProvider.notifier).state = stack.sublist(
              0,
              stack.length - 1,
            );
            ref.read(currentPageIndexProvider.notifier).state = prev;
          } else {
            ref.read(currentPageIndexProvider.notifier).state = 0;
          }
        } else if (destType == 'folder' || pageIndex >= 1000) {
          var stack = ref.read(folderBackStackProvider);
          ref.read(folderBackStackProvider.notifier).state = [
            ...stack,
            current,
          ];
          ref.read(currentPageIndexProvider.notifier).state = pageIndex;
        } else {
          ref.read(folderBackStackProvider.notifier).state = <int>[];
          ref.read(currentPageIndexProvider.notifier).state = pageIndex;
        }
        await Future.delayed(const Duration(milliseconds: 100));
      case MacroActionType.setVolume:
        var volume = _paramNum(action.params, 'volume')?.toDouble();
        if (volume != null) {
          ref.read(audioEngineProvider).setGlobalVolume(volume);
        }
      case MacroActionType.triggerPad:
        // Resolucion de Ruta Contextual
        var targetWsId = _paramInt(action.params, 'targetWorkspaceId');
        if (targetWsId != null &&
            targetWsId != ref.read(currentWorkspaceIdProvider)) {
          // Safe workspace switching with request ID (inlined — see above:
          // a notifier's Ref is disjoint from WidgetRef in Riverpod 3).
          ref.read(currentWorkspaceRequestIdProvider.notifier).state =
              ConcurrencyShield.nextRequestId().toString();
          ref.read(currentWorkspaceIdProvider.notifier).state = targetWsId;
          ref.read(currentPageIndexProvider.notifier).state = 0;
          ref.read(folderBackStackProvider.notifier).state = <int>[];
          await ref.read(settingsServiceProvider).setLastWorkspaceId(targetWsId);
        }

        int targetPage =
            _paramInt(action.params, 'targetPageIndex') ??
            _paramInt(action.params, 'pageIndex') ??
            ref.read(currentPageIndexProvider);

        if (ref.read(currentPageIndexProvider) != targetPage) {
          if (targetPage >= 1000) {
            final stack = ref.read(folderBackStackProvider);
            ref.read(folderBackStackProvider.notifier).state = [
              ...stack,
              ref.read(currentPageIndexProvider),
            ];
          } else {
            ref.read(folderBackStackProvider.notifier).state = <int>[];
          }
          ref.read(currentPageIndexProvider.notifier).state = targetPage;
          await Future.delayed(const Duration(milliseconds: 100));
        }

        var padId = _paramString(action.params, 'targetPadId') ??
            _paramString(action.params, 'padId');
        if (padId == null) break;
        await ref.read(padPageProvider(targetPage).future);
        ref.read(padPageProvider(targetPage).notifier).onPadDown(padId);
        await Future.delayed(const Duration(milliseconds: 80));
        ref.read(padPageProvider(targetPage).notifier).onPadUp(padId);
      case MacroActionType.sendMidiNote:
        break;
      case MacroActionType.setLimiter:
        var value = _paramNum(action.params, 'value')?.toDouble();
        if (value != null) {
          ref.read(audioEngineProvider).setMasterLimiter(value);
        }
      case MacroActionType.delay:
        var ms = _paramInt(action.params, 'milliseconds') ?? 0;
        await Future.delayed(Duration(milliseconds: ms));
    }
  }
}

final macroExecutorProvider = Provider<MacroExecutor>((ref) {
  return MacroExecutor(ref);
});

num? _paramNum(Map<String, dynamic> params, String key) {
  final v = params[key];
  if (v is num) return v;
  if (v is String) return double.tryParse(v);
  return null;
}

int? _paramInt(Map<String, dynamic> params, String key) {
  final v = params[key];
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

String? _paramString(Map<String, dynamic> params, String key) {
  final v = params[key];
  return v is String ? v : null;
}
