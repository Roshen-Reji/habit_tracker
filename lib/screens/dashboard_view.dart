import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/widgets/mysterious_quote_card.dart';
import 'package:habit_tracker/widgets/mysterious_momentum_graph.dart';
import 'package:habit_tracker/widgets/star_background.dart';
import 'package:habit_tracker/screens/settings_page.dart';
import 'package:habit_tracker/core/theme/neu_theme.dart';
import 'package:habit_tracker/data/services/rank_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, Box settings, _) {
        final String name = settings.get('username', defaultValue: 'COMMANDER');

        return StarBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ValueListenableBuilder(
                          valueListenable: Hive.box<Goal>('mission_box_v4').listenable(),
                          builder: (context, Box<Goal> missionBox, _) {
                            final record = RankService.calculateServiceRecord(missionBox.values.toList());
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("WELCOME,", style: TextStyle(color: NeuTheme.accent.withValues(alpha: 0.6), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                                Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 1.5, color: NeuTheme.textPrimary)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: NeuTheme.accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: NeuTheme.accent.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    "${record.title} • LVL ${record.level}",
                                    style: TextStyle(color: NeuTheme.accent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                  ),
                                ),
                              ],
                            ).animate().slideX(begin: -0.1, duration: 400.ms, curve: Curves.easeOutQuad).fade();
                          }
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
                          child: NeuContainer(
                            borderRadius: 20,
                            padding: const EdgeInsets.all(10),
                            child: Icon(LucideIcons.settings, color: NeuTheme.accent, size: 20),
                          ),
                        ).animate().scale(delay: 200.ms, duration: 300.ms, curve: Curves.easeOutBack),
                      ],
                    ),
                  ),
                  const MysteriousQuoteCard(),
                  const SizedBox(height: 10),
                  const MysteriousMomentumGraph(),
                  const SizedBox(height: 20),
                  _buildSectionHeader("Diet Today"),
                  _buildDietSummaryCard(),
                  const SizedBox(height: 20),
                  _buildSectionHeader("Tasks"),
                  _buildDailyMissionsList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
      child: Row(
        children: [
          Icon(LucideIcons.radar, color: NeuTheme.accent, size: 16),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: NeuTheme.accent.withValues(alpha: 0.8), letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDailyMissionsList() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Goal>('mission_box_v4').listenable(),
      builder: (context, Box<Goal> box, _) {
        final dailyGoals = box.values.where((g) => g.type == GoalType.daily).toList();
        if (dailyGoals.isEmpty) return Padding(padding: const EdgeInsets.all(40), child: Center(child: Text("NO ACTIVE MISSIONS", style: TextStyle(color: NeuTheme.textSecondary))));
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: dailyGoals.length > 3 ? 3 : dailyGoals.length,
          itemBuilder: (context, index) => _buildGoalTile(dailyGoals[index]),
        );
      },
    );
  }

  Widget _buildGoalTile(Goal goal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: NeuContainer(
        borderRadius: 16,
        isPressed: goal.isCompleted,
        padding: EdgeInsets.zero,
        child: ListTile(
          onTap: () { 
            goal.isCompleted = !goal.isCompleted; 
            goal.save(); 
          },
          leading: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: Icon(
              goal.isCompleted ? LucideIcons.checkCircle2 : LucideIcons.circle, 
              key: ValueKey<bool>(goal.isCompleted),
              color: goal.isCompleted ? NeuTheme.accent : NeuTheme.textSecondary,
            ),
          ),
          title: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              color: goal.isCompleted ? NeuTheme.textSecondary : NeuTheme.textPrimary, 
              decoration: goal.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
              fontSize: 16,
            ),
            child: Text(goal.title),
          ),
        ),
      ),
    );
  }

  Widget _buildDietSummaryCard() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final box = Hive.box<DietDayLog>('diet_logs');
    final log = box.get(today);

    final intake = log?.totalCalories ?? 0;
    final target = log?.targetCalories ?? Hive.box('settings').get('daily_calorie_target', defaultValue: 2000.0).toDouble();
    final burned = log?.totalBurned ?? 0;
    final net = intake - burned;
    final isOver = net > target;
    final progress = target > 0 ? (net / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: NeuContainer(
        borderRadius: 20,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${net.toStringAsFixed(0)} kcal",
                      style: TextStyle(
                        color: NeuTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "of ${target.toStringAsFixed(0)} kcal target",
                      style: TextStyle(color: NeuTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isOver ? Colors.redAccent : Colors.greenAccent).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isOver
                        ? "+${(net - target).toStringAsFixed(0)} over"
                        : "${(target - net).toStringAsFixed(0)} left",
                    style: TextStyle(
                      color: isOver ? Colors.redAccent : Colors.greenAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.toDouble(),
                minHeight: 6,
                backgroundColor: NeuTheme.isDark ? Colors.black26 : Colors.black12,
                valueColor: AlwaysStoppedAnimation(
                  isOver ? Colors.redAccent : NeuTheme.accent,
                ),
              ),
            ),
            if (log != null && log.entries.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                log.entries.take(3).map((e) => e.name).join(", ") + (log.entries.length > 3 ? "..." : ""),
                style: TextStyle(color: NeuTheme.textSecondary, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    ).animate().fade(duration: 400.ms, delay: 200.ms).slideY(begin: 0.1);
  }
}
