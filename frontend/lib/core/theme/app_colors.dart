import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Paleta unificada BDJ Studio ──
  static const Color background = Color(0xFF0A0C10);
  static const Color surface = Color(0xFF141822);
  static const Color surfaceLight = Color(0xFF1E2430);
  static const Color primary = Color(0xFF7C4DFF);
  static const Color primaryVariant = Color(0xFF651FFF);
  static const Color secondary = Color(0xFF00E5FF);
  static const Color accent = Color(0xFFFF4081);
  static const Color success = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFD600);
  static const Color error = Color(0xFFFF1744);
  static const Color borderSubtle = Color(0xFF1E2530);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textDisabled = Color(0xFF606060);

  static const Color padDefault = Color(0xFF42A5F5);
  static const Color padActive = Color(0xFF7C4DFF);
  static const Color padPlaying = Color(0xFF00E5FF);

   // ── Pad-specific constants ──
  static const int folderPadColor = 0xFFFF6D00;

  /// Paleta de 6 colores para pads de audio (ciclo al recibir más pads que colores).
  static const List<int> audioPadPalette = [
    0xFF7C4DFF,
    0xFF00E5FF,
    0xFFFF4081,
    0xFF00C853,
    0xFFFFD600,
    0xFFFF6D00,
  ];

  static const List<int> padPalette = [
    0xFF880E4F, // Guinda / Borgoña Vino
    0xFF9C27B0, // Morado / Púrpura
    0xFFE91E63, // Rosa / Magenta
    0xFFF44336, // Rojo Pánico / FX
    0xFFFF9800, // Naranja Drop
    0xFFFFEB3B, // Amarillo Jingle
    0xFF4CAF50, // Verde Base
    0xFF00BCD4, // Cian Lead
    0xFF2196F3, // Azul Voz
    0xFF795548, // Marrón / Moka
    0xFFE0E0E0, // Blanco / Plata
  ];
}
