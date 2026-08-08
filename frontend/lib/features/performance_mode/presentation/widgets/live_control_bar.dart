import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/ui_providers.dart';
import '../../../desktop/presentation/providers/desktop_providers.dart';
import '../../../desktop/domain/desktop_shortcut_resolver.dart';
import '../../../../core/utils/concurrency_shield.dart';
import '../../../pad_system/presentation/providers/pad_providers.dart';
import '../../../workspace/presentation/providers/workspace_providers.dart';

/// Barra inferior de control maestro estilo Consola / Reproductor Pro DJ:
/// MUTE-ALL + STOP-ALL + Slider Master con reset 0dB + Indicador LED VU Meter.
class LiveControlBar extends ConsumerWidget {
  const LiveControlBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var master = ref.watch(masterVolumeProvider);
    var isMuted = ref.watch(masterMuteProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 550;
    final ultraCompact = screenWidth < 400;
    final isMobile = Platform.isAndroid || Platform.isIOS;

    final bindings = ref.watch(keyBindingsProvider);
    final service = ref.read(keyBindingServiceProvider);

    String stopLabel = 'ESC';
    String muteLabel = 'M';

    for (var entry in bindings.entries) {
      if (entry.value == DesktopShortcutResolver.keyStopAll) {
        stopLabel = service.labelFor(entry.key);
      }
      if (entry.value == DesktopShortcutResolver.keyMuteAll) {
        muteLabel = service.labelFor(entry.key);
      }
    }

    final barHeight = MediaQuery.sizeOf(context).height < 500 ? 44.0 : 56.0;

    return Container(
      height: barHeight,
      padding: EdgeInsets.symmetric(
        horizontal: ultraCompact ? 4 : (compact ? 8 : 14),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1117),
        border: const Border(
          top: BorderSide(color: Color(0xFF232836), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ⏹ STOP ALL / PANIC Button
          Tooltip(
            message: 'Detener todo el audio (Tecla $stopLabel)',
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                elevation: 6,
                padding: EdgeInsets.symmetric(
                  horizontal: ultraCompact ? 4 : (compact ? 6 : 14),
                  vertical: ultraCompact ? 4 : (compact ? 6 : 10),
                ),
                minimumSize: ultraCompact ? const Size(36, 36) : Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                ),
              ),
              icon: Icon(
                Icons.stop_rounded,
                size: ultraCompact ? 14 : (compact ? 16 : 20),
              ),
              label: Text(
                (isMobile || compact) ? 'STOP' : 'PANIC STOP [$stopLabel]',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: (isMobile || compact) ? 0.5 : 1.0,
                  fontSize: (isMobile || ultraCompact)
                      ? 11
                      : (compact ? 11 : 12),
                ),
              ),
              onPressed: () {
                final pageIndex = ref.read(currentPageIndexProvider);
                ref.read(padPageProvider(pageIndex).notifier).forceStopAll();
              },
            ),
          ),
          SizedBox(width: ultraCompact ? 4 : (compact ? 6 : 10)),

          // 🔇 MUTE ALL Button
          Tooltip(
            message: 'Mutear/Desmutear todo (Tecla $muteLabel)',
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isMuted
                    ? Colors.amberAccent
                    : const Color(0xFF262B38),
                foregroundColor: isMuted ? Colors.black : Colors.white,
                elevation: 3,
                padding: EdgeInsets.symmetric(
                  horizontal: ultraCompact ? 6 : (compact ? 8 : 14),
                  vertical: ultraCompact ? 4 : (compact ? 6 : 10),
                ),
                minimumSize: ultraCompact ? const Size(36, 36) : Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isMuted ? Colors.amberAccent : Colors.white12,
                  ),
                ),
              ),
              icon: Icon(
                isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                size: ultraCompact ? 14 : (compact ? 16 : 18),
              ),
              label: Text(
                isMuted
                    ? 'MUTED'
                    : ((isMobile || compact)
                          ? 'MUTE'
                          : 'MUTE ALL [$muteLabel]'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: (isMobile || ultraCompact)
                      ? 11
                      : (compact ? 11 : 12),
                  color: isMuted ? Colors.black : Colors.white,
                ),
              ),
              onPressed: () {
                if (!ConcurrencyShield.throttle(
                  'mute_toggle',
                  cooldown: const Duration(milliseconds: 250),
                ))
                  return;
                if (isMuted) {
                  var prev = ref.read(preMuteVolumeProvider);
                  ref.read(masterMuteProvider.notifier).state = false;
                  ref.read(masterVolumeProvider.notifier).state = prev;
                  ref.read(audioEngineProvider).setGlobalVolume(prev);
                  persistMasterVolume(prev);
                } else {
                  ref.read(preMuteVolumeProvider.notifier).state = master;
                  ref.read(masterMuteProvider.notifier).state = true;
                  ref.read(masterVolumeProvider.notifier).state = 0.0;
                  ref.read(audioEngineProvider).setGlobalVolume(0.0);
                  persistMasterVolume(0.0);
                }
              },
            ),
          ),
          SizedBox(width: ultraCompact ? 2 : (compact ? 4 : 16)),

          // Master Console Label (se oculta en pantallas angostas)
          if (!compact) ...[
            const Text(
              'MASTER',
              style: TextStyle(
                color: Colors.cyanAccent,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 10),
          ],

          // Master Volume Slider
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: isMuted ? Colors.grey : Colors.cyanAccent,
                inactiveTrackColor: Colors.white10,
                thumbColor: isMuted ? Colors.grey : Colors.cyan,
                overlayColor: Colors.cyanAccent.withValues(alpha: 0.2),
                trackHeight: ultraCompact ? 4.0 : 6.0,
                thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius: ultraCompact ? 6.0 : 8.0,
                ),
              ),
              child: Slider(
                value: master,
                onChanged: (v) {
                  if (isMuted) {
                    ref.read(masterMuteProvider.notifier).state = false;
                  }
                  ref.read(masterVolumeProvider.notifier).state = v;
                  ref.read(audioEngineProvider).setGlobalVolume(v);
                  persistMasterVolume(v);
                },
              ),
            ),
          ),

          // Indicador de Porcentaje de Volumen + VU Meter
          SizedBox(width: ultraCompact ? 2 : (compact ? 4 : 10)),
          Container(
            height: ultraCompact ? 24 : 28,
            padding: EdgeInsets.symmetric(
              horizontal: ultraCompact ? 4 : 8,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isMuted
                    ? Colors.amberAccent.withValues(alpha: 0.5)
                    : Colors.cyanAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMuted ? '0%' : '${(master * 100).round()}%',
                  style: TextStyle(
                    color: isMuted ? Colors.amberAccent : Colors.cyanAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: ultraCompact ? 10 : (compact ? 11 : 13),
                    letterSpacing: ultraCompact ? 0 : 0.5,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 8),
                  Row(
                    children: List.generate(8, (i) {
                      var level = (master * 8).round();
                      var active = i < level && !isMuted;
                      Color ledColor = i < 5
                          ? Colors.greenAccent
                          : (i < 7 ? Colors.amberAccent : Colors.redAccent);
                      return Container(
                        width: 3,
                        height: 14,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: active ? ledColor : Colors.white10,
                          borderRadius: BorderRadius.circular(1),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: ledColor.withValues(alpha: 0.6),
                                    blurRadius: 4,
                                  ),
                                ]
                              : null,
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: ultraCompact ? 2 : 6),
        ],
      ),
    );
  }
}
