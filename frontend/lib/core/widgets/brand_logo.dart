import 'package:flutter/material.dart';

/// Logo de marca decodificado al tamaño en pantalla (el PNG es 1254 px).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 104, this.radius = 22});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final px = (size * dpr).round();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurpleAccent.withValues(alpha: 0.35),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/icon/logo.png',
          width: size,
          height: size,
          cacheWidth: px,
          cacheHeight: px,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.library_music_rounded,
            color: Colors.deepPurpleAccent,
            size: size * 0.7,
          ),
        ),
      ),
    );
  }
}
