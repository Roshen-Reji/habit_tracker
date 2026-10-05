import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/engine/report_engine.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> with SingleTickerProviderStateMixin {
  final FinanceController _controller = FinanceController();
  late TabController _tabController;

  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _trendMonths = 6;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  Future<void> _exportCsvDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: BentoTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Export Financial Data (CSV)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold).copyWith(color: BentoTheme.textPrimary),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(LucideIcons.fileSpreadsheet, color: BentoTheme.accent),
                  title: const Text('Export All Transactions', style: TextStyle(color: Colors.white)),
                  subtitle: Text('${_controller.allTransactions.length} records with accounts & categories', style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _doExport(
                      filename: 'transactions_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
                      content: _controller.exportTransactionsToCsv(),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.calendar, color: Colors.green),
                  title: const Text('Export 12-Month Summary', style: TextStyle(color: Colors.white)),
                  subtitle: Text('Income, spending, savings & net worth changes', style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _doExport(
                      filename: 'monthly_summary_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
                      content: _controller.exportMonthlyReportToCsv(monthsBack: 12),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.pieChart, color: Color(0xFFF59E0B)),
                  title: Text('Export ${DateFormat('MMM yyyy').format(_currentMonth)} Categories', style: const TextStyle(color: Colors.white)),
                  subtitle: Text('Category spending breakdown & deltas', style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _doExport(
                      filename: 'category_report_${DateFormat('yyyyMM').format(_currentMonth)}.csv',
                      content: _controller.exportCategoryReportToCsv(_currentMonth),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _doExport({required String filename, required String content}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${dir.path}/exports');
      if (!exportDir.existsSync()) {
        exportDir.createSync(recursive: true);
      }
      final file = File('${exportDir.path}/$filename');
      await file.writeAsString(content);

      // Also copy to clipboard for convenience
      await Clipboard.setData(ClipboardData(text: content));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to ${file.path}\nCopied CSV to clipboard!'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthStr = DateFormat('MMMM yyyy').format(_currentMonth);

    return Scaffold(
      backgroundColor: BentoTheme.background,
      appBar: AppBar(
        title: const Text('Financial Reports', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: BentoTheme.surface,
        foregroundColor: BentoTheme.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(LucideIcons.download, color: BentoTheme.accent),
            tooltip: 'Export CSV',
            onPressed: _exportCsvDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: BentoTheme.accent,
          labelColor: BentoTheme.accent,
          unselectedLabelColor: BentoTheme.textSecondary,
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'Categories'),
            Tab(text: 'Merchants'),
            Tab(text: 'Comparison'),
            Tab(text: 'Trends'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Month navigation bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: BentoTheme.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(LucideIcons.chevronLeft, color: BentoTheme.textPrimary, size: 20),
                  onPressed: _prevMonth,
                ),
                Text(
                  monthStr,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold).copyWith(
                    color: BentoTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(LucideIcons.chevronRight, color: BentoTheme.textPrimary, size: 20),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryTab(),
                _buildCategoriesTab(),
                _buildMerchantsTab(),
                _buildComparisonTab(),
                _buildTrendsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1. Monthly Summary Tab
  Widget _buildSummaryTab() {
    final rep = _controller.getMonthlySummaryReport(_currentMonth);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Key metrics grid
          Row(
            children: [
              Expanded(child: _metricCard('Income', rep.income, Colors.green, LucideIcons.arrowDownLeft)),
              const SizedBox(width: 12),
              Expanded(child: _metricCard('Spending', rep.spending, Colors.red, LucideIcons.arrowUpRight)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _metricCard('Net Cash Flow', rep.net, rep.net >= 0 ? BentoTheme.accent : Colors.red, LucideIcons.wallet)),
              const SizedBox(width: 12),
              Expanded(child: _metricCard('Total Saved & Invested', rep.saved, const Color(0xFFF59E0B), LucideIcons.piggyBank)),
            ],
          ),
          const SizedBox(height: 16),

          // Net worth change card
          Container(
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Net Worth Delta', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold).copyWith(color: BentoTheme.textPrimary)),
                    Text(
                      '${rep.netWorthChange >= 0 ? '+' : ''}${FormatUtils.formatCurrency(rep.netWorthChange)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold).copyWith(
                        color: rep.netWorthChange >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _rowText('Starting Net Worth', '${FormatUtils.formatCurrency(rep.netWorthStart)}'),
                const SizedBox(height: 6),
                _rowText('Ending Net Worth', '${FormatUtils.formatCurrency(rep.netWorthEnd)}'),
                const SizedBox(height: 6),
                _rowText('Savings Rate', '${(rep.savingsRate * 100).toStringAsFixed(1)}%'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Categories Breakdown Tab
  Widget _buildCategoriesTab() {
    final items = _controller.getCategoryReport(_currentMonth);

    if (items.isEmpty) {
      return Center(
        child: Text('No spending recorded for this month', style: const TextStyle(fontSize: 12).copyWith(color: BentoTheme.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        final isUp = item.changePct > 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.categoryName,
                    style: const TextStyle(fontSize: 14).copyWith(
                      color: BentoTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${FormatUtils.formatCurrency(item.amount)}',
                    style: const TextStyle(fontSize: 14).copyWith(
                      color: BentoTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${item.percentage.toStringAsFixed(1)}% of total',
                    style: const TextStyle(fontSize: 12).copyWith(color: BentoTheme.textSecondary),
                  ),
                  if (item.lastMonthAmount > 0)
                    Text(
                      '${isUp ? '+' : ''}${item.changePct.toStringAsFixed(1)}% vs last mo',
                      style: TextStyle(
                        fontSize: 11,
                        color: isUp ? Colors.orange : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 3. Merchants Tab
  Widget _buildMerchantsTab() {
    final items = _controller.getMerchantReport(_currentMonth);

    if (items.isEmpty) {
      return Center(
        child: Text('No merchant records for this month', style: const TextStyle(fontSize: 12).copyWith(color: BentoTheme.textSecondary)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.merchant,
                    style: const TextStyle(fontSize: 14).copyWith(
                      color: BentoTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.transactionCount} txn${item.transactionCount > 1 ? 's' : ''} · Avg ${FormatUtils.formatMoney(item.avgAmount, decimals: 0)}',
                    style: const TextStyle(fontSize: 12).copyWith(color: BentoTheme.textSecondary),
                  ),
                ],
              ),
              Text(
                '${FormatUtils.formatCurrency(item.totalSpent)}',
                style: const TextStyle(fontSize: 14).copyWith(
                  color: BentoTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 4. Month Comparison Tab
  Widget _buildComparisonTab() {
    final prevMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    final comp = _controller.compareMonths(prevMonth, _currentMonth);

    final m1Label = DateFormat('MMM yy').format(prevMonth);
    final m2Label = DateFormat('MMM yy').format(_currentMonth);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Metric', style: TextStyle(color: BentoTheme.textSecondary, fontWeight: FontWeight.bold)),
                    Text(m1Label, style: TextStyle(color: BentoTheme.textSecondary, fontWeight: FontWeight.bold)),
                    Text(m2Label, style: TextStyle(color: BentoTheme.accent, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 20, color: Colors.white12),
                _compRow('Income', comp.month1Income, comp.month2Income),
                const SizedBox(height: 8),
                _compRow('Spending', comp.month1Spending, comp.month2Spending, isExpense: true),
                const SizedBox(height: 8),
                _compRow('Net', comp.month1Net, comp.month2Net),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text('Category Deltas', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold).copyWith(color: BentoTheme.textPrimary)),
          const SizedBox(height: 12),

          ...comp.categoryComparisons.map((c) {
            final isIncrease = c.difference > 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(c.categoryName, style: const TextStyle(fontSize: 14).copyWith(color: BentoTheme.textPrimary)),
                  Row(
                    children: [
                      Text('${FormatUtils.formatCurrency(c.month2Amount)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text(
                        '${isIncrease ? '+' : ''}${FormatUtils.formatMoney(c.difference, decimals: 0)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isIncrease ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // 5. Multi-Month Trends Tab
  Widget _buildTrendsTab() {
    final points = _controller.getTrendReport(_trendMonths, currentMonth: _currentMonth);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _trendChip(3),
              const SizedBox(width: 6),
              _trendChip(6),
              const SizedBox(width: 6),
              _trendChip(12),
            ],
          ),
          const SizedBox(height: 12),

          ...points.reversed.map((p) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold).copyWith(color: BentoTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text(
                        'In: ${FormatUtils.formatMoney(p.income, decimals: 0)} · Out: ${FormatUtils.formatMoney(p.spending, decimals: 0)}',
                        style: const TextStyle(fontSize: 12).copyWith(color: BentoTheme.textSecondary),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'NW: ${FormatUtils.formatMoney(p.netWorth, decimals: 0)}',
                        style: const TextStyle(fontSize: 14).copyWith(color: BentoTheme.accent, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Net: ${p.net >= 0 ? '+' : ''}${FormatUtils.formatMoney(p.net, decimals: 0)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: p.net >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _metricCard(String title, double amount, Color color, IconData icon) {
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
              Text(title, style: const TextStyle(fontSize: 12).copyWith(color: BentoTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${FormatUtils.formatCurrency(amount)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold).copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _rowText(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12).copyWith(color: BentoTheme.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 12).copyWith(color: BentoTheme.textPrimary, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _compRow(String title, double val1, double val2, {bool isExpense = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        Text('${FormatUtils.formatMoney(val1, decimals: 0)}', style: TextStyle(color: BentoTheme.textSecondary)),
        Text('${FormatUtils.formatMoney(val2, decimals: 0)}', style: TextStyle(color: isExpense ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _trendChip(int months) {
    final isSelected = _trendMonths == months;
    return ChoiceChip(
      label: Text('$months Mo'),
      selected: isSelected,
      onSelected: (_) => setState(() => _trendMonths = months),
      backgroundColor: BentoTheme.surface,
      selectedColor: BentoTheme.accent.withValues(alpha: 0.2),
      labelStyle: const TextStyle(fontSize: 12).copyWith(
        color: isSelected ? BentoTheme.accent : BentoTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
