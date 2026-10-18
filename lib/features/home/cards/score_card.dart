import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/tactile_tokens.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/data/models/user_rank.dart';
import 'package:habit_tracker/data/services/global_xp_service.dart';
import 'package:habit_tracker/data/services/rank_service.dart';
import 'package:habit_tracker/data/services/score_service.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/core/motion/animated_metric_ticker.dart';
import 'package:habit_tracker/core/utils/page_transitions.dart';
import 'package:habit_tracker/features/tasks/task_analytics_page.dart';

/// Executive Telemetry Module for XP Totals & Live Service Rank (AGENTS.md Phase 3.1).
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

        // Calculate live UserRank
        final missionBox = Hive.isBoxOpen('mission_box_v4')
            ? Hive.box<Goal>('mission_box_v4')
            : null;
        final goals = missionBox?.values.toList() ?? <Goal>[];
        final UserRank rank = RankService.calculateServiceRecord(goals);

        return HomeCardFrame(
          domain: HomeCardDomain.telemetry,
          icon: LucideIcons.trophy,
          title: 'Executive Telemetry',
          subtitle: '${rank.title} • LVL ${rank.level}',
          onTap: () {
            Navigator.push(
              context,
              PageTransitions.containerTransform(
                const TaskAnalyticsPage(),
              ),
            );
          },
          statusBadge: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: TactileTokens.vermilion.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: TactileTokens.vermilion.withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.shield, size: 10, color: TactileTokens.vermilion),
                const SizedBox(width: 4),
                Text(
                  rank.position,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    color: TactileTokens.vermilion,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          trailing: const Icon(
            LucideIcons.arrowUpRight,
            size: 14,
            color: TactileTokens.textMuted,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const XpProgressBar(height: 5),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildXPColumn('WEEK', week, 'Past 7 days'),
                  Container(
                    width: 1,
                    height: 38,
                    color: const Color(0x12FFFFFF),
                  ),
                  _buildXPColumn('MONTH', month, 'Past 30 days'),
                  Container(
                    width: 1,
                    height: 38,
                    color: const Color(0x12FFFFFF),
                  ),
                  _buildXPColumn('YEAR', year, 'Past 365 days'),
                ],
              ),
              if (size == HomeCardSize.large || size == HomeCardSize.hero) ...[
                const SizedBox(height: 16),
                Text(
                  '7-DAY XP TREND',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: BentoTheme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
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

  Widget _buildXPColumn(String label, num xpValue, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: BentoTheme.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 3),
        AnimatedMetricTicker.xp(
          value: xpValue,
          prefix: '',
          style: TactileTokens.tabular(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: TactileTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: BentoTheme.textMuted,
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  Widget _build7DayBars(List<int> xpHistory) {
    final max = xpHistory.isEmpty ? 1 : xpHistory.reduce((a, b) => a > b ? a : b);
    final safeMax = max == 0 ? 1 : max;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (index) {
        final xp = xpHistory.length > index ? xpHistory[index] : 0;
        final ratio = (xp / safeMax).clamp(0.05, 1.0);
        final isToday = index == 6;

        return Column(
          children: [
            Container(
              width: 28,
              height: 48 * ratio,
              decoration: BoxDecoration(
                color: isToday
                    ? TactileTokens.vermilion
                    : TactileTokens.surfaceRaised,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isToday
                      ? TactileTokens.vermilion
                      : const Color(0x18FFFFFF),
                  width: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isToday ? 'NOW' : 'D${index + 1}',
              style: TextStyle(
                fontFamily: 'Roboto',
                color: isToday
                    ? TactileTokens.textPrimary
                    : BentoTheme.textMuted,
                fontSize: 9,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        );
      }),
    );
  }
}
