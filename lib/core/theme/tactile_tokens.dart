import 'package:flutter/material.dart';

/// Centralized tokens for the "Tactile Precision / Neo-Hardware Dark" design system.
/// Inspired by Teenage Engineering, Nothing OS, and Linear.
///
/// Mandates:
/// - Deep Obsidian Canvas (#090A0C)
/// - Matte Carbon Elevated Surface (#121418) with 1px specular top border (rgba(255, 255, 255, 0.07))
/// - Tactile Slate Pressed Surface (#1A1D24)
/// - High-contrast purposeful signal palette
/// - Tabular figures for all numerical readouts
/// - Spring physics (stiffness: 380, damping: 28) with 0.96x press scale
class TactileTokens {
  const TactileTokens._();

  // --- Surface Hierarchy (Native Black & White defaults per AGENTS.md) ---
  /// Deep Obsidian Canvas background (#000000)
  static const Color canvas = Color(0xFF000000);

  /// Matte Carbon elevated card surface (#0A0A0A)
  static const Color surface = Color(0xFF0A0A0A);

  /// Elevated card surface for floating sheets and nested cards (#141414)
  static const Color surfaceRaised = Color(0xFF141414);

  /// Sunken card surface for track meters, wells, and recessed inputs
  static const Color surfaceSunken = Color(0xFF000000);

  /// Tactile Slate pressed / interactive state surface
  static const Color surfacePressed = Color(0xFF1A1D24);

  /// Modal / sheet overlay barrier color
  static const Color barrier = Color(0xCC000000);

  // --- Specular & Border Tokens ---
  /// Crisp 1px border (#262626 in dark mode)
  static const Color specularBorder = Color(0xFF262626);

  /// Subtle bright specular highlight for active states
  static const Color specularHighlight = Color(0x28FFFFFF);

  /// Dark bevel border for bottom edges
  static const Color borderDark = Color(0x33000000);

  /// Divider color between hardware segments
  static const Color divider = Color(0xFF262626);

  // --- Semantic Signal Palette ---
  /// Primary Signal / Action: Native B&W white default (#FFFFFF)
  static const Color vermilion = Color(0xFFFFFFFF);
  static const Color primarySignal = vermilion;

  /// Secondary Signal: Acid Lime
  static const Color acidLime = Color(0xFFD4FF33);

  /// Finance / Ledger positive: Emerald Mint
  static const Color mint = Color(0xFF10B981);
  static const Color financePositive = mint;

  /// Finance / System warning: Amber Warning
  static const Color amber = Color(0xFFF59E0B);
  static const Color warningSignal = amber;

  /// Health / Biometrics / Destructive: Crimson Pulse
  static const Color crimson = Color(0xFFF43F5E);
  static const Color biometricsPulse = crimson;
  static const Color destructive = crimson;

  /// Health / Biometrics / Telemetry: Cyan Telemetry
  static const Color cyan = Color(0xFF06B6D4);
  static const Color telemetryCyan = cyan;

  /// Mind / Journal / Reader: Warm Editorial Ivory
  static const Color ivory = Color(0xFFEAE6DF);
  static const Color warmIvory = ivory;

  /// Mind / Journal: Violet Ink
  static const Color violet = Color(0xFF8B5CF6);
  static const Color violetInk = violet;

  // Semantic Token Aliases
  static const Color accentVermilion = vermilion;
  static const Color accentLime = acidLime;
  static const Color accentMint = mint;
  static const Color accentWarning = amber;
  static const Color amberWarning = amber;
  static const Color accentPulse = crimson;
  static const Color accentCyan = cyan;
  static const Color accentViolet = violet;

  // Dynamic Theme Resolution Helpers
  static Color resolvePrimary(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color resolveSurface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color resolveBorder(BuildContext context) =>
      Theme.of(context).dividerColor;

  // --- Typography Colors ---
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8E93); // High-contrast iOS-style secondary
  static const Color textMuted = Color(0xFF71717A);
  static const Color textDisabled = Color(0x40FFFFFF);

  // --- Corner Radii (Standardized to 20.0 per AGENTS.md Task 6) ---
  static const double radiusButton = 12.0;
  static const double radiusCard = 20.0;
  static const double radiusModal = 20.0;
  static const double radiusPill = 999.0;
  static const double radiusSmall = 8.0;

  static const BorderRadius borderButton =
      BorderRadius.all(Radius.circular(radiusButton));
  static const BorderRadius borderCard =
      BorderRadius.all(Radius.circular(radiusCard));
  static const BorderRadius borderModal =
      BorderRadius.all(Radius.circular(radiusModal));
  static const BorderRadius borderPill =
      BorderRadius.all(Radius.circular(radiusPill));

  // --- Minimum Hit Target ---
  static const double minTouchTarget = 48.0;

  // --- Spring Physics & Motion ---
  /// Shared Neo-Hardware spring description (stiffness: 380, damping: 28)
  static const SpringDescription spring = SpringDescription(
    mass: 1.0,
    stiffness: 380.0,
    damping: 28.0,
  );

  /// Scale compression on tap
  static const double pressScale = 0.96;

  /// Standard micro-durations
  static const Duration durationFast = Duration(milliseconds: 140);
  static const Duration durationStandard = Duration(milliseconds: 240);
  static const Duration durationMorph = Duration(milliseconds: 320);

  // --- Typography Helpers ---
  /// Heading typography: tight tracking (-0.5), bold geometric grotesk
  static TextStyle heading({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w700,
    Color color = textPrimary,
    double letterSpacing = -0.5,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'Roboto',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Tabular Monospace figures for numbers, currency, timers, biometrics
  static TextStyle tabular({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w600,
    Color color = textPrimary,
    double? letterSpacing,
    double? height,
    TextStyle? baseStyle,
  }) {
    final style = baseStyle ??
        TextStyle(
          fontFamily: 'Roboto',
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing,
          height: height,
        );

    return style.copyWith(
      fontFeatures: [
        ...?style.fontFeatures,
        const FontFeature.tabularFigures(),
      ],
    );
  }

  /// Metric readout typography with tabular figures and tight tracking
  static TextStyle metric({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w700,
    Color color = textPrimary,
    double letterSpacing = -0.5,
  }) {
    return tabular(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  // --- Hardware Bevel & Card Decorations ---
  /// 1px specular top border and darker bottom edge bevel border
  static Border get tactileBevelBorder => const Border(
        top: BorderSide(color: Color(0x18FFFFFF), width: 1.0),
        bottom: BorderSide(color: Color(0x38000000), width: 1.0),
        left: BorderSide(color: Color(0x0FFFFFFF), width: 0.8),
        right: BorderSide(color: Color(0x0FFFFFFF), width: 0.8),
      );

  /// Specular 1px border for elevated matte carbon cards
  static Border get cardBorder => const Border(
        top: BorderSide(color: specularBorder, width: 1.0),
        bottom: BorderSide(color: Color(0x28000000), width: 1.0),
        left: BorderSide(color: Color(0x0AFFFFFF), width: 0.8),
        right: BorderSide(color: Color(0x0AFFFFFF), width: 0.8),
      );

  /// Tactile card box decoration
  static BoxDecoration cardDecoration({
    Color? color,
    double radius = radiusCard,
    bool isPressed = false,
    Border? border,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: isPressed ? surfacePressed : (color ?? surface),
      borderRadius: BorderRadius.circular(radius),
      border: border ?? (isPressed ? null : cardBorder),
      boxShadow: shadows ??
          [
            const BoxShadow(
              color: Color(0x59000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
    );
  }
}
