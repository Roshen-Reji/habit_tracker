import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/engine/goal_planner_engine.dart';
import 'package:habit_tracker/features/finance/models/models.dart';
import 'package:habit_tracker/features/finance/ui/goals/goal_contribution_dialog.dart';
import 'package:habit_tracker/features/finance/ui/goals/goal_edit_sheet.dart';

class GoalDetailPage extends StatefulWidget {
  final String goalId;

  const GoalDetailPage({
    super.key,
    required this.goalId,
  });

  @override
  State<GoalDetailPage> createState() => _GoalDetailPageState();
}

class _GoalDetailPageState extends State<GoalDetailPage> {
  final FinanceController _controller = FinanceController();

  Future<void> _applyTrims(GoalPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BentoTheme.surface,
        title: Text(
          'Apply Budget Trims?',
          style: TextStyle(color: BentoTheme.textPrimary),
        ),
        content: Text(
          'This will update ${plan.trimSuggestions.length} non-essential category budgets to free up ${FormatUtils.formatMoney(plan.shortfall)}/month for this goal.',
          style: TextStyle(color: BentoTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: BentoTheme.accent),
            child: const Text('Apply Changes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _controller.applyTrimSuggestions(plan.trimSuggestions);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Budgets adjusted according to goal plan!'),
            backgroundColor: BentoTheme.surface,
          ),
        );
      }
    }
  }

  Future<void> _deleteEntry(GoalEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BentoTheme.surface,
        title: Text(
          'Delete Entry?',
          style: TextStyle(color: BentoTheme.textPrimary),
        ),
        content: Text(
          'Remove this ${entry.amount >= 0 ? 'contribution' : 'withdrawal'} of ${FormatUtils.formatMoney(entry.amount.abs())}?',
          style: TextStyle(color: BentoTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: BentoTheme.negative),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _controller.deleteGoalEntry(entry.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final goal = _controller.storage.goalBox.get(widget.goalId);
        if (goal == null) {
          return Scaffold(
            backgroundColor: BentoTheme.background,
            body: const Center(child: Text('Goal not found')),
          );
        }

        final entries = _controller.getGoalEntries(goal.id);
        final saved = _controller.getGoalSaved(goal.id);
        final target = goal.targetAmount;
        final pct = target > 0 ? (saved / target).clamp(0.0, 1.0) : 0.0;
        final plan = _controller.planGoal(goal);

        final deadline = goal.deadline ?? goal.dueDate;
        final earmark = goal.accountId != null
            ? _controller.storage.accountBox.get(goal.accountId!)
            : null;

        return Scaffold(
          backgroundColor: BentoTheme.background,
          appBar: AppBar(
            backgroundColor: BentoTheme.background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, size: 20),
              color: BentoTheme.textPrimary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              goal.name,
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.pencil, size: 18),
                color: BentoTheme.textSecondary,
                onPressed: () {
                  GoalEditSheet.show(
                    context,
                    controller: _controller,
                    existingGoal: goal,
                  );
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // Hero Progress Card
              _buildHeroCard(goal, saved, target, pct, deadline, earmark),
              const SizedBox(height: 16),

              // Action Buttons: Contribute vs Withdraw
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        GoalContributionDialog.show(
                          context,
                          controller: _controller,
                          goal: goal,
                        );
                      },
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: const Text('Add Money'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BentoTheme.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: ExpressiveTokens.borderM,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      GoalContributionDialog.show(
                        context,
                        controller: _controller,
                        goal: goal,
                      );
                    },
                    icon: const Icon(LucideIcons.arrowUpRight, size: 16),
                    label: const Text('Withdraw'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BentoTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.15)),
                      shape: RoundedRectangleBorder(
                        borderRadius: ExpressiveTokens.borderM,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Goal Planner & Shortfall Card (P5-2)
              _buildPlannerCard(plan),
              const SizedBox(height: 24),

              // History of contributions & withdrawals
              Text(
                'CONTRIBUTION HISTORY',
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),

              if (entries.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: BentoTheme.surface,
                    borderRadius: ExpressiveTokens.borderM,
                  ),
                  child: Center(
                    child: Text(
                      'No contributions recorded yet.\nTap "Add Money" to start saving.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: BentoTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                ),
              ] else ...[
                ...entries.map((entry) => _buildEntryTile(entry)),
              ],

              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroCard(
    SavingsGoal goal,
    double saved,
    double target,
    double pct,
    DateTime? deadline,
    Account? earmark,
  ) {
    final isDone = saved >= target;
    final remaining = target - saved;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(goal.colorValue).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  goal.kind == 'sinking_fund' ? 'Sinking Fund' : 'Savings Goal',
                  style: TextStyle(
                    color: Color(goal.colorValue),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${(pct * 100).toStringAsFixed(0)}% Saved',
                style: TextStyle(
                  color: isDone ? const Color(0xFF10B981) : BentoTheme.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                FormatUtils.formatMoney(saved),
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'of ${FormatUtils.formatMoney(target)}',
                style: TextStyle(color: BentoTheme.textSecondary, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress bar
          ProgressBarX(
            value: pct,
            height: 10,
            customColor:
                isDone ? const Color(0xFF10B981) : Color(goal.colorValue),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.calendar,
                      size: 14, color: BentoTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    deadline != null
                        ? 'Due: ${DateFormat('dd MMM yyyy').format(deadline)}'
                        : 'No deadline set',
                    style: TextStyle(
                        color: BentoTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              Text(
                isDone
                    ? 'Goal Achieved!'
                    : '${FormatUtils.formatMoney(remaining)} to go',
                style: TextStyle(
                  color: isDone
                      ? const Color(0xFF10B981)
                      : BentoTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          if (earmark != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(LucideIcons.lock,
                    size: 13, color: BentoTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Earmarked in ${earmark.name}',
                  style:
                      TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlannerCard(GoalPlan plan) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.sparkles, size: 18, color: BentoTheme.accent),
              const SizedBox(width: 8),
              Text(
                'Goal Intelligence & Planner',
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3-Metric Stats Row
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  'REQUIRED',
                  '${FormatUtils.formatMoney(plan.requiredMonthly)}/mo',
                  'to meet deadline (${plan.monthsLeft} mo left)',
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  'CURRENT RATE',
                  '${FormatUtils.formatMoney(plan.currentRate)}/mo',
                  'past 3-month average',
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  'SHORTFALL',
                  plan.shortfall > 0
                      ? '${FormatUtils.formatMoney(plan.shortfall)}/mo'
                      : 'None! 🎉',
                  plan.shortfall > 0 ? 'monthly gap' : 'on track',
                  color: plan.shortfall > 0
                      ? BentoTheme.warning
                      : BentoTheme.positive,
                ),
              ),
            ],
          ),

          // Trim Suggestions Section (P5-2)
          if (plan.shortfall > 0 && plan.trimSuggestions.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            Text(
              'RECOMMENDED BUDGET TRIMS',
              style: TextStyle(
                color: BentoTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cut non-essential budgets to bridge your monthly shortfall:',
              style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ...plan.trimSuggestions.map((trim) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: BentoTheme.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trim.categoryName,
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '3m avg: ${FormatUtils.formatMoney(trim.threeMonthAvg)}',
                            style: TextStyle(
                                color: BentoTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '-${FormatUtils.formatMoney(trim.suggestedTrim)}',
                          style: TextStyle(
                            color: BentoTheme.warning,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'New: ${FormatUtils.formatMoney(trim.newBudget)}',
                          style: TextStyle(
                              color: BentoTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () => _applyTrims(plan),
                icon: const Icon(LucideIcons.check, size: 16),
                label: const Text('Apply Suggested Trims'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BentoTheme.accent.withValues(alpha: 0.2),
                  foregroundColor: BentoTheme.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],

          if (plan.isInsufficient) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: BentoTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.alertTriangle,
                      size: 16, color: BentoTheme.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Shortfall exceeds 20% safe trims on non-essentials. Consider extending the deadline or adding fresh income.',
                      style: TextStyle(
                          color: BentoTheme.warning, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, String sub,
      {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: BentoTheme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color ?? BentoTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          style: TextStyle(color: BentoTheme.textSecondary, fontSize: 10),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildEntryTile(GoalEntry entry) {
    final isDeposit = entry.amount >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderM,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: isDeposit
                ? BentoTheme.positive.withValues(alpha: 0.2)
                : BentoTheme.negative.withValues(alpha: 0.2),
            child: Icon(
              isDeposit ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
              size: 14,
              color: isDeposit ? BentoTheme.positive : BentoTheme.negative,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.note ?? (isDeposit ? 'Contribution' : 'Withdrawal'),
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(entry.date),
                  style:
                      TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${isDeposit ? '+' : ''}${FormatUtils.formatMoney(entry.amount)}',
            style: TextStyle(
              color: isDeposit ? BentoTheme.positive : BentoTheme.negative,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon:
                const Icon(LucideIcons.trash2, size: 14, color: Colors.white38),
            onPressed: () => _deleteEntry(entry),
          ),
        ],
      ),
    );
  }
}
