import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/engine/split_settle_engine.dart';
import 'package:habit_tracker/features/finance/models/split_entry.dart';
import 'package:habit_tracker/features/finance/models/split_group.dart';

class SplitGroupDetailPage extends StatefulWidget {
  final SplitGroup group;

  const SplitGroupDetailPage({super.key, required this.group});

  @override
  State<SplitGroupDetailPage> createState() => _SplitGroupDetailPageState();
}

class _SplitGroupDetailPageState extends State<SplitGroupDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FinanceController _controller = FinanceController();
  late final FinanceRepository _repository = _controller.repository;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

  void _openAddExpenseSheet() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String paidBy = widget.group.members.first;
    bool splitEqually = true;
    final customShares = <String, TextEditingController>{
      for (var m in widget.group.members) m: TextEditingController(),
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BentoTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add Split Expense',
                        style: TextStyle(color: BentoTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 20, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Title
                  TextField(
                    controller: titleController,
                    style: TextStyle(color: BentoTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'e.g. Dinner, Fuel, Hotel',
                      labelStyle: TextStyle(color: BentoTheme.textSecondary),
                      filled: true,
                      fillColor: BentoTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Amount
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: BentoTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Amount (₹)',
                      labelStyle: TextStyle(color: BentoTheme.textSecondary),
                      prefixText: '₹ ',
                      prefixStyle: TextStyle(color: BentoTheme.accent),
                      filled: true,
                      fillColor: BentoTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Paid By
                  DropdownButtonFormField<String>(
                    value: paidBy,
                    dropdownColor: BentoTheme.surface,
                    style: TextStyle(color: BentoTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Paid By',
                      labelStyle: TextStyle(color: BentoTheme.textSecondary),
                      filled: true,
                      fillColor: BentoTheme.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: widget.group.members.map((m) {
                      return DropdownMenuItem(value: m, child: Text(m));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setSheetState(() => paidBy = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Split Mode Switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Split Equally',
                        style: TextStyle(color: BentoTheme.textPrimary, fontWeight: FontWeight.w600),
                      ),
                      Switch(
                        value: splitEqually,
                        activeColor: BentoTheme.accent,
                        onChanged: (val) => setSheetState(() => splitEqually = val),
                      ),
                    ],
                  ),

                  if (!splitEqually) ...[
                    const SizedBox(height: 8),
                    Text(
                      'CUSTOM SHARES',
                      style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    ...widget.group.members.map((m) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: TextField(
                          controller: customShares[m],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: '$m share (₹)',
                            labelStyle: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                            prefixText: '₹ ',
                            isDense: true,
                            filled: true,
                            fillColor: BentoTheme.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final total = double.tryParse(amountController.text) ?? 0.0;
                        if (total <= 0) return;
                        final title = titleController.text.trim().isNotEmpty ? titleController.text.trim() : 'Expense';

                        Map<String, double> shares;
                        if (splitEqually) {
                          shares = SplitSettleEngine.splitEqually(
                            totalAmount: total,
                            participants: widget.group.members,
                          );
                        } else {
                          shares = {};
                          for (final m in widget.group.members) {
                            shares[m] = double.tryParse(customShares[m]!.text) ?? 0.0;
                          }
                        }

                        final entry = SplitEntry(
                          id: 'entry_${DateTime.now().millisecondsSinceEpoch}',
                          groupId: widget.group.id,
                          date: DateTime.now(),
                          title: title,
                          amount: total,
                          paidBy: paidBy,
                          shares: shares,
                        );

                        await _repository.addSplitEntry(entry);
                        if (mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BentoTheme.accent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _promptSettleTransfer(SettlementTransfer transfer) {
    final isYouDebtor = transfer.from.toLowerCase() == 'you';
    final isYouCreditor = transfer.to.toLowerCase() == 'you';

    if (!isYouDebtor && !isYouCreditor) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Settlement between ${transfer.from} and ${transfer.to}')),
      );
      return;
    }

    final actionText = isYouCreditor
        ? 'Confirm receiving ₹${transfer.amount.toStringAsFixed(2)} from ${transfer.from}?'
        : 'Confirm paying ₹${transfer.amount.toStringAsFixed(2)} to ${transfer.to}?';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BentoTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Settle Balance', style: TextStyle(color: BentoTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(actionText, style: TextStyle(color: BentoTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 12),
            Text(
              isYouCreditor
                  ? '• A reimbursement transaction will be recorded to your account.'
                  : '• An expense transaction will be recorded to your account.',
              style: TextStyle(color: BentoTheme.textSecondary.withValues(alpha: 0.7), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: BentoTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final groupEntries = _repository.splitEntries.values
                  .where((e) => e.groupId == widget.group.id && !e.settled)
                  .toList();

              // Mark relevant entries as settled
              for (final e in groupEntries) {
                if (isYouCreditor && e.paidBy.toLowerCase() == 'you' && e.shares.containsKey(transfer.from)) {
                  await _repository.settleSplitEntry(
                    entryId: e.id,
                    isReimbursement: true,
                    settlementAmount: e.shares[transfer.from],
                    note: 'Settled from ${transfer.from}',
                  );
                } else if (isYouDebtor && e.paidBy.toLowerCase() == transfer.to.toLowerCase() && e.shares.containsKey('You')) {
                  await _repository.settleSplitEntry(
                    entryId: e.id,
                    isReimbursement: false,
                    settlementAmount: e.shares['You'],
                    note: 'Settled to ${transfer.to}',
                  );
                }
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Settlement of ₹${transfer.amount.toStringAsFixed(2)} recorded!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isYouCreditor ? const Color(0xFF22C55E) : BentoTheme.accent,
              foregroundColor: Colors.black,
            ),
            child: const Text('Confirm Settle'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _repository.splitEntries.values
        .where((e) => e.groupId == widget.group.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final report = SplitSettleEngine.generateGroupReport(widget.group, entries);

    return Scaffold(
      backgroundColor: BentoTheme.background,
      appBar: AppBar(
        backgroundColor: BentoTheme.background,
        elevation: 0,
        title: Text(
          widget.group.name,
          style: TextStyle(color: BentoTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: BentoTheme.accent,
          labelColor: BentoTheme.accent,
          unselectedLabelColor: BentoTheme.textSecondary,
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Balances & Settle'),
            Tab(text: 'Trip Report'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Expenses Tab
          _buildExpensesTab(entries),

          // 2. Balances & Settle Tab
          _buildBalancesTab(report),

          // 3. Trip Report Tab (P12-3)
          _buildTripReportTab(report),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddExpenseSheet,
        backgroundColor: BentoTheme.accent,
        foregroundColor: Colors.black,
        icon: const Icon(LucideIcons.plus, size: 20),
        label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildExpensesTab(List<SplitEntry> entries) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'No expenses added yet.\nTap "+ Add Expense" to begin.',
          textAlign: TextAlign.center,
          style: TextStyle(color: BentoTheme.textSecondary, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final formattedDate = DateFormat('dd MMM').format(entry.date);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            title: Text(
              entry.title,
              style: TextStyle(color: BentoTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              'Paid by ${entry.paidBy} on $formattedDate • ${entry.settled ? 'Settled' : 'Active'}',
              style: TextStyle(
                color: entry.settled ? const Color(0xFF22C55E) : BentoTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '₹${FormatUtils.formatMoney(entry.amount, decimals: 0)}',
                  style: TextStyle(color: BentoTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(LucideIcons.trash2, size: 16, color: BentoTheme.textSecondary),
                  onPressed: () async {
                    await _repository.deleteSplitEntry(entry.id);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBalancesTab(GroupReport report) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'NET BALANCES',
          style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: ExpressiveTokens.borderM,
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: report.balances.map((b) {
              final isPositive = b.net > 0.005;
              final isNegative = b.net < -0.005;
              final color = isPositive ? const Color(0xFF22C55E) : (isNegative ? const Color(0xFFEF4444) : BentoTheme.textSecondary);
              final text = isPositive
                  ? 'gets back ₹${b.net.toStringAsFixed(2)}'
                  : (isNegative ? 'owes ₹${(-b.net).toStringAsFixed(2)}' : 'settled');

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(b.member, style: TextStyle(color: BentoTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'MINIMAL SETTLEMENT SUGGESTIONS',
          style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1),
        ),
        const SizedBox(height: 10),

        if (report.settlements.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: ExpressiveTokens.borderM,
            ),
            child: Center(
              child: Text(
                '🎉 All debts are settled!',
                style: TextStyle(color: const Color(0xFF22C55E), fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          )
        else
          ...report.settlements.map((s) {
            final involvesYou = s.from.toLowerCase() == 'you' || s.to.toLowerCase() == 'you';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: ExpressiveTokens.borderM,
                border: Border.all(color: involvesYou ? BentoTheme.accent.withValues(alpha: 0.3) : Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: BentoTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(LucideIcons.arrowRight, color: BentoTheme.accent, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                        children: [
                          TextSpan(text: s.from, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const TextSpan(text: ' pays '),
                          TextSpan(text: s.to, style: const TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(
                            text: ' ₹${s.amount.toStringAsFixed(2)}',
                            style: TextStyle(color: BentoTheme.accent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (involvesYou) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _promptSettleTransfer(s),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BentoTheme.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Settle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildTripReportTab(GroupReport report) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Total Spent Banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: ExpressiveTokens.borderL,
            border: Border.all(color: BentoTheme.accent.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOTAL GROUP SPEND',
                style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1),
              ),
              const SizedBox(height: 6),
              Text(
                '₹${FormatUtils.formatMoney(report.totalSpent, decimals: 0)}',
                style: TextStyle(color: BentoTheme.accent, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Across ${widget.group.members.length} members in "${widget.group.name}"',
                style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'MEMBER SPEND BREAKDOWN',
          style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1),
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BentoTheme.surface,
            borderRadius: ExpressiveTokens.borderM,
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: widget.group.members.map((m) {
              final paid = report.perPersonPaid[m] ?? 0.0;
              final consumed = report.perPersonSpent[m] ?? 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        m,
                        style: TextStyle(color: BentoTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Paid: ₹${paid.toStringAsFixed(0)}', style: TextStyle(color: BentoTheme.textPrimary, fontSize: 12)),
                          Text('Share: ₹${consumed.toStringAsFixed(0)}', style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
