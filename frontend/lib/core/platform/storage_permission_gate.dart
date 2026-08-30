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
  /// null = verificando; true = concedido (muestra la app);
  /// false = sin permiso (muestra el portón bloqueante).
  bool? _granted;

  /// Verdadero mientras el usuario está en Ajustes otorgando el permiso.
  bool _waitingAuthorization = false;

  @override
  void initState() {
    super.initState();
    // Verificación automática al volver de Ajustes o al cerrar el diálogo
    // runtime de Android 10-.
    _lifecycleListener = AppLifecycleListener(
      onShow: _verifyAccess,
      onResume: _verifyAccess,
    );
    _verifyAccess();
  }

  late final AppLifecycleListener _lifecycleListener;

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

  void _openSystemSettings() {
    setState(() => _waitingAuthorization = true);
    SafFolderImportService.requestDirectStorageAccess();
    // Al volver de Ajustes (o cerrar el diálogo runtime) se re-verifica.
  }

  @override
  Widget build(BuildContext context) {
    final granted = _granted;
    if (granted == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepPurpleAccent),
        ),
      );
    }
    if (granted) return widget.child;
    return _BlockedPermissionScreen(
      waitingAuthorization: _waitingAuthorization,
      onGrantPressed: _openSystemSettings,
      onManualCheck: _verifyAccess,
    );
  }
}

class _BlockedPermissionScreen extends StatelessWidget {
  const _BlockedPermissionScreen({
    required this.waitingAuthorization,
    required this.onGrantPressed,
    required this.onManualCheck,
  });

  final bool waitingAuthorization;
  final VoidCallback onGrantPressed;
  final VoidCallback onManualCheck;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
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
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.library_music_rounded,
                        color: Colors.deepPurpleAccent,
                        size: 96,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Permisos necesarios',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'BDJ Studio necesita acceso a TODOS LOS ARCHIVOS para '
                    'importar tus carpetas de audios con su estructura de '
                    'subcarpetas, igual que en PC.\n\n'
                    'Sin este permiso obligatorio la aplicación no puede usarse.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  _StatusIndicator(waitingAuthorization: waitingAuthorization),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StepRow(
                          number: '1',
                          text: 'Toca el botón "Permitir acceso a archivos"',
                        ),
                        SizedBox(height: 8),
                        _StepRow(
                          number: '2',
                          text: 'Activa el interruptor "Todos los archivos" para BDJ Studio',
                        ),
                        SizedBox(height: 8),
                        _StepRow(number: '3', text: 'Regresa a la aplicación'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                      ),
                      onPressed:
                          waitingAuthorization ? onManualCheck : onGrantPressed,
                      icon: Icon(
                        waitingAuthorization
                            ? Icons.refresh_rounded
                            : Icons.folder_open_rounded,
                      ),
                      label: Text(
                        waitingAuthorization
                            ? 'Ya lo activé, verificar'
                            : 'Permitir acceso a archivos',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.waitingAuthorization});

  final bool waitingAuthorization;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String text;
    if (waitingAuthorization) {
      color = Colors.amberAccent;
      icon = Icons.hourglass_top_rounded;
      text = 'Esperando autorización... activa el interruptor en Ajustes y vuelve.';
    } else {
      color = Colors.redAccent;
      icon = Icons.gpp_bad_rounded;
      text = 'Permiso NO concedido — la aplicación está bloqueada.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.cyanAccent,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
          ),
        ),
      ],
    );
  }
}
