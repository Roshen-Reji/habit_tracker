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

class GalaxyWatchCard extends StatelessWidget {
  const GalaxyWatchCard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!WearableSettings.isEnabled) {
      return HomeCardFrame(
        icon: LucideIcons.watch,
        title: 'Galaxy Watch 7',
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
          child: Row(
            children: [
              Expanded(
                child: _buildTile(
                  icon: LucideIcons.footprints,
                  title: 'STEPS',
                  value: steps > 0 ? NumberFormat('#,###').format(steps) : '—',
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
        );
      },
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
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1,
        ),
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
