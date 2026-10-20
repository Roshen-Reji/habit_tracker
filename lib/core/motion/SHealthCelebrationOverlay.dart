// ignore_for_file: file_names
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// Samsung Health Goal & Task Completion Animations (AGENTS.md Phase 4).
///
/// Provides:
/// 1. [SHealthCelebrationOverlay]: Top-drop spring badge with confetti particles.
/// 2. [CelebrationBurstPainter]: 12-particle radial burst for task/habit completion.
/// 3. [GoalRingPulse]: Radial pulse ring that expands and fades over 750ms.
class SHealthCelebrationOverlay {
  static OverlayEntry? _activeEntry;

  /// Trigger the Samsung Health-style Goal Achieved Banner.
  /// Drops from the top safe area with sparkles, holds for 2.2s, and springs away.
  static void show(
    BuildContext context, {
    String title = '🏆 Daily Goal Reached! +50 XP',
    String subtitle = 'All targets achieved. Incredible discipline!',
  }) {
    _activeEntry?.remove();
    _activeEntry = null;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // Double-tap celebratory haptic feedback
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 80), () {
      HapticFeedback.lightImpact();
    });

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _CelebrationBannerWidget(
        title: title,
        subtitle: subtitle,
        onDismiss: () {
          entry.remove();
          if (_activeEntry == entry) {
            _activeEntry = null;
          }
        },
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);
  }
}

class _CelebrationBannerWidget extends StatefulWidget {
  final String title;
  final String subtitle;
  final VoidCallback onDismiss;

  const _CelebrationBannerWidget({
    required this.title,
    required this.subtitle,
    required this.onDismiss,
  });

  @override
  State<_CelebrationBannerWidget> createState() => _CelebrationBannerWidgetState();
}

class _CelebrationBannerWidgetState extends State<_CelebrationBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    // Spring curve for entering
    _slideAnimation = Tween<double>(begin: -120.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const SpringCurve(mass: 1.0, stiffness: 350.0, damping: 24.0),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // Hold for 2.2s, then dismiss smoothly
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        _dismissWithAnimation();
      }
    });
  }

  void _dismissWithAnimation() {
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: topPadding + 16,
      left: 20,
      right: 20,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value.clamp(0.0, 1.0),
                child: child,
              ),
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Sparkles & Confetti Background
              Positioned.fill(
                child: CustomPaint(
                  painter: _ConfettiSparklePainter(progress: _controller.value),
                ),
              ),

              // Banner Pill Container
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1F2937), const Color(0xFF111827)]
                        : [const Color(0xFFFFFFFF), const Color(0xFFF3F4F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.28),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Glowing Trophy / Star Icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFEAB308)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '🏆',
                          style: TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Texts
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF111827),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF6B7280),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Close tap
                    GestureDetector(
                      onTap: _dismissWithAnimation,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// SpringCurve for realistic physics
class SpringCurve extends Curve {
  final double mass;
  final double stiffness;
  final double damping;

  const SpringCurve({
    this.mass = 1.0,
    this.stiffness = 350.0,
    this.damping = 24.0,
  });

  @override
  double transformInternal(double t) {
    final spring = SpringDescription(
      mass: mass,
      stiffness: stiffness,
      damping: damping,
    );
    final sim = SpringSimulation(spring, 0.0, 1.0, 0.0);
    return sim.x(t * 0.6).clamp(0.0, 1.2);
  }
}

/// Sparkles / Confetti surrounding the Banner
class _ConfettiSparklePainter extends CustomPainter {
  final double progress;

  _ConfettiSparklePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.05) return;

    final random = math.Random(42);
    final colors = [
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF3B82F6),
      const Color(0xFFEC4899),
    ];

    for (int i = 0; i < 18; i++) {
      final angle = (i * (360.0 / 18.0)) * (math.pi / 180.0);
      final dist = (40.0 + random.nextDouble() * 30.0) * progress;
      final cx = (size.width / 2.0) + math.cos(angle) * (size.width * 0.45 + dist);
      final cy = (size.height / 2.0) + math.sin(angle) * (size.height * 0.35 + dist);

      final color = colors[i % colors.length];
      final paint = Paint()
        ..color = color.withValues(alpha: (1.0 - (progress * 0.7)).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      if (i % 3 == 0) {
        // Rounded sparkle pill
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy), width: 8, height: 3),
            const Radius.circular(2),
          ),
          paint,
        );
      } else {
        // Circle dot
        canvas.drawCircle(Offset(cx, cy), 3.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiSparklePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 12-particle radial burst for Task/Habit checkmark completion.
class CelebrationBurstPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0 (600ms duration)
  final Color burstColor;

  CelebrationBurstPainter({
    required this.progress,
    this.burstColor = const Color(0xFF10B981),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.01 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final count = 12;
    final maxRadius = size.width * 0.85;

    final curvedProgress = Curves.easeOutCubic.transform(progress);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    final palette = [
      burstColor,
      const Color(0xFFF59E0B),
      const Color(0xFF3B82F6),
      burstColor.withValues(alpha: 0.9),
    ];

    for (int i = 0; i < count; i++) {
      final angle = (i * (360.0 / count)) * (math.pi / 180.0);
      final currentDist = (size.width * 0.28) + (maxRadius * curvedProgress);

      final px = center.dx + math.cos(angle) * currentDist;
      final py = center.dy + math.sin(angle) * currentDist;

      final color = palette[i % palette.length].withValues(alpha: opacity);
      final paint = Paint()..color = color;

      if (i % 2 == 0) {
        // Pill particle aligned radially
        canvas.save();
        canvas.translate(px, py);
        canvas.rotate(angle);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 7 * (1.0 - progress * 0.3), height: 2.5),
            const Radius.circular(2),
          ),
          paint,
        );
        canvas.restore();
      } else {
        // Circular particle
        final dotRadius = (3.2 * (1.0 - progress * 0.4)).clamp(0.5, 4.0);
        canvas.drawCircle(Offset(px, py), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CelebrationBurstPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.burstColor != burstColor;
  }
}

/// Samsung Health Goal Achieved Ring Pulse Widget.
/// Animates a radial pulse wave that expands outward and fades over 750ms.
class GoalRingPulse extends StatefulWidget {
  final Widget child;
  final bool trigger;
  final Color pulseColor;

  const GoalRingPulse({
    super.key,
    required this.child,
    required this.trigger,
    this.pulseColor = const Color(0xFF10B981),
  });

  @override
  State<GoalRingPulse> createState() => _GoalRingPulseState();
}

class _GoalRingPulseState extends State<GoalRingPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    if (widget.trigger) {
      _pulseController.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant GoalRingPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _pulseController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return CustomPaint(
          foregroundPainter: _pulseController.isAnimating
              ? _GoalPulsePainter(
                  progress: _pulseController.value,
                  pulseColor: widget.pulseColor,
                )
              : null,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _GoalPulsePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0 over 750ms
  final Color pulseColor;

  _GoalPulsePainter({required this.progress, required this.pulseColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) / 2;
    final pulseRadius = baseRadius + (24.0 * Curves.easeOutQuad.transform(progress));
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    final paint = Paint()
      ..color = pulseColor.withValues(alpha: opacity * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (4.0 * (1.0 - progress)).clamp(0.5, 4.0);

    canvas.drawCircle(center, pulseRadius, paint);
  }

  @override
  bool shouldRepaint(covariant _GoalPulsePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
