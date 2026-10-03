import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'dart:math';

class ProceduralArtwork extends StatelessWidget {
  final String title;
  final String artist;
  final double size;
  final double borderRadius;
  final IconData? fallbackIcon;

  const ProceduralArtwork({
    super.key,
    required this.title,
    required this.artist,
    this.size = 50,
    this.borderRadius = 8,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    final String seedString = "$title$artist";
    final int seed = seedString.hashCode;
    final Random random = Random(seed);

    final List<Color> baseColors = [
      AppColors.primary,
      const Color(0xFF1ABC9C), // Lighter teal
      const Color(0xFF0F6456), // Darker teal
      const Color(0xFF00B4D8), // Cyan
      const Color(0xFF48CAE4), // Light Cyan
      const Color(0xFF0077B6), // Ocean Blue
      const Color(0xFF9B5DE5), // Purple
      const Color(0xFFF15BB5), // Pink
      const Color(0xFFFEE440), // Yellow (rare)
    ];

    final Color color1 = baseColors[random.nextInt(baseColors.length)];
    final Color color2 = baseColors[random.nextInt(baseColors.length)];
    final Color color3 = baseColors[random.nextInt(baseColors.length)];

    final Alignment begin =
        Alignment(random.nextDouble() * 2 - 1, random.nextDouble() * 2 - 1);
    final Alignment end =
        Alignment(random.nextDouble() * 2 - 1, random.nextDouble() * 2 - 1);

    String initials = "?";
    if (title.isNotEmpty) {
      final parts = title.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        initials = "${parts[0][0]}${parts[1][0]}".toUpperCase();
      } else {
        initials = parts[0].substring(0, min(2, parts[0].length)).toUpperCase();
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: [
            color1.withValues(alpha: 0.7),
            color2.withValues(alpha: 0.9),
            color3.withValues(alpha: 0.5),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color1.withValues(alpha: 0.3),
            blurRadius: size * 0.2,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Center(
        child: fallbackIcon != null
            ? Icon(fallbackIcon, color: Colors.white, size: size * 0.5)
            : Text(
                initials,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: size * 0.35,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(1, 1))
                    ]),
              ),
      ),
    );
  }
}
