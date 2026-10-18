import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/tactile_tokens.dart';
import 'package:habit_tracker/core/widgets/tactile_button.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/features/home/cards/home_card.dart';
import 'package:habit_tracker/core/motion/animated_strikethrough.dart';
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
          domain: HomeCardDomain.tactical,
          icon: LucideIcons.checkSquare,
          title: 'DAILY MISSIONS',
          onTap: () {
            AppNav.goTo(
              AppTab.tasks,
              sub: TasksSubview.missions,
            );
          },
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: TactileTokens.accentLime.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: TactileTokens.accentLime.withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$completedCount/${dailyGoals.length}',
                  style: TextStyle(
                    color: TactileTokens.accentLime,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  LucideIcons.arrowRight,
                  size: 13,
                  color: TactileTokens.accentLime,
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
                ...displayGoals.map((goal) => TacticalMissionItem(
                      key: ValueKey(goal.id),
                      goal: goal,
                    )),
            ],
          ),
        );
      },
    );
  }
}

/// Tactical mission checklist item with physical checkbox snap, strikethrough sweep,
/// haptic thud, and floating +XP micro-toast.
class TacticalMissionItem extends StatefulWidget {
  final Goal goal;

  const TacticalMissionItem({
    super.key,
    required this.goal,
  });

  @override
  State<TacticalMissionItem> createState() => _TacticalMissionItemState();
}

class _TacticalMissionItemState extends State<TacticalMissionItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _toastController;
  late final Animation<double> _toastOpacity;
  late final Animation<Offset> _toastSlide;
  bool _showToast = false;

  @override
  void initState() {
    super.initState();
    _toastController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _toastOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
    ]).animate(_toastController);

    _toastSlide = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -24),
    ).animate(CurvedAnimation(
      parent: _toastController,
      curve: Curves.easeOutCubic,
    ));

    _toastController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _showToast = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _toastController.dispose();
    super.dispose();
  }

  void _handleToggle(bool? value) {
    HapticFeedback.mediumImpact();
    if (!widget.goal.isCompleted) {
      setState(() {
        _showToast = true;
      });
      _toastController.forward(from: 0.0);
      widget.goal.complete();
    } else {
      widget.goal.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = widget.goal.isCompleted;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDone
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDone
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.08),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              TactileCheckbox(
                value: isDone,
                onChanged: _handleToggle,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedStrikethroughText(
                  text: widget.goal.title,
                  isDone: isDone,
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: isDone ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDone
                      ? Colors.white.withValues(alpha: 0.04)
                      : TactileTokens.accentLime.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '+${widget.goal.xpValue} XP',
                  style: TextStyle(
                    color: isDone
                        ? BentoTheme.textSecondary
                        : TactileTokens.accentLime,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Floating +XP Micro-Toast
        if (_showToast)
          Positioned(
            right: 12,
            top: 6,
            child: AnimatedBuilder(
              animation: _toastController,
              builder: (context, _) {
                return Transform.translate(
                  offset: _toastSlide.value,
                  child: Opacity(
                    opacity: _toastOpacity.value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: TactileTokens.accentLime,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: TactileTokens.accentLime
                                .withValues(alpha: 0.6),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '+${widget.goal.xpValue} XP',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

