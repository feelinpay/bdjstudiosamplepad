import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/midi_providers.dart';

class MidiStatusIcon extends ConsumerWidget {
  const MidiStatusIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var connectedDevice = ref.watch(connectedMidiDeviceProvider);
    var isConnected = connectedDevice != null;

    return IconButton(
      icon: Icon(
        Icons.usb,
        color: isConnected ? Colors.greenAccent : Colors.grey,
      ),
      tooltip: isConnected ? 'MIDI: ${connectedDevice.name}' : 'Conectar MIDI',
      onPressed: () {
        _showMidiDevicesBottomSheet(context, ref);
      },
    );
  }

  void _showMidiDevicesBottomSheet(BuildContext context, WidgetRef ref) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, child) {
            var devicesAsync = ref.watch(midiDevicesProvider);
            var connectedDevice = ref.watch(connectedMidiDeviceProvider);

            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: screenHeight * 0.65),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Dispositivos MIDI Disponibles',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(color: Colors.white24),
                    Row(
                      children: [
                        Flexible(
                          child: TextButton.icon(
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text(
                              'Importar',
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () async {
                              bool success = await ref
                                  .read(midiControllerProvider)
                                  .importMidiProfile();
                              if (success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    duration: const Duration(seconds: 2),
                                    content: Text('Perfil MIDI Importado'),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        Flexible(
                          child: TextButton.icon(
                            icon: const Icon(Icons.upload, size: 16),
                            label: const Text(
                              'Exportar',
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () async {
                              String? path = await ref
                                  .read(midiControllerProvider)
                                  .exportMidiProfile();
                              if (path != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(duration: const Duration(seconds: 2), content: Text('Guardado en: $path')),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    Flexible(
                      child: devicesAsync.when(
                        data: (devices) {
                          if (devices.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                'No se encontraron dispositivos.',
                                style: TextStyle(color: Colors.white54),
                              ),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: devices.length,
                            itemBuilder: (ctx, index) {
                              var device = devices[index];
                              var isThisConnected =
                                  connectedDevice?.name == device.name;

                              return ListTile(
                                leading: Icon(
                                  device.type.toString().toLowerCase().contains(
                                        'ble',
                                      )
                                      ? Icons.bluetooth
                                      : Icons.usb,
                                  color: isThisConnected
                                      ? Colors.greenAccent
                                      : Colors.white,
                                ),
                                title: Text(
                                  device.name,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  device.id,
                                  style: const TextStyle(color: Colors.white54),
                                ),
                                trailing: isThisConnected
                                    ? TextButton(
                                        onPressed: () {
                                          ref
                                              .read(midiControllerProvider)
                                              .disconnect(device);
                                        },
                                        child: const Text(
                                          'Desconectar',
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      )
                                    : TextButton(
                                        onPressed: () {
                                          ref
                                              .read(midiControllerProvider)
                                              .connect(device);
                                          Navigator.pop(context);
                                        },
                                        child: const Text(
                                          'Conectar',
                                          style: TextStyle(
                                            color: Colors.greenAccent,
                                          ),
                                        ),
                                      ),
                              );
                            },
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, st) => Text(
                          'Error: $e',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
