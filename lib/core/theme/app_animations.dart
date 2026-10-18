import 'package:flutter/material.dart';
import 'package:habit_tracker/core/motion/motion_tokens.dart';

class AppAnimations {
  // Springs
  static const SpringDescription snappyMicro = MotionTokens.snappyMicro;
  static const SpringDescription fluidSpatial = MotionTokens.fluidSpatial;
  static const SpringDescription heavyArchitectural = MotionTokens.heavyArchitectural;

  // Modern High-Velocity Curves
  static const Cubic emphasizedDecelerate = MotionTokens.emphasizedDecelerate;
  static const Cubic emphasizedAccelerate = MotionTokens.emphasizedAccelerate;
  static const Cubic fastOutExtraSlowIn = MotionTokens.fastOutExtraSlowIn;

  // Durations
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration superSlow = Duration(milliseconds: 800);

  // Legacy Curves
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve bounceCurve = Curves.easeOutBack;

  // Staggered list delays (capped at 25ms per item per Section 3.1)
  static Duration listDelay(int index) =>
      Duration(milliseconds: (25 * index).clamp(0, 200));

  // Page Transitions
  static Widget fadeThrough(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(
      opacity: animation.drive(CurveTween(curve: defaultCurve)),
      child: child,
    );
  }

  static Widget slideUp(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: emphasizedDecelerate,
      )),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
        ),
        child: child,
      ),
    );
  }
}
