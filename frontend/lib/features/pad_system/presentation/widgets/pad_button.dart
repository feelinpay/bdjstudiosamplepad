import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/pad_entity.dart';
import '../../../../core/audio/trigger_mode.dart';
import '../providers/pad_providers.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../desktop/presentation/providers/desktop_providers.dart';
import '../../../../core/providers/ui_providers.dart';
import '../../../../core/utils/concurrency_shield.dart';

class PadButton extends ConsumerWidget {
  final PadEntity pad;
  final int pageIndex;

  const PadButton({super.key, required this.pad, required this.pageIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var isPlaying = pad.state == PadState.playing;
    var isQueued = pad.state == PadState.queued;
    var hasBackground =
        pad.backgroundImagePath != null && pad.backgroundImagePath!.isNotEmpty;
    var isHighContrast = ref.watch(
      settingsProvider.select((s) => s.highContrast),
    );
    var fontScale = ref.watch(settingsProvider.select((s) => s.fontScale));
    var hasSample = pad.sampleId != null && pad.sampleId!.isNotEmpty;
    var isFolder = pad.type == PadType.folder;
    var baseColor = (hasSample || isFolder)
        ? Color(pad.colorHex)
        : const Color(0xFF2A2E39);
    var velocity = ref.watch(
      padVelocityProvider.select((m) => m[pad.id] ?? 1.0),
    );
    var keyLabel = ref.watch(padKeyLabelsProvider.select((m) => m[pad.id]));
    var enableShortcuts = ref.watch(
      settingsProvider.select((s) => s.enablePadShortcuts),
    );

    var isEditMode = ref.watch(isEditModeProvider);
    final isMobile = Platform.isAndroid || Platform.isIOS;

    return LayoutBuilder(
      builder: (context, constraints) {
        final padW = constraints.maxWidth;
        final padH = constraints.maxHeight;
        final minDim = padW < padH ? padW : padH;

        final dynamicFontSize = ((minDim * 0.12).clamp(12.0, 22.0)) * fontScale;
        final dynamicIconSize = (minDim * 0.26).clamp(10.0, 48.0);
        final maxLines = minDim > 120 ? 3 : 2;
        final showIcon = minDim > 55;

        return Listener(
          onPointerDown: (event) {
            try {
              if (isEditMode || ref.read(padMoveSourceProvider) != null) return;
              if (event.buttons != kPrimaryButton) return;
              HapticFeedback.lightImpact();

              // Carpeta: navegar de forma segura con SafeFolderNavigator y protección contra spam
              if (isFolder && pad.targetPageIndex != null) {
                if (!ConcurrencyShield.throttle(
                  'folder_tap_${pad.targetPageIndex}',
                  cooldown: const Duration(milliseconds: 300),
                ))
                  return;
                SafeFolderNavigator.openFolder(
                  ref,
                  pageIndex,
                  pad.targetPageIndex!,
                );
                return;
              }

              ref.read(padPageProvider(pageIndex).notifier).onPadDown(pad.id);
            } catch (_) {}
          },
          onPointerUp: (event) {
            try {
              if (isEditMode || ref.read(padMoveSourceProvider) != null) return;
              if (isFolder) return;
              ref.read(padPageProvider(pageIndex).notifier).onPadUp(pad.id);
            } catch (_) {}
          },
          onPointerCancel: (_) {
            try {
              if (isEditMode || ref.read(padMoveSourceProvider) != null) return;
              if (isFolder) return;
              ref.read(padPageProvider(pageIndex).notifier).onPadUp(pad.id);
            } catch (_) {}
          },
          child: RepaintBoundary(
            child: Container(
              margin: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: hasBackground ? baseColor : null,
                gradient: hasBackground
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isPlaying
                            ? [
                                Color.lerp(baseColor, Colors.white, 0.45)!,
                                Color.lerp(baseColor, Colors.white, 0.15)!,
                              ]
                            : isQueued
                            ? [
                                baseColor.withValues(alpha: 0.85),
                                Color.lerp(baseColor, Colors.black, 0.4)!,
                              ]
                            : (hasSample || isFolder)
                            ? [
                                Color.lerp(baseColor, Colors.white, 0.1)!,
                                Color.lerp(baseColor, Colors.black, 0.35)!,
                              ]
                            : [
                                const Color(0xFF262B36),
                                const Color(0xFF14171E),
                              ],
                      ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isPlaying
                      ? (isHighContrast
                            ? Colors.yellowAccent
                            : Colors.cyanAccent)
                      : (hasSample || isFolder
                            ? baseColor.withValues(alpha: 0.7)
                            : const Color(0xFF384050)),
                  width: isPlaying ? 2.5 : 1.5,
                ),
                boxShadow: isPlaying
                    ? (isMobile
                          ? [
                              BoxShadow(
                                color: baseColor.withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: baseColor.withValues(
                                  alpha: (0.8 * velocity).clamp(0.4, 1.0),
                                ),
                                blurRadius: 20 * velocity,
                                spreadRadius: 2 * velocity,
                              ),
                              BoxShadow(
                                color: Colors.cyanAccent.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ])
                    : (isMobile
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ]),
                image: hasBackground
                    ? DecorationImage(
                        image: FileImage(File(pad.backgroundImagePath!)),
                        fit: BoxFit.cover,
                        opacity: isPlaying ? 0.8 : 0.45,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: hasBackground
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.3),
                                Colors.black.withValues(alpha: 0.75),
                              ],
                            ),
                          )
                        : null,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: _buildContent(
                          showIcon: showIcon,
                          dynamicIconSize: dynamicIconSize,
                          dynamicFontSize: dynamicFontSize,
                          maxLines: maxLines,
                          isHighContrast: isHighContrast,
                          isPlaying: isPlaying,
                          hasSample: hasSample,
                          isFolder: isFolder,
                          minDim: minDim,
                        ),
                      ),
                    ),
                  ),

                  // Mode badge (Loop, Gate, Toggle, Hold) — hide on tiny pads
                  if (minDim > 50 &&
                      hasSample &&
                      pad.playMode != TriggerMode.oneShot)
                    Positioned(
                      bottom: 5,
                      right: 6,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: minDim > 80 ? 5 : 3,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.cyanAccent.withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          pad.playMode.name.toUpperCase(),
                          style: TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: minDim > 80 ? 8.5 : 7.0,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                  // Keybinding indicator (top-right) — hide on tiny pads or if disabled
                  if (minDim > 50 && keyLabel != null && enableShortcuts)
                    Positioned(
                      top: 5,
                      right: 6,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: minDim > 80 ? 6 : 3,
                          vertical: minDim > 80 ? 2 : 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: Colors.amberAccent.withValues(alpha: 0.8),
                            width: minDim > 80 ? 1.2 : 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          keyLabel,
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontSize: minDim > 80 ? 10.5 : 8.0,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                  // Individual Stop button (top-left) - visible when playing
                  if (isPlaying)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          var currentPageIndex = ref.read(
                            currentPageIndexProvider,
                          );
                          ref
                              .read(padPageProvider(currentPageIndex).notifier)
                              .forceStop(pad.id);
                        },
                        child: Container(
                          width: minDim > 80 ? 22.0 : 16.0,
                          height: minDim > 80 ? 22.0 : 16.0,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF1744),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withValues(alpha: 0.8),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.stop_rounded,
                            color: Colors.white,
                            size: minDim > 80 ? 14.0 : 10.0,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent({
    required bool showIcon,
    required double dynamicIconSize,
    required double dynamicFontSize,
    required int maxLines,
    required bool isHighContrast,
    required bool isPlaying,
    required bool hasSample,
    required bool isFolder,
    required double minDim,
  }) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showIcon && pad.type == PadType.folder) ...[
          Icon(
            Icons.folder_open_rounded,
            color: isHighContrast ? Colors.yellowAccent : Colors.orangeAccent,
            size: dynamicIconSize,
          ),
          const SizedBox(height: 4),
        ],
        Text(
          pad.label.isEmpty
              ? 'PAD ${pad.index + 1}'
              : pad.label.replaceAll('_', ' ').trim(),
          textAlign: TextAlign.center,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isPlaying
                ? Colors.white
                : (hasSample || isFolder ? Colors.white : Colors.white54),
            fontWeight: FontWeight.w800,
            fontSize: dynamicFontSize,
            letterSpacing: 0.2,
            height: 1.15,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.9),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );

    // En pads muy pequeños el contenido se escala para caber sin desbordar.
    if (minDim <= 100) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: content,
      );
    }
    return content;
  }
}
