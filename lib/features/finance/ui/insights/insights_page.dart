import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/navigation/app_nav.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/engine/insights_engine.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  final FinanceController _controller = FinanceController();
  String _selectedFilter = 'all'; // 'all', 'warnings', 'spikes', 'trends'

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

  Future<void> _dismissInsight(FinanceInsight insight) async {
    HapticFeedback.lightImpact();
    await _controller.dismissInsight(insight.stableKey);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dismissed: ${insight.title}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleDeepLink(String? link) {
    if (link == null) return;
    AppNav.openMoney(context, deepLink: link);
  }

  @override
  Widget build(BuildContext context) {
    final allInsights = _controller.getInsights();

    final filteredInsights = allInsights.where((ins) {
      if (_selectedFilter == 'warnings') {
        return ins.severity == InsightSeverity.warning ||
            ins.severity == InsightSeverity.danger;
      }
      if (_selectedFilter == 'spikes') {
        return ins.kind == 'category_spike' || ins.kind == 'unusual_large_tx';
      }
      if (_selectedFilter == 'trends') {
        return ins.kind == 'net_worth_trend' ||
            ins.kind == 'savings_rate_trend' ||
            ins.kind == 'subscription_total';
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: BentoTheme.background,
      appBar: AppBar(
        title: const Text('Financial Insights',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: BentoTheme.surface,
        foregroundColor: BentoTheme.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: BentoTheme.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All (${allInsights.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip('warnings', 'Warnings'),
                  const SizedBox(width: 8),
                  _buildFilterChip('spikes', 'Spikes & Anomaly'),
                  const SizedBox(width: 8),
                  _buildFilterChip('trends', 'Trends'),
                ],
              ),
            ),
          ),

          Expanded(
            child: filteredInsights.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.checkCheck,
                            size: 48,
                            color: BentoTheme.textSecondary
                                .withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'All Clear!',
                          style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)
                              .copyWith(color: BentoTheme.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'No active alerts or unusual spending detected.',
                          style: const TextStyle(fontSize: 12)
                              .copyWith(color: BentoTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredInsights.length,
                    itemBuilder: (context, index) {
                      final item = filteredInsights[index];
                      return _buildInsightCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = key),
      backgroundColor: BentoTheme.background,
      selectedColor: BentoTheme.accent.withValues(alpha: 0.2),
      labelStyle: const TextStyle(fontSize: 12).copyWith(
        color: isSelected ? BentoTheme.accent : BentoTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? BentoTheme.accent
            : Colors.white.withValues(alpha: 0.05),
      ),
    );
  }

  Widget _buildInsightCard(FinanceInsight ins) {
    Color iconColor;
    IconData icon;
    switch (ins.severity) {
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

    return Dismissible(
      key: Key(ins.stableKey),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(LucideIcons.trash2, color: Colors.red),
      ),
      onDismissed: (_) => _dismissInsight(ins),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BentoTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: iconColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ins.title,
                    style: const TextStyle(fontSize: 14).copyWith(
                      color: BentoTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(LucideIcons.x,
                      size: 16, color: BentoTheme.textSecondary),
                  onPressed: () => _dismissInsight(ins),
                  tooltip: 'Dismiss',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ins.body,
              style: const TextStyle(fontSize: 12).copyWith(
                color: BentoTheme.textSecondary,
                height: 1.4,
              ),
            ),
            if (ins.deepLink != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _handleDeepLink(ins.deepLink),
                  icon: const Icon(LucideIcons.arrowUpRight, size: 14),
                  label: Text('Take Action',
                      style: const TextStyle(fontSize: 12)
                          .copyWith(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: BentoTheme.accent,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
