import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/engine/forecast_engine.dart';
import 'package:habit_tracker/features/finance/engine/health_score_engine.dart';
import 'package:habit_tracker/features/finance/engine/insights_engine.dart';
import 'package:habit_tracker/features/finance/ui/cashflow/cash_flow_page.dart';
import 'package:habit_tracker/features/finance/ui/health/health_score_sheet.dart';
import 'package:habit_tracker/features/finance/ui/insights/insights_page.dart';
import 'package:habit_tracker/features/finance/ui/transactions/transaction_sheet.dart';
import 'package:habit_tracker/features/finance/ui/what_if/what_if_sheet.dart';
import 'package:habit_tracker/features/finance/ui/widgets/charts/cash_flow_chart.dart';
import 'package:habit_tracker/features/finance/ui/widgets/charts/category_donut_chart.dart';
import 'package:habit_tracker/features/finance/ui/widgets/charts/net_trend_chart.dart';

class MoneyOverviewTab extends StatefulWidget {
  final VoidCallback onSeeAllTransactions;

  const MoneyOverviewTab({super.key, required this.onSeeAllTransactions});

  @override
  State<MoneyOverviewTab> createState() => _MoneyOverviewTabState();
}

class _MoneyOverviewTabState extends State<MoneyOverviewTab> {
  final FinanceController _controller = FinanceController();
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _chartMode = 'flow'; // 'flow', 'net', 'categories'

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

  List<Map<String, dynamic>> _buildTrendData() {
    final list = <Map<String, dynamic>>[];
    for (var i = 4; i >= 0; i--) {
      final m = DateTime(_currentMonth.year, _currentMonth.month - i);
      final inc = _controller.getMonthIncome(m);
      final exp = _controller.getMonthSpending(m);
      list.add({
        'month': DateFormat('MMM').format(m),
        'income': inc,
        'expense': exp,
      });
    }
    return list;
  }

  List<Map<String, dynamic>> _buildCategoryDonutItems() {
    final breakdown = _controller.getCategoryBreakdown(_currentMonth);
    return breakdown.entries.map((e) {
      final cat = _controller.getCategory(e.key);
      return {
        'name': cat?.name ?? e.key,
        'value': e.value,
        'color': cat != null && cat.colorValue != 0 ? Color(cat.colorValue) : null,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final netWorth = _controller.getNetWorth();
    final liquid = _controller.getLiquidBalance();
    final monthIncome = _controller.getMonthIncome(_currentMonth);
    final monthSpending = _controller.getMonthSpending(_currentMonth);
    final monthNet = monthIncome - monthSpending;
    final savingsRate = monthIncome > 0 ? (monthNet / monthIncome).clamp(0.0, 1.0) : 0.0;

    final safeToSpend = _controller.getSafeToSpend(asOf: _currentMonth);
    final healthScore = _controller.getHealthScore(asOf: _currentMonth);
    final insights = _controller.getInsights(asOf: _currentMonth);

    final recentTransactions = _controller.allTransactions.take(5).toList();
    final trendData = _buildTrendData();
    final categoryDonutItems = _buildCategoryDonutItems();

    return Scaffold(
      backgroundColor: BentoTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month selector bar
              _buildMonthBar(),
              const SizedBox(height: 12),

              // Safe to Spend Hero Card
              _buildSafeToSpendCard(safeToSpend),
              const SizedBox(height: 12),

              // Hero Balance Card (Net Worth & Liquid)
              _buildHeroBalanceCard(netWorth, liquid, savingsRate),
              const SizedBox(height: 12),

              // Health Score & What-If Row
              _buildHealthAndWhatIfRow(healthScore),
              const SizedBox(height: 12),

              // Top Insights Banner
              if (insights.isNotEmpty) ...[
                _buildInsightsBanner(insights),
                const SizedBox(height: 12),
              ],

              // Metric Cards Row: Income, Expenses, Saved
              _buildMetricCards(monthIncome, monthSpending, monthNet),
              const SizedBox(height: 16),

              // Quick Actions
              _buildQuickActionsRow(),
              const SizedBox(height: 20),

              // Visual Analytics Card
              _buildChartCard(trendData, categoryDonutItems),
              const SizedBox(height: 20),

              // Recent Transactions Header & List
              _buildRecentTransactionsSection(recentTransactions),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: BentoTheme.textSecondary, size: 20),
          onPressed: _prevMonth,
          visualDensity: VisualDensity.compact,
        ),
        Text(
          DateFormat('MMMM yyyy').format(_currentMonth).toUpperCase(),
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        IconButton(
          icon: Icon(LucideIcons.chevronRight, color: BentoTheme.textSecondary, size: 20),
          onPressed: _nextMonth,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildHeroBalanceCard(double netWorth, double liquid, double savingsRate) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: ExpressiveTokens.borderL,
        onTap: () => AppNav.openNetWorth(context),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: ExpressiveTokens.borderL,
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'NET WORTH',
                        style: TextStyle(
                          color: BentoTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 14,
                        color: BentoTheme.textSecondary,
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: BentoTheme.cardBackground,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Liquid: ${FormatUtils.formatCurrency(liquid)}',
                      style: TextStyle(
                        color: BentoTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                FormatUtils.formatCurrency(netWorth),
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: savingsRate,
                  color: savingsRate >= 0.2
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFF59E0B),
                  backgroundColor: BentoTheme.textSecondary.withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Savings Rate',
                    style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                  ),
                  Text(
                    '${(savingsRate * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: savingsRate >= 0.2 ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafeToSpendCard(SafeToSpendResult s) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderL,
        border: Border.all(
          color: s.hasShortfall
              ? ExpressiveTokens.semanticError.withValues(alpha: 0.3)
              : BentoTheme.accent.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    s.hasShortfall ? LucideIcons.alertTriangle : LucideIcons.shieldCheck,
                    size: 16,
                    color: s.hasShortfall ? ExpressiveTokens.semanticError : BentoTheme.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SAFE TO SPEND',
                    style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (s.hasShortfall ? ExpressiveTokens.semanticError : BentoTheme.accent)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  s.hasShortfall
                      ? 'Deficit: ₹${FormatUtils.formatCurrency(s.shortfall, decimals: 0)}'
                      : '₹${FormatUtils.formatCurrency(s.perDay, decimals: 0)} / day',
                  style: TextStyle(
                    color: s.hasShortfall ? ExpressiveTokens.semanticError : BentoTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.hasShortfall
                ? '₹0'
                : '₹${FormatUtils.formatCurrency(s.safeToSpend, decimals: 0)}',
            style: TextStyle(
              color: s.hasShortfall ? ExpressiveTokens.semanticError : BentoTheme.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.hasShortfall
                ? 'Projected obligations exceed liquid balance by month-end'
                : 'Available for discretionary spending over the next ${s.daysLeft} days',
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _safeToSpendChip('Liquid', s.liquid, ExpressiveTokens.semanticSuccess),
                const SizedBox(width: 6),
                _safeToSpendChip('Bills', -s.obligations, ExpressiveTokens.semanticError),
                const SizedBox(width: 6),
                _safeToSpendChip('Goals', -s.goalsEarmark, const Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                _safeToSpendChip('Essential', -s.plannedEssential, BentoTheme.textSecondary),
                if (s.cardDues > 0) ...[
                  const SizedBox(width: 6),
                  _safeToSpendChip('Cards', -s.cardDues, ExpressiveTokens.semanticError),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _safeToSpendChip(String label, double val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BentoTheme.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Text(
        '$label: ${val >= 0 ? '' : '-'}₹${FormatUtils.formatCurrency(val.abs(), decimals: 0)}',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildHealthAndWhatIfRow(HealthScoreResult health) {
    Color scoreColor;
    if (health.overallScore >= 80) {
      scoreColor = ExpressiveTokens.semanticSuccess;
    } else if (health.overallScore >= 50) {
      scoreColor = BentoTheme.accent;
    } else {
      scoreColor = ExpressiveTokens.semanticWarning;
    }

    return Row(
      children: [
        // Health Score Button
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => HealthScoreSheet.show(context),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BentoTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(LucideIcons.heartPulse, color: scoreColor, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HEALTH SCORE',
                            style: TextStyle(
                              color: BentoTheme.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${health.overallScore.toStringAsFixed(0)} / 100',
                            style: TextStyle(
                              color: scoreColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // What-If Simulator Button
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => WhatIfSheet.show(context),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BentoTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BentoTheme.accent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: BentoTheme.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(LucideIcons.sparkles, color: BentoTheme.accent, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WHAT-IF',
                            style: TextStyle(
                              color: BentoTheme.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Can I Afford?',
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightsBanner(List<FinanceInsight> insights) {
    final top = insights.first;
    Color iconColor;
    IconData icon;
    switch (top.severity) {
      case InsightSeverity.danger:
        iconColor = ExpressiveTokens.semanticError;
        icon = LucideIcons.alertOctagon;
        break;
      case InsightSeverity.warning:
        iconColor = ExpressiveTokens.semanticWarning;
        icon = LucideIcons.alertTriangle;
        break;
      case InsightSeverity.success:
        iconColor = ExpressiveTokens.semanticSuccess;
        icon = LucideIcons.trendingUp;
        break;
      case InsightSeverity.info:
        iconColor = BentoTheme.accent;
        icon = LucideIcons.info;
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => AppNav.openInsights(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: iconColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            top.title,
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${insights.length} insight${insights.length > 1 ? 's' : ''} →',
                          style: TextStyle(
                            color: BentoTheme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      top.body,
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 11,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCards(double income, double spending, double net) {
    return Row(
      children: [
        Expanded(
          child: _metricBox(
            title: 'INCOME',
            amount: income,
            color: const Color(0xFF22C55E),
            icon: LucideIcons.trendingUp,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricBox(
            title: 'SPENT',
            amount: spending,
            color: const Color(0xFFEF4444),
            icon: LucideIcons.trendingDown,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricBox(
            title: 'NET',
            amount: net,
            color: net >= 0 ? BentoTheme.accent : const Color(0xFFEF4444),
            icon: LucideIcons.wallet,
          ),
        ),
      ],
    );
  }

  Widget _metricBox({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderM,
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            FormatUtils.formatCurrency(amount.abs()),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow() {
    return Row(
      children: [
        _actionChip('Expense', LucideIcons.minus, () {
          TransactionSheet.show(context, initialKind: 'expense');
        }),
        const SizedBox(width: 6),
        _actionChip('Income', LucideIcons.plus, () {
          TransactionSheet.show(context, initialKind: 'income');
        }),
        const SizedBox(width: 6),
        _actionChip('Transfer', LucideIcons.arrowRightLeft, () {
          TransactionSheet.show(context, initialKind: 'transfer');
        }),
        const SizedBox(width: 6),
        _actionChip('Accounts', LucideIcons.landmark, () {
          AppNav.openAccounts(context);
        }),
      ],
    );
  }

  Widget _actionChip(String label, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: BentoTheme.accent),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard(
    List<Map<String, dynamic>> trendData,
    List<Map<String, dynamic>> categoryDonutItems,
  ) {
    Widget chartWidget;
    if (_chartMode == 'net') {
      chartWidget = NetTrendChart(data: trendData);
    } else if (_chartMode == 'categories') {
      chartWidget = categoryDonutItems.isEmpty
          ? Center(
              child: Text(
                'No category expenses this month',
                style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
              ),
            )
          : CategoryDonutChart(items: categoryDonutItems);
    } else {
      chartWidget = CashFlowChart(data: trendData);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderL,
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ANALYTICS',
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              Row(
                children: [
                  _modeButton('flow', 'Flow'),
                  const SizedBox(width: 4),
                  _modeButton('net', 'Net'),
                  const SizedBox(width: 4),
                  _modeButton('categories', 'Categories'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 200,
            child: chartWidget,
          ),
        ],
      ),
    );
  }

  Widget _modeButton(String modeKey, String label) {
    final isSelected = _chartMode == modeKey;
    return InkWell(
      onTap: () => setState(() => _chartMode = modeKey),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? BentoTheme.accent.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? BentoTheme.accent : BentoTheme.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsSection(List<dynamic> recent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RECENT TRANSACTIONS',
              style: TextStyle(
                color: BentoTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            TextButton(
              onPressed: widget.onSeeAllTransactions,
              child: Text(
                'See All',
                style: TextStyle(
                  color: BentoTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (recent.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: ExpressiveTokens.borderM,
            ),
            child: Text(
              'No transactions recorded yet',
              style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
            ),
          )
        else
          Column(
            children: recent.map((tx) {
              final isIncome = tx.effectiveKind == 'income' ||
                  tx.effectiveKind == 'refund' ||
                  tx.effectiveKind == 'reimbursement';
              final category = _controller.getCategory(tx.categoryId);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: BentoTheme.surface,
                  borderRadius: ExpressiveTokens.borderM,
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: ExpressiveTokens.borderM,
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: (category != null && category.colorValue != 0
                              ? Color(category.colorValue)
                              : BentoTheme.accent)
                          .withValues(alpha: 0.15),
                      child: Icon(
                        LucideIcons.tag,
                        size: 16,
                        color: category != null && category.colorValue != 0
                            ? Color(category.colorValue)
                            : BentoTheme.accent,
                      ),
                    ),
                    title: Text(
                      tx.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      category?.name ?? tx.category,
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    trailing: Text(
                      '${isIncome ? '+' : '-'}${FormatUtils.formatCurrency(tx.amount.abs())}',
                      style: TextStyle(
                        color: isIncome ? const Color(0xFF22C55E) : BentoTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () {
                      TransactionSheet.show(context, existingTransaction: tx);
                    },
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
