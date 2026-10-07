import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/app_tokens.dart';
import 'package:habit_tracker/core/widgets/depth_card.dart';

/// Money v2 DepthCard wrapper adhering to Section 7 Look guidelines:
/// - Calm, minimal: cards have no border, two soft shadows, and a faint top highlight.
/// - Isolated with [RepaintBoundary].
class MoneyDepthCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final DepthElevation elevation;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final double? width;
  final double? height;

  const MoneyDepthCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.space16),
    this.margin,
    this.elevation = DepthElevation.e2,
    this.radius = AppTokens.radiusCard,
    this.onTap,
    this.onLongPress,
    this.color,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return DepthCard(
      padding: padding,
      margin: margin,
      elevation: elevation,
      radius: radius,
      onTap: onTap,
      onLongPress: onLongPress,
      color: color,
      width: width,
      height: height,
      child: child,
    );
  }
}
