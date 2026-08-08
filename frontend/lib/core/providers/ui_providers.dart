import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

final globalLoadingProvider = StateProvider<bool>((ref) => false);
final isEditModeProvider = StateProvider<bool>((ref) => false);

/// Volumen master compartido (barra Live + mixer).
final masterVolumeProvider = StateProvider<double>((ref) => 1.0);
final masterMuteProvider = StateProvider<bool>((ref) => false);
final preMuteVolumeProvider = StateProvider<double>((ref) => 1.0);

/// Persistencia unica para cambios provenientes del mixer, la barra Live y
/// atajos. No bloquea la respuesta de controles de audio en tiempo real.
Future<void> persistMasterVolume(double value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble('mixer_masterVolume', value.clamp(0.0, 2.0));
}
