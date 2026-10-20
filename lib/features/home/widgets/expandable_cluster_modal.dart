import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/features/money/state/money_state.dart';
import 'package:habit_tracker/features/wearables/data/wearable_repository.dart';
import 'package:habit_tracker/features/wearables/models/models.dart';

/// OxygenOS Expandable Widget Stack & Smart Cluster Components (AGENTS.md Section 3).
///
/// Features:
/// 1. Card A — 1x1 Circular Gauge Card (260° open-bottom arc, 18dp walk icon, 34sp hero, sub-metric in bottom gap).
/// 2. Card B — 1x1 Smart Cluster Folder (2x2 preview: Tasks, Diet, Money, Academic).
/// 3. Frosted 3-Tier Cluster Modal:
///    - Tier 1: AI Daily Insight Card (Deep Slate #1A2232) with live task & finance status rows.
///    - Tier 2: Steps / Daily Goal Card (Alabaster #F4F6F9) with perched walking figure icon riding above the fill position.
///    - Tier 3: Two 1x1 Square Cards (Tasks Quota + Radar Pulse CTA with 3 concentric rings).

// ---------------------------------------------------------------------------
// 1. Card A — 1x1 Circular Gauge Card (Steps)
// ---------------------------------------------------------------------------

class CompactMetricTile extends StatelessWidget {
  final int? steps;
  final int? goal;
  final double? distanceMeters;
  final VoidCallback? onTap;

  const CompactMetricTile({
    super.key,
    this.steps,
    this.goal,
    this.distanceMeters,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (Hive.isBoxOpen('wear_daily')) {
      return ValueListenableBuilder(
        valueListenable: Hive.box<DailyActivity>('wear_daily').listenable(),
        builder: (context, _, __) {
          final dayView = WearableRepository.instance.dayView(today);
          final currentSteps = steps ?? dayView.totalSteps;
          final stepGoal = goal ??
              (Hive.isBoxOpen('settings')
                  ? (Hive.box('settings').get('daily_step_goal', defaultValue: 8000) as num).toInt()
                  : 8000);
          final distM = distanceMeters ??
              (dayView.activity?.distanceM?.toDouble() ?? (currentSteps > 0 ? currentSteps * 0.762 : 0.0));
          return _buildContent(context, currentSteps, stepGoal, distM);
        },
      );
    }

    final dayView = WearableRepository.instance.dayView(today);
    final currentSteps = steps ?? dayView.totalSteps;
    final stepGoal = goal ??
        (Hive.isBoxOpen('settings')
            ? (Hive.box('settings').get('daily_step_goal', defaultValue: 8000) as num).toInt()
            : 8000);
    final distM = distanceMeters ??
        (dayView.activity?.distanceM?.toDouble() ?? (currentSteps > 0 ? currentSteps * 0.762 : 0.0));
    return _buildContent(context, currentSteps, stepGoal, distM);
  }

  Widget _buildContent(BuildContext context, int currentSteps, int stepGoal, double distM) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMono = AppTheme.isMonochromeMode;
    final accentGreen = AppColors.resolveAccent(context, const Color(0xFF22C55E));

    final progress = stepGoal > 0 ? (currentSteps / stepGoal).clamp(0.0, 1.0) : 0.0;
    final distText = distM >= 1000 ? '${(distM / 1000).toStringAsFixed(1)} km' : '${distM.toStringAsFixed(0)} m';

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
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF262A30), Color(0xFF1C1F24)],
                )
              : null,
          color: isDark ? null : Colors.white,
          borderRadius: BorderRadius.circular(28.0),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.09) : const Color(0xFFE5E7EB),
            width: 0.8,
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
              // 260-degree Centered Open-Bottom Arc
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: CustomPaint(
                    painter: _CircularGaugeArcPainter(
                      progress: progress,
                      trackColor: isDark
                          ? Colors.white.withOpacity(0.08)
                          : const Color(0xFFE2E8F0),
                      progressColor: isMono ? Colors.white : accentGreen,
                      strokeWidth: 9.5,
                    ),
                  ),
                ),
              ),

              // 18dp Icon at top-center inside ring
              Positioned(
                top: 22,
                child: Icon(
                  Icons.directions_walk_rounded,
                  size: 18,
                  color: isMono ? Colors.white70 : accentGreen,
                ),
              ),

              // Hero Number dead-center
              Center(
                child: Text(
                  '$currentSteps',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: isDark ? Colors.white : const Color(0xFF111417),
                  ),
                ),
              ),

              // Sub-metric nestled in bottom gap of the arc
              Positioned(
                bottom: 16,
                child: Text(
                  distText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
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
    this.strokeWidth = 9.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // 260 degree arc starts at 140 degrees (bottom-left) and sweeps 260 degrees clockwise to 400 degrees (40 deg, bottom-right).
    // Bottom gap is 100 degrees centered at 90 degrees.
    const startAngle = 140 * (math.pi / 180);
    const sweepTotal = 260 * (math.pi / 180);

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

    // Background track arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      trackPaint,
    );

    // Active arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepTotal * progress.clamp(0.0, 1.0),
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularGaugeArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

// ---------------------------------------------------------------------------
// 2. Card B — 1x1 Smart Cluster Folder (Resting State)
// ---------------------------------------------------------------------------

class SmartClusterFolderTile extends StatelessWidget {
  final VoidCallback? onTap;

  const SmartClusterFolderTile({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF262A30), Color(0xFF1C1F24)],
                )
              : null,
          color: isDark ? null : Colors.white,
          borderRadius: BorderRadius.circular(28.0),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.09) : const Color(0xFFE5E7EB),
            width: 0.8,
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
            // Top Row Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Hub',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.sparkles,
                        size: 9,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'AI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
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
                  _buildSectorBadge(context, LucideIcons.checkSquare, const Color(0xFF3B82F6)),
                  _buildSectorBadge(context, LucideIcons.utensils, const Color(0xFFF59E0B)),
                  _buildSectorBadge(context, LucideIcons.wallet, const Color(0xFF10B981)),
                  _buildSectorBadge(context, LucideIcons.graduationCap, const Color(0xFF8B5CF6)),
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
// 3. Frosted 3-Tier Cluster Modal
// ---------------------------------------------------------------------------

void showExpandableClusterModal(BuildContext context) {
  HapticFeedback.mediumImpact();

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Daily Cluster',
    barrierColor: Colors.black.withOpacity(0.60),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return const _ExpandableClusterContent();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
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
          filter: ImageFilter.blur(sigmaX: 28.0, sigmaY: 28.0),
          child: Container(
            width: totalWidth,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xEB16191E) : const Color(0xEBFFFFFF),
              borderRadius: BorderRadius.circular(32.0),
              border: Border.all(
                color: Colors.white.withOpacity(isDark ? 0.12 : 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.48),
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

                  // TIER 1: AI Daily Insight Card (Deep Slate #1A2232)
                  _buildAiDailyCard(context, isDark, isMono),
                  const SizedBox(height: 12),

                  // TIER 2: Steps / Goal Contrast Card (Crisp Alabaster #F4F6F9)
                  _buildStepsGoalCard(context, isDark, isMono),
                  const SizedBox(height: 12),

                  // TIER 3: Two 1x1 Action Cards Side-by-Side (12dp gap)
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

  // Tier 1: AI Daily Insight Card (Deep Slate #1A2232)
  Widget _buildAiDailyCard(BuildContext context, bool isDark, bool isMono) {
    const bgColor = Color(0xFF1A2232);

    // Live state bindings
    final moneySnapshot = MoneyState().value;
    final safeRupees = moneySnapshot.freeToSpend.freeToSpendRupees;

    List<Goal> dailyGoals = [];
    if (Hive.isBoxOpen('mission_box_v4')) {
      dailyGoals = Hive.box<Goal>('mission_box_v4')
          .values
          .where((g) => g.type == GoalType.daily)
          .toList();
    }
    final pendingCount = dailyGoals.where((g) => !g.isCompleted).length;
    final nextMissionTitle = dailyGoals.any((g) => !g.isCompleted)
        ? dailyGoals.firstWhere((g) => !g.isCompleted).title
        : 'All daily missions completed';

    DietDayLog? dietLog;
    if (Hive.isBoxOpen('diet_logs')) {
      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      dietLog = Hive.box<DietDayLog>('diet_logs').get(todayKey);
    }
    final dietIntake = dietLog?.totalCalories ?? 0;
    final dietTarget = dietLog?.targetCalories ?? 2000;

    final primaryInsight = pendingCount > 0
        ? 'High focus window active. $pendingCount key missions pending. Budget safe: ₹${safeRupees.toStringAsFixed(0)} remaining.'
        : 'All core missions complete. Great momentum! Budget safe: ₹${safeRupees.toStringAsFixed(0)} remaining.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: AI Daily pill + Updated time
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

          // Primary 2-line headline insight
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  primaryInsight,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
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

          // 2 clean hairline-separated live status rows below
          _buildInsightDividerRow(
            icon: LucideIcons.checkSquare,
            text: pendingCount > 0 ? 'Mission: $nextMissionTitle' : 'Missions: 100% completed today',
            onTap: () {
              Navigator.pop(context);
              AppNav.instance.setTab(3); // Tasks tab
            },
          ),
          const SizedBox(height: 8),
          _buildInsightDividerRow(
            icon: LucideIcons.utensils,
            text: 'Diet: $dietIntake / $dietTarget kcal (${math.max(0, dietTarget - dietIntake)} left)',
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

  // Tier 2: Steps / Goal Contrast Card (Crisp Alabaster #F4F6F9)
  Widget _buildStepsGoalCard(BuildContext context, bool isDark, bool isMono) {
    const cardBg = Color(0xFFF4F6F9);
    final accentGreen = AppColors.resolveAccent(context, const Color(0xFF22C55E));

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dayView = WearableRepository.instance.dayView(today);
    final currentSteps = dayView.totalSteps;
    final goalSteps = Hive.isBoxOpen('settings')
        ? (Hive.box('settings').get('daily_step_goal', defaultValue: 8000) as num).toInt()
        : 8000;
    final progress = goalSteps > 0 ? (currentSteps / goalSteps).clamp(0.0, 1.0) : 0.0;
    final distanceM = (dayView.activity?.distanceM ?? (currentSteps > 0 ? currentSteps * 0.762 : 0)).round();

    int highestSteps = currentSteps;
    for (int i = 0; i < 7; i++) {
      final dKey = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: i)));
      final s = WearableRepository.instance.dayView(dKey).totalSteps;
      if (s > highestSteps) highestSteps = s;
    }
    if (highestSteps == 0) highestSteps = 8000;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Goal label row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Steps / Goal',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              Text(
                goalSteps > currentSteps
                    ? '${goalSteps - currentSteps} steps to your goal ($goalSteps)'
                    : 'Goal achieved ($goalSteps steps)!',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Horizontal Linear Progress Bar (8dp) with perched walking figure icon riding above fill position
          LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              final iconPosition = (barWidth * progress).clamp(0.0, barWidth - 18.0);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: Offset(iconPosition, 0),
                    child: Icon(
                      Icons.directions_walk_rounded,
                      size: 16,
                      color: accentGreen,
                    ),
                  ),
                  const SizedBox(height: 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 8,
                      width: double.infinity,
                      color: const Color(0xFFE2E8F0),
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

          // Huge bottom-left metric (32sp, #111417)
          Text(
            '$currentSteps steps',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              color: Color(0xFF111417),
            ),
          ),
          const SizedBox(height: 6),

          // Bottom metadata row (Distance left, Highest steps right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Distance ${distanceM >= 1000 ? "${(distanceM / 1000).toStringAsFixed(2)} km" : "$distanceM m"}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
              Text(
                'Highest $highestSteps steps',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Tier 3 (Left): Tasks / Habits Quota Card (Matte Dark #1E2126)
  Widget _buildTasksQuotaCard(BuildContext context, bool isDark, bool isMono) {
    const cardBg = Color(0xFF1E2126);

    List<Goal> dailyGoals = [];
    if (Hive.isBoxOpen('mission_box_v4')) {
      dailyGoals = Hive.box<Goal>('mission_box_v4')
          .values
          .where((g) => g.type == GoalType.daily)
          .toList();
    }
    final total = math.max(1, dailyGoals.length);
    final completed = dailyGoals.where((g) => g.isCompleted).length;
    final habitFraction = ((total - completed) * 0.4).round();
    final pendingFraction = math.max(0, total - completed - habitFraction);

    return Container(
      height: 156,
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22.0),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Focus",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$completed / $total done',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 10),

          // 3-segment thin color-coded progress bar (Completed / Habit / Pending)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: math.max(1, completed),
                    child: Container(
                      color: AppColors.resolveAccent(context, const Color(0xFF3B82F6)),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: math.max(1, habitFraction),
                    child: Container(
                      color: AppColors.resolveAccent(context, const Color(0xFFF59E0B)),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: math.max(1, pendingFraction),
                    child: Container(color: Colors.white.withOpacity(0.18)),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),

          // Bottom translucent pill button (✓ Complete Next)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                AppNav.instance.setTab(3);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0x33FFFFFF),
                foregroundColor: Colors.white,
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

  // Tier 3 (Right): Quick Sync / Focus Card with 3 concentric radar rings (Matte Dark #1E2126)
  Widget _buildQuickActionCard(BuildContext context, bool isDark, bool isMono) {
    const cardBg = Color(0xFF1E2126);
    final accent = AppColors.resolveAccent(context, const Color(0xFF10B981));

    return Container(
      height: 156,
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22.0),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Focus',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '25m Deep Work',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
          ),
          const Spacer(),

          // Bottom-Right 44dp Circular Accent Button + 3 Concentric Radar Rings
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
                        // CustomPainter with 3 subtle concentric radar rings
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _RadarPulsePainter(
                              pulse: pulse,
                              accent: accent,
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

/// 3 subtle concentric radar rings animated outwards
class _RadarPulsePainter extends CustomPainter {
  final double pulse;
  final Color accent;

  const _RadarPulsePainter({required this.pulse, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const baseRadius = 22.0;

    for (int i = 1; i <= 3; i++) {
      final ringPulse = (pulse + (i * 0.33)) % 1.0;
      final ringRadius = baseRadius + (18.0 * ringPulse);
      final opacity = (1.0 - ringPulse) * 0.45;
      final paint = Paint()
        ..color = accent.withOpacity(opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(center, ringRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPulsePainter oldDelegate) =>
      oldDelegate.pulse != pulse || oldDelegate.accent != accent;
}
