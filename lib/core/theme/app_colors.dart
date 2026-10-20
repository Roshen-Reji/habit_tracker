import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Available color scheme presets for the application.
enum AppColorSchemePreset {
  monochrome,
  obsidianEmerald,
  cobaltPulse,
  solarAmber,
  crimsonEditorial,
  violetNebula;

  static AppColorSchemePreset fromString(String? value) {
    if (value == null) return AppColorSchemePreset.monochrome;
    return AppColorSchemePreset.values.firstWhere(
      (preset) => preset.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AppColorSchemePreset.monochrome,
    );
  }

  String get displayName {
    switch (this) {
      case AppColorSchemePreset.monochrome:
        return 'Monochrome B&W';
      case AppColorSchemePreset.obsidianEmerald:
        return 'Obsidian Emerald';
      case AppColorSchemePreset.cobaltPulse:
        return 'Cobalt Pulse';
      case AppColorSchemePreset.solarAmber:
        return 'Solar Amber';
      case AppColorSchemePreset.crimsonEditorial:
        return 'Crimson Editorial';
      case AppColorSchemePreset.violetNebula:
        return 'Violet Nebula';
    }
  }

  Color get swatchColor {
    switch (this) {
      case AppColorSchemePreset.monochrome:
        return const Color(0xFFFFFFFF);
      case AppColorSchemePreset.obsidianEmerald:
        return const Color(0xFF10B981);
      case AppColorSchemePreset.cobaltPulse:
        return const Color(0xFF3B82F6);
      case AppColorSchemePreset.solarAmber:
        return const Color(0xFFF59E0B);
      case AppColorSchemePreset.crimsonEditorial:
        return const Color(0xFFF43F5E);
      case AppColorSchemePreset.violetNebula:
        return const Color(0xFF8B5CF6);
    }
  }

  PresetPalette get palette => PresetPalette.forPreset(this);
}

/// Immutable color palette specification for dark and light modes of a preset.
class PresetPalette {
  final AppColorSchemePreset preset;
  final Color darkBackground;
  final Color darkSurface;
  final Color darkSurfaceElevated;
  final Color darkBorder;
  final Color darkPrimary;
  final Color darkOnPrimary;
  final Color darkPrimaryContainer;
  final Color darkOnPrimaryContainer;
  final Color darkSecondary;
  final Color darkTextPrimary;
  final Color darkTextSecondary;

  final Color lightBackground;
  final Color lightSurface;
  final Color lightSurfaceElevated;
  final Color lightBorder;
  final Color lightPrimary;
  final Color lightOnPrimary;
  final Color lightPrimaryContainer;
  final Color lightOnPrimaryContainer;
  final Color lightSecondary;
  final Color lightTextPrimary;
  final Color lightTextSecondary;

  const PresetPalette({
    required this.preset,
    required this.darkBackground,
    required this.darkSurface,
    required this.darkSurfaceElevated,
    required this.darkBorder,
    required this.darkPrimary,
    required this.darkOnPrimary,
    required this.darkPrimaryContainer,
    required this.darkOnPrimaryContainer,
    required this.darkSecondary,
    required this.darkTextPrimary,
    required this.darkTextSecondary,
    required this.lightBackground,
    required this.lightSurface,
    required this.lightSurfaceElevated,
    required this.lightBorder,
    required this.lightPrimary,
    required this.lightOnPrimary,
    required this.lightPrimaryContainer,
    required this.lightOnPrimaryContainer,
    required this.lightSecondary,
    required this.lightTextPrimary,
    required this.lightTextSecondary,
  });

  static PresetPalette forPreset(AppColorSchemePreset preset) {
    // Material 3 Expressive Tonal Surfaces
    const darkBg = Color(0xFF0E1113);
    const darkSurf = Color(0xFF1B2024);
    const darkSurfElevated = Color(0xFF242A2F);
    const darkBrd = Color(0xFF282F35);
    const darkTxtPrimary = Color(0xFFF1F4F7);
    const darkTxtSecondary = Color(0xFFA2ACB5);

    const lightBg = Color(0xFFF7F9FC);
    const lightSurf = Color(0xFFEBEEF3);
    const lightSurfElevated = Color(0xFFE3E7ED);
    const lightBrd = Color(0xFFC2C7CE);
    const lightTxtPrimary = Color(0xFF111417);
    const lightTxtSecondary = Color(0xFF444C54);

    switch (preset) {
      case AppColorSchemePreset.monochrome:
        return const PresetPalette(
          preset: AppColorSchemePreset.monochrome,
          darkBackground: Color(0xFF0A0A0A),
          darkSurface: Color(0xFF1C1C1E),
          darkSurfaceElevated: Color(0xFF2C2C2E),
          darkBorder: Color(0xFF48484A),
          darkPrimary: Color(0xFFFFFFFF),
          darkOnPrimary: Color(0xFF000000),
          darkPrimaryContainer: Color(0xFF3A3A3C),
          darkOnPrimaryContainer: Color(0xFFF2F2F7),
          darkSecondary: Color(0xFFAEAEB2),
          darkTextPrimary: Color(0xFFF2F2F7),
          darkTextSecondary: Color(0xFFAEAEB2),
          lightBackground: Color(0xFFF5F5F7),
          lightSurface: Color(0xFFEBEBF0),
          lightSurfaceElevated: Color(0xFFD8D8DC),
          lightBorder: Color(0xFFC7C7CC),
          lightPrimary: Color(0xFF111111),
          lightOnPrimary: Color(0xFFFFFFFF),
          lightPrimaryContainer: Color(0xFFE5E5EA),
          lightOnPrimaryContainer: Color(0xFF1C1C1E),
          lightSecondary: Color(0xFF636366),
          lightTextPrimary: Color(0xFF111111),
          lightTextSecondary: Color(0xFF636366),
        );

      case AppColorSchemePreset.obsidianEmerald:
        return const PresetPalette(
          preset: AppColorSchemePreset.obsidianEmerald,
          darkBackground: darkBg,
          darkSurface: darkSurf,
          darkSurfaceElevated: darkSurfElevated,
          darkBorder: darkBrd,
          darkPrimary: Color(0xFF10B981),
          darkOnPrimary: Color(0xFF003822),
          darkPrimaryContainer: Color(0xFF005234),
          darkOnPrimaryContainer: Color(0xFF66FEBA),
          darkSecondary: Color(0xFF34D399),
          darkTextPrimary: darkTxtPrimary,
          darkTextSecondary: darkTxtSecondary,
          lightBackground: lightBg,
          lightSurface: lightSurf,
          lightSurfaceElevated: lightSurfElevated,
          lightBorder: lightBrd,
          lightPrimary: Color(0xFF059669),
          lightOnPrimary: Color(0xFFFFFFFF),
          lightPrimaryContainer: Color(0xFF86F8CA),
          lightOnPrimaryContainer: Color(0xFF002113),
          lightSecondary: Color(0xFF10B981),
          lightTextPrimary: lightTxtPrimary,
          lightTextSecondary: lightTxtSecondary,
        );

      case AppColorSchemePreset.cobaltPulse:
        return const PresetPalette(
          preset: AppColorSchemePreset.cobaltPulse,
          darkBackground: darkBg,
          darkSurface: darkSurf,
          darkSurfaceElevated: darkSurfElevated,
          darkBorder: darkBrd,
          darkPrimary: Color(0xFF3B82F6),
          darkOnPrimary: Color(0xFF002B75),
          darkPrimaryContainer: Color(0xFF0040A8),
          darkOnPrimaryContainer: Color(0xFFD8E2FF),
          darkSecondary: Color(0xFF60A5FA),
          darkTextPrimary: darkTxtPrimary,
          darkTextSecondary: darkTxtSecondary,
          lightBackground: lightBg,
          lightSurface: lightSurf,
          lightSurfaceElevated: lightSurfElevated,
          lightBorder: lightBrd,
          lightPrimary: Color(0xFF2563EB),
          lightOnPrimary: Color(0xFFFFFFFF),
          lightPrimaryContainer: Color(0xFFDBE4FF),
          lightOnPrimaryContainer: Color(0xFF001B4B),
          lightSecondary: Color(0xFF3B82F6),
          lightTextPrimary: lightTxtPrimary,
          lightTextSecondary: lightTxtSecondary,
        );

      case AppColorSchemePreset.solarAmber:
        return const PresetPalette(
          preset: AppColorSchemePreset.solarAmber,
          darkBackground: darkBg,
          darkSurface: darkSurf,
          darkSurfaceElevated: darkSurfElevated,
          darkBorder: darkBrd,
          darkPrimary: Color(0xFFF59E0B),
          darkOnPrimary: Color(0xFF432C00),
          darkPrimaryContainer: Color(0xFF624000),
          darkOnPrimaryContainer: Color(0xFFFFDDB0),
          darkSecondary: Color(0xFFFBBF24),
          darkTextPrimary: darkTxtPrimary,
          darkTextSecondary: darkTxtSecondary,
          lightBackground: lightBg,
          lightSurface: lightSurf,
          lightSurfaceElevated: lightSurfElevated,
          lightBorder: lightBrd,
          lightPrimary: Color(0xFFD97706),
          lightOnPrimary: Color(0xFFFFFFFF),
          lightPrimaryContainer: Color(0xFFFFDDB0),
          lightOnPrimaryContainer: Color(0xFF2B1700),
          lightSecondary: Color(0xFFF59E0B),
          lightTextPrimary: lightTxtPrimary,
          lightTextSecondary: lightTxtSecondary,
        );

      case AppColorSchemePreset.crimsonEditorial:
        return const PresetPalette(
          preset: AppColorSchemePreset.crimsonEditorial,
          darkBackground: darkBg,
          darkSurface: darkSurf,
          darkSurfaceElevated: darkSurfElevated,
          darkBorder: darkBrd,
          darkPrimary: Color(0xFFF43F5E),
          darkOnPrimary: Color(0xFF4C0015),
          darkPrimaryContainer: Color(0xFF6E0022),
          darkOnPrimaryContainer: Color(0xFFFFD9DF),
          darkSecondary: Color(0xFFFB7185),
          darkTextPrimary: darkTxtPrimary,
          darkTextSecondary: darkTxtSecondary,
          lightBackground: lightBg,
          lightSurface: lightSurf,
          lightSurfaceElevated: lightSurfElevated,
          lightBorder: lightBrd,
          lightPrimary: Color(0xFFE11D48),
          lightOnPrimary: Color(0xFFFFFFFF),
          lightPrimaryContainer: Color(0xFFFFD9DF),
          lightOnPrimaryContainer: Color(0xFF3F0010),
          lightSecondary: Color(0xFFF43F5E),
          lightTextPrimary: lightTxtPrimary,
          lightTextSecondary: lightTxtSecondary,
        );

      case AppColorSchemePreset.violetNebula:
        return const PresetPalette(
          preset: AppColorSchemePreset.violetNebula,
          darkBackground: darkBg,
          darkSurface: darkSurf,
          darkSurfaceElevated: darkSurfElevated,
          darkBorder: darkBrd,
          darkPrimary: Color(0xFF8B5CF6),
          darkOnPrimary: Color(0xFF2E0066),
          darkPrimaryContainer: Color(0xFF470099),
          darkOnPrimaryContainer: Color(0xFFEADBFF),
          darkSecondary: Color(0xFFA78BFA),
          darkTextPrimary: darkTxtPrimary,
          darkTextSecondary: darkTxtSecondary,
          lightBackground: lightBg,
          lightSurface: lightSurf,
          lightSurfaceElevated: lightSurfElevated,
          lightBorder: lightBrd,
          lightPrimary: Color(0xFF7C3AED),
          lightOnPrimary: Color(0xFFFFFFFF),
          lightPrimaryContainer: Color(0xFFEADBFF),
          lightOnPrimaryContainer: Color(0xFF250059),
          lightSecondary: Color(0xFF8B5CF6),
          lightTextPrimary: lightTxtPrimary,
          lightTextSecondary: lightTxtSecondary,
        );
    }
  }
}

class AppColors {
  // M3 Expressive Tonal Tokens - Dark Mode
  static const Color darkSurface = Color(0xFF0E1113);
  static const Color darkSurfaceContainerLowest = Color(0xFF090B0D);
  static const Color darkSurfaceContainerLow = Color(0xFF15191C);
  static const Color darkSurfaceContainer = Color(0xFF1B2024);
  static const Color darkSurfaceContainerHigh = Color(0xFF242A2F);
  static const Color darkSurfaceContainerHighest = Color(0xFF2F363C);
  static const Color darkOnSurface = Color(0xFFF1F4F7);
  static const Color darkOnSurfaceVariant = Color(0xFFA2ACB5);
  static const Color darkPrimary = Color(0xFF5CE1E6);
  static const Color darkOnPrimary = Color(0xFF00363A);
  static const Color darkPrimaryContainer = Color(0xFF004F54);
  static const Color darkOnPrimaryContainer = Color(0xFF9DF4F8);
  static const Color darkSecondaryContainer = Color(0xFF324655);
  static const Color darkOnSecondaryContainer = Color(0xFFCEE5F6);
  static const Color darkTertiaryContainer = Color(0xFF5C3B1E);
  static const Color darkOnTertiaryContainer = Color(0xFFFFDCC2);
  static const Color darkOutline = Color(0xFF454E56);
  static const Color darkOutlineVariant = Color(0xFF282F35);

  // M3 Expressive Tonal Tokens - Light Mode
  static const Color lightSurface = Color(0xFFF7F9FC);
  static const Color lightSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerLow = Color(0xFFF1F4F8);
  static const Color lightSurfaceContainer = Color(0xFFEBEEF3);
  static const Color lightSurfaceContainerHigh = Color(0xFFE3E7ED);
  static const Color lightSurfaceContainerHighest = Color(0xFFDCE1E8);
  static const Color lightOnSurface = Color(0xFF111417);
  static const Color lightOnSurfaceVariant = Color(0xFF444C54);
  static const Color lightPrimary = Color(0xFF006874);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFF97F0FF);
  static const Color lightOnPrimaryContainer = Color(0xFF001F24);
  static const Color lightSecondaryContainer = Color(0xFFCFE6F7);
  static const Color lightOnSecondaryContainer = Color(0xFF0D1E2A);
  static const Color lightTertiaryContainer = Color(0xFFFFDCC2);
  static const Color lightOnTertiaryContainer = Color(0xFF2E1500);
  static const Color lightOutline = Color(0xFF72787E);
  static const Color lightOutlineVariant = Color(0xFFC2C7CE);

  // Static references maintaining backward compatibility
  static const Color primary = darkPrimary;
  static const Color primaryDark = darkPrimaryContainer;
  static const Color tealAccent = Color(0xFF10B981);

  // Surfaces
  static const Color background = darkSurface;
  static const Color surface = darkSurfaceContainer;
  static const Color surfaceLight = darkSurfaceContainerHigh;
  static const Color surfaceRaised = darkSurfaceContainerHigh;
  static const Color surfaceGlass = darkSurfaceContainer;

  // Typography
  static const Color textPrimary = darkOnSurface;
  static const Color textSecondary = darkOnSurfaceVariant;
  static const Color textTertiary = Color(0xFF71717A);

  // Semantic Status
  static const Color error = Color(0xFFFFB4AB);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);

  // Strict Monochrome Semantic Alert Exceptions
  static const Color alertError = Color(0xFFFF3B30);
  static const Color alertWarning = Color(0xFFFF9F0A);

  // Category Colors
  static const Color health = Color(0xFFF43F5E);
  static const Color productivity = Color(0xFFFFFFFF);
  static const Color learning = Color(0xFF3B82F6);
  static const Color fitness = Color(0xFF10B981);
  static const Color hobby = Color(0xFF8B5CF6);

  // Crisp Border
  static const Color glassBorder = darkOutlineVariant;
  static const Color primaryGlow = Color(0x00000000);

  /// Helper to resolve accent colors based on Strict Monochrome Mode.
  /// If [isAlert] is true, returns semantic alert color.
  /// If monochrome mode is active, returns the grayscale Theme primary color.
  /// Otherwise, returns [chromaticColor].
  static Color resolveAccent(
    BuildContext context,
    Color chromaticColor, {
    bool isAlert = false,
  }) {
    if (isAlert) return chromaticColor;
    if (AppTheme.isMonochromeMode) {
      return Theme.of(context).colorScheme.primary;
    }
    return chromaticColor;
  }
}


