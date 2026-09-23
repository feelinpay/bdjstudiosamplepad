import 'dart:io';

import 'package:flutter/material.dart';

import '../services/saf_folder_import_service.dart';

/// Portón OBLIGATORIO de permisos de almacenamiento (solo Android).
///
/// Igual que las grandes aplicaciones: se muestra al iniciar y bloquea el uso
/// hasta que se concede "Todos los archivos" (Android 11+) o lectura de
/// almacenamiento (Android 10-), porque sin ese acceso la app no puede
/// importar carpetas de audios. Muestra un indicador de estado claro,
/// abre Ajustes con un toque y verifica automáticamente al regresar.
///
/// En escritorio/iOS es transparente: entrega [child] directamente.
class StoragePermissionGate extends StatefulWidget {
  const StoragePermissionGate({super.key, required this.child});

  final Widget child;

  @override
  State<StoragePermissionGate> createState() => _StoragePermissionGateState();
}

class _StoragePermissionGateState extends State<StoragePermissionGate> {
  bool? _granted;
  bool _dismissed = false;
  bool _waitingAuthorization = false;

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onShow: _verifyAccess,
      onResume: _verifyAccess,
    );
    _verifyAccess();
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _verifyAccess() async {
    var granted = !Platform.isAndroid;
    if (Platform.isAndroid) {
      try {
        granted = await SafFolderImportService.isDirectStorageAccessGranted();
      } catch (error) {
        debugPrint('[StorageGate] No se pudo consultar el permiso: $error');
        granted = false;
      }
    }
    if (!mounted) return;
    setState(() {
      _granted = granted;
      _waitingAuthorization = false;
    });
  }

  void _requestPermission() {
    setState(() => _waitingAuthorization = true);
    SafFolderImportService.requestDirectStorageAccess();
  }

  void _openSettings() {
    setState(() => _waitingAuthorization = true);
    SafFolderImportService.openAppSettings();
  }

  void _continueToApp() {
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) return widget.child;

    final granted = _granted;
    if (granted == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
        ),
      );
    }

    if (granted || _dismissed) return widget.child;

    return _PermissionRequestScreen(
      waitingAuthorization: _waitingAuthorization,
      onRequestPressed: _requestPermission,
      onOpenSettings: _openSettings,
      onContinuePressed: _continueToApp,
      onManualCheck: _verifyAccess,
    );
  }
}

class _PermissionRequestScreen extends StatelessWidget {
  const _PermissionRequestScreen({
    required this.waitingAuthorization,
    required this.onRequestPressed,
    required this.onOpenSettings,
    required this.onContinuePressed,
    required this.onManualCheck,
  });

  final bool waitingAuthorization;
  final VoidCallback onRequestPressed;
  final VoidCallback onOpenSettings;
  final VoidCallback onContinuePressed;
  final VoidCallback onManualCheck;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/icon/logo.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.library_music_rounded,
                      color: Colors.deepPurpleAccent,
                      size: 80,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Acceso a Audio y Samples',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Para cargar tus propios samples, kits y música desde tu dispositivo, '
                  'BDJ Studio necesita permiso de acceso a archivos de audio.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onRequestPressed,
                    icon: const Icon(Icons.music_note_rounded),
                    label: const Text(
                      'Permitir acceso a música y audio',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Abrir Ajustes de la aplicación'),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: onContinuePressed,
                  child: const Text(
                    'Continuar a la aplicación',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
