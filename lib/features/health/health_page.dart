import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/data/models/health_models.dart';
import 'package:habit_tracker/data/services/medicine_service.dart';
import 'package:habit_tracker/core/motion/SHealthCelebrationOverlay.dart';
import 'package:habit_tracker/features/health/walking_steps_detail_page.dart';
import 'package:habit_tracker/features/wearables/data/wearable_repository.dart';
import 'package:habit_tracker/features/wearables/ui/fitness_tab.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/features/diet/data/diet_repository.dart';
import 'package:habit_tracker/features/diet/diet_page.dart';

/// Health & Wellness Master Page.
/// Features the Dribbble-inspired Personal Health Dashboard (Phase 3)
/// plus integrated tabs for Medicine Adherence, Weight Journey, and Wearables.
class HealthPage extends StatefulWidget {
  final int initialTab; // 0: Personal Health, 1: Medicine, 2: Weight, 3: Wearables

  const HealthPage({super.key, this.initialTab = 0});

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 3);
  }

  void _switchTab(int index) {
    HapticFeedback.lightImpact();
    setState(() => _selectedTab = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Section 2.3 Master Surface Tokens
    final bgColor = isDark ? const Color(0xFF0B0E11) : const Color(0xFFF6F7F9);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Tab Selector Bar
            _buildTabSelector(isDark),

            // Tab View Body
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  _PersonalHealthDashboard(
                    onOpenTab: _switchTab,
                  ),
                  const _MedicineTab(),
                  const _WeightTab(),
                  const FitnessTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector(bool isDark) {
    final tabs = const [
      ('HEALTH', LucideIcons.heartPulse),
      ('MEDICINE', LucideIcons.pill),
      ('WEIGHT', LucideIcons.scale),
      ('WEARABLE', LucideIcons.activity),
    ];

    final pillBg = isDark ? const Color(0xFF161B22) : const Color(0xFFFFFFFF);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTab == index;
          final label = tabs[index].$1;
          final icon = tabs[index].$2;

          final emerald = isDark ? const Color(0xFF10B981) : const Color(0xFF05B87C);
          final activeColor = AppColors.resolveAccent(context, emerald);

          return Expanded(
            child: GestureDetector(
              onTap: () => _switchTab(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? const Color(0xFF8B949E) : const Color(0xFF8A929A)),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark ? const Color(0xFF8B949E) : const Color(0xFF8A929A)),
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ============================================================================
// 3.1 MASTER HEALTH DASHBOARD (DRIBBBLE REFERENCE EXACT IMPLEMENTATION)
// ============================================================================
class _PersonalHealthDashboard extends StatefulWidget {
  final Function(int) onOpenTab;

  const _PersonalHealthDashboard({required this.onOpenTab});

  @override
  State<_PersonalHealthDashboard> createState() => _PersonalHealthDashboardState();
}

class _PersonalHealthDashboardState extends State<_PersonalHealthDashboard> {
  int _selectedDayIndex = 6; // Default to today (last index of 7-day rolling window)

  late List<DateTime> _weekDays;

  @override
  void initState() {
    super.initState();
    _refreshDays();
  }

  void _refreshDays() {
    final now = DateTime.now();
    _weekDays = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Palette Tokens from AGENTS.md Section 2.3
    final cardSurface = isDark ? const Color(0xFF15191E) : const Color(0xFFFFFFFF);
    final secSurface = isDark ? const Color(0xFF1F2630) : const Color(0xFFF3F5F7);
    final textPrimary = isDark ? const Color(0xFFF3F6F9) : const Color(0xFF111417);
    final textSubtitle = isDark ? const Color(0xFF8B949E) : const Color(0xFF8A929A);

    final emeraldAccent = isDark ? const Color(0xFF10B981) : const Color(0xFF05B87C);
    final coralAccent = isDark ? const Color(0xFFFF6B6B) : const Color(0xFFFF6E6E);
    final actionCircle = isDark ? const Color(0xFF1E293B) : const Color(0xFF111111);
    final actionCircleText = isDark ? const Color(0xFF10B981) : Colors.white;

    final resolvedEmerald = AppColors.resolveAccent(context, emeraldAccent);
    final resolvedCoral = AppColors.resolveAccent(context, coralAccent);

    // Selected Date & Real Day View
    final selectedDate = _weekDays[_selectedDayIndex];
    final selectedDateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    final dayView = WearableRepository.instance.dayView(selectedDateKey);

    final stepCount = dayView.totalSteps;
    final distanceMeters = dayView.activity?.distanceM ?? (stepCount * 0.762);
    final distanceKm = distanceMeters / 1000.0;

    // Real Sleep Metric
    final mainSleep = WearableRepository.instance.getMainSleep(selectedDateKey);
    final sleepMinutes = mainSleep?.durationMin ?? dayView.sleepDurationMin;
    final sleepScore = mainSleep?.score ?? dayView.sleepScore;

    // Real Nutrition Metric
    final dietRepo = DietRepository.instance;
    final dayLogs = dietRepo.getLogsForDate(selectedDateKey);
    final consumedKcal = dayLogs.fold<double>(0.0, (acc, entry) => acc + entry.kcal).round();
    final targetKcal = (dietRepo.profile.targetCalories != null && dietRepo.profile.targetCalories! > 0)
        ? dietRepo.profile.targetCalories!.round()
        : dietRepo.dailyTargets.targetKcal.round();
    final caloriePercent = targetKcal > 0 ? ((consumedKcal / targetKcal) * 100).round() : 0;

    // Real Weight Metric
    final weightTrendVal = dietRepo.weightTrend.currentEwmaKg;
    final latestWeight = weightTrendVal > 0
        ? weightTrendVal
        : (dietRepo.profile.currentWeightKg > 0
            ? dietRepo.profile.currentWeightKg
            : WearableRepository.instance.getLatestBodyComp()?.weightKg);

    // Real Exercise Active Minutes
    final dayExercises = WearableRepository.instance.getExercisesForDay(selectedDateKey);
    final exerciseMins = dayView.activeMinutes > 0
        ? dayView.activeMinutes
        : dayExercises.fold<int>(0, (acc, e) => acc + e.durationMin);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        // 1. Top Header Row: User Avatar + Welcome + User Name + 42dp Grid Button
        _buildTopHeaderRow(textPrimary, textSubtitle, secSurface),
        const SizedBox(height: 16),

        // 2. Hero Steps & Day-Ruler Pill Card (100% Real Steps + Interactive 7-Day Ruler)
        _buildHeroStepsPill(
          cardSurface: cardSurface,
          secSurface: secSurface,
          textPrimary: textPrimary,
          textSubtitle: textSubtitle,
          emerald: resolvedEmerald,
          stepCount: stepCount,
          distanceKm: distanceKm,
          selectedDate: selectedDate,
          dayView: dayView,
          isDark: isDark,
        ),
        const SizedBox(height: 18),

        // 3. Section Heading: Personal Health
        Text(
          'Personal Health',
          style: TextStyle(
            color: textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 14),

        // 4. Asymmetric 2-Column Bento Grid
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Sleep & Recovery (175dp) + Body Weight Trend (115dp)
            Expanded(
              child: Column(
                children: [
                  _buildSleepRecoveryCard(
                    cardSurface: cardSurface,
                    textPrimary: textPrimary,
                    textSubtitle: textSubtitle,
                    emerald: resolvedEmerald,
                    coral: resolvedCoral,
                    sleepMinutes: sleepMinutes,
                    sleepScore: sleepScore,
                    weekDays: _weekDays,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  _buildBodyWeightCard(
                    cardSurface: cardSurface,
                    textPrimary: textPrimary,
                    textSubtitle: textSubtitle,
                    coral: resolvedCoral,
                    latestWeight: latestWeight,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Right Column: Nutrition & Calorie Target (175dp) + Workouts Circle CTA (115dp)
            Expanded(
              child: Column(
                children: [
                  _buildNutritionCard(
                    cardSurface: cardSurface,
                    textPrimary: textPrimary,
                    textSubtitle: textSubtitle,
                    emerald: resolvedEmerald,
                    consumedKcal: consumedKcal,
                    targetKcal: targetKcal,
                    hitPercent: caloriePercent,
                    dietRepo: dietRepo,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  _buildExerciseCtaCard(
                    circleBg: actionCircle,
                    textColor: actionCircleText,
                    emerald: resolvedEmerald,
                    exerciseMins: exerciseMins,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 5. Bottom Full-Width Card: Weekly Activity Bar Card (96dp)
        _buildWeeklyActivityBarCard(
          cardSurface: cardSurface,
          secSurface: secSurface,
          textPrimary: textPrimary,
          textSubtitle: textSubtitle,
          emerald: resolvedEmerald,
          weekDays: _weekDays,
          selectedIndex: _selectedDayIndex,
          isDark: isDark,
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // 1. TOP HEADER ROW
  // --------------------------------------------------------------------------
  Widget _buildTopHeaderRow(Color textPrimary, Color textSubtitle, Color secSurface) {
    final settingsBox = Hive.box('settings');
    final userName = settingsBox.get('username', defaultValue: 'User');

    return Row(
      children: [
        // Circular User Avatar (42dp)
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Welcome + Name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome',
                style: TextStyle(
                  color: textSubtitle,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                userName,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),

        // 42dp Circular Surface Button with 2x2 dot grid icon
        GestureDetector(
          onTap: _showHealthMenuSheet,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: secSurface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.grid_view_rounded,
              color: textPrimary,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  void _showHealthMenuSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF15191E) : Colors.white;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? const Color(0xFF222831) : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Health Modules',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x2205B87C),
                  child: Icon(LucideIcons.heartPulse, color: Color(0xFF05B87C)),
                ),
                title: const Text('Personal Health Dashboard', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Overview & Realtime Vitals'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onOpenTab(0);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x223B82F6),
                  child: Icon(LucideIcons.pill, color: Color(0xFF3B82F6)),
                ),
                title: const Text('Medicine Adherence', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Scheduled prescriptions & dosage'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onOpenTab(1);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x22F59E0B),
                  child: Icon(LucideIcons.scale, color: Color(0xFFF59E0B)),
                ),
                title: const Text('Weight Journey', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Target weight and logs'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onOpenTab(2);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x228B5CF6),
                  child: Icon(LucideIcons.activity, color: Color(0xFF8B5CF6)),
                ),
                title: const Text('Wearable & Sensor Data', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Galaxy Watch & Health Connect'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onOpenTab(3);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // 2. HERO STEPS & INTERACTIVE 7-DAY RULER PILL CARD
  // --------------------------------------------------------------------------
  Widget _buildHeroStepsPill({
    required Color cardSurface,
    required Color secSurface,
    required Color textPrimary,
    required Color textSubtitle,
    required Color emerald,
    required int stepCount,
    required double distanceKm,
    required DateTime selectedDate,
    required WearableDayView dayView,
    required bool isDark,
  }) {
    return Container(
      height: 116,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(64),
        border: Border.all(
          color: isDark ? const Color(0xFF222831) : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.35) : const Color(0x0A000000),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Circle (92dp diameter): Solid Emerald Steps Circle
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WalkingStepsDetailPage(
                    totalSteps: stepCount,
                    totalDistanceKm: distanceKm,
                    selectedDate: selectedDate,
                    activeKcal: dayView.activity?.activeKcal,
                    activeMinutes: dayView.activeMinutes,
                  ),
                ),
              );
            },
            child: GoalRingPulse(
              trigger: stepCount >= 8000,
              pulseColor: emerald,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: emerald,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: emerald.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.directions_walk_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      NumberFormat('#,###').format(stepCount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'Steps',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Right Timeline Ruler: Interactive 7-Day Strip + Horizontal Ruler Ticks
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 7 Days Strip (Mon..Sun)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(_weekDays.length, (idx) {
                    final dayDate = _weekDays[idx];
                    final dayLabel = DateFormat('E').format(dayDate);
                    final isSelected = _selectedDayIndex == idx;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedDayIndex = idx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? emerald.withOpacity(0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          dayLabel,
                          style: TextStyle(
                            color: isSelected ? emerald : textSubtitle,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),

                // Horizontal Timeline Ruler with Major and Minor Vertical Tick Marks
                SizedBox(
                  height: 22,
                  child: CustomPaint(
                    size: const Size(double.infinity, 22),
                    painter: _TimelineRulerPainter(
                      totalDays: _weekDays.length,
                      selectedIndex: _selectedDayIndex,
                      tickColor: textSubtitle.withOpacity(0.35),
                      activeColor: emerald,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 4.1 BENTO CARD 1: SLEEP & RECOVERY (175dp) — REAL DATA
  // --------------------------------------------------------------------------
  Widget _buildSleepRecoveryCard({
    required Color cardSurface,
    required Color textPrimary,
    required Color textSubtitle,
    required Color emerald,
    required Color coral,
    required int? sleepMinutes,
    required int? sleepScore,
    required List<DateTime> weekDays,
    required bool isDark,
  }) {
    final sleepDurations = weekDays.map((d) {
      final k = DateFormat('yyyy-MM-dd').format(d);
      return WearableRepository.instance.getMainSleep(k)?.durationMin.toDouble() ?? 0.0;
    }).toList();

    return GestureDetector(
      onTap: () => widget.onOpenTab(3), // Open Wearables tab
      child: Container(
        height: 175,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? const Color(0xFF222831) : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.35) : const Color(0x0A000000),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Soft Coral/Indigo Circle (36dp) + Sleep & Recovery label
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: coral.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bedtime_rounded,
                    color: coral,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Sleep &\nRecovery',
                  style: TextStyle(
                    color: textSubtitle,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
            const Spacer(),

            // Middle: Real Sleep Hours / Score
            if (sleepMinutes != null && sleepMinutes > 0)
              RichText(
                text: TextSpan(
                  text: '${sleepMinutes ~/ 60}h ${sleepMinutes % 60}m',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  children: [
                    if (sleepScore != null)
                      TextSpan(
                        text: '  $sleepScore',
                        style: TextStyle(
                          color: emerald,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              )
            else if (sleepScore != null)
              RichText(
                text: TextSpan(
                  text: 'Score $sleepScore',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              )
            else
              Text(
                'Tap to log',
                style: TextStyle(
                  color: textSubtitle,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 10),

            // Bottom: Real Sleep ECG/Rhythm Waveform with Emerald Peak Highlight
            SizedBox(
              height: 42,
              width: double.infinity,
              child: CustomPaint(
                painter: _SleepWaveformPainter(
                  emeraldColor: emerald,
                  lineColor: textSubtitle.withOpacity(0.4),
                  sleepDurations: sleepDurations,
                  selectedIndex: _selectedDayIndex,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 4.2 BENTO CARD 3: BODY WEIGHT TREND (115dp) — REAL DATA
  // --------------------------------------------------------------------------
  Widget _buildBodyWeightCard({
    required Color cardSurface,
    required Color textPrimary,
    required Color textSubtitle,
    required Color coral,
    required double? latestWeight,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => widget.onOpenTab(2), // Open Weight Journey Tab
      child: Container(
        height: 115,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? const Color(0xFF222831) : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.35) : const Color(0x0A000000),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Soft Rose Circle (34dp) + Body Weight label
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: coral.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.scale,
                    color: coral,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Body\nWeight',
                  style: TextStyle(
                    color: textSubtitle,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  latestWeight != null && latestWeight > 0
                      ? '${latestWeight.toStringAsFixed(1)} kg'
                      : '-- kg',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const Spacer(),

            // Bottom: Smooth coral-pink spline wave with gradient fill plotted from actual weight
            SizedBox(
              height: 34,
              width: double.infinity,
              child: CustomPaint(
                painter: _SmoothWavePainter(coralColor: coral),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 4.3 BENTO CARD 2: NUTRITION & CALORIE TARGET (175dp) — REAL DATA
  // --------------------------------------------------------------------------
  Widget _buildNutritionCard({
    required Color cardSurface,
    required Color textPrimary,
    required Color textSubtitle,
    required Color emerald,
    required int consumedKcal,
    required int targetKcal,
    required int hitPercent,
    required DietRepository dietRepo,
    required bool isDark,
  }) {
    // Compute the 18 dot states for the last 18 days
    final now = DateTime.now();
    final dotStates = List.generate(18, (i) {
      final d = now.subtract(Duration(days: 17 - i));
      final k = DateFormat('yyyy-MM-dd').format(d);
      final logs = dietRepo.getLogsForDate(k);
      final dayKcal = logs.fold<double>(0.0, (acc, e) => acc + e.kcal);
      if (dayKcal >= (targetKcal * 0.85) && targetKcal > 0) return 2; // Target met (Emerald)
      if (dayKcal > 0) return 1; // Logged/partial (Mint)
      return 0; // Missed / empty (Grey)
    });

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Switch to Diet page or show dietary quick log
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DietPage()),
        );
      },
      child: Container(
        height: 175,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? const Color(0xFF222831) : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.35) : const Color(0x0A000000),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Soft Coral/Orange Circle (36dp) + Nutrition & Calorie label
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6E6E).withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.restaurant_rounded,
                    color: Color(0xFFFF6E6E),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Nutrition &\nCalories',
                  style: TextStyle(
                    color: textSubtitle,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
            const Spacer(),

            // Middle: Real Consumed Kcal + Target %
            RichText(
              text: TextSpan(
                text: NumberFormat('#,###').format(consumedKcal),
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                children: [
                  TextSpan(
                    text: ' kcal',
                    style: TextStyle(
                      color: textSubtitle,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (hitPercent > 0)
                    TextSpan(
                      text: ' • $hitPercent%',
                      style: TextStyle(
                        color: emerald,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Bottom: 6x3 Dot Matrix (18 dots) representing real meal target adherence
            SizedBox(
              height: 42,
              width: double.infinity,
              child: CustomPaint(
                painter: _DotMatrixPainter(
                  emeraldColor: emerald,
                  inactiveColor: textSubtitle.withOpacity(0.25),
                  dotStates: dotStates,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 4.4 BENTO CARD 4: WORKOUTS CIRCLE CTA (115dp) — REAL DATA
  // --------------------------------------------------------------------------
  Widget _buildExerciseCtaCard({
    required Color circleBg,
    required Color textColor,
    required Color emerald,
    required int exerciseMins,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: _showExerciseLoggerSheet,
      child: Container(
        height: 115,
        alignment: Alignment.center,
        child: Container(
          width: 115,
          height: 115,
          decoration: BoxDecoration(
            color: circleBg,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? emerald.withOpacity(0.4) : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: circleBg.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.directions_run_rounded,
                color: textColor,
                size: 30,
              ),
              const SizedBox(height: 3),
              Text(
                'Exercise',
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                exerciseMins > 0 ? '$exerciseMins min' : '0 min',
                style: TextStyle(
                  color: textColor.withOpacity(0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExerciseLoggerSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF15191E) : Colors.white;
        final emerald = isDark ? const Color(0xFF10B981) : const Color(0xFF05B87C);

        final exercises = const [
          ('Running', Icons.directions_run_rounded, '30 min', '260 kcal'),
          ('Cycling', Icons.directions_bike_rounded, '45 min', '320 kcal'),
          ('Gym / Strength', Icons.fitness_center_rounded, '45 min', '280 kcal'),
          ('Walking', Icons.directions_walk_rounded, '60 min', '190 kcal'),
        ];

        return Container(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? const Color(0xFF222831) : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Log Workout Session',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              ...exercises.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F2630) : const Color(0xFFF3F5F7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: emerald.withOpacity(0.2),
                        child: Icon(item.$2, color: emerald, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$1,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            Text(
                              '${item.$3} • ${item.$4}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: emerald,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(sheetCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Logged ${item.$1} session (+${item.$4})!'),
                              backgroundColor: emerald,
                            ),
                          );
                        },
                        child: const Text('Log', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // 5. BOTTOM FULL-WIDTH CARD: WEEKLY ACTIVITY BAR CARD (96dp) — REAL DATA
  // --------------------------------------------------------------------------
  Widget _buildWeeklyActivityBarCard({
    required Color cardSurface,
    required Color secSurface,
    required Color textPrimary,
    required Color textSubtitle,
    required Color emerald,
    required List<DateTime> weekDays,
    required int selectedIndex,
    required bool isDark,
  }) {
    final selectedDate = weekDays[selectedIndex];
    final selectedDayName = DateFormat('EEEE').format(selectedDate);

    // Real steps for each of the 7 days
    final weeklySteps = weekDays.map((d) {
      final k = DateFormat('yyyy-MM-dd').format(d);
      return WearableRepository.instance.dayView(k).totalSteps;
    }).toList();

    final maxSteps = math.max(8000, weeklySteps.reduce(math.max));

    return GestureDetector(
      onTap: () {
        final currentSteps = weeklySteps[selectedIndex];
        final distKm = (currentSteps * 0.762) / 1000.0;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WalkingStepsDetailPage(
              totalSteps: currentSteps,
              totalDistanceKm: distKm,
              selectedDate: selectedDate,
            ),
          ),
        );
      },
      child: Container(
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: cardSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? const Color(0xFF222831) : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.35) : const Color(0x0A000000),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Activity label + Selected Weekday Name
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Activity',
                  style: TextStyle(
                    color: textSubtitle,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedDayName,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),

            // Right: 7 vertical rounded bars scaled to real daily step counts
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(weeklySteps.length, (index) {
                final isSelected = index == selectedIndex;
                final heightFraction = (weeklySteps[index] / maxSteps).clamp(0.12, 1.0);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    width: 14,
                    height: 54 * heightFraction,
                    decoration: BoxDecoration(
                      color: isSelected ? emerald : secSurface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CUSTOM PAINTERS (100% REAL DATA BOUND)
// ============================================================================

/// 1. Timeline Ruler with major ticks under days and minor ticks in between
class _TimelineRulerPainter extends CustomPainter {
  final int totalDays;
  final int selectedIndex;
  final Color tickColor;
  final Color activeColor;

  _TimelineRulerPainter({
    required this.totalDays,
    required this.selectedIndex,
    required this.tickColor,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final regularPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final minorPaint = Paint()
      ..color = tickColor.withOpacity(0.45)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final step = size.width / totalDays;

    for (int i = 0; i < totalDays; i++) {
      final centerX = (i + 0.5) * step;
      final isSelected = i == selectedIndex;

      // Major tick
      final paintToUse = isSelected ? activePaint : regularPaint;
      final tickTop = isSelected ? 0.0 : 4.0;
      canvas.drawLine(
        Offset(centerX, tickTop),
        Offset(centerX, size.height),
        paintToUse,
      );

      // Minor ticks between days
      if (i < totalDays - 1) {
        for (int m = 1; m <= 3; m++) {
          final minorX = centerX + (m * (step / 4.0));
          canvas.drawLine(
            Offset(minorX, size.height - 8),
            Offset(minorX, size.height),
            minorPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineRulerPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.tickColor != tickColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.totalDays != totalDays;
  }
}

/// 2. Sleep ECG/Rhythm Waveform with Emerald Peak Highlight & Real Durations
class _SleepWaveformPainter extends CustomPainter {
  final Color emeraldColor;
  final Color lineColor;
  final List<double> sleepDurations;
  final int selectedIndex;

  _SleepWaveformPainter({
    required this.emeraldColor,
    required this.lineColor,
    required this.sleepDurations,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final baseline = h * 0.65;

    // Determine the peak night (or selected night)
    int peakIndex = selectedIndex;
    if (sleepDurations.isNotEmpty) {
      final maxDur = sleepDurations.reduce(math.max);
      if (maxDur > 0) {
        peakIndex = sleepDurations.indexOf(maxDur);
      }
    }

    final n = math.max(1, sleepDurations.length);
    final peakX = (peakIndex / (n - 1).clamp(1, double.infinity)) * (w * 0.70) + (w * 0.15);

    // 1. Vertical Emerald Highlight Band behind the Peak
    final bandRect = Rect.fromLTWH(peakX - 10, 0, 20, h);
    final bandPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          emeraldColor.withOpacity(0.28),
          emeraldColor.withOpacity(0.04),
        ],
      ).createShader(bandRect);
    canvas.drawRRect(RRect.fromRectAndRadius(bandRect, const Radius.circular(8)), bandPaint);

    // 2. ECG Sleep Wave Path
    final path = Path();
    path.moveTo(0, baseline);
    path.lineTo(w * 0.15, baseline);

    // First rhythm
    path.quadraticBezierTo(w * 0.20, baseline - 5, w * 0.25, baseline);
    path.lineTo(peakX - 16, baseline);

    // Q-dip
    path.lineTo(peakX - 8, baseline + 4);

    // R-peak (sharp tall spike)
    final peakY = h * 0.15;
    path.lineTo(peakX, peakY);

    // S-dip (deep sharp dip)
    path.lineTo(peakX + 8, baseline + 10);
    path.lineTo(peakX + 16, baseline);

    // T-wave
    path.quadraticBezierTo(w * 0.82, baseline - 8, w * 0.90, baseline);
    path.lineTo(w, baseline);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // 3. Glowing Dot on Peak
    final glowPaint = Paint()
      ..color = emeraldColor.withOpacity(0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(peakX, peakY), 7, glowPaint);

    final dotPaint = Paint()
      ..color = emeraldColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(peakX, peakY), 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SleepWaveformPainter oldDelegate) {
    return oldDelegate.emeraldColor != emeraldColor ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.sleepDurations != sleepDurations;
  }
}

/// 3. Smooth Coral-Pink Spline Wave with Soft Gradient Fill Underneath
class _SmoothWavePainter extends CustomPainter {
  final Color coralColor;

  _SmoothWavePainter({required this.coralColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(0, h * 0.75);
    path.cubicTo(w * 0.25, h * 0.2, w * 0.55, h * 0.85, w * 0.80, h * 0.3);
    path.quadraticBezierTo(w * 0.92, h * 0.1, w, h * 0.4);

    // Fill underneath
    final fillPath = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          coralColor.withOpacity(0.32),
          coralColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, fillPaint);

    // Stroke
    final strokePaint = Paint()
      ..color = coralColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SmoothWavePainter oldDelegate) {
    return oldDelegate.coralColor != coralColor;
  }
}

/// 4. 6-column x 3-row Dot Matrix Painter bound to 18 meal/day states
class _DotMatrixPainter extends CustomPainter {
  final Color emeraldColor;
  final Color inactiveColor;
  final List<int> dotStates; // 2 = target met (emerald), 1 = logged/partial (mint), 0 = missed (grey)

  _DotMatrixPainter({
    required this.emeraldColor,
    required this.inactiveColor,
    required this.dotStates,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const cols = 6;
    const rows = 3;
    final cellW = size.width / cols;
    final cellH = size.height / rows;
    final radius = math.min(cellW, cellH) * 0.28;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cx = (c + 0.5) * cellW;
        final cy = (r + 0.5) * cellH;

        final index = r * cols + c;
        final state = index < dotStates.length ? dotStates[index] : 0;

        Paint p = Paint()..style = PaintingStyle.fill;

        if (state == 2) {
          p.color = emeraldColor;
        } else if (state == 1) {
          p.color = emeraldColor.withOpacity(0.45);
        } else {
          p.color = inactiveColor;
        }

        canvas.drawCircle(Offset(cx, cy), radius, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotMatrixPainter oldDelegate) {
    return oldDelegate.emeraldColor != emeraldColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.dotStates != dotStates;
  }
}

// ============================================================================
// MEDICINE TAB (FULL FUNCTIONALITY PRESERVED)
// ============================================================================
class _MedicineTab extends StatefulWidget {
  const _MedicineTab();

  @override
  State<_MedicineTab> createState() => _MedicineTabState();
}

class _MedicineTabState extends State<_MedicineTab> {
  void _openAddMedicineDialog([Medicine? existing]) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final doseController = TextEditingController(text: existing?.doseLabel ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');

    List<int> times = existing?.timesMinutes.toList() ?? [480]; // default 8:00 AM
    List<int> weekdays = existing?.weekdays.toList() ?? [];
    DateTime startDate = existing?.startDate ?? DateTime.now();
    DateTime? endDate = existing?.endDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      existing == null ? 'NEW MEDICINE' : 'EDIT MEDICINE',
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: nameController,
                      style: TextStyle(color: BentoTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Medicine Name',
                        labelStyle: TextStyle(color: BentoTheme.textSecondary),
                        filled: true,
                        fillColor: BentoTheme.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: doseController,
                      style: TextStyle(color: BentoTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Dose (e.g. 500mg, 1 tablet)',
                        labelStyle: TextStyle(color: BentoTheme.textSecondary),
                        filled: true,
                        fillColor: BentoTheme.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'REMINDER TIMES',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...times.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final mins = entry.value;
                          final timeStr =
                              '${(mins ~/ 60).toString().padLeft(2, '0')}:${(mins % 60).toString().padLeft(2, '0')}';
                          return Chip(
                            backgroundColor: BentoTheme.surfaceElevated,
                            label: Text(timeStr, style: TextStyle(color: BentoTheme.textPrimary)),
                            deleteIcon: const Icon(LucideIcons.x, size: 14),
                            deleteIconColor: Colors.redAccent,
                            onDeleted: times.length > 1
                                ? () {
                                    setModalState(() => times.removeAt(idx));
                                  }
                                : null,
                          );
                        }),
                        ActionChip(
                          avatar: Icon(LucideIcons.plus, size: 14, color: BentoTheme.accent),
                          backgroundColor: BentoTheme.accent.withValues(alpha: 0.15),
                          label: Text('Add Time', style: TextStyle(color: BentoTheme.accent)),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: const TimeOfDay(hour: 8, minute: 0),
                            );
                            if (picked != null) {
                              final total = picked.hour * 60 + picked.minute;
                              if (!times.contains(total)) {
                                setModalState(() {
                                  times.add(total);
                                  times.sort();
                                });
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'ACTIVE DAYS (Empty = Every Day)',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (int i = 1; i <= 7; i++)
                          _buildDayChip(i, weekdays, (day) {
                            setModalState(() {
                              if (weekdays.contains(day)) {
                                weekdays.remove(day);
                              } else {
                                weekdays.add(day);
                                weekdays.sort();
                              }
                            });
                          }),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: notesController,
                      style: TextStyle(color: BentoTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional, e.g. After meal)',
                        labelStyle: TextStyle(color: BentoTheme.textSecondary),
                        filled: true,
                        fillColor: BentoTheme.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: BentoTheme.accent,
                          foregroundColor: BentoTheme.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;

                          final med = Medicine(
                            id: existing?.id ?? 'med_${DateTime.now().millisecondsSinceEpoch}',
                            name: name,
                            doseLabel: doseController.text.trim().isEmpty ? '1 dose' : doseController.text.trim(),
                            timesMinutes: times,
                            weekdays: weekdays,
                            startDate: startDate,
                            endDate: endDate,
                            notes: notesController.text.trim(),
                            active: existing?.active ?? true,
                          );

                          final box = Hive.box<Medicine>('medicines');
                          await box.put(med.id, med);
                          await MedicineService.scheduleMedicine(med);

                          if (mounted) Navigator.pop(sheetContext);
                        },
                        child: Text(
                          existing == null ? 'CREATE MEDICINE' : 'UPDATE MEDICINE',
                          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDayChip(int day, List<int> selectedDays, Function(int) onToggle) {
    const dayNames = ['', 'M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final isSelected = selectedDays.contains(day);

    return GestureDetector(
      onTap: () => onToggle(day),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? BentoTheme.accent : BentoTheme.surfaceElevated,
          shape: BoxShape.circle,
        ),
        child: Text(
          dayNames[day],
          style: TextStyle(
            color: isSelected ? BentoTheme.background : BentoTheme.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<Medicine>>(
      valueListenable: Hive.box<Medicine>('medicines').listenable(),
      builder: (context, medBox, _) {
        return ValueListenableBuilder<Box<MedicineLog>>(
          valueListenable: Hive.box<MedicineLog>('medicine_logs').listenable(),
          builder: (context, logBox, _) {
            final stats = MedicineService.getDailyStats(
              medicines: medBox.values.toList(),
              logs: logBox.values.toList(),
            );
            final medicines = medBox.values.toList();

            return Scaffold(
              backgroundColor: Colors.transparent,
              floatingActionButton: FloatingActionButton(
                backgroundColor: BentoTheme.accent,
                foregroundColor: BentoTheme.background,
                onPressed: () => _openAddMedicineDialog(),
                child: const Icon(LucideIcons.plus),
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: BentoTheme.surface,
                      borderRadius: BorderRadius.circular(ExpressiveTokens.radiusCard),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "TODAY'S ADHERENCE",
                              style: TextStyle(
                                color: BentoTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${stats.takenDosesToday} / ${stats.totalDosesToday} TAKEN',
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ProgressBarX(
                          value: stats.complianceRate,
                          height: 6,
                          color: const Color(0xFF10B981),
                        ),
                        if (stats.nextDoseMedicine != null && stats.nextDoseTime != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(LucideIcons.clock, size: 14, color: BentoTheme.accent),
                              const SizedBox(width: 6),
                              Text(
                                'Next: ${stats.nextDoseMedicine!.name} at ${DateFormat('h:mm a').format(stats.nextDoseTime!)}',
                                style: TextStyle(
                                  color: BentoTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (medicines.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(LucideIcons.pill, size: 48, color: BentoTheme.textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            'No medicines added yet',
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap + below to add your first medicine reminder',
                            style: TextStyle(
                              color: BentoTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...medicines.map((med) => _buildMedicineTile(med)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMedicineTile(Medicine med) {
    final timesStr = med.timesMinutes
        .map((m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}')
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(ExpressiveTokens.radiusCard),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: med.active ? BentoTheme.accent.withValues(alpha: 0.15) : Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              LucideIcons.pill,
              color: med.active ? BentoTheme.accent : BentoTheme.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  med.name,
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${med.doseLabel} • $timesStr',
                  style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                ),
                if (med.notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    med.notes,
                    style: TextStyle(
                      color: BentoTheme.textSecondary.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.check, color: Color(0xFF10B981)),
            onPressed: () async {
              HapticFeedback.mediumImpact();
              await MedicineService.markTaken(med.id, DateTime.now());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Logged ${med.name} as taken!'),
                    backgroundColor: const Color(0xFF10B981),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(LucideIcons.moreVertical, color: BentoTheme.textSecondary, size: 18),
            color: BentoTheme.surface,
            onSelected: (val) async {
              if (val == 'edit') {
                _openAddMedicineDialog(med);
              } else if (val == 'toggle') {
                final updated = Medicine(
                  id: med.id,
                  name: med.name,
                  doseLabel: med.doseLabel,
                  timesMinutes: med.timesMinutes,
                  weekdays: med.weekdays,
                  startDate: med.startDate,
                  endDate: med.endDate,
                  notes: med.notes,
                  active: !med.active,
                );
                final box = Hive.box<Medicine>('medicines');
                await box.put(updated.id, updated);
                await MedicineService.scheduleMedicine(updated);
              } else if (val == 'delete') {
                await MedicineService.cancelMedicine(med);
                await med.delete();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Text('Edit', style: TextStyle(color: BentoTheme.textPrimary)),
              ),
              PopupMenuItem(
                value: 'toggle',
                child: Text(
                  med.active ? 'Pause Reminders' : 'Resume Reminders',
                  style: TextStyle(color: BentoTheme.textPrimary),
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WEIGHT TAB (FULL FUNCTIONALITY PRESERVED)
// ============================================================================
class _WeightTab extends StatefulWidget {
  const _WeightTab();

  @override
  State<_WeightTab> createState() => _WeightTabState();
}

class _WeightTabState extends State<_WeightTab> {
  void _openLogWeightDialog() {
    final weightController = TextEditingController();
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'LOG TODAY\'S WEIGHT',
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: 'Weight (kg)',
                  labelStyle: TextStyle(color: BentoTheme.textSecondary),
                  filled: true,
                  fillColor: BentoTheme.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                style: TextStyle(color: BentoTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Note (Optional, e.g. Morning, fasted)',
                  labelStyle: TextStyle(color: BentoTheme.textSecondary),
                  filled: true,
                  fillColor: BentoTheme.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BentoTheme.accent,
                    foregroundColor: BentoTheme.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    final val = double.tryParse(weightController.text.trim());
                    if (val == null || val <= 0) return;

                    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                    final entry = WeightEntry(
                      date: today,
                      kg: val,
                      note: noteController.text.trim(),
                    );

                    final box = Hive.box<WeightEntry>('weight_entries');
                    await box.put(today, entry);

                    if (mounted) Navigator.pop(sheetContext);
                  },
                  child: const Text(
                    'SAVE WEIGHT',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openSettingsDialog() {
    final settingsBox = Hive.box('settings');
    final startController = TextEditingController(text: settingsBox.get('weight_start')?.toString() ?? '');
    final goalController = TextEditingController(text: settingsBox.get('weight_goal')?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BentoTheme.surface,
        title: Text('Weight Journey Goals', style: TextStyle(color: BentoTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: startController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: BentoTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Starting Weight (kg)',
                labelStyle: TextStyle(color: BentoTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: goalController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: BentoTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Target / Goal Weight (kg)',
                labelStyle: TextStyle(color: BentoTheme.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BentoTheme.accent,
              foregroundColor: BentoTheme.background,
            ),
            onPressed: () {
              final start = double.tryParse(startController.text.trim());
              final goal = double.tryParse(goalController.text.trim());
              if (start != null) settingsBox.put('weight_start', start);
              if (goal != null) settingsBox.put('weight_goal', goal);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<WeightEntry>>(
      valueListenable: Hive.box<WeightEntry>('weight_entries').listenable(),
      builder: (context, box, _) {
        final entries = box.values.toList();
        entries.sort((a, b) => a.date.compareTo(b.date));

        final settingsBox = Hive.box('settings');
        final startWeight = (settingsBox.get('weight_start') as num?)?.toDouble();
        final goalWeight = (settingsBox.get('weight_goal') as num?)?.toDouble();
        final latestWeight = entries.isNotEmpty ? entries.last.kg : startWeight;

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton(
            backgroundColor: BentoTheme.accent,
            foregroundColor: BentoTheme.background,
            onPressed: _openLogWeightDialog,
            child: const Icon(LucideIcons.plus),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: BentoTheme.surface,
                  borderRadius: BorderRadius.circular(ExpressiveTokens.radiusCard),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatColumn('START', startWeight != null ? '$startWeight kg' : '--'),
                        _buildStatColumn('CURRENT', latestWeight != null ? '$latestWeight kg' : '--', isCurrent: true),
                        _buildStatColumn('TARGET', goalWeight != null ? '$goalWeight kg' : '--'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _openSettingsDialog,
                      icon: const Icon(LucideIcons.settings, size: 14),
                      label: const Text('Configure Start & Goal', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BentoTheme.textSecondary,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (entries.length >= 2) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                  height: 220,
                  decoration: BoxDecoration(
                    color: BentoTheme.surface,
                    borderRadius: BorderRadius.circular(ExpressiveTokens.radiusCard),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: entries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.kg)).toList(),
                          isCurved: true,
                          color: BentoTheme.accent,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: BentoTheme.accent.withValues(alpha: 0.15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'WEIGHT LOG HISTORY',
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              if (entries.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: Text(
                    'No weight logs recorded yet',
                    style: TextStyle(color: BentoTheme.textSecondary),
                  ),
                )
              else
                ...entries.reversed.map((e) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: BentoTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.date,
                              style: TextStyle(
                                color: BentoTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (e.note.isNotEmpty)
                              Text(
                                e.note,
                                style: TextStyle(
                                  color: BentoTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          '${e.kg} kg',
                          style: TextStyle(
                            color: BentoTheme.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, String value, {bool isCurrent = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: BentoTheme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isCurrent ? BentoTheme.accent : BentoTheme.textPrimary,
            fontSize: isCurrent ? 20 : 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
