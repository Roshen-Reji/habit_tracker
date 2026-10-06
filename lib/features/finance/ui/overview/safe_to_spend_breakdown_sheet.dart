import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/engine/safe_to_spend_engine.dart';

class SafeToSpendBreakdownSheet extends StatelessWidget {
  final SafeToSpendExplanation explanation;

  const SafeToSpendBreakdownSheet({
    super.key,
    required this.explanation,
  });

  static Future<void> show(
    BuildContext context,
    SafeToSpendExplanation explanation,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeToSpendBreakdownSheet(explanation: explanation),
    );
  }

  @override
  Widget build(BuildContext context) {
    final res = explanation.result;
    final isShortfall = res.hasShortfall;

    return Container(
      decoration: BoxDecoration(
        color: BentoTheme.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: BentoTheme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SAFE TO SPEND BREAKDOWN',
                    style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isShortfall)
                    Text(
                      'Short by ${FormatUtils.formatMoney(res.shortfall)}',
                      style: const TextStyle(
                        color: Color(0xFFD98A86), // Muted coral
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  else
                    Text(
                      FormatUtils.formatMoney(res.safeToSpend),
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isShortfall
                          ? const Color(0xFFD98A86)
                          : BentoTheme.accent)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isShortfall
                      ? 'Deficit'
                      : '${FormatUtils.formatMoney(res.perDay)} / day',
                  style: TextStyle(
                    color: isShortfall
                        ? const Color(0xFFD98A86)
                        : BentoTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Content list
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Liquid
                  _buildSectionHeader(
                    icon: LucideIcons.wallet,
                    title: 'Liquid Funds',
                    amount: explanation.liquid,
                    isPositive: true,
                  ),
                  ...explanation.liquidItems.map((item) => _buildItemRow(item)),

                  const SizedBox(height: 16),

                  // 2. Obligations
                  _buildSectionHeader(
                    icon: LucideIcons.calendarClock,
                    title: 'Upcoming Obligations (Bills & SIPs)',
                    amount: -explanation.obligations,
                    isPositive: false,
                  ),
                  if (explanation.obligationItems.isEmpty)
                    _buildEmptyNotice('No remaining obligations this month')
                  else
                    ...explanation.obligationItems
                        .map((item) => _buildItemRow(item, isDeduction: true)),

                  const SizedBox(height: 16),

                  // 3. Goals
                  _buildSectionHeader(
                    icon: LucideIcons.target,
                    title: 'Goals Earmark',
                    amount: -explanation.goalsEarmark,
                    isPositive: false,
                  ),
                  if (explanation.goalItems.isEmpty)
                    _buildEmptyNotice('No active goal requirements')
                  else
                    ...explanation.goalItems.map((item) => _buildItemRow(
                          item,
                          isDeduction: !item.isDeduplicated,
                        )),

                  if (explanation.deduplicationNotes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...explanation.deduplicationNotes.map(
                      (note) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: BentoTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: BentoTheme.accent.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              LucideIcons.info,
                              size: 14,
                              color: BentoTheme.accent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                note,
                                style: TextStyle(
                                  color: BentoTheme.textSecondary,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // 4. Essential Budget
                  _buildSectionHeader(
                    icon: LucideIcons.shoppingBag,
                    title: 'Planned Essential Budget',
                    amount: -explanation.plannedEssential,
                    isPositive: false,
                  ),
                  if (explanation.essentialItems.isEmpty)
                    _buildEmptyNotice('No essential budget lines remaining')
                  else
                    ...explanation.essentialItems
                        .map((item) => _buildItemRow(item, isDeduction: true)),

                  if (explanation.cardDues > 0) ...[
                    const SizedBox(height: 16),
                    // 5. Card Dues
                    _buildSectionHeader(
                      icon: LucideIcons.creditCard,
                      title: 'Credit Card Dues',
                      amount: -explanation.cardDues,
                      isPositive: false,
                    ),
                    ...explanation.cardDueItems
                        .map((item) => _buildItemRow(item, isDeduction: true)),
                  ],
                  if (explanation.excludedItems.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    // 6. Excluded Accounts (liabilities, non-spendable, archived)
                    _buildSectionHeader(
                      icon: LucideIcons.shieldAlert,
                      title: 'Excluded Accounts',
                      amount: explanation.excludedItems
                          .fold(0.0, (s, i) => s + i.amount),
                      isPositive: false,
                    ),
                    ...explanation.excludedItems
                        .map((item) => _buildExcludedItemRow(context, item)),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExcludedItemRow(
      BuildContext context, SafeToSpendExplanationItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    color: BentoTheme.textPrimary.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item.subtitle != null)
                  Text(
                    item.subtitle!,
                    style: TextStyle(
                      color: BentoTheme.textSecondary.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            FormatUtils.formatMoney(item.amount),
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required double amount,
    required bool isPositive,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: BentoTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            FormatUtils.formatMoney(amount),
            style: TextStyle(
              color:
                  isPositive ? const Color(0xFF7FB69E) : BentoTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(
    SafeToSpendExplanationItem item, {
    bool isDeduction = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: item.isDeduplicated
                              ? BentoTheme.textSecondary.withValues(alpha: 0.6)
                              : BentoTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          decoration: item.isDeduplicated
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (FinanceController().primaryAccountId == item.id) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: BentoTheme.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'MAIN',
                          style: TextStyle(
                            color: BentoTheme.accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.subtitle != null)
                  Text(
                    item.subtitle!,
                    style: TextStyle(
                      color: BentoTheme.textSecondary.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${isDeduction ? '-' : ''}${FormatUtils.formatMoney(item.amount)}',
            style: TextStyle(
              color: item.isDeduplicated
                  ? BentoTheme.textSecondary.withValues(alpha: 0.5)
                  : BentoTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyNotice(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          color: BentoTheme.textSecondary.withValues(alpha: 0.6),
          fontSize: 11,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
