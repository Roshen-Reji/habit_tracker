import 'package:flutter/material.dart';

/// Design tokens for the MVP 5 calm, borderless, depth design system.
///
/// Immutable tokens computed once per theme change via [ThemeExtension].
class AppTokens extends ThemeExtension<AppTokens> {
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color positive;
  final Color negative;
  final Color warning;
  final Color accent;
  final Color divider;
  final bool isDark;

  const AppTokens({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.positive,
    required this.negative,
    required this.warning,
    required this.accent,
    required this.divider,
    required this.isDark,
  });

  /// Dark mode tokens
  static const AppTokens dark = AppTokens(
    background: Color(0xFF0A0A0B),
    surface: Color(0xFF151517),
    surfaceRaised: Color(0xFF1B1B1E),
    surfaceSunken: Color(0xFF101011),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xA3FFFFFF), // 64% white
    textMuted: Color(0x66FFFFFF), // 40% white
    positive: Color(0xFF6BB58A), // muted calm green
    negative: Color(0xFFE07A7A), // muted calm red
    warning: Color(0xFFD9AE6B), // muted warm amber
    accent: Color(0xFFFFFFFF), // neutral equals textPrimary
    divider: Color(0x1AFFFFFF), // ~10% white for subtle dividers
    isDark: true,
  );

  /// Light mode tokens
  static const AppTokens light = AppTokens(
    background: Color(0xFFF3F3F6),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFECECF0),
    textPrimary: Color(0xFF16161A),
    textSecondary: Color(0x9E16161A), // 62%
    textMuted: Color(0x6616161A), // 40%
    positive: Color(0xFF2F8F5B),
    negative: Color(0xFFC0504D),
    warning: Color(0xFFB8873A),
    accent: Color(0xFF16161A), // neutral equals textPrimary
    divider: Color(0x1416161A), // ~8% black for subtle dividers
    isDark: false,
  );

  /// Radii
  static const double radiusCard = 20.0;
  static const double radiusHero = 28.0;
  static const double radiusInnerChip = 14.0;
  static const double radiusPill = 999.0;

  /// Spacing 4-pt grid
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;

  /// Motion
  static const Duration motionFast = Duration(milliseconds: 160);
  static const Duration motionNormal = Duration(milliseconds: 240);
  static const Duration motionSlow = Duration(milliseconds: 320);
  static const Curve curveEnter = Curves.easeOutCubic;
  static const Curve curveMove = Curves.fastOutSlowIn;

  /// Typography styles
  static TextStyle heroNumber({Color? color}) => TextStyle(
        fontFamily: 'Roboto',
        fontSize: 44,
        height: 48 / 44,
        fontWeight: FontWeight.w700,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle sectionTitle({Color? color}) => TextStyle(
        fontFamily: 'Roboto',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle bodyText({Color? color}) => TextStyle(
        fontFamily: 'Roboto',
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle label({Color? color}) => TextStyle(
        fontFamily: 'Roboto',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: color,
      );

  static TextStyle tabularFigures(TextStyle style) => style.copyWith(
        fontFeatures: [
          ...?style.fontFeatures,
          const FontFeature.tabularFigures(),
        ],
      );

  /// Retrieve tokens from [BuildContext] with fallback based on brightness.
  static AppTokens of(BuildContext context) {
    final extension = Theme.of(context).extension<AppTokens>();
    if (extension != null) return extension;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppTokens.dark : AppTokens.light;
  }

  @override
  ThemeExtension<AppTokens> copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? positive,
    Color? negative,
    Color? warning,
    Color? accent,
    Color? divider,
    bool? isDark,
  }) {
    return AppTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
      warning: warning ?? this.warning,
      accent: accent ?? this.accent,
      divider: divider ?? this.divider,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  ThemeExtension<AppTokens> lerp(
    covariant ThemeExtension<AppTokens>? other,
    double t,
  ) {
    if (other is! AppTokens) return this;
    return AppTokens(
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceRaised:
          Color.lerp(surfaceRaised, other.surfaceRaised, t) ?? surfaceRaised,
      surfaceSunken:
          Color.lerp(surfaceSunken, other.surfaceSunken, t) ?? surfaceSunken,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      positive: Color.lerp(positive, other.positive, t) ?? positive,
      negative: Color.lerp(negative, other.negative, t) ?? negative,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      divider: Color.lerp(divider, other.divider, t) ?? divider,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Elevation levels for calm layered depth without borders.
enum DepthElevation { e1, e2, e3, e4 }

/// Factory for shadows and fills corresponding to [DepthElevation].
class AppElevation {
  AppElevation._();

  /// Soft two-layer shadows for each elevation level.
  static List<BoxShadow> shadows(DepthElevation elevation,
      {required bool isDark}) {
    if (isDark) {
      switch (elevation) {
        case DepthElevation.e1:
          return const [
            BoxShadow(
              offset: Offset(0, 1),
              blurRadius: 2,
              color: Color(0x59000000), // 35% black
            ),
          ];
        case DepthElevation.e2:
          return const [
            BoxShadow(
              offset: Offset(0, 1),
              blurRadius: 2,
              color: Color(0x66000000), // 40% black
            ),
            BoxShadow(
              offset: Offset(0, 8),
              blurRadius: 24,
              spreadRadius: -6,
              color: Color(0x8C000000), // 55% black
            ),
          ];
        case DepthElevation.e3:
          return const [
            BoxShadow(
              offset: Offset(0, 1),
              blurRadius: 2,
              color: Color(0x66000000), // 40%
            ),
            BoxShadow(
              offset: Offset(0, 8),
              blurRadius: 24,
              spreadRadius: -6,
              color: Color(0x8C000000), // 55%
            ),
            BoxShadow(
              offset: Offset(0, 18),
              blurRadius: 40,
              spreadRadius: -12,
              color: Color(0x8C000000), // 55%
            ),
          ];
        case DepthElevation.e4:
          return const [
            BoxShadow(
              offset: Offset(0, 14),
              blurRadius: 32,
              spreadRadius: -8,
              color: Color(0x99000000), // 60%
            ),
          ];
      }
    } else {
      switch (elevation) {
        case DepthElevation.e1:
          return const [
            BoxShadow(
              offset: Offset(0, 1),
              blurRadius: 2,
              color: Color(0x0F000000), // 6% black
            ),
          ];
        case DepthElevation.e2:
          return const [
            BoxShadow(
              offset: Offset(0, 1),
              blurRadius: 2,
              color: Color(0x0F000000), // 6% black
            ),
            BoxShadow(
              offset: Offset(0, 10),
              blurRadius: 28,
              spreadRadius: -8,
              color: Color(0x24000000), // 14% black
            ),
          ];
        case DepthElevation.e3:
          return const [
            BoxShadow(
              offset: Offset(0, 1),
              blurRadius: 2,
              color: Color(0x0F000000),
            ),
            BoxShadow(
              offset: Offset(0, 10),
              blurRadius: 28,
              spreadRadius: -8,
              color: Color(0x24000000),
            ),
            BoxShadow(
              offset: Offset(0, 18),
              blurRadius: 40,
              spreadRadius: -12,
              color: Color(0x24000000), // 14%
            ),
          ];
        case DepthElevation.e4:
          return const [
            BoxShadow(
              offset: Offset(0, 14),
              blurRadius: 32,
              spreadRadius: -8,
              color: Color(0x29000000), // 16%
            ),
          ];
      }
    }
  }

  /// Card fill vertical gradient from [surfaceRaised] to [surface].
  static LinearGradient cardGradient(AppTokens tokens) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        tokens.surfaceRaised,
        tokens.surface,
      ],
    );
  }
}
