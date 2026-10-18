import 'package:flutter/material.dart';
import 'motion_tokens.dart';

/// Scoped motion policy provider for accessibility and performance.
///
/// Returns instant durations or disabled simulations when `MediaQuery.disableAnimations` is true.
class MotionScope extends InheritedWidget {
  final bool? overrideDisableAnimations;

  const MotionScope({
    super.key,
    required super.child,
    this.overrideDisableAnimations,
  });

  /// Returns true if animations are disabled by system accessibility or override.
  static bool animationsDisabled(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MotionScope>();
    if (scope?.overrideDisableAnimations != null) {
      return scope!.overrideDisableAnimations!;
    }
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  /// Resolves the effective duration given a target base duration.
  static Duration duration(
    BuildContext context,
    Duration base, {
    bool zeroIfDisabled = false,
  }) {
    if (animationsDisabled(context)) {
      return zeroIfDisabled ? Duration.zero : MotionTokens.instant;
    }
    return base;
  }

  static Duration standard(BuildContext context) =>
      duration(context, MotionTokens.standard);

  static Duration quick(BuildContext context) =>
      duration(context, MotionTokens.quick);

  static Duration emphasized(BuildContext context) =>
      duration(context, MotionTokens.emphasized);

  static Duration tabSwitch(BuildContext context) =>
      duration(context, MotionTokens.tabSwitch);

  @override
  bool updateShouldNotify(MotionScope oldWidget) {
    return overrideDisableAnimations != oldWidget.overrideDisableAnimations;
  }
}
