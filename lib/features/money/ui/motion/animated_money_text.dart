import 'package:flutter/material.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import '../../core/minor.dart';
import 'motion_scope.dart';
import 'motion_tokens.dart';

/// Smooth counting text widget that animates numeric value changes over ~450ms.
///
/// Features:
/// - Enforces [FontFeature.tabularFigures] to prevent character width jitter and layout jumps.
/// - Interpolates smoothly with [Curves.easeOutCubic].
/// - Instant transition when [MotionScope.animationsDisabled] is active.
/// - Supports both integer paise ([amountMinor]) and floating rupees ([amount]).
class AnimatedMoneyText extends StatefulWidget {
  final int? amountMinor;
  final double? amount;
  final TextStyle? style;
  final bool compact;
  final int? decimals;
  final String? customSymbol;
  final TextAlign? textAlign;
  final bool signed;

  const AnimatedMoneyText({
    super.key,
    this.amountMinor,
    this.amount,
    this.style,
    this.compact = false,
    this.decimals,
    this.customSymbol,
    this.textAlign,
    this.signed = false,
  }) : assert(amountMinor != null || amount != null,
            'Either amountMinor or amount must be provided');

  @override
  State<AnimatedMoneyText> createState() => _AnimatedMoneyTextState();
}

class _AnimatedMoneyTextState extends State<AnimatedMoneyText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late double _currentValue;

  double get _targetValue {
    if (widget.amountMinor != null) {
      return Minor.fromMinor(widget.amountMinor!);
    }
    return widget.amount ?? 0.0;
  }

  @override
  void initState() {
    super.initState();
    _currentValue = _targetValue;
    _controller = AnimationController(
      vsync: this,
      duration: MoneyMotionTokens.numberCount,
    );
    _animation =
        Tween<double>(begin: _currentValue, end: _currentValue).animate(
      CurvedAnimation(parent: _controller, curve: MoneyMotionTokens.enter),
    );
  }

  @override
  void didUpdateWidget(AnimatedMoneyText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTarget = _targetValue;
    if (_currentValue != newTarget) {
      if (MotionScope.animationsDisabled(context)) {
        _currentValue = newTarget;
        _animation = Tween<double>(begin: newTarget, end: newTarget).animate(
          CurvedAnimation(parent: _controller, curve: Curves.linear),
        );
        setState(() {});
        return;
      }

      final startVal = _animation.value;
      _currentValue = newTarget;
      _animation = Tween<double>(begin: startVal, end: newTarget).animate(
        CurvedAnimation(parent: _controller, curve: MoneyMotionTokens.enter),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = (widget.style ?? const TextStyle()).copyWith(
      fontFeatures: [
        ...?widget.style?.fontFeatures,
        const FontFeature.tabularFigures(),
      ],
    );

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final val = _animation.value;
        final String text;
        if (widget.signed) {
          text = FormatUtils.signed(
            val,
            compact: widget.compact,
            decimals: widget.decimals,
            customSymbol: widget.customSymbol,
          );
        } else {
          text = FormatUtils.formatMoney(
            val,
            compact: widget.compact,
            decimals: widget.decimals,
            customSymbol: widget.customSymbol,
          );
        }

        return Text(
          text,
          style: effectiveStyle,
          textAlign: widget.textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
