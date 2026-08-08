import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/license_providers.dart';
import '../../../../core/licensing/licensing_port.dart';

class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;
  String _hardwareCode = 'Cargando...';
  String _appVersion = 'Cargando...';

  @override
  void initState() {
    super.initState();
    _loadHardwareCode();
  }

  Future<void> _loadHardwareCode() async {
    final fingerprint = await ref
        .read(licenseManagerProvider)
        .getHardwareFingerprint();
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _hardwareCode = fingerprint;
        _appVersion = packageInfo.version;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    var key = _controller.text.trim();
    if (key.isEmpty) return;

    setState(() => _isLoading = true);
    await ref.read(licenseProvider.notifier).activate(key);

    if (mounted) {
      setState(() => _isLoading = false);
    }

    if (mounted && ref.read(licenseProvider).status == LicenseStatus.active) {
      Navigator.of(context).pushReplacementNamed('/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    var licenseState = ref.watch(licenseProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isEn = Localizations.maybeLocaleOf(context)?.languageCode == 'en';

    return Scaffold(
      backgroundColor: const Color(0xFF07090D),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Container(
                width: screenWidth < 472 ? screenWidth - 32 : 440,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF131722),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.cyanAccent.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withValues(alpha: 0.15),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.purpleAccent.withValues(alpha: 0.1),
                      blurRadius: 40,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black38,
                        border: Border.all(
                          color: Colors.cyanAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Image.asset(
                        'assets/icon/logo.png',
                        height: 64,
                        width: 64,
                        errorBuilder: (ctx, err, stack) => const Icon(
                          Icons.grid_view_rounded,
                          color: Colors.cyanAccent,
                          size: 54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'BDJ STUDIO SAMPLE PAD',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'SISTEMA PROFESIONAL DJ • ACTIVACIÓN DE LICENCIA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.cyanAccent,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // HWID CARD
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0E17),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.cyanAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Aplicacion: BDJ Studio Sample Pad',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Version: $_appVersion',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'CÓDIGO DE DISPOSITIVO ÚNICO (HWID)',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white54,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SelectableText(
                              _hardwareCode,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.cyanAccent,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.cyanAccent.withValues(alpha: 0.6),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(
                              Icons.copy_rounded,
                              size: 14,
                              color: Colors.cyanAccent,
                            ),
                            label: const Text(
                              'Copiar Código HWID',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.cyanAccent,
                              ),
                            ),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: _hardwareCode),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: Color(0xFF00F0FF),
                                  content: Text(
                                    '¡Código HWID copiado al portapapeles! ✓',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (licenseState.error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          licenseState.error!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: isEn ? 'SPP3 license key' : 'Llave de licencia SPP3',
                        hintText: isEn ? 'Paste your SPP3 license here' : 'Pega aquí tu licencia SPP3',
                        helperText: isEn ? 'Example: SPP3.<payload>.<signature>' : 'Ejemplo: SPP3.<payload>.<firma>',
                        helperStyle: TextStyle(
                          color: Colors.cyanAccent.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF161C2A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.cyanAccent,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _activate(),
                    ),
                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _activate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00F0FF),
                          foregroundColor: Colors.black,
                          elevation: 6,
                          shadowColor: const Color(
                            0xFF00F0FF,
                          ).withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.black,
                              )
                            : const Text(
                                'ACTIVAR APLICACIÓN',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          color: Colors.cyanAccent,
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Licencia válida para 1 dispositivo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading) ...[
            const ModalBarrier(dismissible: false, color: Colors.black54),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF131722),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.cyanAccent.withValues(alpha: 0.5),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(color: Colors.cyanAccent),
                    SizedBox(height: 16),
                    Text(
                      'Validando licencia con el servidor...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
