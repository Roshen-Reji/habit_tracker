import 'package:flutter/material.dart';

/// Material 3 Expressive design tokens for the Commander Habit Tracker.
/// Provides unified spring curves, durations, corner radii, and container shapes.
class ExpressiveTokens {
  // --- Corner Radii (Crisp Neo-Hardware Precision) ---
  static const double radiusNone = 0.0;
  static const double radiusXS = 4.0;
  static const double radiusS = 8.0;
  static const double radiusSm = radiusS;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 28.0;
  static const double radiusFull = 9999.0;

  static const double radiusCard = radiusM; // Crisp 12-14px
  static const double radiusDialog = radiusXL;

  static const BorderRadius borderXS =
      BorderRadius.all(Radius.circular(radiusXS));
  static const BorderRadius borderS =
      BorderRadius.all(Radius.circular(radiusS));
  static const BorderRadius borderM =
      BorderRadius.all(Radius.circular(radiusM));
  static const BorderRadius borderL =
      BorderRadius.all(Radius.circular(radiusL));
  static const BorderRadius borderXL =
      BorderRadius.all(Radius.circular(radiusXL));
  static const BorderRadius borderXXL =
      BorderRadius.all(Radius.circular(radiusXXL));
  static const BorderRadius borderFull =
      BorderRadius.all(Radius.circular(radiusFull));

  // --- Expressive Motion & Curves ---
  /// Material 3 Expressive emphasized deceleration (spring-like feel)
  static const Curve curveEmphasizedDecel = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Material 3 Expressive emphasized acceleration
  static const Curve curveEmphasizedAccel = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Standard expressive spring curve for cards and modal expansions
  static const Curve curveSpring = Curves.easeOutBack;

  /// Hardware spring simulation (stiffness: 380, damping: 28)
  static const SpringDescription spring = SpringDescription(
    mass: 1.0,
    stiffness: 380.0,
    damping: 28.0,
  );

  /// Standard smooth fluid curve
  static const Curve curveFluid = Curves.easeInOutCubicEmphasized;

  // --- Animation Durations ---
  static const Duration durationFast = Duration(milliseconds: 140);
  static const Duration durationStandard = Duration(milliseconds: 240);
  static const Duration durationExpressive = Duration(milliseconds: 360);
  static const Duration durationLong = Duration(milliseconds: 500);

  // --- Elevation / Shadows (Crisp Tactile Depth without AI Slop Blurs) ---
  static List<BoxShadow> elevationLow(Color shadowColor) => [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.15),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> elevationMedium(Color shadowColor) => [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.25),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ];

  static List<BoxShadow> elevationHigh(Color shadowColor) => [
        BoxShadow(
          color: shadowColor.withValues(alpha: 0.35),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
}
