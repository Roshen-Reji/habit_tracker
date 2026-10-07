import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';

class MissionsCard extends StatelessWidget {
  final HomeCardSize size;

  const MissionsCard({
    super.key,
    this.size = HomeCardSize.compact,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Goal>('mission_box_v4').listenable(),
      builder: (context, Box<Goal> box, _) {
        final dailyGoals =
            box.values.where((g) => g.type == GoalType.daily).toList();
        final completedCount = dailyGoals.where((g) => g.isCompleted).length;
        final maxCount = size == HomeCardSize.large ? dailyGoals.length : 3;
        final displayGoals = dailyGoals.take(maxCount).toList();

        return HomeCardFrame(
          icon: LucideIcons.checkSquare,
          title: 'Daily Missions',
          onTap: () {
            AppNav.goTo(
              AppTab.tasks,
              sub: TasksSubview.missions,
            );
          },
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: BentoTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$completedCount/${dailyGoals.length}',
                  style: TextStyle(
                    color: BentoTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  LucideIcons.arrowRight,
                  size: 13,
                  color: BentoTheme.accent,
                ),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const XpProgressBar(height: 5),
              const SizedBox(height: 12),
              if (dailyGoals.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Center(
                    child: Text(
                      'NO ACTIVE MISSIONS',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                ...displayGoals.map((goal) => _buildMissionTile(goal)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMissionTile(Goal goal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (!goal.isCompleted) {
                goal.complete();
              } else {
                goal.reset();
              }
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                goal.isCompleted
                    ? LucideIcons.checkCircle2
                    : LucideIcons.circle,
                key: ValueKey<bool>(goal.isCompleted),
                size: 20,
                color: goal.isCompleted
                    ? BentoTheme.accent
                    : BentoTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              goal.title,
              style: TextStyle(
                color: goal.isCompleted
                    ? BentoTheme.textSecondary
                    : BentoTheme.textPrimary,
                decoration: goal.isCompleted
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: BentoTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '+${goal.xpValue} XP',
              style: TextStyle(
                color: BentoTheme.accent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
