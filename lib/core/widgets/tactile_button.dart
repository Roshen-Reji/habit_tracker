import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:habit_tracker/core/motion/motion_tokens.dart';
import 'package:habit_tracker/core/theme/tactile_tokens.dart';

enum TactileButtonVariant {
  primary,
  secondary,
  destructive,
  ghost,
  outline,
}

enum TactileButtonSize {
  small,
  medium,
  large,
}

/// Unified Tactile Precision button component adhering to AGENTS.md Section 2.2.
///
/// Features:
/// - Physical Spring Press Physics: 0.96x compression on tap down, spring release on tap up.
/// - Light tactile haptic feedback ([HapticFeedback.lightImpact]).
/// - Crisp 10px–12px border radius with subtle top-edge specular highlight bevel.
/// - Minimum 48x48dp touch hit target.
/// - Distinct primary, secondary, destructive, ghost, and outline variants.
class TactileButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget? child;
  final String? label;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final TactileButtonVariant variant;
  final TactileButtonSize size;
  final double? width;
  final double? height;
  final double borderRadius;
  final bool isLoading;
  final bool disabled;
  final EdgeInsetsGeometry? padding;

  const TactileButton({
    super.key,
    required this.onPressed,
    this.child,
    this.label,
    this.icon,
    this.leading,
    this.trailing,
    this.variant = TactileButtonVariant.primary,
    this.size = TactileButtonSize.medium,
    this.width,
    this.height,
    this.borderRadius = TactileTokens.radiusButton,
    this.isLoading = false,
    this.disabled = false,
    this.padding,
  });

  const TactileButton.icon({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.variant = TactileButtonVariant.secondary,
    this.size = TactileButtonSize.medium,
    this.width,
    this.height,
    this.borderRadius = TactileTokens.radiusButton,
    this.isLoading = false,
    this.disabled = false,
    this.padding,
  })  : child = null,
        leading = null,
        trailing = null;

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isPressed = false;

  bool get _isEnabled =>
      widget.onPressed != null && !widget.disabled && !widget.isLoading;

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

  void _handleTapDown(TapDownDetails _) {
    if (!_isEnabled) return;
    setState(() => _isPressed = true);
    HapticFeedback.lightImpact();
    _runSpring(1.0, velocity: 1.5);
  }

  void _handleTapUp(TapUpDetails _) {
    if (!_isEnabled) return;
    setState(() => _isPressed = false);
    _runSpring(0.0, velocity: -2.0);
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    if (!_isEnabled) return;
    setState(() => _isPressed = false);
    _runSpring(0.0, velocity: -1.0);
  }

  double get _resolvedHeight {
    if (widget.height != null) return widget.height!;
    switch (widget.size) {
      case TactileButtonSize.small:
        return 48.0; // Enforce minimum 48dp touch target
      case TactileButtonSize.medium:
        return 50.0;
      case TactileButtonSize.large:
        return 56.0;
    }
  }

  EdgeInsetsGeometry get _resolvedPadding {
    if (widget.padding != null) return widget.padding!;
    switch (widget.size) {
      case TactileButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0);
      case TactileButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0);
      case TactileButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0);
    }
  }

  Color _backgroundColor(ColorScheme cs) {
    if (!_isEnabled) return cs.surfaceContainerHighest;

    switch (widget.variant) {
      case TactileButtonVariant.primary:
        return _isPressed
            ? cs.primary.withValues(alpha: 0.85)
            : cs.primary;
      case TactileButtonVariant.secondary:
        return _isPressed
            ? cs.surfaceContainerHighest
            : cs.secondaryContainer;
      case TactileButtonVariant.destructive:
        return _isPressed
            ? cs.error.withValues(alpha: 0.85)
            : cs.error;
      case TactileButtonVariant.ghost:
        return _isPressed
            ? cs.surfaceContainerHighest
            : Colors.transparent;
      case TactileButtonVariant.outline:
        return _isPressed
            ? cs.surfaceContainerHighest
            : cs.surfaceContainer;
    }
  }

  Color _foregroundColor(ColorScheme cs) {
    if (!_isEnabled) return cs.onSurface.withValues(alpha: 0.38);

    switch (widget.variant) {
      case TactileButtonVariant.primary:
        return cs.onPrimary;
      case TactileButtonVariant.destructive:
        return cs.onError;
      case TactileButtonVariant.secondary:
        return cs.onSecondaryContainer;
      case TactileButtonVariant.outline:
      case TactileButtonVariant.ghost:
        return cs.onSurface;
    }
  }

  Border? _border(ColorScheme cs) {
    if (!_isEnabled) {
      return Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 1.0);
    }

    switch (widget.variant) {
      case TactileButtonVariant.primary:
        return null;
      case TactileButtonVariant.secondary:
        return Border.all(
          color: cs.outlineVariant,
          width: 1.0,
        );
      case TactileButtonVariant.destructive:
        return null;
      case TactileButtonVariant.outline:
        return Border.all(
          color: cs.outlineVariant,
          width: 1.0,
        );
      case TactileButtonVariant.ghost:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = _foregroundColor(cs);

    Widget content;
    if (widget.isLoading) {
      content = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          valueColor: AlwaysStoppedAnimation<Color>(fg),
        ),
      );
    } else if (widget.child != null) {
      content = widget.child!;
    } else {
      final List<Widget> rowItems = [];

      if (widget.leading != null) {
        rowItems.add(widget.leading!);
        rowItems.add(const SizedBox(width: 8));
      } else if (widget.icon != null) {
        rowItems.add(Icon(widget.icon, size: 18, color: fg));
        if (widget.label != null && widget.label!.isNotEmpty) {
          rowItems.add(const SizedBox(width: 8));
        }
      }

      if (widget.label != null && widget.label!.isNotEmpty) {
        rowItems.add(
          Text(
            widget.label!,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: widget.size == TactileButtonSize.small ? 13 : 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: fg,
            ),
          ),
        );
      }

      if (widget.trailing != null) {
        rowItems.add(const SizedBox(width: 8));
        rowItems.add(widget.trailing!);
      }

      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: rowItems,
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: TactileTokens.minTouchTarget,
        minHeight: TactileTokens.minTouchTarget,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = _controller.value.clamp(0.0, 1.0);
            final scale = 1.0 - (progress * (1.0 - MotionTokens.buttonPressScale));
            final currentRadius = widget.borderRadius + (14.0 - widget.borderRadius) * progress;
            return Transform.scale(
              scale: scale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                width: widget.width,
                height: _resolvedHeight,
                padding: _resolvedPadding,
                decoration: BoxDecoration(
                  color: _backgroundColor(cs),
                  borderRadius: BorderRadius.circular(currentRadius),
                  border: _border(cs),
                  boxShadow: _isEnabled &&
                          widget.variant != TactileButtonVariant.ghost &&
                          !_isPressed
                      ? [
                          const BoxShadow(
                            color: Color(0x38000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(child: content),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Compact Icon Button with guaranteed 48x48dp hit target and spring scale.
class TactileIconButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final double iconSize;
  final Color? color;
  final Color? backgroundColor;
  final String? tooltip;
  final double size;
  final double borderRadius;
  final Border? border;

  const TactileIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.iconSize = 20.0,
    this.color,
    this.backgroundColor,
    this.tooltip,
    this.size = 48.0,
    this.borderRadius = 12.0,
    this.border,
  });

  @override
  State<TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<TactileIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isPressed = false;

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEnabled = widget.onPressed != null;
    final fg = widget.color ??
        (isEnabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.38));
    final bg = widget.backgroundColor ??
        (_isPressed
            ? cs.surfaceContainerHighest
            : cs.surfaceContainerHigh);

    Widget button = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: TactileTokens.minTouchTarget,
        minHeight: TactileTokens.minTouchTarget,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: isEnabled
            ? (_) {
                setState(() => _isPressed = true);
                HapticFeedback.lightImpact();
                _runSpring(1.0, velocity: 1.5);
              }
            : null,
        onTapUp: isEnabled
            ? (_) {
                setState(() => _isPressed = false);
                _runSpring(0.0, velocity: -2.0);
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: isEnabled
            ? () {
                setState(() => _isPressed = false);
                _runSpring(0.0, velocity: -1.0);
              }
            : null,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = _controller.value.clamp(0.0, 1.2);
            final scale = 1.0 - (progress * (1.0 - MotionTokens.buttonPressScale));
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: widget.border ??
                  const Border(
                    top: BorderSide(color: Color(0x18FFFFFF), width: 1.0),
                    bottom: BorderSide(color: Color(0x28000000), width: 1.0),
                    left: BorderSide(color: Color(0x0AFFFFFF), width: 0.8),
                    right: BorderSide(color: Color(0x0AFFFFFF), width: 0.8),
                  ),
            ),
            child: Center(
              child: Icon(widget.icon, size: widget.iconSize, color: fg),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }
}

/// Tactical Checklist Checkbox with physical snap, light haptics, and min 48x48 touch target.
class TactileCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;

  const TactileCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  State<TactileCheckbox> createState() => _TactileCheckboxState();
}

class _TactileCheckboxState extends State<TactileCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController.unbounded(
      vsync: this,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onChanged == null) return;
    final simulation = SpringSimulation(
      MotionTokens.snappyMicro,
      _scaleController.value,
      0.85,
      0.0,
    );
    _scaleController.animateWith(simulation);
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onChanged == null) return;
    HapticFeedback.lightImpact();
    // Spring pop to 1.15x overshoot then settle back to 1.0x
    final popSimulation = SpringSimulation(
      MotionTokens.snappyMicro,
      _scaleController.value,
      1.0,
      14.0,
    );
    _scaleController.animateWith(popSimulation);
    widget.onChanged!(!widget.value);
  }

  void _onTapCancel() {
    final simulation = SpringSimulation(
      MotionTokens.snappyMicro,
      _scaleController.value,
      1.0,
      0.0,
    );
    _scaleController.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeColor = widget.activeColor ?? cs.primary;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: TactileTokens.minTouchTarget,
        minHeight: TactileTokens.minTouchTarget,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: Center(
          child: AnimatedBuilder(
            animation: _scaleController,
            builder: (context, child) => Transform.scale(
              scale: _scaleController.value,
              child: child,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: widget.value ? activeColor : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(widget.value ? 6.0 : 11.0),
                border: Border.all(
                  color: widget.value
                      ? activeColor
                      : cs.outlineVariant,
                  width: 1.2,
                ),
                boxShadow: widget.value
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: widget.value
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: Color(0xFF090A0C),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
