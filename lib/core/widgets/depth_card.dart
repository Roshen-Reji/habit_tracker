import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/app_tokens.dart';

/// A calm, borderless card with layered elevation, soft shadows, and subtle depth.
///
/// Implements MVP 5 design system requirements:
/// - No borders or strokes
/// - Two-layer soft shadows ([DepthElevation])
/// - Top-light overlay in dark mode (3.5% white over top 40%)
/// - Pressed micro-interaction: scale 0.985 + shadow step-down (120ms)
/// - Optional 3D tilt on scroll (for hero cards)
/// - RepaintBoundary isolated
class DepthCard extends StatefulWidget {
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

  @override
  State<DepthCard> createState() => _DepthCardState();
}

class _DepthCardState extends State<DepthCard> {
  bool _isPressed = false;

  DepthElevation _getPressedElevation(DepthElevation base) {
    switch (base) {
      case DepthElevation.e4:
        return DepthElevation.e3;
      case DepthElevation.e3:
        return DepthElevation.e2;
      case DepthElevation.e2:
        return DepthElevation.e1;
      case DepthElevation.e1:
        return DepthElevation.e1;
    }
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null || widget.onLongPress != null) {
      setState(() => _isPressed = true);
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _onTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  Decoration _buildDecoration(AppTokens tokens) {
    final activeElevation =
        _isPressed ? _getPressedElevation(widget.elevation) : widget.elevation;
    final shadows =
        AppElevation.shadows(activeElevation, isDark: tokens.isDark);
    final borderRadius = BorderRadius.circular(widget.radius);

    if (widget.color != null) {
      return BoxDecoration(
        color: widget.color,
        borderRadius: borderRadius,
        boxShadow: shadows,
      );
    }

    if (tokens.isDark) {
      // Dark mode: vertical gradient from surfaceRaised to surface with a 3.5% white top-light overlay
      // across the top 40%.
      final topLight =
          Color.alphaBlend(const Color(0x09FFFFFF), tokens.surfaceRaised);
      return BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.4, 1.0],
          colors: [
            topLight,
            tokens.surfaceRaised,
            tokens.surface,
          ],
        ),
        boxShadow: shadows,
      );
    } else {
      // Light mode: solid surface relying on soft shadows
      return BoxDecoration(
        color: tokens.surface,
        borderRadius: borderRadius,
        boxShadow: shadows,
      );
    }
  }

  Widget _buildCardContent(BuildContext context, AppTokens tokens) {
    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: _buildDecoration(tokens),
      clipBehavior: widget.clipBehavior,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          borderRadius: BorderRadius.circular(widget.radius),
          splashColor: Colors.transparent,
          highlightColor: tokens.isDark
              ? Colors.white.withValues(alpha: 0.02)
              : Colors.black.withValues(alpha: 0.02),
          child: Padding(
            padding: widget.padding,
            child: widget.child,
          ),
        ),
      ),
    );

    // Micro-scale press interaction
    if (widget.onTap != null || widget.onLongPress != null) {
      card = AnimatedScale(
        scale: _isPressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: card,
      );
    }

    return card;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    Widget result;
    if (widget.tiltOnScroll != null) {
      // Repaint transform without rebuilding child tree
      result = AnimatedBuilder(
        animation: widget.tiltOnScroll!,
        builder: (context, child) {
          double angle = 0.0;
          final listenable = widget.tiltOnScroll;
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
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: _buildCardContent(context, tokens),
        ),
      );
    } else {
      result = GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: _buildCardContent(context, tokens),
      );
    }

    return RepaintBoundary(child: result);
  }
}
