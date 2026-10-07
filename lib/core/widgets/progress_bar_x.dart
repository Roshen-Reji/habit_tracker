import 'package:flutter/material.dart';
import 'package:habit_tracker/core/progression/progression_engine.dart';
import 'package:habit_tracker/core/progression/progression_service.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/data/models/user_rank.dart';

enum ProgressSemantic {
  neutral,
  warn,
  over,
}

class ProgressMath {
  /// Pure mathematical ratio helper: NaN and Infinity safe, clamped between 0.0 and 1.0.
  static double ratio(num current, num target) {
    if (target <= 0) return 0.0;
    final r = (current / target).toDouble();
    if (r.isNaN || r.isInfinite) return 0.0;
    return r.clamp(0.0, 1.0);
  }

  /// Returns un-clamped ratio for budget tracking (can exceed 1.0).
  static double rawRatio(num current, num target) {
    if (target <= 0) return 0.0;
    final r = (current / target).toDouble();
    if (r.isNaN || r.isInfinite) return 0.0;
    return r;
  }
}

/// Unified, animated progress bar for the app.
class ProgressBarX extends StatelessWidget {
  final double value;
  final double height;
  final ProgressSemantic semantic;
  final Color? customColor;
  final Color? customTrackColor;
  final Duration duration;
  final Curve curve;

  const ProgressBarX({
    super.key,
    required this.value,
    this.height = 6.0,
    this.semantic = ProgressSemantic.neutral,
    Color? color,
    Color? customColor,
    this.customTrackColor,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOutCubic,
  }) : customColor = color ?? customColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textCol = BentoTheme.textPrimary;
    final safeValue =
        (value.isNaN || value.isInfinite) ? 0.0 : value.clamp(0.0, 1.0);

    final trackColor = customTrackColor ??
        (isDark
            ? textCol.withValues(alpha: 0.08)
            : textCol.withValues(alpha: 0.06));

    Color fillColor;
    if (customColor != null) {
      fillColor = customColor!;
    } else {
      switch (semantic) {
        case ProgressSemantic.warn:
          fillColor = const Color(0xFFD9AE6B);
          break;
        case ProgressSemantic.over:
          fillColor = const Color(0xFFE07A7A);
          break;
        case ProgressSemantic.neutral:
          fillColor = BentoTheme.accent;
          break;
      }
    }

    final radius = BorderRadius.circular(height / 2);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: radius,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: safeValue),
            duration: duration,
            curve: curve,
            builder: (context, animValue, _) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: totalWidth * animValue,
                  height: height,
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: radius,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Unified XP progress bar showing current rank, level and numeric XP.
class XpProgressBar extends StatelessWidget {
  final double height;
  final bool showLabels;
  final TextStyle? labelStyle;

  const XpProgressBar({
    super.key,
    this.height = 6.0,
    this.showLabels = true,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserRank>(
      valueListenable: ProgressionService.rankListenable,
      builder: (context, rank, _) {
        final result = ProgressionEngine.calculate(rank.totalXp);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLabels) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Level ${result.level} · ${result.rankTitle}',
                    style: labelStyle ??
                        TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '${result.xpIntoLevel} / ${result.xpForNextLevel} XP',
                    style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            ProgressBarX(
              value: result.progress,
              height: height,
              semantic: ProgressSemantic.neutral,
            ),
          ],
        );
      },
    );
  }
}
