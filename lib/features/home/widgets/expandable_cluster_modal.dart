import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';

/// OxygenOS Expandable Widget Stack & Smart Cluster Components (AGENTS.md Phase 2).
///
/// Features:
/// 1. Compact 1x1 Metric Tile with 270-degree circular gauge arc.
/// 2. Smart Folder / Cluster Tile (2x2 preview) opening the 3-tier expanded cluster.
/// 3. Frosted modal with BackdropFilter(20, 20) and spring scale/rect morphing.
/// 4. Row 1: AI Daily Insight Card (#182235 / #1E1E1E).
/// 5. Row 2: Steps / Goal Contrast Card with perched walking icon.
/// 6. Row 3: Two 1x1 Action Cards (Multi-segment progress + Concentric Radar CTA).

// ---------------------------------------------------------------------------
// 1. Compact Metric Tile (1x1 Resting State)
// ---------------------------------------------------------------------------

class CompactMetricTile extends StatelessWidget {
  final int steps;
  final int goal;
  final double distanceMeters;
  final VoidCallback? onTap;

  const CompactMetricTile({
    super.key,
    this.steps = 993,
    this.goal = 8000,
    this.distanceMeters = 702.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF26292E) : const Color(0xFFF1F4F8);
    final accentGreen = AppColors.resolveAccent(context, const Color(0xFF22C55E));

    final progress = (steps / math.max(1, goal)).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap!();
        } else {
          showExpandableClusterModal(context);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(28.0),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.28 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 270-degree Arc Painter
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: CustomPaint(
                    painter: _CircularGaugeArcPainter(
                      progress: progress,
                      trackColor: isDark
                          ? const Color(0xFF3A3E45)
                          : const Color(0xFFE2E8F0),
                      progressColor: accentGreen,
                      strokeWidth: 7.0,
                    ),
                  ),
                ),
              ),

              // Centered Metrics
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.footprints,
                    size: 16,
                    color: accentGreen,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$steps',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${distanceMeters.toStringAsFixed(0)} m',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircularGaugeArcPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  const _CircularGaugeArcPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // 270 degree arc starts at 135 degrees (3 * pi / 4)
    const startAngle = 135 * (math.pi / 180);
    const sweepTotal = 270 * (math.pi / 180);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      trackPaint,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepTotal * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularGaugeArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}

// ---------------------------------------------------------------------------
// 2. Smart Folder / Cluster Tile (1x1 Resting State)
// ---------------------------------------------------------------------------

class SmartClusterFolderTile extends StatelessWidget {
  final VoidCallback? onTap;

  const SmartClusterFolderTile({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF26292E) : const Color(0xFFF1F4F8);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap!();
        } else {
          showExpandableClusterModal(context);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(28.0),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.28 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Cluster',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'AI',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // 2x2 Sector Icons Preview
            Expanded(
              flex: 3,
              child: GridView.count(
                crossAxisCount: 2,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  _buildSectorBadge(context, LucideIcons.checkCircle2, const Color(0xFF3B82F6)),
                  _buildSectorBadge(context, LucideIcons.utensils, const Color(0xFFF59E0B)),
                  _buildSectorBadge(context, LucideIcons.wallet, const Color(0xFF10B981)),
                  _buildSectorBadge(context, LucideIcons.heartPulse, const Color(0xFFEF4444)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectorBadge(BuildContext context, IconData icon, Color color) {
    final resolvedColor = AppColors.resolveAccent(context, color);
    return Container(
      decoration: BoxDecoration(
        color: resolvedColor.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Icon(icon, size: 18, color: resolvedColor),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Expandable Frosted Cluster Modal
// ---------------------------------------------------------------------------

void showExpandableClusterModal(BuildContext context) {
  HapticFeedback.mediumImpact();

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Daily Cluster',
    barrierColor: Colors.black.withOpacity(0.55),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return const _ExpandableClusterContent();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      // Custom Spring Curve matching SpringDescription(mass: 1.0, stiffness: 320, damping: 28)
      final curvedValue = Curves.easeOutBack.transform(animation.value);
      return Transform.scale(
        scale: 0.88 + (0.12 * curvedValue),
        child: Opacity(
          opacity: animation.value.clamp(0.0, 1.0),
          child: child,
        ),
      );
    },
  );
}

class _ExpandableClusterContent extends StatefulWidget {
  const _ExpandableClusterContent();

  @override
  State<_ExpandableClusterContent> createState() => _ExpandableClusterContentState();
}

class _ExpandableClusterContentState extends State<_ExpandableClusterContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMono = AppTheme.isMonochromeMode;
    final totalWidth = MediaQuery.of(context).size.width - 32;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
            width: totalWidth,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xEB16191E) : const Color(0xEBFFFFFF),
              borderRadius: BorderRadius.circular(32.0),
              border: Border.all(
                color: Colors.white.withOpacity(isDark ? 0.12 : 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Close indicator drag bar
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ROW 1: AI Daily Insight Card (Full Width)
                  _buildAiDailyCard(context, isDark, isMono),
                  const SizedBox(height: 12),

                  // ROW 2: Steps / Goal Contrast Card (Full Width)
                  _buildStepsGoalCard(context, isDark, isMono),
                  const SizedBox(height: 12),

                  // ROW 3: Two 1x1 Action Cards Side-by-Side
                  Row(
                    children: [
                      Expanded(child: _buildTasksQuotaCard(context, isDark, isMono)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQuickActionCard(context, isDark, isMono)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Row 1: AI Daily Insight Card
  Widget _buildAiDailyCard(BuildContext context, bool isDark, bool isMono) {
    final bgColor = isMono
        ? const Color(0xFF1E1E1E)
        : (isDark ? const Color(0xFF182235) : const Color(0xFF1A263D));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.sparkles, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'AI Daily',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Updated just now',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Headline insight
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'High productivity window active. Budget safe: ₹420 remaining today.',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.arrowUpRight, color: Colors.white, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),
          // Secondary clickable insights
          _buildInsightDividerRow(
            icon: LucideIcons.clock,
            text: 'CS301 OS Revision due today at 5:00 PM',
            onTap: () {
              Navigator.pop(context);
              AppNav.instance.setTab(3); // Tasks tab
            },
          ),
          const SizedBox(height: 8),
          _buildInsightDividerRow(
            icon: LucideIcons.utensils,
            text: 'Diet: 1,450 / 2,100 kcal consumed (650 left)',
            onTap: () {
              Navigator.pop(context);
              AppNav.instance.setTab(2); // Diet tab
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInsightDividerRow({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 14, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  // Row 2: Steps / Goal Contrast Card
  Widget _buildStepsGoalCard(BuildContext context, bool isDark, bool isMono) {
    final cardBg = isDark ? const Color(0xFF25282E) : const Color(0xFFF8FAFC);
    final accentGreen = AppColors.resolveAccent(context, const Color(0xFF22C55E));

    const currentSteps = 993;
    const goalSteps = 8000;
    const progress = currentSteps / goalSteps;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Goal label row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Steps / Goal',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${goalSteps - currentSteps} steps to your goal ($goalSteps)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Horizontal Progress Bar with Walking Icon
          LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              final iconPosition = (barWidth * progress).clamp(0.0, barWidth - 18.0);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Perched walking icon
                  Transform.translate(
                    offset: Offset(iconPosition, 0),
                    child: Icon(
                      LucideIcons.footprints,
                      size: 16,
                      color: accentGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 8,
                      width: double.infinity,
                      color: isDark ? const Color(0xFF383C44) : const Color(0xFFE2E8F0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(color: accentGreen),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          // Large Count
          Text(
            '$currentSteps steps',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),

          // Bottom metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Distance 702 m',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                'Highest 24182 steps',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Row 3 (Left): Tasks / Budget Quota Card
  Widget _buildTasksQuotaCard(BuildContext context, bool isDark, bool isMono) {
    final cardBg = isDark ? const Color(0xFF202328) : const Color(0xFFF1F4F8);

    return Container(
      height: 156,
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tasks / Quota',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '3 / 5 completed',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),

          // Multi-segment horizontal bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      color: AppColors.resolveAccent(context, const Color(0xFF3B82F6)),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 1,
                    child: Container(
                      color: AppColors.resolveAccent(context, const Color(0xFFF59E0B)),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 2,
                    child: Container(color: Colors.grey.withOpacity(0.4)),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),

          // Bottom pill button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                AppNav.instance.setTab(3);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                '✓ Complete Next',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Row 3 (Right): Quick Action / Focus Card with Concentric Ripple Rings
  Widget _buildQuickActionCard(BuildContext context, bool isDark, bool isMono) {
    final cardBg = isDark ? const Color(0xFF202328) : const Color(0xFFF1F4F8);
    final accent = AppColors.resolveAccent(context, const Color(0xFF10B981));

    return Container(
      height: 156,
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Focus',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '25m Deep Work',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),

          // Bottom-Right Concentric Radar Circle CTA
          Align(
            alignment: Alignment.bottomRight,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final pulse = _pulseController.value;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    AppNav.instance.setTab(3);
                  },
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ripple Ring 2
                        Container(
                          width: 44 + (18 * pulse),
                          height: 44 + (18 * pulse),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accent.withOpacity((1.0 - pulse) * 0.4),
                              width: 1.5,
                            ),
                          ),
                        ),
                        // Ripple Ring 1
                        Container(
                          width: 44 + (9 * pulse),
                          height: 44 + (9 * pulse),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accent.withOpacity((1.0 - pulse) * 0.6),
                              width: 1.5,
                            ),
                          ),
                        ),
                        // 44dp Primary Action Circle Button
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accent.withOpacity(0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            LucideIcons.play,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
