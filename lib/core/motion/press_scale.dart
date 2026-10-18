import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'motion_scope.dart';
import 'motion_tokens.dart';

/// Tactile press physics wrapper that responds instantaneously with physical spring physics.
///
/// Adheres strictly to Section 5.1 of AGENTS.md:
/// - onTapDown: Immediately starts spring compression toward [minScale] (default 0.96 for cards,
///   0.94 for buttons) and applies a 4% surface darkening overlay.
/// - onTapUp / onTapCancel: Releases spring with initial velocity so even rapid tap-and-release
///   completes a visible, satisfying dip-and-rebound pulse.
/// - Zero linear movement; GPU-accelerated Matrix4 transform scale.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double minScale;
  final bool enableHaptics;
  final bool darkenOnPress;
  final HitTestBehavior behavior;
  final BorderRadius? borderRadius;

  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.minScale = MotionTokens.pressMinScale,
    this.enableHaptics = true,
    this.darkenOnPress = true,
    this.behavior = HitTestBehavior.opaque,
    this.borderRadius,
  });

  /// Factory preset for buttons (scale down to 0.94)
  const PressScale.button({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.minScale = MotionTokens.buttonPressScale,
    this.enableHaptics = true,
    this.darkenOnPress = true,
    this.behavior = HitTestBehavior.opaque,
    this.borderRadius,
  });

  /// Factory preset for cards & tiles (scale down to 0.96)
  const PressScale.card({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.minScale = MotionTokens.cardPressScale,
    this.enableHaptics = true,
    this.darkenOnPress = true,
    this.behavior = HitTestBehavior.opaque,
    this.borderRadius,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isDown = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(
      vsync: this,
      value: 0.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _runSpring(double target, {double velocity = 0.0}) {
    final simulation = SpringSimulation(
      MotionTokens.snappyMicro,
      _controller.value,
      target,
      velocity,
    );
    _controller.animateWith(simulation);
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (MotionScope.animationsDisabled(context)) return;
    _isDown = true;
    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    _runSpring(1.0, velocity: 1.5);
  }

  void _onTapUp(TapUpDetails _) {
    if (!_isDown) return;
    _isDown = false;
    _runSpring(0.0, velocity: -2.0);
  }

  void _onTapCancel() {
    if (!_isDown) return;
    _isDown = false;
    _runSpring(0.0, velocity: -1.0);
  }

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) {
      return widget.child;
    }

    final disabled = MotionScope.animationsDisabled(context);

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: disabled ? null : _onTapDown,
      onTapUp: disabled ? null : _onTapUp,
      onTapCancel: disabled ? null : _onTapCancel,
      onTap: _handleTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          if (disabled) return child!;

          // Progress: 0.0 (rest) -> 1.0 (fully compressed)
          final progress = _controller.value.clamp(0.0, 1.2);
          final scale = 1.0 - (progress * (1.0 - widget.minScale));

          Widget result = Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: child,
          );

          if (widget.darkenOnPress && progress > 0.01) {
            result = Stack(
              children: [
                result,
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(
                          alpha: (0.04 * progress).clamp(0.0, 0.08),
                        ),
                        borderRadius: widget.borderRadius,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return result;
        },
      ),
    );
  }
}
