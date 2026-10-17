import 'package:flutter/material.dart';
import 'motion_tokens.dart';

/// Scoped motion policy provider for accessibility and performance.
///
/// Returns instant durations when `MediaQuery.disableAnimations` is true.
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
  ///
  /// If animations are disabled, returns [MoneyMotionTokens.instant] (or [Duration.zero] if specified).
  static Duration duration(
    BuildContext context,
    Duration base, {
    bool zeroIfDisabled = false,
  }) {
    if (animationsDisabled(context)) {
      return zeroIfDisabled ? Duration.zero : MoneyMotionTokens.instant;
    }
    return base;
  }

  /// Shortcut for retrieving the standard animation duration under the current scope.
  static Duration standard(BuildContext context) =>
      duration(context, MoneyMotionTokens.standard);

  /// Shortcut for retrieving the quick animation duration under the current scope.
  static Duration quick(BuildContext context) =>
      duration(context, MoneyMotionTokens.quick);

  /// Shortcut for retrieving the emphasized animation duration under the current scope.
  static Duration emphasized(BuildContext context) =>
      duration(context, MoneyMotionTokens.emphasized);

  /// Shortcut for retrieving the tab switch duration under the current scope.
  static Duration tabSwitch(BuildContext context) =>
      duration(context, MoneyMotionTokens.tabSwitch);

  @override
  bool updateShouldNotify(MotionScope oldWidget) {
    return overrideDisableAnimations != oldWidget.overrideDisableAnimations;
  }
}
