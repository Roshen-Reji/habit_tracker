import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/widgets/mysterious_quote_card.dart';
import 'package:habit_tracker/widgets/mysterious_momentum_graph.dart';

import 'package:habit_tracker/screens/settings_page.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/data/services/global_xp_service.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settings').listenable(),
      builder: (context, Box settings, _) {
        final String name = settings.get('username', defaultValue: 'USER');

        return SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(builder: (context) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Welcome back,",
                                style: TextStyle(
                                    color: BentoTheme.textSecondary,
                                    fontSize: 14,
                                    letterSpacing: 1.2)),
                            Text(name,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                    letterSpacing: 1.0,
                                    color: BentoTheme.textPrimary)),
                          ],
                        )
                            .animate()
                            .slideX(
                                begin: -0.1,
                                duration: 400.ms,
                                curve: Curves.easeOutQuad)
                            .fade();
                      }),
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SettingsPage())),
                        child: BentoContainer(
                          borderRadius: 12,
                          padding: const EdgeInsets.all(10),
                          child: Icon(LucideIcons.settings,
                              color: BentoTheme.textPrimary, size: 20),
                        ),
                      ).animate().scale(
                          delay: 200.ms,
                          duration: 300.ms,
                          curve: Curves.easeOutBack),
                    ],
                  ),
                ),
                const MysteriousQuoteCard(),
                const SizedBox(height: 10),
                const MysteriousMomentumGraph(),
                const SizedBox(height: 20),
                _buildDietSummaryCard(),
                const SizedBox(height: 20),
                _buildSectionHeader("Tasks"),
                _buildDailyMissionsList(),
              ],
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
          Icon(LucideIcons.radar, color: BentoTheme.accent, size: 16),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  color: BentoTheme.accent.withValues(alpha: 0.8),
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDailyMissionsList() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Goal>('mission_box_v4').listenable(),
      builder: (context, Box<Goal> box, _) {
        final dailyGoals =
            box.values.where((g) => g.type == GoalType.daily).toList();
        if (dailyGoals.isEmpty)
          return Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                  child: Text("NO ACTIVE MISSIONS",
                      style: TextStyle(color: BentoTheme.textSecondary))));
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
      child: BentoContainer(
        borderRadius: 16,
        padding: EdgeInsets.zero,
        child: ListTile(
          onTap: () {
            goal.isCompleted = !goal.isCompleted;
            if (goal.isCompleted) {
              GlobalXPService.addXP(goal.xpValue);
            } else {
              GlobalXPService.subtractXP(goal.xpValue);
            }
            goal.save();
          },
          leading: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              goal.isCompleted ? LucideIcons.checkCircle2 : LucideIcons.circle,
              key: ValueKey<bool>(goal.isCompleted),
              color: goal.isCompleted
                  ? BentoTheme.accent
                  : BentoTheme.textSecondary,
            ),
          ),
          title: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              color: goal.isCompleted
                  ? BentoTheme.textSecondary
                  : BentoTheme.textPrimary,
              decoration: goal.isCompleted
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
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
    final target = log?.targetCalories ??
        Hive.box('settings')
            .get('daily_calorie_target', defaultValue: 2000.0)
            .toDouble();
    final burned = log?.totalBurned ?? 0;
    final net = intake - burned;
    final isOver = net > target;
    final progress = target > 0 ? (net / target).clamp(0.0, 1.0) : 0.0;

    final protein = log?.totalProtein ?? 0;
    final carbs = log?.totalCarbs ?? 0;
    final fat = log?.totalFat ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: BentoContainer(
        borderRadius: 20,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.radar, color: BentoTheme.accent, size: 16),
                const SizedBox(width: 8),
                Text("DIET TODAY",
                    style: TextStyle(
                        color: BentoTheme.accent.withValues(alpha: 0.8),
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${net.toStringAsFixed(0)} kcal",
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "of ${target.toStringAsFixed(0)} kcal target",
                      style: TextStyle(
                          color: BentoTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isOver ? Colors.redAccent : Colors.greenAccent)
                        .withValues(alpha: 0.15),
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
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress.toDouble(),
              minHeight: 6,
              borderRadius: BorderRadius.circular(6),
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(
                isOver ? Colors.redAccent : BentoTheme.accent,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMacroText("Protein", "${protein.toStringAsFixed(0)}g"),
                _buildMacroText("Carbs", "${carbs.toStringAsFixed(0)}g"),
                _buildMacroText("Fat", "${fat.toStringAsFixed(0)}g"),
              ],
            ),
            if (log != null && log.entries.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                log.entries.take(3).map((e) => e.name).join(", ") +
                    (log.entries.length > 3 ? "..." : ""),
                style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    ).animate().fade(duration: 400.ms, delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildMacroText(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                color: BentoTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
        Text(label,
            style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11)),
      ],
    );
  }
}
