import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/data/services/score_service.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/features/tasks/task_analytics_page.dart';

class ScoreCard extends StatelessWidget {
  const ScoreCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('xp_history').listenable(),
      builder: (context, Box xpBox, _) {
        final summary = ScoreService.getScoreSummary(xpBox: xpBox);
        final week = summary['week'] ?? 0;
        final month = summary['month'] ?? 0;
        final year = summary['year'] ?? 0;

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
          child: Row(
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
        );
      },
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
