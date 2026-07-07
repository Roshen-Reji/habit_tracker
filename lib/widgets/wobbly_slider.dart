import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';

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
      duration: const Duration(milliseconds: 2000), // Slightly slower, more fluid
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
                inactiveColor: BentoTheme.textSecondary.withValues(alpha: 0.2),
                knobColor: BentoTheme.textPrimary,
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
  final Color knobColor;

  _WobblySliderPainter({
    required this.progress,
    required this.animationValue,
    required this.activeColor,
    required this.inactiveColor,
    required this.knobColor,
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

    double amplitude = 6.0; // height of the wave
    double wavelength = 40.0; // length of one wave cycle

    // Draw secondary (background) active track for a premium liquid feel
    if (activeWidth > 0) {
      final secondaryPaint = Paint()
        ..color = activeColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      Path secondaryPath = Path();
      secondaryPath.moveTo(0, midY);
      
      for (double x = 0; x <= activeWidth; x++) {
        // Different phase and wavelength to create organic overlap
        double phase = (x / (wavelength * 1.5)) - (animationValue * 2 * math.pi * 2);
        
        // Sine envelope creates a rounded pill/blob shape, tapering perfectly at ends
        double normalizedX = x / activeWidth;
        double envelope = math.sin(normalizedX * math.pi);
        
        double y = midY + math.sin(phase) * (amplitude * 0.8) * envelope;
        secondaryPath.lineTo(x, y);
      }
      canvas.drawPath(secondaryPath, secondaryPaint);
    }

    // Draw primary active track (wobbly)
    if (activeWidth > 0) {
      Path activePath = Path();
      activePath.moveTo(0, midY);
      
      for (double x = 0; x <= activeWidth; x++) {
        // Shift wave backwards to simulate forward movement
        double phase = (x / wavelength) - (animationValue * 2 * math.pi * 3);
        
        // Sine envelope creates a rounded pill/blob shape, tapering perfectly at ends
        double normalizedX = x / activeWidth;
        double envelope = math.sin(normalizedX * math.pi);
        
        double y = midY + math.sin(phase) * amplitude * envelope;
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
      ..color = knobColor
      ..style = PaintingStyle.fill;
    
    // Add subtle shadow to the knob to make it pop, especially in light mode
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: Offset(activeWidth, midY), radius: 6.5)), 
      Colors.black, 
      4, 
      true
    );
    canvas.drawCircle(Offset(activeWidth, midY), 6.5, knobPaint);
  }

  @override
  bool shouldRepaint(covariant _WobblySliderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.animationValue != animationValue ||
           oldDelegate.activeColor != activeColor ||
           oldDelegate.inactiveColor != inactiveColor ||
           oldDelegate.knobColor != knobColor;
  }
}
