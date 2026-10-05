import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'dart:math';
import 'dart:ui';
import 'dart:typed_data';

class StarBackground extends StatefulWidget {
  final Widget child;
  final ScrollController? parallaxController;

  const StarBackground({
    super.key,
    required this.child,
    this.parallaxController,
  });

  @override
  State<StarBackground> createState() => _StarBackgroundState();
}

class _StarBackgroundState extends State<StarBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Star> _stars = List.generate(24, (index) => Star());

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Stack(
      children: [
        // 1. The Background Layer
        Container(
          decoration: BoxDecoration(
            color: BentoTheme.background,
          ),
        ),
        // 2. The Star Layer
        TickerMode(
          enabled: !reduceMotion,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return RepaintBoundary(
                child: CustomPaint(
                  painter: StarPainter(
                    _stars,
                    reduceMotion ? 0.5 : _controller.value,
                    BentoTheme.accent,
                  ),
                  size: Size.infinite,
                ),
              );
            },
          ),
        ),
        // 3. The Content Layer
        widget.child,
      ],
    );
  }
}

class StarPainter extends CustomPainter {
  final List<Star> stars;
  final double animationValue;
  final Color starColor;

  StarPainter(
    this.stars,
    this.animationValue,
    this.starColor,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (stars.isEmpty) return;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..color = starColor.withOpacity(0.15); // Global single color to allow batched drawPoints

    final Float32List points = Float32List(stars.length * 2);
    
    // Calculate global twinkle effect
    final double globalTwinkle = (0.5 + (sin(animationValue * 2) * 0.2)).clamp(0.0, 1.0);
    paint.color = Color.alphaBlend(starColor.withValues(alpha: 0.15), Colors.white)
          .withValues(alpha: globalTwinkle);
          
    // Draw thick stars
    paint.strokeWidth = 2.0;

    for (int i = 0; i < stars.length; i++) {
      final star = stars[i];
      points[i * 2] = star.x * size.width;
      points[i * 2 + 1] = star.y * size.height;
    }

    // One batched call
    canvas.drawRawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Star {
  double x = Random().nextDouble();
  double y = Random().nextDouble();
}
