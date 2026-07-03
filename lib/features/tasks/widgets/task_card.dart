import 'package:flutter/material.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class TaskCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onTap;

  const TaskCard({super.key, required this.goal, required this.onTap});

  Color _getCategoryColor(GoalCategory category) {
    switch (category) {
      case GoalCategory.health:
        return AppColors.health;
      case GoalCategory.productivity:
        return AppColors.productivity;
      case GoalCategory.learning:
        return AppColors.learning;
      case GoalCategory.fitness:
        return AppColors.fitness;
      case GoalCategory.hobby:
        return AppColors.hobby;
    }
  }

  bool _isExpired(Goal goal) {
    if (goal.endDate == null || goal.isCompleted) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end =
        DateTime(goal.endDate!.year, goal.endDate!.month, goal.endDate!.day);
    return today.isAfter(end);
  }

  IconData _getCategoryIcon(GoalCategory category) {
    switch (category) {
      case GoalCategory.health:
        return LucideIcons.heartPulse;
      case GoalCategory.productivity:
        return LucideIcons.zap;
      case GoalCategory.learning:
        return LucideIcons.bookOpen;
      case GoalCategory.fitness:
        return LucideIcons.dumbbell;
      case GoalCategory.hobby:
        return LucideIcons.puzzle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: BentoContainer(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        isPressed: goal.isCompleted,
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(goal.category)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(goal.category),
                    color: _getCategoryColor(goal.category),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: goal.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (goal.description.isNotEmpty)
                        Text(
                          goal.description,
                          style: TextStyle(
                              color: BentoTheme.textSecondary, fontSize: 12),
                        ),
                      if (goal.endDate != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _isExpired(goal)
                                ? Colors.redAccent.withValues(alpha: 0.2)
                                : BentoTheme.textSecondary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _isExpired(goal)
                                ? 'Expired: ${DateFormat('MMM dd').format(goal.endDate!)}'
                                : 'Ends: ${DateFormat('MMM dd').format(goal.endDate!)}',
                            style: TextStyle(
                                color: _isExpired(goal)
                                    ? Colors.redAccent
                                    : BentoTheme.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                if (goal.streakCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: BentoTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: BentoTheme.accent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.flame,
                            color: BentoTheme.accent, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${goal.streakCount}',
                          style: TextStyle(
                              color: BentoTheme.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    goal.isCompleted
                        ? LucideIcons.checkCircle2
                        : LucideIcons.circle,
                    color: goal.isCompleted
                        ? BentoTheme.accent
                        : BentoTheme.textSecondary,
                  ),
                  onPressed: () {
                    final box = Hive.box<Goal>('mission_box_v4');
                    if (!box.containsKey(goal.id)) return;

                    if (goal.isCompleted) {
                      HapticFeedback.mediumImpact();
                      goal.reset();
                    } else {
                      HapticFeedback.heavyImpact();
                      goal.complete();
                    }
                    box.put(goal.id, goal);
                  },
                ).animate(target: goal.isCompleted ? 1 : 0).scaleXY(
                    end: 1.2, duration: 200.ms, curve: Curves.easeOutBack),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: goal.progress,
                        borderRadius: BorderRadius.circular(4),
                        backgroundColor:
                            true ? Colors.black26 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getCategoryColor(goal.category),
                        ),
                        minHeight: 6,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${goal.currentValue.toInt()}/${goal.targetValue.toInt()} ${goal.unit}',
                        style: TextStyle(
                            color: BentoTheme.textSecondary, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${goal.completionPercentage.toInt()}%',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate(target: goal.isCompleted ? 1 : 0)
        .scaleXY(
            begin: 1.0, end: 1.05, curve: Curves.easeOutBack, duration: 150.ms)
        .then()
        .scaleXY(
            begin: 1.05, end: 0.98, curve: Curves.bounceOut, duration: 250.ms)
        .tint(color: BentoTheme.accent.withValues(alpha: 0.1), duration: 300.ms);
  }
}
