import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/engine/forecast_engine.dart';
import 'package:habit_tracker/features/finance/engine/health_score_engine.dart';
import 'package:habit_tracker/features/finance/engine/insights_engine.dart';
import 'package:habit_tracker/features/finance/ui/health/health_score_sheet.dart';
import 'package:habit_tracker/features/finance/ui/overview/safe_to_spend_breakdown_sheet.dart';
import 'package:habit_tracker/features/finance/ui/transactions/transaction_sheet.dart';
import 'package:habit_tracker/features/finance/ui/what_if/what_if_sheet.dart';
import 'package:habit_tracker/features/finance/ui/widgets/charts/cash_flow_chart.dart';
import 'package:habit_tracker/features/finance/ui/widgets/charts/category_donut_chart.dart';
import 'package:habit_tracker/features/finance/ui/ai/ai_privacy_page.dart';
import 'package:habit_tracker/features/finance/ui/overview/balance_audit_screen.dart';
import 'package:habit_tracker/features/finance/ui/widgets/charts/net_trend_chart.dart';
import 'package:habit_tracker/features/finance/engine/recurring_engine.dart';
import 'package:habit_tracker/features/finance/ui/accounts/account_detail_page.dart';
import 'package:habit_tracker/features/finance/ui/accounts/accounts_page.dart';

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
        'color':
            cat != null && cat.colorValue != 0 ? Color(cat.colorValue) : null,
      };
    }).toList();
  }

  /// Determines the month type relative to the real current month.
  /// Returns: 'current', 'past', or 'future'.
  String get _monthType {
    final now = DateTime.now();
    final nowMonth = DateTime(now.year, now.month);
    if (_currentMonth.year == nowMonth.year &&
        _currentMonth.month == nowMonth.month) {
      return 'current';
    }
    return _currentMonth.isBefore(nowMonth) ? 'past' : 'future';
  }

  @override
  Widget build(BuildContext context) {
    final monthIncome = _controller.getMonthIncome(_currentMonth);
    final monthSpending = _controller.getMonthSpending(_currentMonth);
    final monthNet = monthIncome - monthSpending;
    final savingsRate =
        monthIncome > 0 ? (monthNet / monthIncome).clamp(0.0, 1.0) : 0.0;

    // P1-1: Fix Safe to Spend clock.
    final now = DateTime.now();
    final isCurrent = _monthType == 'current';
    SafeToSpendResult? safeToSpend;
    if (isCurrent) {
      safeToSpend = _controller.getSafeToSpend(asOf: now);
    }
    final healthScore =
        _controller.getHealthScore(asOf: isCurrent ? now : _currentMonth);
    final insights =
        _controller.getInsights(asOf: isCurrent ? now : _currentMonth);

    final moneyLeft = _controller.getLiquidBalance();
    final lastDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0, 23, 59, 59);
    final closingBalance = _controller.getLiquidBalance(asOf: lastDayOfMonth);

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

              // P1-1 / P1-3: Hero Money Left Card
              _buildMoneyLeftHeroCard(
                moneyLeft: moneyLeft,
                safeToSpend: safeToSpend,
                isCurrent: isCurrent,
                monthIncome: monthIncome,
                monthSpending: monthSpending,
                monthNet: monthNet,
                savingsRate: savingsRate,
                closingBalance: closingBalance,
              ),
              const SizedBox(height: 12),

              // P2-4: Investments Card
              _buildInvestmentsCard(),

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
              const SizedBox(height: 100),
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
        Row(
          children: [
            IconButton(
              icon: Icon(LucideIcons.chevronLeft,
                  color: BentoTheme.textSecondary, size: 20),
              onPressed: _prevMonth,
              visualDensity: VisualDensity.compact,
            ),
            GestureDetector(
              onLongPress: (kDebugMode || kProfileMode)
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BalanceAuditScreen(),
                        ),
                      )
                  : null,
              child: Text(
                DateFormat('MMMM yyyy').format(_currentMonth).toUpperCase(),
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            IconButton(
              icon: Icon(LucideIcons.chevronRight,
                  color: BentoTheme.textSecondary, size: 20),
              onPressed: _nextMonth,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        IconButton(
          icon: Icon(LucideIcons.shieldCheck,
              color: BentoTheme.textSecondary, size: 18),
          tooltip: 'AI & Privacy',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AiPrivacyPage()),
          ),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  /// P1-1 / P1-3: Combined hero card — headline is Money Left (as of now, signed),
  /// secondary section is Safe to Spend (current month) or Month Review (other months).
  Widget _buildMoneyLeftHeroCard({
    required double moneyLeft,
    required SafeToSpendResult? safeToSpend,
    required bool isCurrent,
    required double monthIncome,
    required double monthSpending,
    required double monthNet,
    required double savingsRate,
    required double closingBalance,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "MONEY LEFT" headline, tappable to SafeToSpendBreakdownSheet
          GestureDetector(
            onTap: () {
              final explanation = _controller.getSafeToSpendExplanation(
                asOf: isCurrent ? null : _currentMonth,
              );
              SafeToSpendBreakdownSheet.show(context, explanation);
            },
            child: Row(
              children: [
                Text(
                  'MONEY LEFT',
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
                const Spacer(),
                Text(
                  'Why this number?',
                  style: TextStyle(
                    color: BentoTheme.accent.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Headline: Money Left across all spendable accounts
          Text(
            FormatUtils.formatMoney(moneyLeft),
            style: TextStyle(
              color: moneyLeft < 0
                  ? const Color(0xFFE07A7A)
                  : BentoTheme.textPrimary,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          // Savings rate bar
          ProgressBarX(
            height: 7,
            value: savingsRate,
            customColor: savingsRate >= 0.2
                ? const Color(0xFF22C55E)
                : const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Savings Rate (${DateFormat('MMM yyyy').format(_currentMonth)})',
                style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
              ),
              Text(
                '${(savingsRate * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: savingsRate >= 0.2
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFF59E0B),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Divider before Safe to Spend / Month Review section
          Divider(
            color: Colors.white.withValues(alpha: 0.06),
            height: 1,
          ),
          const SizedBox(height: 14),
          // Secondary line: Safe to Spend for current month, or Month Review for other months
          if (isCurrent)
            _buildSafeToSpendSection(safeToSpend)
          else
            _buildMonthReviewSection(
              income: monthIncome,
              spending: monthSpending,
              net: monthNet,
              closingBalance: closingBalance,
            ),
        ],
      ),
    );
  }

  /// P1-1 / P1-3: Safe to Spend section inside the hero card.
  Widget _buildSafeToSpendSection(SafeToSpendResult? s) {
    if (s == null) {
      return Row(
        children: [
          Icon(LucideIcons.shieldCheck,
              size: 14, color: BentoTheme.textSecondary),
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
          const SizedBox(width: 12),
          Text(
            '—',
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    final hasShortfall = s.hasShortfall;
    final displayValue = hasShortfall
        ? FormatUtils.formatMoney(s.raw)
        : FormatUtils.formatMoney(s.safeToSpend);
    final valueColor =
        hasShortfall ? const Color(0xFFE07A7A) : BentoTheme.textPrimary;

    return GestureDetector(
      onTap: () {
        final explanation = _controller.getSafeToSpendExplanation();
        SafeToSpendBreakdownSheet.show(context, explanation);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                hasShortfall
                    ? LucideIcons.alertTriangle
                    : LucideIcons.shieldCheck,
                size: 14,
                color:
                    hasShortfall ? const Color(0xFFE07A7A) : BentoTheme.accent,
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
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayValue,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!hasShortfall)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: BentoTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${FormatUtils.formatMoney(s.perDay)}/day',
                    style: TextStyle(
                      color: BentoTheme.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
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
          if (hasShortfall) ...[
            const SizedBox(height: 4),
            Text(
              'Short by ${FormatUtils.formatMoney(s.shortfall)} until month end',
              style: const TextStyle(
                color: Color(0xFFE07A7A),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// P1-1: Month review section shown for non-current months.
  Widget _buildMonthReviewSection({
    required double income,
    required double spending,
    required double net,
    required double closingBalance,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.calendarCheck,
                size: 14, color: BentoTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              'MONTH REVIEW · ${DateFormat('MMM yyyy').format(_currentMonth).toUpperCase()}',
              style: TextStyle(
                color: BentoTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildReviewStat('Income', FormatUtils.formatMoney(income),
                const Color(0xFF22C55E)),
            _buildReviewStat('Spending', FormatUtils.formatMoney(spending),
                BentoTheme.textPrimary),
            _buildReviewStat(
              'Net',
              (net >= 0 ? '+' : '') + FormatUtils.formatMoney(net),
              net >= 0 ? const Color(0xFF22C55E) : const Color(0xFFE07A7A),
            ),
            _buildReviewStat(
                'Closing Bal',
                FormatUtils.formatMoney(closingBalance),
                BentoTheme.textSecondary),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: BentoTheme.textSecondary, fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  /// P2-4: Investments card between the hero card and health score row.
  Widget _buildInvestmentsCard() {
    final funds = _controller.activeAccounts
        .where((a) => a.kind == 'investment' || a.isValuedAsset)
        .toList();
    if (funds.isEmpty) return const SizedBox.shrink();

    double totalDeposited = 0.0;
    double totalCurrentValue = 0.0;
    for (final f in funds) {
      totalDeposited += _controller.getInvestedAmount(f);
      totalCurrentValue += _controller.getAccountBalance(f);
    }
    final totalGainLoss = totalCurrentValue - totalDeposited;
    final totalReturnPct =
        totalDeposited > 0 ? (totalGainLoss / totalDeposited) * 100 : 0.0;

    final now = DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BentoTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
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
                    LucideIcons.trendingUp,
                    size: 16,
                    color: BentoTheme.accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'INVESTMENTS',
                    style: TextStyle(
                      color: BentoTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AccountsPage(controller: _controller),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See all',
                      style: TextStyle(
                        color: BentoTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 14,
                      color: BentoTheme.accent,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Summary Metrics
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deposited',
                      style: TextStyle(
                        color: BentoTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      FormatUtils.formatMoney(totalDeposited),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Value',
                      style: TextStyle(
                        color: BentoTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      FormatUtils.formatMoney(totalCurrentValue),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Gain / Loss',
                      style: TextStyle(
                        color: BentoTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${totalGainLoss >= 0 ? '+' : ''}${FormatUtils.formatMoney(totalGainLoss)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: totalGainLoss >= 0
                            ? Colors.greenAccent
                            : Colors.redAccent,
                      ),
                    ),
                    Text(
                      '(${totalReturnPct >= 0 ? '+' : ''}${totalReturnPct.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: totalGainLoss >= 0
                            ? Colors.greenAccent
                            : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 10),
          // Fund rows (up to 4)
          ...funds.take(4).map((fund) {
            final deposited = _controller.getInvestedAmount(fund);
            final currentVal = _controller.getAccountBalance(fund);

            final sipRule = _controller.allRecurringRules
                .where((r) =>
                    r.status == 'active' &&
                    (r.kind == 'sip' || r.kind == 'investment') &&
                    r.toAccountId == fund.id)
                .firstOrNull;

            String? sipInfo;
            if (sipRule != null) {
              final occs = RecurringEngine.occurrences(
                  sipRule, now, now.add(const Duration(days: 60)));
              if (occs.isNotEmpty) {
                sipInfo =
                    'Next SIP: ${DateFormat('d MMM').format(occs.first)} · ${FormatUtils.formatMoney(sipRule.amount)}';
              } else {
                sipInfo = 'SIP: ${FormatUtils.formatMoney(sipRule.amount)}';
              }
            }

            return InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AccountDetailPage(accountId: fund.id),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          Color(fund.colorValue).withValues(alpha: 0.15),
                      child: Icon(
                        LucideIcons.trendingUp,
                        size: 16,
                        color: Color(fund.colorValue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fund.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (sipInfo != null)
                            Text(
                              sipInfo,
                              style: TextStyle(
                                fontSize: 11,
                                color: BentoTheme.textMuted,
                              ),
                            )
                          else
                            Text(
                              'Deposited: ${FormatUtils.formatMoney(deposited)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: BentoTheme.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          FormatUtils.formatMoney(currentVal),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (sipInfo != null)
                          Text(
                            'Dep: ${FormatUtils.formatMoney(deposited)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: BentoTheme.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHealthAndWhatIfRow(HealthScoreResult health) {
    Color scoreColor;
    if (health.overallScore >= 80) {
      scoreColor = Colors.green;
    } else if (health.overallScore >= 50) {
      scoreColor = BentoTheme.accent;
    } else {
      scoreColor = Colors.orange;
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
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(LucideIcons.heartPulse,
                          color: scoreColor, size: 16),
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
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: BentoTheme.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(LucideIcons.sparkles,
                          color: BentoTheme.accent, size: 16),
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
        iconColor = Colors.red;
        icon = LucideIcons.alertOctagon;
        break;
      case InsightSeverity.warning:
        iconColor = Colors.orange;
        icon = LucideIcons.alertTriangle;
        break;
      case InsightSeverity.success:
        iconColor = Colors.green;
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
          color: isSelected
              ? BentoTheme.accent.withValues(alpha: 0.2)
              : Colors.transparent,
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
                      backgroundColor:
                          (category != null && category.colorValue != 0
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
                        color: isIncome
                            ? const Color(0xFF22C55E)
                            : BentoTheme.textPrimary,
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
