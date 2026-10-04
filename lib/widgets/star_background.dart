import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'dart:math';

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
  final List<Star> _stars = List.generate(50, (index) => Star());

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
            animation: Listenable.merge([
              _controller,
              if (widget.parallaxController != null) widget.parallaxController!,
            ]),
            builder: (context, child) {
              final scrollOffset = widget.parallaxController?.hasClients == true
                  ? widget.parallaxController!.offset
                  : 0.0;
              return RepaintBoundary(
                child: CustomPaint(
                  painter: StarPainter(
                    _stars,
                    reduceMotion ? 0.5 : _controller.value,
                    BentoTheme.accent,
                    parallaxOffset: reduceMotion ? 0.0 : scrollOffset,
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
  final double parallaxOffset;

  StarPainter(
    this.stars,
    this.animationValue,
    this.starColor, {
    this.parallaxOffset = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (var star in stars) {
      // Twinkle effect: Opacity changes based on animation value
      final double opacity =
          (star.baseOpacity + (sin(animationValue * star.speed) * 0.3))
              .clamp(0.0, 1.0);
      paint.color =
          Color.alphaBlend(starColor.withValues(alpha: 0.15), Colors.white)
              .withValues(alpha: opacity);

      // Draw star at random position scaled to screen size
      final dx = star.x * size.width;
      // The field is the most distant layer: it travels only 2.5% as fast as
      // the card deck and provides a quiet ambient parallax cue.
      final dy = star.y * size.height - (parallaxOffset * 0.025);
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
