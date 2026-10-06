import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';

class CaloriesCard extends StatelessWidget {
  const CaloriesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<DietDayLog>('diet_logs').listenable(),
      builder: (context, Box<DietDayLog> box, _) {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final log = box.get(today);

        final intake = log?.totalCalories ?? 0;
        final target = log?.targetCalories ??
            Hive.box('settings')
                .get('daily_calorie_target', defaultValue: 2000.0)
                .toDouble();
        final burned = log?.totalBurned ?? 0;
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
          icon: LucideIcons.utensils,
          title: 'Diet & Calories',
          onTap: () {
            AppNav.goTo(AppTab.diet);
          },
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isOver ? Colors.redAccent : Colors.greenAccent)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                color: isOver ? Colors.redAccent : Colors.greenAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${net.toStringAsFixed(0)} kcal',
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'of ${target.toStringAsFixed(0)} kcal daily target',
                        style: TextStyle(
                          color: BentoTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      color: isOver ? Colors.redAccent : BentoTheme.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ProgressBarX(
                value: progress.toDouble(),
                height: 6,
                color: isOver ? Colors.redAccent : BentoTheme.accent,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMacroText('Protein', '${protein.toStringAsFixed(0)}g'),
                  _buildMacroText('Carbs', '${carbs.toStringAsFixed(0)}g'),
                  _buildMacroText('Fat', '${fat.toStringAsFixed(0)}g'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMacroText(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: BentoTheme.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
