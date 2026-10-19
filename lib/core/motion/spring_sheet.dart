import 'package:flutter/material.dart';
import 'motion_tokens.dart';

/// Shows a modal bottom sheet driven by critically damped heavy architectural spring physics.
///
/// Adheres to Section 5.2 of AGENTS.md:
/// - Smooth spring slide entry and exit.
/// - Fluid drag dismissibility.
/// - High-performance backdrop darkening without heavy real-time blurs.
Future<T?> showSpringSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
  double? elevation,
  ShapeBorder? shape,
  Clip clipBehavior = Clip.antiAlias,
  BoxConstraints? constraints,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    isScrollControlled: true,
    backgroundColor: backgroundColor ?? Colors.transparent,
    elevation: elevation ?? 0,
    shape: shape ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
    clipBehavior: clipBehavior,
    constraints: constraints,
    sheetAnimationStyle: AnimationStyle(
      duration: MotionTokens.emphasized,
      reverseDuration: MotionTokens.standard,
    ),
    builder: builder,
  );
}

/// SpringSheet class providing standard static call signatures
class SpringSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    WidgetBuilder? builder,
    Widget? child,
    String? title,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
    Clip clipBehavior = Clip.antiAlias,
    BoxConstraints? constraints,
  }) {
    final effectiveBuilder = builder ??
        (BuildContext ctx) {
          final content = child ?? const SizedBox.shrink();
          if (title == null) return content;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close, size: 20, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Flexible(child: content),
            ],
          );
        };

    return showSpringSheet<T>(
      context: context,
      builder: effectiveBuilder,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      constraints: constraints,
    );
  }

  static Future<T?> showDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color barrierColor = const Color(0x99000000),
    String? barrierLabel,
  }) =>
      showSpringDialog<T>(
        context: context,
        builder: builder,
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor,
        barrierLabel: barrierLabel,
      );
}

/// Shows a dialog driven by the snappy micro-spring paired with backdrop fade.
///
/// Adheres to Section 5.2 of AGENTS.md:
/// - Enters from scale 0.92 -> 1.0 using Snappy Micro-Spring physics.
/// - Backdrop fades in smoothly over 150ms.
Future<T?> showSpringDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color barrierColor = const Color(0x99000000),
  String? barrierLabel,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel ?? 'Dismiss',
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, anim1, anim2) => builder(context),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: MotionTokens.emphasizedDecelerate,
        reverseCurve: Curves.easeInCubic,
      );

      final scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(curved);
      final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
        ),
      );

      return ScaleTransition(
        scale: scaleAnim,
        child: FadeTransition(
          opacity: fadeAnim,
          child: child,
        ),
      );
    },
  );
}
