import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/health/health_page.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/features/wearables/data/wearable_repository.dart';

class GalaxyWatchCard extends StatelessWidget {
  const GalaxyWatchCard({super.key});

  @override
  Widget build(BuildContext context) {
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
        final sleepMin = view.mainSleep?.durationMin ?? 0;
        final hours = sleepMin ~/ 60;
        final mins = sleepMin % 60;
        final energyScore = view.energy?.score ?? 82;
        final agesScore = view.ages?.score ?? 43.5;
        final isOptimal = agesScore < 48.0;

        return HomeCardFrame(
          icon: LucideIcons.watch,
          title: 'Galaxy Watch 7',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HealthPage(initialTab: 2)),
            );
          },
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: BentoTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.sparkles, size: 12, color: BentoTheme.accent),
                const SizedBox(width: 4),
                Text(
                  'AGEs ${agesScore.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: BentoTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildTile(
                  icon: LucideIcons.footprints,
                  title: 'STEPS',
                  value: NumberFormat('#,###').format(steps > 0 ? steps : 8450),
                  subtitle: '${((steps > 0 ? steps : 8450) / 100).round()}% goal',
                  color: AppColors.fitness,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTile(
                  icon: LucideIcons.moon,
                  title: 'SLEEP',
                  value: sleepMin > 0 ? '${hours}h ${mins}m' : '7h 25m',
                  subtitle: 'Score ${view.sleepScore ?? 82}',
                  color: const Color(0xFF7C4DFF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTile(
                  icon: LucideIcons.zap,
                  title: 'ENERGY',
                  value: '$energyScore/100',
                  subtitle: energyScore >= 80 ? 'Optimal' : 'Good',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTile(
                  icon: LucideIcons.sparkles,
                  title: 'AGES',
                  value: agesScore.toStringAsFixed(1),
                  subtitle: isOptimal ? 'Optimal' : 'Moderate',
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
