import 'package:flutter/material.dart';
import 'dart:math';

class StarBackground extends StatefulWidget {
  final Widget child;
  const StarBackground({super.key, required this.child});

  @override
  State<StarBackground> createState() => _StarBackgroundState();
}

class _StarBackgroundState extends State<StarBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Star> _stars = List.generate(50, (index) => Star());

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. The Gradient Layer
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Color(0xFF1A0033)], // Deep Void
            ),
          ),
        ),
        // 2. The Star Layer
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: StarPainter(_stars, _controller.value),
              size: Size.infinite,
            );
          },
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

  StarPainter(this.stars, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (var star in stars) {
      // Twinkle effect: Opacity changes based on animation value
      final double opacity = (star.baseOpacity + (sin(animationValue * star.speed) * 0.3)).clamp(0.0, 1.0);
      paint.color = Colors.white.withOpacity(opacity);

      // Draw star at random position scaled to screen size
      final dx = star.x * size.width;
      final dy = star.y * size.height;
      canvas.drawCircle(Offset(dx, dy), star.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Star {
  double x = Random().nextDouble();
  double y = Random().nextDouble();
  double size = Random().nextDouble() * 1.5 + 0.5;
  double baseOpacity = Random().nextDouble() * 0.5 + 0.1;
  double speed = Random().nextDouble() * 2 + 1;
}