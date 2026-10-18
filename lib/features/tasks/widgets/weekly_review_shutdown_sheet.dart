import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/widgets/tactile_button.dart';
import 'package:habit_tracker/features/tasks/data/task_os_repository.dart';
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';

class WeeklyReviewShutdownSheet extends StatefulWidget {
  final bool isWeeklyReview; // true for weekly review, false for daily shutdown

  const WeeklyReviewShutdownSheet({
    super.key,
    this.isWeeklyReview = false,
  });

  @override
  State<WeeklyReviewShutdownSheet> createState() =>
      _WeeklyReviewShutdownSheetState();
}

class _WeeklyReviewShutdownSheetState extends State<WeeklyReviewShutdownSheet> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final activeTasks = TaskOsRepository.instance.activeTasks;
    final doneToday = activeTasks.where((t) => t.isDone).length;
    final remainingOpen = activeTasks.where((t) => !t.isDone).length;

    return Container(
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: BentoTheme.divider),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: BentoTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                widget.isWeeklyReview
                    ? LucideIcons.calendarCheck
                    : LucideIcons.moon,
                color: BentoTheme.accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                widget.isWeeklyReview
                    ? 'Weekly Review Ritual'
                    : 'Daily Shutdown Ritual',
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.isWeeklyReview
                ? 'Clear your head, review stats, and prepare for the week ahead.'
                : 'Wrap up your day cleanly with zero open cognitive loops.',
            style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 18),
          if (_step == 0) ...[
            // Step 1: Today's Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BentoTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: BentoTheme.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$doneToday Tasks Completed',
                          style: TextStyle(
                            color: BentoTheme.accent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$remainingOpen tasks left in active queue',
                          style: TextStyle(
                            color: BentoTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(LucideIcons.award, size: 32, color: BentoTheme.accent),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Unfinished items for today:',
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (var t in activeTasks.where((t) => !t.isDone).take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(LucideIcons.circle,
                              size: 10, color: BentoTheme.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: BentoTheme.textPrimary,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          Text(
                            'Defer to tomorrow',
                            style: TextStyle(
                              color: BentoTheme.accent,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TactileButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _step = 1);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: BentoTheme.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Next: Tomorrow Preview',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ] else ...[
            // Step 2: Final Shut Down Confirmation
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: BentoTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: BentoTheme.accent.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Icon(LucideIcons.checkCircle, size: 40, color: BentoTheme.accent),
                  const SizedBox(height: 10),
                  Text(
                    'Mind Clear. Day Complete.',
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'All open loops are scheduled or deferred. You can rest without anxiety.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TactileButton(
              onPressed: () {
                HapticFeedback.heavyImpact();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎉 Shutdown ritual complete! Rest well.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: BentoTheme.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Complete Shutdown Ritual',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
