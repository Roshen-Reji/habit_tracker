import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:habit_tracker/core/theme/app_colors.dart';

class WobblySlider extends StatefulWidget {
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  const WobblySlider({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  State<WobblySlider> createState() => _WobblySliderState();
}

class _WobblySliderState extends State<WobblySlider> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isDragging = false;
  double _dragValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateValue(Offset localPosition, double width) {
    double percent = (localPosition.dx / width).clamp(0.0, 1.0);
    double newValue = percent * widget.max;
    setState(() {
      _dragValue = newValue;
    });
    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    double currentValue = _isDragging ? _dragValue : widget.value;
    double percent = widget.max > 0 ? (currentValue / widget.max).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onPanStart: (details) {
        setState(() => _isDragging = true);
      },
      onPanUpdate: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        _updateValue(details.localPosition, box.size.width);
      },
      onPanEnd: (details) {
        setState(() => _isDragging = false);
      },
      onTapDown: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        _updateValue(details.localPosition, box.size.width);
      },
      child: SizedBox(
        height: 40,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _WobblySliderPainter(
                progress: percent,
                animationValue: _controller.value,
                activeColor: AppColors.primary,
                inactiveColor: Colors.white.withValues(alpha: 0.1),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WobblySliderPainter extends CustomPainter {
  final double progress;
  final double animationValue;
  final Color activeColor;
  final Color inactiveColor;

  _WobblySliderPainter({
    required this.progress,
    required this.animationValue,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    double midY = size.height / 2;
    double activeWidth = size.width * progress;

    // Draw active track (wobbly)
    if (activeWidth > 0) {
      Path activePath = Path();
      activePath.moveTo(0, midY);
      
      double amplitude = 6.0; // height of the wave
      double wavelength = 40.0; // length of one wave cycle
      
      for (double x = 0; x <= activeWidth; x++) {
        // Shift wave backwards to simulate forward movement
        double phase = (x / wavelength) - (animationValue * 2 * math.pi * 3);
        
        // Dampen wave near the end so it transitions smoothly to the knob
        double damping = 1.0;
        if (activeWidth - x < 20) {
          damping = (activeWidth - x) / 20.0;
        }
        
        double y = midY + math.sin(phase) * amplitude * damping;
        activePath.lineTo(x, y);
      }
      canvas.drawPath(activePath, activePaint);
    }

    // Draw inactive track (straight line)
    if (activeWidth < size.width) {
      canvas.drawLine(
        Offset(activeWidth, midY),
        Offset(size.width, midY),
        inactivePaint,
      );
    }

    // Draw knob
    final knobPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(activeWidth, midY), 6, knobPaint);
  }

  @override
  bool shouldRepaint(covariant _WobblySliderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.animationValue != animationValue ||
           oldDelegate.activeColor != activeColor ||
           oldDelegate.inactiveColor != inactiveColor;
  }
}
