import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/features/home/widgets/biometric_cluster.dart';

class CaloriesCard extends StatelessWidget {
  final HomeCardSize size;

  const CaloriesCard({
    super.key,
    this.size = HomeCardSize.compact,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<DietDayLog>('diet_logs').listenable(),
      builder: (context, Box<DietDayLog> box, _) {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final log = box.get(today);

        final intake = (log?.totalCalories ?? 0).toDouble();
        final target = (log?.targetCalories ??
            Hive.box('settings')
                .get('daily_calorie_target', defaultValue: 2000.0)
                .toDouble()).toDouble();
        final burned = (log?.totalBurned ?? 0).toDouble();
        final net = intake - burned;
        final isOver = net > target;
        final progress = target > 0 ? (net / target).clamp(0.0, 1.0) : 0.0;

        final protein = log?.totalProtein ?? 0;
        final carbs = log?.totalCarbs ?? 0;
        final fat = log?.totalFat ?? 0;

        final badgeText = isOver
            ? '+${(net - target).toStringAsFixed(0)} kcal over'
            : '${(target - net).toStringAsFixed(0)} kcal left';

        return HomeCardFrame(
          domain: HomeCardDomain.biometrics,
          icon: LucideIcons.utensils,
          title: 'Diet & Calorie Burn',
          onTap: () {
            AppNav.goTo(AppTab.diet);
          },
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isOver ? BentoTheme.negative : BentoTheme.positive)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                color: isOver ? BentoTheme.negative : BentoTheme.positive,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          child: _buildBody(
            intake: intake,
            burned: burned,
            net: net,
            target: target,
            progress: progress,
            isOver: isOver,
            protein: protein,
            carbs: carbs,
            fat: fat,
            entries: log?.entries ?? [],
          ),
        );
      },
    );
  }

  Widget _buildBody({
    required double intake,
    required double burned,
    required double net,
    required double target,
    required double progress,
    required bool isOver,
    required double protein,
    required double carbs,
    required double fat,
    required List<FoodEntry> entries,
  }) {
    switch (size) {
      case HomeCardSize.compact:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CalorieDualMeter(
              intakeKcal: intake,
              burnKcal: burned,
              targetKcal: target,
            ),
          ],
        );
      case HomeCardSize.large:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CalorieDualMeter(
              intakeKcal: intake,
              burnKcal: burned,
              targetKcal: target,
            ),
            const SizedBox(height: 12),
            // Macro bars with targets
            Row(
              children: [
                Expanded(
                  child: _buildMacroBar('Protein', protein, 140),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMacroBar('Carbs', carbs, 220),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMacroBar('Fat', fat, 65),
                ),
              ],
            ),
          ],
        );
      case HomeCardSize.hero:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CalorieDualMeter(
              intakeKcal: intake,
              burnKcal: burned,
              targetKcal: target,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMacroBar('Protein', protein, 140),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMacroBar('Carbs', carbs, 220),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMacroBar('Fat', fat, 65),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'TODAY\'S MEALS',
              style: TextStyle(
                color: BentoTheme.textSecondary,
                fontSize: 10,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            if (entries.isEmpty)
              Text(
                'No meals logged today yet',
                style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
              )
            else
              ...entries.take(5).map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          e.name,
                          style: TextStyle(
                            color: BentoTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${e.calories.round()} kcal',
                        style: TextStyle(
                          color: BentoTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
    }
  }

  Widget _buildMacroBar(String label, double value, double target) {
    final ratio = (value / target).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${value.round()}g',
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ProgressBarX(
            value: ratio,
            height: 4,
            semantic: ProgressSemantic.neutral,
          ),
        ],
      ),
    );
  }
}
