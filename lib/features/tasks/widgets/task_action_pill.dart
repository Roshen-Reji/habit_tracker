import 'package:flutter/material.dart';
import 'package:habit_tracker/core/motion/press_scale.dart';

/// Single-layer physical action pill widget adhering to AGENTS.md Phase 2.
/// Eliminates "pill-in-pill" double-container nesting and white box defaults.
class TaskActionPill extends StatelessWidget {
  final String label;
  final Widget? icon;
  final VoidCallback? onTap;
  final bool isPrimary;
  final double height;
  final double horizontalPadding;
  final double borderRadius;
  final TextStyle? textStyle;

  const TaskActionPill({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.isPrimary = false,
    this.height = 36.0,
    this.horizontalPadding = 14.0,
    this.borderRadius = 12.0,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isPrimary
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? const Color(0xFF141414) : const Color(0xFFF4F4F5));

    final Color fgColor = isPrimary
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? Colors.white : Colors.black);

    final Border? border = isPrimary
        ? null
        : Border.all(color: const Color(0xFF262626), width: 1);

    return PressScale(
      onTap: onTap,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: border,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              IconTheme(
                data: IconThemeData(color: fgColor, size: 14),
                child: icon!,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: (textStyle ??
                      TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: fgColor,
                      ))
                  .copyWith(color: fgColor),
            ),
          ],
        ),
      ),
    );
  }
}
