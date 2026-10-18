import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/tactile_tokens.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/data/services/global_xp_service.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/features/home/cards/home_card_frame.dart';
import 'package:habit_tracker/features/home/widgets/momentum_sparkline.dart';
import 'package:intl/intl.dart';

/// Executive Telemetry Module for Momentum Signal (AGENTS.md Phase 3.1).
/// Features a smooth cubic-bezier sparkline, gradient fill, and glowing current-day node.
class MomentumCard extends StatefulWidget {
  final HomeCardSize size;

  const MomentumCard({
    super.key,
    this.size = HomeCardSize.compact,
  });

  @override
  State<MomentumCard> createState() => _MomentumCardState();
}

class _MomentumCardState extends State<MomentumCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.size == HomeCardSize.large || widget.size == HomeCardSize.hero;
  }

  @override
  void didUpdateWidget(covariant MomentumCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.size != widget.size) {
      _isExpanded = widget.size == HomeCardSize.large || widget.size == HomeCardSize.hero;
    }
  }

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
        final todayXp = xpHistory.isNotEmpty ? xpHistory.last : 0;

        return HomeCardFrame(
          domain: HomeCardDomain.telemetry,
          icon: LucideIcons.activity,
          title: 'MOMENTUM SIGNAL',
          subtitle: 'Active Streak: $completedDays / 7 Days',
          onTap: _toggleExpanded,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: TactileTokens.vermilion.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: TactileTokens.vermilion.withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+$todayXp XP TODAY',
                  style: TactileTokens.tabular(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: TactileTokens.vermilion,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 13,
                  color: TactileTokens.vermilion,
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
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
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
        // Micro cubic-bezier sparkline with glowing today node
        MomentumSparkline(
          values: xpHistory,
          height: 60.0,
          showLabels: false,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final isToday = index == 6;
            final date = DateTime.now().subtract(Duration(days: 6 - index));
            final dayLabel =
                isToday ? 'NOW' : DateFormat('EE').format(date).toUpperCase();
            final xp = xpHistory.length > index ? xpHistory[index] : 0;
            final hasWork = xp > 0;

            return Column(
              children: [
                Text(
                  dayLabel,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: isToday
                        ? TactileTokens.textPrimary
                        : TactileTokens.textMuted,
                    fontSize: 9,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isToday
                        ? TactileTokens.vermilion
                        : (hasWork
                            ? BentoTheme.accent
                            : const Color(0x28FFFFFF)),
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
        MomentumSparkline(
          values: xpHistory,
          height: 110.0,
          showLabels: true,
        ),
      ],
    );
  }
}
