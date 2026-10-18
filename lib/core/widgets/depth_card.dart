import 'package:flutter/material.dart';
import 'package:habit_tracker/core/motion/press_scale.dart';
import 'package:habit_tracker/core/theme/app_tokens.dart';

/// A calm, crisp card with subtle tactile feedback and standardized borders.
///
/// Implements AGENTS.md Task 5 & 6 standards:
/// - Crisp 1.0px borders (`Theme.of(context).dividerColor`)
/// - Standardized border radius ([AppTokens.radiusCard] = 20.0)
/// - Single unified press physics via [PressScale]
/// - Static layout container (no AnimatedContainer frame jank)
/// - RepaintBoundary isolated
class DepthCard extends StatelessWidget {
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
  final Clip clipBehavior;
  final Listenable? tiltOnScroll;

  const DepthCard({
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
    this.clipBehavior = Clip.antiAlias,
    this.tiltOnScroll,
  });

  Decoration _buildDecoration(BuildContext context, AppTokens tokens) {
    final borderRadius = BorderRadius.circular(radius);
    final borderColor = Theme.of(context).dividerColor;
    final cardBg = color ?? tokens.surface;

    return BoxDecoration(
      color: cardBg,
      borderRadius: borderRadius,
      border: Border.all(color: borderColor, width: 1.0),
    );
  }

  Widget _buildCardContent(BuildContext context, AppTokens tokens) {
    Widget card = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: _buildDecoration(context, tokens),
      clipBehavior: clipBehavior,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap != null || onLongPress != null) {
      card = PressScale.card(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      );
    }

    return card;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    Widget result = _buildCardContent(context, tokens);

    if (tiltOnScroll != null) {
      result = AnimatedBuilder(
        animation: tiltOnScroll!,
        builder: (context, child) {
          double angle = 0.0;
          final listenable = tiltOnScroll;
          if (listenable is ScrollController && listenable.hasClients) {
            const maxRadians = 1.5 * 3.141592653589793 / 180.0;
            angle = (listenable.offset / 400.0).clamp(-1.0, 1.0) * maxRadians;
          }
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(angle),
            alignment: Alignment.center,
            child: child,
          );
        },
        child: result,
      );
    }

    return RepaintBoundary(child: result);
  }
}
