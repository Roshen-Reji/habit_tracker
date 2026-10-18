import 'package:flutter/material.dart';

/// Centralized motion tokens and physical spring standards for habit_tracker.
///
/// Adheres strictly to Section 1 of AGENTS.md:
/// - Snappy Micro-Spring: Buttons, toggles, checkboxes, pills.
/// - Fluid Spatial Spring: Bottom nav indicator, sheet expansion, card morphing.
/// - Heavy Architectural Spring: Page transitions, modal sheets, wallet stack fling.
/// - High-velocity cubic curves for opacity & color interpolation only.
class MotionTokens {
  const MotionTokens._();

  // --- Exact Physics Standards (Section 1) ---

  /// Snappy Micro-Spring: Buttons, toggles, checkboxes, pills.
  /// Instantaneous response with crisp, subtle settle.
  static const SpringDescription snappyMicro = SpringDescription(
    mass: 1.0,
    stiffness: 520.0,
    damping: 28.0,
  );

  /// Fluid Spatial Spring: Bottom nav indicator, sheet expansion, card morphing.
  /// Slight elastic overshoot (~3%) that gives hardware weight to moving containers.
  static const SpringDescription fluidSpatial = SpringDescription(
    mass: 1.0,
    stiffness: 360.0,
    damping: 26.0,
  );

  /// Heavy Architectural Spring: Page transitions, modal sheets, wallet stack fling.
  /// Critically damped—smooth deceleration with zero distracting bounce.
  static const SpringDescription heavyArchitectural = SpringDescription(
    mass: 1.1,
    stiffness: 280.0,
    damping: 28.0,
  );

  // --- High-Velocity Cubic Curves (For Opacity & Color Interpolation Only) ---

  /// emphasizedDecelerate: Cubic(0.05, 0.7, 0.1, 1.0)
  static const Cubic emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// emphasizedAccelerate: Cubic(0.3, 0.0, 0.8, 0.15)
  static const Cubic emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  /// fastOutExtraSlowIn: Cubic(0.16, 1.0, 0.3, 1.0)
  static const Cubic fastOutExtraSlowIn = Cubic(0.16, 1.0, 0.3, 1.0);

  // --- Time-based tokens (fallback / coordination) ---
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration tabSwitch = Duration(milliseconds: 220);
  static const Duration standard = Duration(milliseconds: 240);
  static const Duration emphasized = Duration(milliseconds: 360);
  static const Duration numberCount = Duration(milliseconds: 450);
  static const Duration progressBar = Duration(milliseconds: 500);

  /// Cap stagger delay at 25ms per card (max total stagger 200ms)
  static const Duration staggerInterval = Duration(milliseconds: 25);
  static const Duration maxStaggerTotal = Duration(milliseconds: 200);
  static const int maxStaggerCount = 8;

  // Press Scale
  static const double buttonPressScale = 0.94;
  static const double cardPressScale = 0.96;
  static const double pressMinScale = 0.96;

  // Backwards compatibility tokens
  static const Curve enter = emphasizedDecelerate;
  static const Curve exit = emphasizedAccelerate;
  static const double tabVerticalShiftPx = 8.0;
}

/// Backwards compatibility alias for existing features/money/ imports
typedef MoneyMotionTokens = MotionTokens;
