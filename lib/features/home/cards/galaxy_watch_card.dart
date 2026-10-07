import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/health/health_page.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/features/wearables/data/wearable_repository.dart';

import 'package:habit_tracker/features/wearables/data/wearable_settings.dart';
import 'package:habit_tracker/features/wearables/ui/wearables_settings_page.dart';

import 'package:habit_tracker/features/home/cards/home_card.dart';

class GalaxyWatchCard extends StatelessWidget {
  final HomeCardSize size;

  const GalaxyWatchCard({
    super.key,
    this.size = HomeCardSize.compact,
  });

  @override
  Widget build(BuildContext context) {
    if (!WearableSettings.isEnabled) {
      return HomeCardFrame(
        icon: LucideIcons.watch,
        title: 'Activity',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WearablesSettingsPage()),
          );
        },
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: BentoTheme.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Connect',
            style: TextStyle(
              color: BentoTheme.accent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BentoTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(LucideIcons.bluetooth,
                    color: BentoTheme.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No Watch Connected',
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to connect Galaxy Watch 7 or Health Connect',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight,
                  size: 16, color: BentoTheme.textSecondary),
            ],
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([
        WearableRepository.instance.dailyBox.listenable(),
        WearableRepository.instance.sleepBox.listenable(),
        WearableRepository.instance.energyBox.listenable(),
        WearableRepository.instance.agesBox.listenable(),
      ]),
      builder: (context, _) {
        final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final view = WearableRepository.instance.dayView(todayKey);

        final steps = view.totalSteps;
        final sleep = view.mainSleep;
        final sleepMin = sleep?.durationMin;
        final hours = (sleepMin ?? 0) ~/ 60;
        final mins = (sleepMin ?? 0) % 60;
        final energy = view.energy?.score;
        final ages = view.ages?.score;

        return HomeCardFrame(
          icon: LucideIcons.watch,
          title: 'Activity',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const HealthPage(initialTab: 2)),
            );
          },
          trailing: ages != null
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: BentoTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.sparkles,
                          size: 12, color: BentoTheme.accent),
                      const SizedBox(width: 4),
                      Text(
                        'AGEs ${ages.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: BentoTheme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : null,
          child: size == HomeCardSize.hero
              ? _buildHeroContent(
                  context,
                  steps: steps,
                  hours: hours,
                  mins: mins,
                  sleepScore: view.sleepScore,
                  energy: energy,
                  ages: ages,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTile(
                            icon: LucideIcons.footprints,
                            title: 'STEPS',
                            value: steps > 0
                                ? NumberFormat('#,###').format(steps)
                                : '—',
                            subtitle: steps > 0
                                ? '${((steps / 10000) * 100).round()}% goal'
                                : 'No steps',
                            color: AppColors.fitness,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTile(
                            icon: LucideIcons.moon,
                            title: 'SLEEP',
                            value: sleepMin != null && sleepMin > 0
                                ? '${hours}h ${mins}m'
                                : '—',
                            subtitle: view.sleepScore != null
                                ? 'Score ${view.sleepScore}'
                                : 'No sleep data',
                            color: const Color(0xFF7C4DFF),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTile(
                            icon: LucideIcons.zap,
                            title: 'ENERGY',
                            value: energy != null ? '$energy/100' : '—',
                            subtitle: energy != null
                                ? (energy >= 80 ? 'Optimal' : 'Good')
                                : 'No score',
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTile(
                            icon: LucideIcons.sparkles,
                            title: 'AGES',
                            value: ages != null ? ages.toStringAsFixed(1) : '—',
                            subtitle: ages != null ? 'Logged' : 'No data',
                            color: BentoTheme.accent,
                          ),
                        ),
                      ],
                    ),
                    if (size == HomeCardSize.large) ...[
                      const SizedBox(height: 16),
                      Text(
                        '7-DAY STEPS',
                        style: TextStyle(
                          color: BentoTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _build7DayStepsBar(),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _buildHeroContent(
    BuildContext context, {
    required int steps,
    required int hours,
    required int mins,
    required int? sleepScore,
    required int? energy,
    required double? ages,
  }) {
    final percent = ((steps / 10000) * 100).clamp(0, 999).round();
    final stepProgress = (steps / 10000).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: CircularProgressIndicator(
                      value: stepProgress,
                      strokeWidth: 7,
                      backgroundColor:
                          BentoTheme.textPrimary.withValues(alpha: 0.08),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(BentoTheme.textPrimary),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    steps > 0 ? NumberFormat('#,###').format(steps) : '0',
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Steps today of 10,000 goal',
                    style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'PAST 7 DAYS',
          style: TextStyle(
            color: BentoTheme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        _build7DayStepsBar(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTile(
                icon: LucideIcons.moon,
                title: 'SLEEP',
                value: (hours > 0 || mins > 0) ? '${hours}h ${mins}m' : '—',
                subtitle: sleepScore != null ? 'Score $sleepScore' : 'No data',
                color: const Color(0xFF7C4DFF),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTile(
                icon: LucideIcons.zap,
                title: 'ENERGY',
                value: energy != null ? '$energy/100' : '—',
                subtitle: energy != null
                    ? (energy >= 80 ? 'Optimal' : 'Good')
                    : 'No score',
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _build7DayStepsBar() {
    final dailySteps = List.generate(7, (index) {
      final date = DateTime.now().subtract(Duration(days: 6 - index));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      return WearableRepository.instance.dayView(dateKey).totalSteps;
    });

    final maxVal =
        dailySteps.fold<int>(10000, (prev, e) => e > prev ? e : prev);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (index) {
        final daySteps = dailySteps[index];
        final isToday = index == 6;
        final date = DateTime.now().subtract(Duration(days: 6 - index));
        final label = isToday
            ? 'TODAY'
            : DateFormat('EE').format(date).substring(0, 1).toUpperCase();
        final ratio = (daySteps / maxVal).clamp(0.08, 1.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 48 * ratio,
              decoration: BoxDecoration(
                color: isToday
                    ? BentoTheme.textPrimary
                    : BentoTheme.textSecondary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color:
                    isToday ? BentoTheme.textPrimary : BentoTheme.textSecondary,
                fontSize: 9,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
