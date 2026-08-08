// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../licensing/presentation/providers/license_providers.dart';
import '../../../../core/licensing/licensing_port.dart';
import '../../../support/presentation/screens/diagnostic_screen.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/audio/audio_output_device.dart';
import '../../../../core/audio/audio_engine_port.dart';
import '../../../../core/audio/audio_engine_state.dart';
import '../../../../core/audio/audio_initialization_result.dart';
import '../../../../core/providers/audio_providers.dart';
import '../../../../core/utils/concurrency_shield.dart';
import '../../domain/audio_change_result.dart';
import '../../../desktop/presentation/providers/desktop_providers.dart';
import '../../../desktop/domain/desktop_shortcut_resolver.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  AudioChangeResult? _audioChangeResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAudioState();
    });
  }

  void _checkAudioState() {
    final engine = ref.read(audioEngineProvider);
    if (engine.engineState == AudioEngineState.ready &&
        _audioChangeResult != null &&
        mounted) {
      setState(() => _audioChangeResult = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final license = ref.watch(licenseProvider);
    final engineState = ref.watch(audioEngineProvider).engineState;

    if (engineState == AudioEngineState.ready &&
        _audioChangeResult != null &&
        !_audioChangeResult!.isNoDevice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _audioChangeResult = null);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Sistema & Rendimiento',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.cyanAccent,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.monitor_heart, color: Colors.cyanAccent),
            title: const Text('Diagnóstico del sistema'),
            subtitle: const Text(
              'Monitoreo de CPU, Memoria y Audio Engine',
              style: TextStyle(fontSize: 11, color: Colors.white38),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DiagnosticScreen()),
            ),
          ),
          const Divider(height: 28),
          const Text(
            'Audio para DJ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.cyanAccent,
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.speaker_group_outlined,
              color: Colors.cyanAccent,
            ),
            title: const Text('Salida de audio'),
            subtitle: _buildAudioStatusSubtitle(engineState),
            trailing: _buildAudioStatusIcon(engineState),
            onTap: engineState == AudioEngineState.changingDevice
                ? null
                : () => _selectAudioOutput(context, ref),
          ),
          ListTile(
            leading: const Icon(
              Icons.memory_outlined,
              color: Colors.cyanAccent,
            ),
            title: const Text('Audios precargados en memoria'),
            subtitle: const Text(
              'No limita pads; ajusta cuántos sonidos quedan listos para disparar',
              style: TextStyle(fontSize: 11, color: Colors.white38),
            ),
            onTap: () => _selectCacheCapacity(context, ref),
          ),
          const Divider(height: 28),
          const Text(
            'Atajos de Control Maestro (Teclado)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.cyanAccent,
            ),
          ),
          const SizedBox(height: 8),
          const _MasterHotkeyTile(
            actionKey: DesktopShortcutResolver.keyStopAll,
            actionName: 'Pánico / Detener todo (STOP ALL)',
            defaultLabel: 'ESC',
            icon: Icons.stop_circle_outlined,
            color: Colors.redAccent,
          ),
          const _MasterHotkeyTile(
            actionKey: DesktopShortcutResolver.keyMuteAll,
            actionName: 'Silencio Maestro (MUTE ALL)',
            defaultLabel: 'M',
            icon: Icons.volume_off_rounded,
            color: Colors.amberAccent,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                await ref
                    .read(keyBindingsProvider.notifier)
                    .resetMasterHotkeys();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      duration: const Duration(seconds: 2),
                      content: Text(
                        'Atajos maestros restablecidos a las teclas por defecto.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Restablecer a las teclas por defecto'),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            secondary: const Icon(
              Icons.keyboard_outlined,
              color: Colors.cyanAccent,
            ),
            title: const Text('Atajos de teclado en los pads'),
            subtitle: const Text(
              'Permite disparar y mostrar atajos de teclado asignados en los pads',
              style: TextStyle(fontSize: 11, color: Colors.white38),
            ),
            value: ref.watch(
              settingsProvider.select((s) => s.enablePadShortcuts),
            ),
            onChanged: (value) => ref
                .read(settingsProvider.notifier)
                .setEnablePadShortcuts(value),
          ),
          const Divider(height: 28),
          const Text(
            'Interfaz',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.cyanAccent,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(
              Icons.dashboard_customize_outlined,
              color: Colors.cyanAccent,
            ),
            title: const Text('Tamaño de los pads'),
            subtitle: Text(
              _padSizeLabel(
                ref.watch(settingsProvider.select((s) => s.padSize)),
              ),
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            ),
            onTap: () => _selectPadSize(context, ref),
          ),
          const Divider(height: 28),
          const Text(
            'Respaldo / Backup',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.cyanAccent,
            ),
          ),
          const Divider(height: 28),
          _LicenseCard(
            license: license,
            onUpdate: () => _showUpdateLicenseDialog(context, ref),
          ),
          if (_audioChangeResult != null) ...[
            const Divider(height: 28),
            _buildAudioDeviceStatus(),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioStatusSubtitle(AudioEngineState state) {
    switch (state) {
      case AudioEngineState.ready:
        return const Text(
          'Listo para reproducir',
          style: TextStyle(fontSize: 11, color: Colors.greenAccent),
        );
      case AudioEngineState.noDevice:
        return const Text(
          'Sin dispositivos de salida',
          style: TextStyle(fontSize: 11, color: Colors.redAccent),
        );
      case AudioEngineState.error:
        return const Text(
          'Error de audio',
          style: TextStyle(fontSize: 11, color: Colors.redAccent),
        );
      case AudioEngineState.changingDevice:
        return const Text(
          'Cambiando salida...',
          style: TextStyle(fontSize: 11, color: Colors.amberAccent),
        );
      case AudioEngineState.initializing:
        return const Text(
          'Inicializando...',
          style: TextStyle(fontSize: 11, color: Colors.amberAccent),
        );
      case AudioEngineState.uninitialized:
      case AudioEngineState.disposed:
        return const Text(
          'No inicializado',
          style: TextStyle(fontSize: 11, color: Colors.white38),
        );
    }
  }

  Widget _buildAudioStatusIcon(AudioEngineState state) {
    switch (state) {
      case AudioEngineState.ready:
        return const Icon(Icons.check_circle, color: Colors.greenAccent);
      case AudioEngineState.noDevice:
        return const Icon(Icons.error, color: Colors.redAccent);
      case AudioEngineState.error:
        return const Icon(Icons.warning, color: Colors.redAccent);
      case AudioEngineState.changingDevice:
      case AudioEngineState.initializing:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case AudioEngineState.uninitialized:
      case AudioEngineState.disposed:
        return const Icon(Icons.radio_button_unchecked, color: Colors.white38);
    }
  }

  Future<void> _selectAudioOutput(BuildContext context, WidgetRef ref) async {
    if (!context.mounted) return;
    final engine = ref.read(audioEngineProvider);
    final settings = ref.read(settingsServiceProvider);
    final selectedId = settings.audioOutputDeviceId;

    final devices = await engine.listOutputDevices();
    if (!context.mounted) return;

    if (devices.isEmpty) {
      setState(() {
        _audioChangeResult = const AudioChangeResult.noDevice(
          'No se encontraron dispositivos de salida de audio. '
          'Conecta parlantes, auriculares o una interfaz de audio y vuelve a intentar.',
        );
      });
      return;
    }

    setState(() => _audioChangeResult = null);

    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Salida de audio'),
        content: SizedBox(
          width: double.maxFinite,
          child: _buildDeviceList(context, devices, selectedId),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (!context.mounted || selected == null) return;

    final deviceId = selected == -1 ? null : selected;
    if (deviceId == selectedId) return;

    final result = await _safeChangeDevice(context, ref, engine, deviceId);
    if (result != null && context.mounted) {
      setState(() => _audioChangeResult = result);
      final messenger = ScaffoldMessenger.of(context);
      if (result.isRecoverable) {
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            content: Text(result.userMessage),
            action: result.isNoDevice
                ? SnackBarAction(
                    label: 'Reintentar',
                    onPressed: () => _retry(context, ref),
                  )
                : SnackBarAction(
                    label: 'Reintentar',
                    onPressed: () => _selectAudioOutput(context, ref),
                  ),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(duration: const Duration(seconds: 2), content: Text(result.userMessage)),
        );
      }
    }
  }

  Future<void> _retry(BuildContext context, WidgetRef ref) async {
    if (!context.mounted) return;
    final engine = ref.read(audioEngineProvider);
    final settings = ref.read(settingsServiceProvider);
    final savedId = settings.audioOutputDeviceId;

    final result = await engine.retryAudioInitialization(savedId);
    ref.read(audioInitializationCacheProvider.notifier).state = result;
    if (result.state == AudioEngineState.ready) {
      if (result.savedDeviceInvalid) {
        setState(() {
          _audioChangeResult = AudioChangeResult.failure(
            result.userMessage ??
                'El dispositivo anterior no estaba disponible. Se usó la salida predeterminada.',
          );
        });
      } else {
        setState(() => _audioChangeResult = null);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(duration: const Duration(seconds: 2), content: Text('Salida de audio restablecida.')),
        );
      }
    } else if (result.state == AudioEngineState.noDevice) {
      setState(() {
        _audioChangeResult = const AudioChangeResult.noDevice(
          'No se encontró una salida de audio disponible. '
          'Conecta parlantes, auriculares o una interfaz de audio.',
        );
      });
    } else if (mounted) {
      setState(() {
        _audioChangeResult = AudioChangeResult.failure(
          result.userMessage ?? 'No se pudo recuperar la salida de audio.',
        );
      });
    }
  }

  Widget _buildAudioDeviceStatus() {
    final result = _audioChangeResult;
    if (result == null) return const SizedBox.shrink();

    final color = result.isNoDevice ? Colors.redAccent : Colors.amberAccent;
    final icon = result.isNoDevice ? Icons.error : Icons.warning;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF262B38),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                result.userMessage,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              TextButton.icon(
                onPressed: () => _retry(context, ref),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reintentar'),
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
              TextButton.icon(
                onPressed: () => _selectAudioOutput(context, ref),
                icon: const Icon(Icons.speaker_group_outlined, size: 16),
                label: const Text('Cambiar salida'),
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() => _audioChangeResult = null);
                },
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Descartar'),
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(
    BuildContext context,
    List<AudioOutputDevice> devices,
    int? selectedId,
  ) {
    return ListView(
      shrinkWrap: true,
      children: [
        RadioListTile<int>(
          value: -1,
          groupValue: selectedId ?? -1,
          title: const Text('Predeterminada del sistema'),
          onChanged: (value) => Navigator.pop(context, value),
        ),
        ...devices.map(
          (device) => _audioDeviceTile(context, device, selectedId),
        ),
      ],
    );
  }

  /// Cambia el dispositivo de salida de forma segura con protección de
  /// concurrencia y fallback automático.
  Future<AudioChangeResult?> _safeChangeDevice(
    BuildContext context,
    WidgetRef ref,
    AudioEnginePort engine,
    int? deviceId,
  ) {
    return ConcurrencyShield.run<AudioChangeResult>(
      'audio_change_device',
       () async {
        try {
          await engine.selectOutputDevice(deviceId);
          if (engine.engineState == AudioEngineState.noDevice) {
            return const AudioChangeResult.noDevice(
              'No se encontraron dispositivos de salida de audio.',
            );
          }
          if (engine.engineState == AudioEngineState.error) {
            return const AudioChangeResult.failure(
              'No se pudo cambiar la salida de audio.',
            );
          }
          await ref
              .read(settingsServiceProvider)
              .setAudioOutputDeviceId(deviceId);
          final devices = await engine.listOutputDevices();
          ref.read(audioInitializationCacheProvider.notifier).state =
              AudioInitializationResult(
                state: engine.engineState,
                devices: devices,
                appliedDeviceId: deviceId,
              );
          return const AudioChangeResult.success('Salida de audio actualizada.');
        } catch (error, st) {
          debugPrint('Audio device change failed: $error\n$st');
          return const AudioChangeResult.failure(
            'No se pudo cambiar la salida de audio.',
          );
        }
      },
    );
  }

  Future<void> _selectCacheCapacity(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsServiceProvider);
    const choices = [50, 100, 200, 500, 1000];
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Audios precargados'),
        children: choices
            .map(
              (value) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, value),
                child: Text(
                  '$value ${value == 1000 ? '(PC potente)' : ''}',
                  style: TextStyle(
                    color: value == settings.soundCacheCapacity
                        ? Colors.cyanAccent
                        : null,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (selected == null || selected == settings.soundCacheCapacity) return;
    ref.read(audioEngineProvider).setSoundCacheCapacity(selected);
    await settings.setSoundCacheCapacity(selected);
  }

  RadioListTile<int> _audioDeviceTile(
    BuildContext dialogContext,
    AudioOutputDevice device,
    int? selectedId,
  ) => RadioListTile<int>(
      value: device.id,
      groupValue: selectedId ?? -1,
      title: Text(device.name),
      subtitle:
          device.isDefault ? const Text('Predeterminada actual') : null,
      onChanged: (value) => Navigator.pop(dialogContext, value),
    );

  Future<void> _selectPadSize(BuildContext context, WidgetRef ref) async {
    const options = <int, String>{
      0: 'Auto (adaptable a la pantalla)',
      1: 'Grande',
      2: 'Mediano',
      3: 'Pequeño',
      4: 'Ultra denso',
      5: 'Extra pequeño (máxima densidad)',
    };
    final current = ref.read(settingsProvider).padSize;
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Tamaño de los pads'),
        children: options.entries
            .map(
              (entry) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, entry.key),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color: entry.key == current ? Colors.cyanAccent : null,
                    fontWeight: entry.key == current
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (selected == null || selected == current) return;
    await ref.read(settingsProvider.notifier).setPadSize(selected);
  }

  String _padSizeLabel(int value) {
    switch (value) {
      case 1:
        return 'Grande';
      case 2:
        return 'Mediano';
      case 3:
        return 'Pequeño';
      case 4:
        return 'Ultra denso';
      case 5:
        return 'Extra pequeño';
      default:
        return 'Auto';
    }
  }

  Future<void> _showUpdateLicenseDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController();
    String? validationError;
    var validating = false;
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Actualizar o renovar licencia'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Pega el nuevo código completo. Si no es válido, tu licencia actual se conservará.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 5,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    labelText: Localizations.maybeLocaleOf(context)?.languageCode == 'en'
                        ? 'SPP3 license key'
                        : 'Llave de licencia SPP3',
                    hintText: Localizations.maybeLocaleOf(context)?.languageCode == 'en'
                        ? 'Paste your SPP3 license here'
                        : 'Pega aquí tu licencia SPP3',
                    helperText: Localizations.maybeLocaleOf(context)?.languageCode == 'en'
                        ? 'Example: SPP3.<payload>.<signature>'
                        : 'Ejemplo: SPP3.<payload>.<firma>',
                    alignLabelWithHint: true,
                  ),
                ),
                if (validationError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    validationError!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: validating ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: validating
                  ? null
                  : () async {
                      final code = controller.text.trim();
                      if (code.isEmpty) {
                        setDialogState(
                          () => validationError = 'Ingresa el nuevo código.',
                        );
                        return;
                      }
                      setDialogState(() {
                        validating = true;
                        validationError = null;
                      });
                      final failure = await ref
                          .read(licenseProvider.notifier)
                          .updateLicense(code);
                      if (!dialogContext.mounted) return;
                      if (failure != null) {
                        setDialogState(() {
                          validating = false;
                          validationError = failure;
                        });
                        return;
                      }
                      Navigator.pop(dialogContext, true);
                    },
              icon: validating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user_outlined),
              label: Text(validating ? 'Validando...' : 'Validar y actualizar'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 300), controller.dispose);
    if (!context.mounted) return;
    if (updated == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(duration: const Duration(seconds: 2), content: Text('Licencia actualizada correctamente.')),
      );
    }
  }
}

class _LicenseCard extends StatelessWidget {
  const _LicenseCard({required this.license, required this.onUpdate});

  final LicenseState license;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final permanent = license.expiresAt == null;
    final statusColor = license.status == LicenseStatus.active
        ? Colors.greenAccent
        : Colors.orangeAccent;
    final details = Wrap(
      spacing: 24,
      runSpacing: 12,
      children: [
        _LicenseValue(
          label: 'Estado',
          value: license.status == LicenseStatus.active ? 'Activa' : 'Revisar',
        ),
        _LicenseValue(
          label: 'Fecha de inicio',
          value: _formatDate(license.activatedAt),
        ),
        _LicenseValue(
          label: 'Fecha final',
          value: permanent ? 'Permanente' : _formatDate(license.expiresAt),
        ),
        _LicenseValue(
          label: 'Vigencia',
          value: permanent
              ? 'Sin vencimiento'
              : '${license.remainingOfflineDays} días restantes',
        ),
        if (license.deviceId != null)
          _LicenseValue(label: 'Dispositivo', value: license.deviceId!),
      ],
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final information = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_user, color: statusColor),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Tu licencia',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                details,
              ],
            );
            final button = FilledButton.icon(
              onPressed: onUpdate,
              icon: const Icon(Icons.autorenew),
              label: const Text('Actualizar o renovar licencia'),
            );
            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [information, const SizedBox(height: 18), button],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: information),
                const SizedBox(width: 20),
                button,
              ],
            );
          },
        ),
      ),
    );
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return 'No disponible';
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _LicenseValue extends StatelessWidget {
  const _LicenseValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
}

class _MasterHotkeyTile extends ConsumerWidget {
  final String actionKey;
  final String actionName;
  final String defaultLabel;
  final IconData icon;
  final Color color;

  const _MasterHotkeyTile({
    required this.actionKey,
    required this.actionName,
    required this.defaultLabel,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bindings = ref.watch(keyBindingsProvider);
    final service = ref.read(keyBindingServiceProvider);
    final learnPad = ref.watch(keyLearnPadProvider);
    final isLearning = learnPad == actionKey;

    final defaultKeyId = actionKey == DesktopShortcutResolver.keyStopAll
        ? LogicalKeyboardKey.escape.keyId.toString()
        : LogicalKeyboardKey.keyM.keyId.toString();

    String currentLabel = defaultLabel;
    bool hasCustom = false;

    for (var entry in bindings.entries) {
      if (entry.value == actionKey) {
        currentLabel = service.labelFor(entry.key);
        if (entry.key != defaultKeyId) {
          hasCustom = true;
        }
        break;
      }
    }

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(actionName, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        isLearning
            ? 'Presiona cualquier tecla...'
            : hasCustom
                ? 'Tecla actual: [$currentLabel] (Personalizada — la tecla por defecto queda desactivada)'
                : 'Tecla actual: [$currentLabel] (Por defecto)',
        style: TextStyle(
          color: isLearning ? Colors.cyanAccent : Colors.white54,
          fontWeight: isLearning ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isLearning
              ? Colors.cyanAccent
              : const Color(0xFF262B38),
          foregroundColor: isLearning ? Colors.black : Colors.white,
        ),
        onPressed: () {
          final enableShortcuts =
              ref.read(settingsProvider).enablePadShortcuts;
          if (!enableShortcuts) {
            // Capturar los notificadores ANTES de mostrar el SnackBar: el
            // onPressed de SnackBarAction puede ejecutarse cuando este widget
            // ya se desmontó, y usar `ref` ahí lanza un StateError.
            final settingsNotifier = ref.read(settingsProvider.notifier);
            final learnNotifier = ref.read(keyLearnPadProvider.notifier);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Activa "Atajos de teclado en los pads" para poder asignar teclas.',
                ),
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Activar',
                  onPressed: () {
                    settingsNotifier.setEnablePadShortcuts(true);
                    learnNotifier.state = actionKey;
                  },
                ),
              ),
            );
            return;
          }
          ref.read(keyLearnPadProvider.notifier).state = isLearning
              ? null
              : actionKey;
        },
        child: Text(isLearning ? 'APRENDIENDO...' : 'CAMBIAR TECLA'),
      ),
    );
  }
}
