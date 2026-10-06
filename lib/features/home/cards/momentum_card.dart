import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/data/services/global_xp_service.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';

class MomentumCard extends StatefulWidget {
  const MomentumCard({super.key});

  @override
  State<MomentumCard> createState() => _MomentumCardState();
}

class _MomentumCardState extends State<MomentumCard> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('xp_history').listenable(),
      builder: (context, Box box, _) {
        final List<int> xpHistory = GlobalXPService.getPast7DaysXP();
        final completedDays = xpHistory.where((xp) => xp > 0).length;

        return HomeCardFrame(
          icon: LucideIcons.activity,
          title: 'Momentum Signal',
          onTap: _toggleExpanded,
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
                  '$completedDays/7 active',
                  style: TextStyle(
                    color: BentoTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 14,
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
              AnimatedSize(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOutCubic,
                child: _isExpanded
                    ? _buildExpandedGraph(xpHistory)
                    : _buildCompactStrip(xpHistory),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactStrip(List<int> xpHistory) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final xp = xpHistory[index];
            final hasWork = xp > 0;
            final isToday = index == 6;
            final date = DateTime.now().subtract(Duration(days: 6 - index));
            final dayLabel =
                isToday ? 'NOW' : DateFormat('EE').format(date).toUpperCase();

            return Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: hasWork
                        ? BentoTheme.accent
                            .withValues(alpha: isToday ? 0.9 : 0.25)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: hasWork
                      ? Icon(
                          LucideIcons.check,
                          size: 16,
                          color:
                              isToday ? Colors.black : BentoTheme.textPrimary,
                        )
                      : Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                BentoTheme.textSecondary.withValues(alpha: 0.3),
                          ),
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  dayLabel,
                  style: TextStyle(
                    color: isToday
                        ? BentoTheme.textPrimary
                        : BentoTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildExpandedGraph(List<int> xpHistory) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 140,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              return _buildDotMatrixColumn(xpHistory[index], index == 6);
            }),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final date = DateTime.now().subtract(Duration(days: 6 - index));
            final isToday = index == 6;
            final label =
                isToday ? 'NOW' : DateFormat('EE').format(date).toUpperCase();
            return Text(
              label,
              style: TextStyle(
                color:
                    isToday ? BentoTheme.textPrimary : BentoTheme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDotMatrixColumn(int xp, bool isToday) {
    final filledDots = (xp / 10).round().clamp(0, 10);
    const totalDots = 10;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: List.generate(totalDots, (index) {
        final invertedIndex = totalDots - 1 - index;
        final isFilled = invertedIndex < filledDots;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2.5),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? (isToday ? BentoTheme.textPrimary : BentoTheme.textSecondary)
                : BentoTheme.textPrimary.withValues(alpha: 0.1),
          ),
        );
      }),
    );
  }
}
