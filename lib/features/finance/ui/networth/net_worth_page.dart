import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/engine/ledger.dart';
import 'package:habit_tracker/features/finance/ui/accounts/accounts_page.dart';
import 'package:habit_tracker/features/finance/ui/widgets/charts/category_donut_chart.dart';
import 'package:habit_tracker/features/finance/ui/widgets/charts/net_worth_history_chart.dart';

/// Full-screen Net Worth dashboard showing historical trend, asset and liability
/// breakdowns, receivables/payables line, and composition.
class NetWorthPage extends StatefulWidget {
  final FinanceController? controller;

  const NetWorthPage({super.key, this.controller});

  @override
  State<NetWorthPage> createState() => _NetWorthPageState();
}

class _NetWorthPageState extends State<NetWorthPage> {
  late final FinanceController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? FinanceController();
    _controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final netWorth = _controller.getNetWorth();
    final changeAmt = _controller.getNetWorthChangeVsLastMonth();
    final changePct = _controller.getNetWorthChangePercentVsLastMonth();
    final history = _controller.getNetWorthHistory(months: 12);

    final totalAssets = _controller.totalAssets;
    final totalLiabilities = _controller.totalLiabilities;

    // Receivables from split transactions
    final receivables = LedgerEngine.receivablesFromSplits(
      _controller.storage.transactionBox.values,
    );

    final assetAccounts = _controller.assetAccounts;
    final liabilityAccounts = _controller.liabilityAccounts;

    // Build data for composition chart
    final compositionData = <Map<String, dynamic>>[];
    for (final acc in assetAccounts) {
      final bal = _controller.getAccountBalance(acc);
      if (bal > 0) {
        compositionData.add({
          'name': acc.name,
          'value': bal,
          'color': Color(acc.colorValue),
        });
      }
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Net Worth'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_outlined),
            tooltip: 'Manage Accounts',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => AccountsPage(controller: _controller),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Net Worth Hero Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: BentoTheme.cardBackground,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL NET WORTH',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: BentoTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    FormatUtils.formatMoney(netWorth),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (changeAmt >= 0 ? Colors.green : Colors.red)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              changeAmt >= 0
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 14,
                              color: changeAmt >= 0
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${changeAmt >= 0 ? '+' : ''}${FormatUtils.formatMoney(changeAmt)} (${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(1)}%)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: changeAmt >= 0
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'vs last month',
                        style: TextStyle(
                            color: BentoTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 12-Month Net Worth History Chart
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: BentoTheme.cardBackground,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '12-Month History',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Month-ends',
                        style: TextStyle(
                            color: BentoTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  NetWorthHistoryChart(
                    points: history,
                    height: 180,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Receivables & Payables Banner (Invariant I2)
            if (receivables > 0) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.blue.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.handshake_outlined,
                        color: Colors.blueAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Unsettled Receivables',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                          Text(
                            'Money owed to you from split expenses',
                            style: TextStyle(
                                color: BentoTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '+${FormatUtils.formatMoney(receivables)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Asset Composition Donut Chart
            if (compositionData.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: BentoTheme.cardBackground,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asset Composition',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: CategoryDonutChart(
                        items: compositionData,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Assets Breakdown List
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: BentoTheme.cardBackground,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Assets (${assetAccounts.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        FormatUtils.formatMoney(totalAssets),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  if (assetAccounts.isEmpty)
                    Text(
                      'No asset accounts added yet.',
                      style:
                          TextStyle(color: BentoTheme.textMuted, fontSize: 12),
                    )
                  else
                    ...assetAccounts.map((acc) {
                      final bal = _controller.getAccountBalance(acc);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 6,
                              backgroundColor: Color(acc.colorValue),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                acc.name,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Text(
                              FormatUtils.formatMoney(bal),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Liabilities Breakdown List
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: BentoTheme.cardBackground,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Liabilities (${liabilityAccounts.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        FormatUtils.formatMoney(totalLiabilities),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.orangeAccent,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  if (liabilityAccounts.isEmpty)
                    Text(
                      'No liabilities or debt accounts recorded.',
                      style:
                          TextStyle(color: BentoTheme.textMuted, fontSize: 12),
                    )
                  else
                    ...liabilityAccounts.map((acc) {
                      final bal = _controller.getAccountBalance(acc);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 6,
                              backgroundColor: Color(acc.colorValue),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                acc.name,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Text(
                              FormatUtils.formatMoney(bal.abs()),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.orangeAccent,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
