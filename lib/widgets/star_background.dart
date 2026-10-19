import 'package:flutter/material.dart';

/// Deprecated no-op placeholder for StarBackground (AGENTS.md Task 2).
///
/// Stripped of all Ticker, AnimationController, and CustomPainter overhead.
class StarBackground extends StatelessWidget {
  final Widget child;
  final ScrollController? parallaxController;

  const StarBackground({
    super.key,
    required this.child,
    this.parallaxController,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: child,
    );
  }
}
