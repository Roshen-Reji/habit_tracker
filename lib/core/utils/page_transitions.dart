import 'package:flutter/material.dart';
import 'package:habit_tracker/core/motion/motion_tokens.dart';

/// Smooth shared-axis, container transform, and spring-driven slide+fade page transitions.
class PageTransitions {
  /// Builds a container transform route expanding from card (radius 16->0, scale 0.94->1.0).
  static Route<T> containerTransform<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: MotionTokens.fastOutExtraSlowIn,
          reverseCurve: MotionTokens.emphasizedAccelerate,
        );

        final scale = Tween<double>(begin: 0.94, end: 1.0).animate(curved);
        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
          ),
        );
        final radius = Tween<double>(begin: 16.0, end: 0.0).animate(curved);

        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: scale,
            child: AnimatedBuilder(
              animation: radius,
              builder: (context, c) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(radius.value),
                  child: c,
                );
              },
              child: child,
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 280),
    );
  }

  /// Builds a route with a spring-driven slide + fade transition.
  static Route<T> springSlideFade<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return buildSpringSlideFadeTransitions(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 280),
    );
  }

  /// Builds a route with a shared-axis scale + slide transition.
  static Route<T> sharedAxis<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return buildSharedAxisTransitions(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// Builds a route with a subtle fade + scale transition.
  static Route<T> fadeScale<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeAnim =
            CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final scaleAnim = Tween<double>(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: fadeAnim,
          child: ScaleTransition(scale: scaleAnim, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// Pure transition builder for spring-driven slide and fade.
  static Widget buildSpringSlideFadeTransitions({
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
  }) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: const Cubic(0.2, 0.0, 0.0, 1.0),
      reverseCurve: const Cubic(0.3, 0.0, 0.8, 0.15),
    );

    final secondaryCurved = CurvedAnimation(
      parent: secondaryAnimation,
      curve: const Cubic(0.2, 0.0, 0.0, 1.0),
      reverseCurve: const Cubic(0.3, 0.0, 0.8, 0.15),
    );

    final slideAnim = Tween<Offset>(
      begin: const Offset(0.06, 0.0),
      end: Offset.zero,
    ).animate(curvedAnimation);

    final secondarySlideAnim = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.03, 0.0),
    ).animate(secondaryCurved);

    final fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
    ));

    final secondaryFadeAnim = Tween<double>(
      begin: 1.0,
      end: 0.88,
    ).animate(secondaryCurved);

    return SlideTransition(
      position: secondarySlideAnim,
      child: FadeTransition(
        opacity: secondaryFadeAnim,
        child: SlideTransition(
          position: slideAnim,
          child: FadeTransition(
            opacity: fadeAnim,
            child: child,
          ),
        ),
      ),
    );
  }

  /// Pure transition builder for shared-axis scale and slide.
  static Widget buildSharedAxisTransitions({
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
  }) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: const Cubic(0.2, 0.0, 0.0, 1.0),
      reverseCurve: const Cubic(0.3, 0.0, 0.8, 0.15),
    );

    final slideAnim = Tween<Offset>(
      begin: const Offset(0.08, 0.0),
      end: Offset.zero,
    ).animate(curvedAnimation);

    final scaleAnim = Tween<double>(
      begin: 0.96,
      end: 1.0,
    ).animate(curvedAnimation);

    final fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));

    return SlideTransition(
      position: slideAnim,
      child: ScaleTransition(
        scale: scaleAnim,
        child: FadeTransition(
          opacity: fadeAnim,
          child: child,
        ),
      ),
    );
  }
}

/// A [PageTransitionsBuilder] that applies a smooth spring slide+fade transition.
class SpringSlideFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const SpringSlideFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return PageTransitions.buildSpringSlideFadeTransitions(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// A [PageTransitionsBuilder] that applies a shared-axis transition.
class SharedAxisPageTransitionsBuilder extends PageTransitionsBuilder {
  const SharedAxisPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return PageTransitions.buildSharedAxisTransitions(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}
