import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/wearables/data/sync_service.dart';
import 'package:habit_tracker/features/wearables/data/wearable_repository.dart';
import 'package:habit_tracker/features/wearables/data/wearable_settings.dart';
import 'package:habit_tracker/features/wearables/models/models.dart';
import 'package:habit_tracker/features/wearables/ui/ages_log_sheet.dart';
import 'package:habit_tracker/features/wearables/ui/wearables_settings_page.dart';

class FitnessTab extends StatefulWidget {
  const FitnessTab({super.key});

  @override
  State<FitnessTab> createState() => _FitnessTabState();
}

class _FitnessTabState extends State<FitnessTab> {
  DateTime _selectedDate = DateTime.now();

  String get _dayKey => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Future<void> _sync() async {
    await SyncService.instance.sync(days: 7);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        WearableRepository.instance.dailyBox.listenable(),
        WearableRepository.instance.sleepBox.listenable(),
        WearableRepository.instance.exerciseBox.listenable(),
        WearableRepository.instance.bodyBox.listenable(),
        WearableRepository.instance.energyBox.listenable(),
        WearableRepository.instance.agesBox.listenable(),
      ]),
      builder: (context, _) {
        final view = WearableRepository.instance.dayView(_dayKey);
        final allAges = WearableRepository.instance.agesBox.values.toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        final isMock = WearableSettings.useMockProvider;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            if (isMock) ...[
              _buildDemoBanner(),
              const SizedBox(height: 12),
            ],
            // Sync & Date Navigation Bar
            _buildSyncAndDateBar(),
            const SizedBox(height: 16),

            // 1. Samsung Health AGEs Index Card (Deliverable C Highlight)
            _buildAgesIndexCard(view.ages, allAges),
            const SizedBox(height: 16),

            // 2. Daily Energy Score Card
            _buildEnergyScoreCard(view.energy),
            const SizedBox(height: 16),

            // 3. Daily Activity & Steps
            _buildDailyActivityCard(view.activity),
            const SizedBox(height: 16),

            // 4. Sleep Stages Breakdown
            _buildSleepCard(view.mainSleep),
            const SizedBox(height: 16),

            // 5. Workouts & Exercise Sessions
            _buildWorkoutsCard(view.exercises),
            const SizedBox(height: 16),

            // 6. Body Composition (BIA)
            _buildBodyCompCard(view.bodyComp),
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }

  Widget _buildSyncAndDateBar() {
    final lastSyncMs = WearableSettings.lastSyncMs;
    final lastSyncStr = lastSyncMs != null
        ? DateFormat('h:mm a').format(DateTime.fromMillisecondsSinceEpoch(lastSyncMs))
        : 'Not synced';

    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    return BentoContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 16,
      customColor: BentoTheme.surface,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.chevronLeft, size: 18),
            color: BentoTheme.textSecondary,
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              });
            },
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              child: Column(
                children: [
                  Text(
                    isToday ? 'TODAY' : DateFormat('EEEE, MMM d').format(_selectedDate).toUpperCase(),
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Galaxy Watch 7 · Synced $lastSyncStr',
                    style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.chevronRight, size: 18),
            color: isToday ? Colors.white12 : BentoTheme.textSecondary,
            onPressed: isToday
                ? null
                : () {
                    setState(() {
                      _selectedDate = _selectedDate.add(const Duration(days: 1));
                    });
                  },
          ),
          ValueListenableBuilder<SyncStatus>(
            valueListenable: SyncService.instance.statusNotifier,
            builder: (context, status, _) {
              final isSyncing = status == SyncStatus.syncing;
              return IconButton(
                icon: isSyncing
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: BentoTheme.accent),
                      )
                    : Icon(LucideIcons.refreshCw, size: 18, color: BentoTheme.accent),
                onPressed: isSyncing ? null : _sync,
              );
            },
          ),
          IconButton(
            icon: Icon(LucideIcons.settings, size: 18, color: BentoTheme.textSecondary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WearablesSettingsPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDemoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(LucideIcons.alertTriangle, size: 16, color: AppColors.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'DEMO MODE: Showing simulated records for testing. Real Galaxy Watch data will replace this when connected.',
              style: TextStyle(color: AppColors.warning, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. Samsung Health AGEs Index Card ---
  Widget _buildAgesIndexCard(AgesSample? sample, List<AgesSample> history) {
    if (sample == null) {
      return BentoContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: 20,
        customColor: BentoTheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BentoTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(LucideIcons.sparkles, color: BentoTheme.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SAMSUNG HEALTH AGEs INDEX',
                        style: TextStyle(
                          color: BentoTheme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Biological Glycation & Aging Marker',
                        style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'No AGEs entry recorded for this date. Galaxy Watch measures AGEs during sleep; log the value here manually.',
              style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => AgesLogSheet.show(context),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Log AGEs Value'),
              style: OutlinedButton.styleFrom(
                foregroundColor: BentoTheme.accent,
                side: BorderSide(color: BentoTheme.accent.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    final score = sample.score;
    final isOptimal = score < 48.0;
    final isLow = score < 44.0;
    final level = isLow ? 'LOW' : (isOptimal ? 'OPTIMAL' : 'MODERATE');
    final levelColor = isLow ? const Color(0xFF64B5F6) : (isOptimal ? AppColors.success : AppColors.warning);

    Map<String, dynamic> extra = {};
    if (sample.extraJson != null) {
      try {
        extra = jsonDecode(sample.extraJson!) as Map<String, dynamic>;
      } catch (_) {}
    }
    final trend = extra['trend']?.toString() ?? 'stable';

    return BentoContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      customColor: BentoTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BentoTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(LucideIcons.sparkles, color: BentoTheme.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SAMSUNG HEALTH AGEs INDEX',
                      style: TextStyle(
                        color: BentoTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Biological Glycation & Aging Marker',
                      style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.plus, size: 18),
                color: BentoTheme.accent,
                tooltip: 'Log / Update AGEs',
                onPressed: () => AgesLogSheet.show(context),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: levelColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    color: levelColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Score & Trend Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score.toStringAsFixed(1),
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      trend == 'improving' ? LucideIcons.trendingDown : LucideIcons.trendingUp,
                      color: trend == 'improving' ? AppColors.success : AppColors.warning,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trend == 'improving' ? 'Lower glycation trend' : 'Stable index',
                      style: TextStyle(
                        color: trend == 'improving' ? AppColors.success : AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sparkline / Mini Trend Chart
          if (history.isNotEmpty) ...[
            SizedBox(
              height: 48,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: history.take(14).toList().asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.score);
                      }).toList(),
                      isCurved: true,
                      color: BentoTheme.accent,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: BentoTheme.accent.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Explainer & Lifestyle Guidance
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.info, size: 14, color: BentoTheme.accent),
                    const SizedBox(width: 6),
                    Text(
                      'Galaxy Watch 7 BioActive Sensor',
                      style: TextStyle(
                        color: BentoTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Monitored optically during deep sleep. Reflects advanced glycation end-products in skin cells. Lower scores reflect optimal biological cellular health.',
                  style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. Daily Energy Score Card ---
  Widget _buildEnergyScoreCard(EnergyScoreDay? energy) {
    if (energy == null) {
      return BentoContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: 20,
        customColor: BentoTheme.surface,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.zap, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DAILY ENERGY SCORE',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('No energy score recorded for today', style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Text(
              '—/100',
              style: TextStyle(color: BentoTheme.textSecondary, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    final score = energy.score;
    final eval = score >= 80 ? 'Optimal Energy' : (score >= 70 ? 'Good Readiness' : 'Needs Recovery');

    Map<String, dynamic> extra = {};
    if (energy.extraJson != null) {
      try {
        extra = jsonDecode(energy.extraJson!) as Map<String, dynamic>;
      } catch (_) {}
    }

    final sleepScore = (extra['sleepScoreAvg'] as num?)?.toDouble();
    final activityScore = (extra['activityScore'] as num?)?.toDouble();
    final sleepHr = (extra['sleepHrScore'] as num?)?.toDouble();
    final sleepHrv = (extra['sleepHrvScore'] as num?)?.toDouble();

    return BentoContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      customColor: BentoTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.zap, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DAILY ENERGY SCORE',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(eval, style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              Text(
                '$score/100',
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Contributing Factors Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (score / 100.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),

          // Contributing 4 Factors Grid
          Row(
            children: [
              Expanded(child: _buildFactorPill('Sleep Avg', sleepScore != null ? '${sleepScore.round()}%' : '—')),
              const SizedBox(width: 8),
              Expanded(child: _buildFactorPill('Prev Activity', activityScore != null ? '${activityScore.round()}%' : '—')),
              const SizedBox(width: 8),
              Expanded(child: _buildFactorPill('Sleep HR', sleepHr != null ? '${sleepHr.round()}%' : '—')),
              const SizedBox(width: 8),
              Expanded(child: _buildFactorPill('Sleep HRV', sleepHrv != null ? '${sleepHrv.round()}%' : '—')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFactorPill(String title, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: BentoTheme.textSecondary, fontSize: 10), maxLines: 1),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(color: BentoTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // --- 3. Daily Activity & Steps ---
  Widget _buildDailyActivityCard(DailyActivity? activity) {
    if (activity == null) {
      return BentoContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: 20,
        customColor: BentoTheme.surface,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.fitness.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.footprints, color: AppColors.fitness, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DAILY ACTIVITY',
                    style: TextStyle(
                      color: AppColors.fitness,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No activity synced for this day.',
                    style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final steps = activity.steps;
    final target = (activity.stepGoal != null && activity.stepGoal! > 0) ? activity.stepGoal! : 10000;
    final totalBurned = activity.totalKcal;
    final activeBurned = activity.activeKcal;
    final activeMin = activity.activeMinutes;
    final distanceM = activity.distanceM;
    final distKm = (distanceM != null && distanceM > 0) ? (distanceM / 1000.0) : (steps > 0 ? (steps * 0.76 / 1000.0) : null);
    final progress = target > 0 ? (steps / target).clamp(0.0, 1.0) : 0.0;

    return BentoContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      customColor: BentoTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.fitness.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.footprints, color: AppColors.fitness, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DAILY ACTIVITY',
                        style: TextStyle(
                          color: AppColors.fitness,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('Target: ${NumberFormat('#,###').format(target)} steps',
                          style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              Text(
                NumberFormat('#,###').format(steps),
                style: TextStyle(color: BentoTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.fitness),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem(LucideIcons.flame, totalBurned != null && totalBurned > 0 ? '${totalBurned.round()} kcal' : '—', 'Total Burned'),
              _buildMetricItem(LucideIcons.zap, activeBurned != null && activeBurned > 0 ? '${activeBurned.round()} kcal' : '—', 'Active Burn'),
              _buildMetricItem(LucideIcons.timer, (activeMin != null && activeMin > 0) ? '$activeMin min' : '—', 'Active Time'),
              _buildMetricItem(LucideIcons.mapPin, distKm != null && distKm > 0 ? '${distKm.toStringAsFixed(1)} km' : '—', 'Distance'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(IconData icon, String val, String label) {
    return Column(
      children: [
        Icon(icon, size: 16, color: BentoTheme.textSecondary),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: BentoTheme.textSecondary, fontSize: 10)),
      ],
    );
  }

  // --- 4. Sleep Stages Breakdown ---
  Widget _buildSleepCard(SleepSession? sleep) {
    if (sleep == null) {
      return BentoContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: 20,
        customColor: BentoTheme.surface,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.moon, color: Color(0xFF7C4DFF), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SLEEP STAGES & SCORE',
                    style: TextStyle(
                      color: Color(0xFF7C4DFF),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No sleep session synced for this day.',
                    style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final durMin = sleep.durationMin;
    final hours = durMin ~/ 60;
    final mins = durMin % 60;
    final score = sleep.score;
    final deep = sleep.deepMin ?? 0;
    final light = sleep.lightMin ?? 0;
    final rem = sleep.remMin ?? 0;
    final awake = sleep.awakeMin ?? 0;
    final totalStageMin = deep + light + rem + awake;

    return BentoContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      customColor: BentoTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.moon, color: Color(0xFF7C4DFF), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SLEEP STAGES & SCORE',
                        style: TextStyle(
                          color: Color(0xFF7C4DFF),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        score != null ? 'Score: $score/100 · ${hours}h ${mins}m' : '${hours}h ${mins}m duration',
                        style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '${hours}h ${mins}m',
                style: TextStyle(color: BentoTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Stacked Stage Bar
          if (totalStageMin > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    if (deep > 0) Expanded(flex: deep, child: Container(color: const Color(0xFF304FFE))),
                    if (rem > 0) Expanded(flex: rem, child: Container(color: const Color(0xFF7C4DFF))),
                    if (light > 0) Expanded(flex: light, child: Container(color: const Color(0xFF00B0FF))),
                    if (awake > 0) Expanded(flex: awake, child: Container(color: Colors.amber)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Stage Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStageLegend('Deep', '${deep}m', const Color(0xFF304FFE)),
                _buildStageLegend('REM', '${rem}m', const Color(0xFF7C4DFF)),
                _buildStageLegend('Light', '${light}m', const Color(0xFF00B0FF)),
                _buildStageLegend('Awake', '${awake}m', Colors.amber),
              ],
            ),
          ] else ...[
            Text(
              'Detailed sleep stage breakdown was not recorded for this session.',
              style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11.5, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStageLegend(String name, String time, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: TextStyle(color: BentoTheme.textSecondary, fontSize: 10)),
            Text(time, style: TextStyle(color: BentoTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  // --- 5. Workouts & Exercise Sessions ---
  Widget _buildWorkoutsCard(List<ExerciseSession> exercises) {
    return BentoContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      customColor: BentoTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.dumbbell, color: AppColors.warning, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WORKOUT SESSIONS',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    exercises.isEmpty ? 'No recorded exercises today' : '${exercises.length} synced session(s)',
                    style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Workouts recorded on Galaxy Watch 7 will automatically sync and credit to your daily burn ledger.',
                style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            )
          else
            ...exercises.map((ex) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      ex.type.toLowerCase().contains('run') ? LucideIcons.footprints : LucideIcons.bicepsFlexed,
                      color: BentoTheme.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ex.title ?? ex.type,
                            style: TextStyle(color: BentoTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${ex.durationMin}m · ${(ex.activeKcal ?? 0).round()} kcal burned',
                            style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (ex.avgHr != null)
                      Row(
                        children: [
                          const Icon(LucideIcons.heartPulse, size: 14, color: AppColors.error),
                          const SizedBox(width: 4),
                          Text(
                            '${ex.avgHr} bpm',
                            style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // --- 6. Body Composition (BIA) ---
  Widget _buildBodyCompCard(BodyCompSample? sample) {
    if (sample == null) {
      return BentoContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: 20,
        customColor: BentoTheme.surface,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.health.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.scale, color: AppColors.health, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BODY COMPOSITION (BIA)',
                    style: TextStyle(
                      color: AppColors.health,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No body composition reading synced.',
                    style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final weight = sample.weightKg;
    final fatPct = sample.bodyFatPct;
    final muscle = sample.skeletalMuscleMassKg;
    final bmi = sample.bmi;

    return BentoContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      customColor: BentoTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.health.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.scale, color: AppColors.health, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BODY COMPOSITION (BIA)',
                    style: TextStyle(
                      color: AppColors.health,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Galaxy Watch 7 BioActive Sensor', style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBodyCompItem('Weight', weight != null ? '${weight.toStringAsFixed(1)} kg' : '—'),
              _buildBodyCompItem('Body Fat', fatPct != null ? '${fatPct.toStringAsFixed(1)}%' : '—'),
              _buildBodyCompItem('Skeletal Muscle', muscle != null ? '${muscle.toStringAsFixed(1)} kg' : '—'),
              _buildBodyCompItem('BMI', bmi != null ? bmi.toStringAsFixed(1) : '—'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBodyCompItem(String label, String val) {
    return Column(
      children: [
        Text(val, style: TextStyle(color: BentoTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: BentoTheme.textSecondary, fontSize: 10)),
      ],
    );
  }
}
