import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/data/services/score_service.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/features/tasks/task_analytics_page.dart';

import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/data/services/global_xp_service.dart';
import 'package:intl/intl.dart';

class ScoreDeltaCard extends StatelessWidget {
  final HomeCardSize size;

  const ScoreDeltaCard({
    super.key,
    this.size = HomeCardSize.compact,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('xp_history').listenable(),
      builder: (context, Box xpBox, _) {
        final deltas = ScoreService.getScoreDeltas(xpBox: xpBox);
        final dayDelta = deltas['dayDelta'] ?? 0;
        final weekDelta = deltas['weekDelta'] ?? 0;
        final monthDelta = deltas['monthDelta'] ?? 0;
        final xpHistory = GlobalXPService.getPast7DaysXP();

        return HomeCardFrame(
          icon: LucideIcons.trendingUp,
          title: 'XP Velocity',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TaskAnalyticsPage(),
              ),
            );
          },
          trailing: _buildDeltaBadge(dayDelta, label: 'Today'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDeltaColumn('DAY', dayDelta, 'vs Yesterday'),
                  Container(
                    width: 1,
                    height: 38,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  _buildDeltaColumn('WEEK', weekDelta, 'vs Prev Week'),
                  Container(
                    width: 1,
                    height: 38,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  _buildDeltaColumn('MONTH', monthDelta, 'vs Prev Month'),
                ],
              ),
              if (size == HomeCardSize.large || size == HomeCardSize.hero) ...[
                const SizedBox(height: 16),
                Text(
                  '7-DAY VELOCITY',
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                _build7DayVelocity(xpHistory),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _build7DayVelocity(List<int> xpHistory) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (index) {
        final xp = xpHistory[index];
        final prevXp = index > 0 ? xpHistory[index - 1] : xp;
        final diff = xp - prevXp;
        final isToday = index == 6;
        final date = DateTime.now().subtract(Duration(days: 6 - index));
        final label = isToday
            ? 'TODAY'
            : DateFormat('EE').format(date).substring(0, 1).toUpperCase();
        final isPos = diff >= 0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isPos
                    ? BentoTheme.positive.withValues(alpha: 0.16)
                    : BentoTheme.negative.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Icon(
                isPos ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight,
                size: 14,
                color: isPos ? BentoTheme.positive : BentoTheme.negative,
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

  Widget _buildDeltaBadge(int delta, {required String label}) {
    final isPos = delta > 0;
    final isNeg = delta < 0;
    final color = isPos
        ? BentoTheme.positive
        : (isNeg ? BentoTheme.negative : BentoTheme.textSecondary);
    final sign = isPos ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$sign$delta XP',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDeltaColumn(String title, int delta, String comparison) {
    final isPos = delta > 0;
    final isNeg = delta < 0;
    final color = isPos
        ? BentoTheme.positive
        : (isNeg ? BentoTheme.negative : BentoTheme.textSecondary);
    final sign = isPos ? '+' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: BentoTheme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPos
                  ? LucideIcons.arrowUpRight
                  : (isNeg ? LucideIcons.arrowDownRight : LucideIcons.minus),
              size: 14,
              color: color,
            ),
            const SizedBox(width: 2),
            Text(
              '$sign$delta XP',
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Text(
          comparison,
          style: TextStyle(
            color: BentoTheme.textSecondary.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
