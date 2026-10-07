import 'package:flutter/material.dart';

/// Centralized motion tokens for Money v2 adhering to Section 7 of AGENTS.md.
///
/// Rules:
/// - Durations: instant 90ms, quick 160ms, standard 240ms, emphasized 360ms.
/// - Curves: enter easeOutCubic, move fastOutSlowIn, press & sheets use one spring.
/// - Tab change: 220ms fade + 12px vertical shift.
/// - Animated numbers: ~450ms.
/// - Progress bars: 500ms on value change only.
class MoneyMotionTokens {
  const MoneyMotionTokens._();

  // Durations
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration tabSwitch = Duration(milliseconds: 220);
  static const Duration standard = Duration(milliseconds: 240);
  static const Duration emphasized = Duration(milliseconds: 360);
  static const Duration numberCount = Duration(milliseconds: 450);
  static const Duration progressBar = Duration(milliseconds: 500);

  // Curves
  static const Curve enter = Curves.easeOutCubic;
  static const Curve move = Curves.fastOutSlowIn;
  static const Curve exit = Curves.easeInCubic;

  // Shared spring simulation (mass 1, stiffness 380, damping 30)
  static const SpringDescription spring = SpringDescription(
    mass: 1.0,
    stiffness: 380.0,
    damping: 30.0,
  );

  /// Tab shift distance in logical pixels
  static const double tabVerticalShiftPx = 12.0;

  /// Press scale down ratio
  static const double pressScaleMin = 0.97;

  /// First 8 rows entrance stagger interval
  static const Duration staggerInterval = Duration(milliseconds: 30);
  static const int maxStaggerCount = 8;
}
