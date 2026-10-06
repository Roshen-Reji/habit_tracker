import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/models/models.dart';
import 'package:habit_tracker/features/finance/ui/goals/goal_contribution_dialog.dart';
import 'package:habit_tracker/features/finance/ui/goals/goal_detail_page.dart';
import 'package:habit_tracker/features/finance/ui/goals/goal_edit_sheet.dart';

class GoalsTab extends StatefulWidget {
  const GoalsTab({super.key});

  @override
  State<GoalsTab> createState() => _GoalsTabState();
}

class _GoalsTabState extends State<GoalsTab>
    with SingleTickerProviderStateMixin {
  final FinanceController _controller = FinanceController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // P5-4: Trigger auto-contribute on first open of the month
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.runAutoContribute();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final allGoals = _controller.allGoals;
        final goals = allGoals
            .where((g) => !g.archived && g.kind != 'sinking_fund')
            .toList();
        final sinkingFunds = allGoals
            .where((g) => !g.archived && g.kind == 'sinking_fund')
            .toList();
        final archived = allGoals.where((g) => g.archived).toList();

        // Calculate overall metrics
        double totalSaved = 0.0;
        double totalTarget = 0.0;
        for (final g in allGoals.where((g) => !g.archived)) {
          totalSaved += _controller.getGoalSaved(g.id);
          totalTarget += g.targetAmount;
        }
        final overallPct =
            totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0.0;

        return Scaffold(
          backgroundColor: BentoTheme.background,
          body: SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title bar
                        Row(
                          children: [
                            Text(
                              'Goals & Funds',
                              style: TextStyle(
                                color: BentoTheme.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Total Savings Progress Card
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: BentoTheme.surface,
                            borderRadius: ExpressiveTokens.borderL,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'TOTAL GOAL SAVINGS',
                                    style: TextStyle(
                                      color: BentoTheme.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  Text(
                                    '${(overallPct * 100).toStringAsFixed(0)}% of goal targets',
                                    style: TextStyle(
                                      color: BentoTheme.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    FormatUtils.formatMoney(totalSaved),
                                    style: TextStyle(
                                      color: BentoTheme.textPrimary,
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'of ${FormatUtils.formatMoney(totalTarget)}',
                                    style: TextStyle(
                                      color: BentoTheme.textSecondary,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: overallPct,
                                  minHeight: 8,
                                  backgroundColor: Colors.white12,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      BentoTheme.accent),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Tab Bar
                        Container(
                          decoration: BoxDecoration(
                            color: BentoTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicator: BoxDecoration(
                              color: BentoTheme.accent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            labelColor: Colors.black,
                            unselectedLabelColor: BentoTheme.textSecondary,
                            labelStyle: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                            unselectedLabelStyle: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                            dividerColor: Colors.transparent,
                            tabs: [
                              Tab(text: 'Goals (${goals.length})'),
                              Tab(
                                  text:
                                      'Sinking Funds (${sinkingFunds.length})'),
                              Tab(text: 'Archived (${archived.length})'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildGoalsList(goals, 'goal'),
                  _buildGoalsList(sinkingFunds, 'sinking_fund'),
                  _buildGoalsList(archived, 'archived'),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              final isSinkingTab = _tabController.index == 1;
              GoalEditSheet.show(
                context,
                controller: _controller,
                initialKind: isSinkingTab ? 'sinking_fund' : 'goal',
              );
            },
            backgroundColor: BentoTheme.accent,
            foregroundColor: Colors.black,
            icon: const Icon(LucideIcons.plus, size: 18),
            label: Text(
              _tabController.index == 1 ? 'New Sinking Fund' : 'New Goal',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGoalsList(List<SavingsGoal> items, String kind) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                kind == 'sinking_fund'
                    ? LucideIcons.calendarClock
                    : LucideIcons.target,
                size: 44,
                color: BentoTheme.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                kind == 'sinking_fund'
                    ? 'No Sinking Funds'
                    : (kind == 'archived'
                        ? 'No Archived Goals'
                        : 'No Savings Goals'),
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                kind == 'sinking_fund'
                    ? 'Set aside money for annual insurance, festivals, medical reserve, and periodic bills.'
                    : 'Track progress towards emergency funds, vacations, down payments, and big milestones.',
                textAlign: TextAlign.center,
                style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
              ),
              if (kind != 'archived') ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    GoalEditSheet.show(
                      context,
                      controller: _controller,
                      initialKind: kind,
                    );
                  },
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: Text(kind == 'sinking_fund'
                      ? 'Create Sinking Fund'
                      : 'Create First Goal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BentoTheme.accent,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: items.length,
      itemBuilder: (context, idx) {
        final goal = items[idx];
        return _buildGoalCard(goal);
      },
    );
  }

  Widget _buildGoalCard(SavingsGoal goal) {
    final saved = _controller.getGoalSaved(goal.id);
    final target = goal.targetAmount;
    final pct = target > 0 ? (saved / target).clamp(0.0, 1.0) : 0.0;
    final isDone = saved >= target;
    final deadline = goal.deadline ?? goal.dueDate;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderM,
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => GoalDetailPage(goalId: goal.id)),
            );
          },
          borderRadius: ExpressiveTokens.borderM,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          Color(goal.colorValue).withValues(alpha: 0.2),
                      child: Icon(
                        goal.kind == 'sinking_fund'
                            ? LucideIcons.calendarClock
                            : LucideIcons.target,
                        size: 15,
                        color: Color(goal.colorValue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.name,
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (deadline != null)
                            Text(
                              'Due: ${DateFormat('dd MMM yyyy').format(deadline)}',
                              style: TextStyle(
                                  color: BentoTheme.textSecondary,
                                  fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          FormatUtils.formatMoney(saved),
                          style: TextStyle(
                            color: isDone
                                ? const Color(0xFF10B981)
                                : BentoTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Target: ${FormatUtils.formatMoney(target)}',
                          style: TextStyle(
                              color: BentoTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDone ? const Color(0xFF10B981) : Color(goal.colorValue),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Footer Row: Badges & Add Money Button
                Row(
                  children: [
                    Text(
                      '${(pct * 100).toStringAsFixed(0)}% reached',
                      style: TextStyle(
                        color: isDone
                            ? const Color(0xFF10B981)
                            : BentoTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (goal.autoContribute) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: BentoTheme.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Auto: ${FormatUtils.formatMoney(goal.plannedMonthly ?? 0)}/mo',
                          style: TextStyle(
                            color: BentoTheme.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        GoalContributionDialog.show(
                          context,
                          controller: _controller,
                          goal: goal,
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: BentoTheme.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.plus,
                                size: 12, color: BentoTheme.accent),
                            const SizedBox(width: 4),
                            Text(
                              'Add Money',
                              style: TextStyle(
                                color: BentoTheme.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
