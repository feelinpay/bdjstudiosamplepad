import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/ui_providers.dart';
import '../../../pad_system/presentation/providers/pad_providers.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../providers/desktop_providers.dart';
import '../../domain/desktop_shortcut_resolver.dart';

class DesktopShortcuts extends ConsumerStatefulWidget {
  final Widget child;
  const DesktopShortcuts({super.key, required this.child});

  @override
  ConsumerState<DesktopShortcuts> createState() => _DesktopShortcutsState();
}

class _DesktopShortcutsState extends ConsumerState<DesktopShortcuts> {
  final Set<int> _pressedKeys = {};

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _pressedKeys.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  bool _shouldBypassShortcuts() {
    if (_pressedKeys.isNotEmpty) return false;

    final focus = FocusManager.instance.primaryFocus;
    if (focus?.context == null) return false;
    final ctx = focus!.context!;
    if (ctx.widget is EditableText ||
        ctx.widget is TextField ||
        ctx.widget is TextFormField)
      return true;

    bool found = false;
    ctx.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is EditableText ||
          widget is TextField ||
          widget is TextFormField) {
        found = true;
        return false;
      }
      if (widget is Dialog ||
          widget is AlertDialog ||
          widget is BottomSheet ||
          widget is MenuBar ||
          widget is ModalBarrier) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyRepeatEvent) return false;
    if (_shouldBypassShortcuts()) return false;

    var key = event.logicalKey;
    var keyId = key.keyId.toString();

    final pageIndex = ref.read(currentPageIndexProvider);
    final workspaceId = ref.read(currentWorkspaceIdProvider);
    final isEditMode = ref.read(isEditModeProvider);
    final enableShortcuts = ref.read(settingsProvider).enablePadShortcuts;
    final bindings = ref.read(keyBindingsProvider);
    final boundPadId = workspaceId == null
        ? null
        : ref
              .read(keyBindingsProvider.notifier)
              .padForKey(
                workspaceId: workspaceId,
                pageIndex: pageIndex,
                keyId: keyId,
              );

    if (event is KeyDownEvent) {
      _pressedKeys.add(key.keyId);

      if (key == LogicalKeyboardKey.escape) {
        var learnPad = ref.read(keyLearnPadProvider);
        // ESC cancels learn mode for pads, but is assignable to master actions
        if (learnPad != null && !learnPad.startsWith('action_')) {
          ref.read(keyLearnPadProvider.notifier).state = null;
          return true;
        }
      }

      var learnPad = ref.read(keyLearnPadProvider);
      if (learnPad != null) {
        // Arrow keys can't be bound to anything
        if (key != LogicalKeyboardKey.arrowLeft &&
            key != LogicalKeyboardKey.arrowRight &&
            key != LogicalKeyboardKey.arrowUp &&
            key != LogicalKeyboardKey.arrowDown) {
          // bind() is fire-and-forget (persists to SharedPreferences async).
          // For pads, reserved keys return false but we still exit learn mode;
          // for master actions, reserved keys are now allowed.
          ref
              .read(keyBindingsProvider.notifier)
              .bind(
                keyId,
                learnPad,
                workspaceId: workspaceId ?? 0,
                pageIndex: pageIndex,
              );
        }
        ref.read(keyLearnPadProvider.notifier).state = null;
        return true;
      }

      if (enableShortcuts &&
          !isEditMode &&
          boundPadId != null &&
          !boundPadId.startsWith('action_')) {
        _triggerPad(boundPadId, true);
        return true;
      }

      final action = DesktopShortcutResolver.resolve(
        key,
        customBindings: bindings,
      );
      switch (action) {
        case DesktopAction.stopAll:
          ref.read(padPageProvider(pageIndex).notifier).forceStopAll();
          _pressedKeys.clear();
          return true;
        case DesktopAction.muteAll:
          var isMuted = ref.read(masterMuteProvider);
          if (isMuted) {
            var prev = ref.read(preMuteVolumeProvider);
            ref.read(masterMuteProvider.notifier).state = false;
            ref.read(masterVolumeProvider.notifier).state = prev;
            ref.read(audioEngineProvider).setGlobalVolume(prev);
            persistMasterVolume(prev);
          } else {
            var current = ref.read(masterVolumeProvider);
            ref.read(preMuteVolumeProvider.notifier).state = current;
            ref.read(masterMuteProvider.notifier).state = true;
            ref.read(masterVolumeProvider.notifier).state = 0.0;
            ref.read(audioEngineProvider).setGlobalVolume(0.0);
            persistMasterVolume(0.0);
          }
          return true;
        case DesktopAction.nextPage:
        case DesktopAction.prevPage:
          _goBack();
          return true;
        case DesktopAction.none:
          return false;
      }
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(key.keyId);

      if (!isEditMode &&
          enableShortcuts &&
          boundPadId != null &&
          !boundPadId.startsWith('action_')) {
        _triggerPad(boundPadId, false);
        return true;
      }
    }
    return false;
  }

  void _triggerPad(String padId, bool down) {
    if (!down) {
      var pageIndex = ref.read(currentPageIndexProvider);
      var notifier = ref.read(padPageProvider(pageIndex).notifier);
      notifier.onPadUp(padId);
      return;
    }
    var pageIndex = ref.read(currentPageIndexProvider);
    var notifier = ref.read(padPageProvider(pageIndex).notifier);

    final asyncPads = ref.read(padPageProvider(pageIndex));
    final pads = asyncPads.whenOrNull(data: (d) => d);
    if (pads != null) {
      final pad = pads.where((p) => p.id == padId).firstOrNull;
      if (pad != null && pad.isFolder && pad.targetPageIndex != null) {
        SafeFolderNavigator.openFolder(ref, pageIndex, pad.targetPageIndex!);
        return;
      }
    }

    notifier.onPadDown(padId);
  }

  void _goBack() {
    var current = ref.read(currentPageIndexProvider);
    if (current < 1000) return;
    SafeFolderNavigator.goBack(ref);
  }
}
