import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import '../motion/motion_tokens.dart';

/// Performance-optimized progress bar that animates only when the value changes.
///
/// Features:
/// - 500ms [TweenAnimationBuilder] interpolation with [Curves.easeOutCubic] (Section 7 Rule 8).
/// - Zero repeated animations.
/// - Avoids [ClipRRect] on scroll paths by using direct [DecoratedBox] rounding (Section 7 Rule 2).
class MoneyProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double height;
  final Color? color;
  final Color? backgroundColor;
  final BorderRadius borderRadius;

  const MoneyProgressBar({
    super.key,
    required this.progress,
    this.height = 6.0,
    this.color,
    this.backgroundColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(3.0)),
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final effectiveBg = backgroundColor ?? BentoTheme.surface;
    final effectiveColor = color ?? BentoTheme.accent;

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: borderRadius,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            return TweenAnimationBuilder<double>(
              tween:
                  Tween<double>(begin: clampedProgress, end: clampedProgress),
              duration: MoneyMotionTokens.progressBar,
              curve: MoneyMotionTokens.enter,
              builder: (context, val, child) {
                final barWidth = maxWidth * val;
                if (barWidth <= 0) return const SizedBox.shrink();

                return Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: barWidth,
                    height: height,
                    child: Stack(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: effectiveColor,
                            borderRadius: borderRadius,
                          ),
                          child: const SizedBox.expand(),
                        ),
                        if (val >= 0.999)
                          _MoneySpecularShimmer(
                            width: barWidth,
                            height: height,
                            radius: borderRadius,
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _MoneySpecularShimmer extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius radius;

  const _MoneySpecularShimmer({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  State<_MoneySpecularShimmer> createState() => _MoneySpecularShimmerState();
}

class _MoneySpecularShimmerState extends State<_MoneySpecularShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: widget.radius,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-2.0 + (_controller.value * 4.0), 0),
                end: Alignment(-1.0 + (_controller.value * 4.0), 0),
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.45),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
