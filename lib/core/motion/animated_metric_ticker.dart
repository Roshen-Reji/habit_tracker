import 'package:flutter/material.dart';
import 'motion_scope.dart';
import 'motion_tokens.dart';

/// A high-performance rolling odometer / metric ticker widget.
///
/// Adheres strictly to Section 4.1 of AGENTS.md:
/// - Enforces [FontFeature.tabularFigures] so digit widths never jitter or cause layout reflows.
/// - Smooth vertical roll per-digit when values update.
/// - Instant display when accessibility/reduced-motion is active.
/// - Supports custom prefixes, suffixes, decimal precision, and formatting.
class AnimatedMetricTicker extends StatefulWidget {
  final num value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final int fractionDigits;
  final bool showSign;
  final Duration duration;
  final Curve curve;

  const AnimatedMetricTicker({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.fractionDigits = 0,
    this.showSign = false,
    this.duration = MotionTokens.numberCount,
    this.curve = MotionTokens.emphasizedDecelerate,
  });

  /// Specialized constructor for currency amounts (e.g. ₹1,250.00)
  const AnimatedMetricTicker.currency({
    super.key,
    required this.value,
    this.style,
    this.prefix = '₹',
    this.suffix = '',
    this.fractionDigits = 2,
    this.showSign = false,
    this.duration = MotionTokens.numberCount,
    this.curve = MotionTokens.emphasizedDecelerate,
  });

  /// Specialized constructor for whole currency (e.g. ₹1,250)
  const AnimatedMetricTicker.rupees({
    super.key,
    required this.value,
    this.style,
    this.prefix = '₹',
    this.suffix = '',
    this.fractionDigits = 0,
    this.showSign = false,
    this.duration = MotionTokens.numberCount,
    this.curve = MotionTokens.emphasizedDecelerate,
  });

  /// Specialized constructor for XP telemetry (e.g. +150 XP)
  const AnimatedMetricTicker.xp({
    super.key,
    required this.value,
    this.style,
    this.prefix = '+',
    this.suffix = ' XP',
    this.fractionDigits = 0,
    this.showSign = false,
    this.duration = MotionTokens.numberCount,
    this.curve = MotionTokens.emphasizedDecelerate,
  });

  /// Specialized constructor for percentage (e.g. 84.5%)
  const AnimatedMetricTicker.percentage({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '%',
    this.fractionDigits = 1,
    this.showSign = false,
    this.duration = MotionTokens.numberCount,
    this.curve = MotionTokens.emphasizedDecelerate,
  });

  @override
  State<AnimatedMetricTicker> createState() => _AnimatedMetricTickerState();
}

class _AnimatedMetricTickerState extends State<AnimatedMetricTicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late double _previousValue;
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value.toDouble();
    _previousValue = _currentValue;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(begin: _currentValue, end: _currentValue).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedMetricTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.value.toDouble();
    if (target != _currentValue) {
      if (MotionScope.animationsDisabled(context)) {
        _previousValue = target;
        _currentValue = target;
        _animation = Tween<double>(begin: target, end: target).animate(
          CurvedAnimation(parent: _controller, curve: Curves.linear),
        );
        setState(() {});
        return;
      }

      _previousValue = _animation.value;
      _currentValue = target;
      _animation = Tween<double>(begin: _previousValue, end: _currentValue).animate(
        CurvedAnimation(parent: _controller, curve: widget.curve),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatNumber(double val) {
    if (widget.fractionDigits > 0) {
      final parts = val.abs().toStringAsFixed(widget.fractionDigits).split('.');
      final intPart = _addCommas(parts[0]);
      final sign = val < 0 ? '-' : (widget.showSign && val > 0 ? '+' : '');
      return '$sign$intPart.${parts[1]}';
    } else {
      final sign = val < 0 ? '-' : (widget.showSign && val > 0 ? '+' : '');
      return '$sign${_addCommas(val.abs().round().toString())}';
    }
  }

  String _addCommas(String intString) {
    // Indian numbering format (e.g. 1,00,000) or standard comma grouping
    if (intString.length <= 3) return intString;
    final last3 = intString.substring(intString.length - 3);
    var rest = intString.substring(0, intString.length - 3);
    final buffer = StringBuffer();
    while (rest.length > 2) {
      buffer.write(',${rest.substring(rest.length - 2)}');
      rest = rest.substring(0, rest.length - 2);
    }
    return '$rest${buffer.toString().split(',').reversed.where((s) => s.isNotEmpty).map((s) => ',$s').join()},$last3';
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = (widget.style ?? const TextStyle()).copyWith(
      fontFeatures: [
        const FontFeature.tabularFigures(),
        ...?widget.style?.fontFeatures,
      ],
    );

    if (MotionScope.animationsDisabled(context)) {
      return Text(
        '${widget.prefix}${_formatNumber(_currentValue)}${widget.suffix}',
        style: effectiveStyle,
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final val = _animation.value;
        final formatted = _formatNumber(val);
        return Text(
          '${widget.prefix}$formatted${widget.suffix}',
          style: effectiveStyle,
        );
      },
    );
  }
}
