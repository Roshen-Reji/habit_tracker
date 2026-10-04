import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/engine/forecast_engine.dart';

class CashFlowPage extends StatefulWidget {
  const CashFlowPage({super.key});

  @override
  State<CashFlowPage> createState() => _CashFlowPageState();
}

class _CashFlowPageState extends State<CashFlowPage> {
  final FinanceController _controller = FinanceController();
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cashFlow = _controller.getCashFlowAnalysis(month: _currentMonth);
    final monthStr = DateFormat('MMMM yyyy').format(_currentMonth);

    return Scaffold(
      backgroundColor: BentoTheme.background,
      appBar: AppBar(
        title: const Text('Cash Flow Analysis', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: BentoTheme.surface,
        foregroundColor: BentoTheme.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Month navigation
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(LucideIcons.chevronLeft, color: BentoTheme.textPrimary),
                    onPressed: _prevMonth,
                  ),
                  Text(
                    monthStr,
                    style: BentoTheme.titleMedium.copyWith(
                      color: BentoTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.chevronRight, color: BentoTheme.textPrimary),
                    onPressed: _nextMonth,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Inflow, Outflow, Net hero
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    title: 'Inflow',
                    amount: cashFlow.income,
                    color: ExpressiveTokens.semanticSuccess,
                    icon: LucideIcons.arrowDownLeft,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    title: 'Outflow',
                    amount: cashFlow.spending,
                    color: ExpressiveTokens.semanticError,
                    icon: LucideIcons.arrowUpRight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Net Cash Flow', style: BentoTheme.bodySmall.copyWith(color: BentoTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Text(
                        '${cashFlow.net >= 0 ? '+' : ''}₹${FormatUtils.formatCurrency(cashFlow.net)}',
                        style: BentoTheme.titleLarge.copyWith(
                          color: cashFlow.net >= 0 ? ExpressiveTokens.semanticSuccess : ExpressiveTokens.semanticError,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: BentoTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${(cashFlow.savingsRate * 100).toStringAsFixed(1)}% Saved',
                      style: BentoTheme.bodySmall.copyWith(
                        color: BentoTheme.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 30-Day Forward Projection Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BentoTheme.accent.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.calendarClock, color: BentoTheme.accent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Next 30 Days Forecast',
                        style: BentoTheme.titleSmall.copyWith(
                          color: BentoTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildProjectionRow('Expected Inflow', '+₹${FormatUtils.formatCurrency(cashFlow.expectedIncomeNext30)}', ExpressiveTokens.semanticSuccess),
                  const SizedBox(height: 8),
                  _buildProjectionRow('Bills & Dues', '-₹${FormatUtils.formatCurrency(cashFlow.billsDueNext30)}', ExpressiveTokens.semanticError),
                  const SizedBox(height: 8),
                  _buildProjectionRow('Expected Variable Spend', '-₹${FormatUtils.formatCurrency(cashFlow.expectedVariableNext30)}', BentoTheme.textSecondary),
                  const Divider(height: 20, color: Colors.white12),
                  _buildProjectionRow(
                    'Projected Net Buffer',
                    '₹${FormatUtils.formatCurrency(cashFlow.remainingNext30)}',
                    cashFlow.remainingNext30 >= 0 ? ExpressiveTokens.semanticSuccess : ExpressiveTokens.semanticError,
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Top Merchants
            if (cashFlow.merchantBreakdown.isNotEmpty) ...[
              Text(
                'Top Spending Merchants',
                style: BentoTheme.titleSmall.copyWith(color: BentoTheme.textPrimary),
              ),
              const SizedBox(height: 12),
              ...cashFlow.merchantBreakdown.entries.take(5).map((e) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: BentoTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.store, size: 16, color: BentoTheme.textSecondary),
                          const SizedBox(width: 10),
                          Text(e.key, style: BentoTheme.bodyMedium.copyWith(color: BentoTheme.textPrimary)),
                        ],
                      ),
                      Text(
                        '₹${FormatUtils.formatCurrency(e.value)}',
                        style: BentoTheme.bodyMedium.copyWith(
                          color: BentoTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],

            // Category Breakdown
            if (cashFlow.categoryBreakdown.isNotEmpty) ...[
              Text(
                'Spending by Category',
                style: BentoTheme.titleSmall.copyWith(color: BentoTheme.textPrimary),
              ),
              const SizedBox(height: 12),
              ...cashFlow.categoryBreakdown.entries.map((e) {
                final cat = _controller.getCategory(e.key);
                final catName = cat?.name ?? e.key;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: BentoTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(catName, style: BentoTheme.bodyMedium.copyWith(color: BentoTheme.textPrimary)),
                      Text(
                        '₹${FormatUtils.formatCurrency(e.value)}',
                        style: BentoTheme.bodyMedium.copyWith(
                          color: BentoTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title, style: BentoTheme.bodySmall.copyWith(color: BentoTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₹${FormatUtils.formatCurrency(amount)}',
            style: BentoTheme.titleMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectionRow(String label, String value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: BentoTheme.bodySmall.copyWith(
            color: BentoTheme.textSecondary,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: BentoTheme.bodyMedium.copyWith(
            color: color,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
