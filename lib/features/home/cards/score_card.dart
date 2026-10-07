import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/data/services/score_service.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/features/tasks/task_analytics_page.dart';

import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/data/services/global_xp_service.dart';
import 'package:intl/intl.dart';

class ScoreCard extends StatelessWidget {
  final HomeCardSize size;

  const ScoreCard({
    super.key,
    this.size = HomeCardSize.compact,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('xp_history').listenable(),
      builder: (context, Box xpBox, _) {
        final summary = ScoreService.getScoreSummary(xpBox: xpBox);
        final week = summary['week'] ?? 0;
        final month = summary['month'] ?? 0;
        final year = summary['year'] ?? 0;
        final xpHistory = GlobalXPService.getPast7DaysXP();

        return HomeCardFrame(
          icon: LucideIcons.trophy,
          title: 'XP Totals',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TaskAnalyticsPage(),
              ),
            );
          },
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Analytics',
                style: TextStyle(
                  color: BentoTheme.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const XpProgressBar(height: 5),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildXPColumn('WEEK', '$week XP', 'Past 7 days'),
                  Container(
                    width: 1,
                    height: 38,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  _buildXPColumn('MONTH', '$month XP', 'Past 30 days'),
                  Container(
                    width: 1,
                    height: 38,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  _buildXPColumn('YEAR', '$year XP', 'Past 365 days'),
                ],
              ),
              if (size == HomeCardSize.large || size == HomeCardSize.hero) ...[
                const SizedBox(height: 16),
                Text(
                  '7-DAY XP TREND',
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                _build7DayBars(xpHistory),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _build7DayBars(List<int> xpHistory) {
    final maxVal = xpHistory.fold<int>(1, (prev, e) => e > prev ? e : prev);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (index) {
        final xp = xpHistory[index];
        final isToday = index == 6;
        final date = DateTime.now().subtract(Duration(days: 6 - index));
        final label = isToday
            ? 'TODAY'
            : DateFormat('EE').format(date).substring(0, 1).toUpperCase();
        final ratio = (xp / maxVal).clamp(0.08, 1.0);

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

  Widget _buildXPColumn(String label, String value, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: BentoTheme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            color: BentoTheme.textSecondary.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
