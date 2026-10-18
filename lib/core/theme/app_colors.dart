import 'package:flutter/material.dart';
import 'tactile_tokens.dart';

class AppColors {
  // Neo-Hardware Signal Colors
  static const Color primary = TactileTokens.vermilion; // Electric Vermilion (#FF4F28)
  static const Color primaryDark = Color(0xFFE03E18);
  static const Color tealAccent = Color(0xFF64FFDA);

  // Surfaces
  static const Color background = TactileTokens.canvas; // Deep Obsidian (#090A0C)
  static const Color surface = TactileTokens.surface; // Matte Carbon (#121418)
  static const Color surfaceLight = TactileTokens.surfacePressed; // Tactile Slate (#1A1D24)
  static const Color surfaceRaised = TactileTokens.surfaceRaised; // (#16191F)
  static const Color surfaceGlass = Color(0x14FFFFFF);

  // Typography
  static const Color textPrimary = TactileTokens.textPrimary;
  static const Color textSecondary = TactileTokens.textSecondary;
  static const Color textTertiary = TactileTokens.textMuted;

  // Semantic Status
  static const Color error = TactileTokens.crimson; // Crimson Pulse (#F43F5E)
  static const Color success = TactileTokens.mint; // Emerald Mint (#10B981)
  static const Color warning = TactileTokens.amber; // Amber Warning (#F59E0B)

  // Category Colors
  static const Color health = TactileTokens.crimson;
  static const Color productivity = TactileTokens.vermilion;
  static const Color learning = TactileTokens.cyan;
  static const Color fitness = TactileTokens.mint;
  static const Color hobby = TactileTokens.violet;

  // Specular Border & Subtle Glow
  static const Color glassBorder = TactileTokens.specularBorder; // 1px specular rgba(255, 255, 255, 0.07)
  static const Color primaryGlow = Color(0x33FF4F28);
}

