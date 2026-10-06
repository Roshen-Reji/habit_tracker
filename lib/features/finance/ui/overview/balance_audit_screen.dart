import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/engine/ledger.dart';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

class BalanceAuditEntry {
  final DateTime date;
  final String title;
  final String kind;
  final double amount;
  final double? delta;
  final double? runningBalance;
  final bool isSkipped;
  final String? skipReason;
  final bool isValuation;
  final String? refId;

  const BalanceAuditEntry({
    required this.date,
    required this.title,
    required this.kind,
    required this.amount,
    this.delta,
    this.runningBalance,
    required this.isSkipped,
    this.skipReason,
    this.isValuation = false,
    this.refId,
  });
}

class BalanceAuditScreen extends StatefulWidget {
  final String? initialAccountId;

  const BalanceAuditScreen({super.key, this.initialAccountId});

  @override
  State<BalanceAuditScreen> createState() => _BalanceAuditScreenState();
}

class _BalanceAuditScreenState extends State<BalanceAuditScreen> {
  final FinanceController _controller = FinanceController();
  late String _selectedAccountId;
  DateTime _asOf = DateTime.now();

  @override
  void initState() {
    super.initState();
    final accounts = _controller.storage.accountBox.values.toList();
    if (widget.initialAccountId != null &&
        accounts.any((a) => a.id == widget.initialAccountId)) {
      _selectedAccountId = widget.initialAccountId!;
    } else if (accounts.isNotEmpty) {
      _selectedAccountId = accounts.first.id;
    } else {
      _selectedAccountId = '';
    }
  }

  Account? get _currentAccount {
    return _controller.storage.accountBox.get(_selectedAccountId);
  }

  List<BalanceAuditEntry> _computeAuditLog(Account account, DateTime cutoff) {
    final entries = <BalanceAuditEntry>[];
    DateTime? valuationDate;

    // Check valuations if valued asset
    if (account.isValuedAsset) {
      final relevantValuations = _controller.storage.valuationBox.values
          .where((v) => v.accountId == account.id && !v.date.isAfter(cutoff))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      if (relevantValuations.isNotEmpty) {
        final vDate = relevantValuations.first.date;
        valuationDate =
            DateTime(vDate.year, vDate.month, vDate.day, 23, 59, 59, 999);
      }
    }

    // 1. Opening balance entry
    entries.add(BalanceAuditEntry(
      date: account.openingDate,
      title: 'Opening Balance',
      kind: 'opening',
      amount: account.openingBalance,
      delta: account.openingBalance,
      runningBalance: account.openingBalance,
      isSkipped: false,
    ));

    // Gather candidate items
    final relatedTx = _controller.allTransactions
        .where(
            (tx) => tx.accountId == account.id || tx.toAccountId == account.id)
        .toList();

    // Sort transactions chronologically
    relatedTx.sort((a, b) => a.date.compareTo(b.date));

    // Reset running balance calculation step-by-step
    double running = account.openingBalance;

    // Valuations
    final allValuations = _controller.storage.valuationBox.values
        .where((v) => v.accountId == account.id)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // Combine transactions and valuations into chronological stream
    final combinedEvents = <dynamic>[];
    combinedEvents.addAll(relatedTx);
    combinedEvents.addAll(allValuations);
    combinedEvents.sort((a, b) {
      final dateA = (a is Transaction) ? a.date : (a as Valuation).date;
      final dateB = (b is Transaction) ? b.date : (b as Valuation).date;
      return dateA.compareTo(dateB);
    });

    for (final event in combinedEvents) {
      if (event is Valuation) {
        final v = event;
        final isAfterCutoff = v.date.isAfter(cutoff);
        if (isAfterCutoff) {
          entries.add(BalanceAuditEntry(
            date: v.date,
            title: 'Valuation Entry',
            kind: 'valuation',
            amount: v.value,
            isSkipped: true,
            skipReason:
                'Dated after cutoff (${DateFormat('yyyy-MM-dd').format(cutoff)})',
            isValuation: true,
            refId: v.id,
          ));
        } else if (account.isValuedAsset) {
          running = v.value;
          entries.add(BalanceAuditEntry(
            date: v.date,
            title: 'Valuation Baseline',
            kind: 'valuation',
            amount: v.value,
            delta: 0,
            runningBalance: running,
            isSkipped: false,
            isValuation: true,
            refId: v.id,
          ));
        } else {
          entries.add(BalanceAuditEntry(
            date: v.date,
            title: 'Valuation (Ignored: Account not Valued Asset)',
            kind: 'valuation',
            amount: v.value,
            isSkipped: true,
            skipReason: 'Account kind is not valued asset',
            isValuation: true,
            refId: v.id,
          ));
        }
        continue;
      }

      final tx = event as Transaction;
      final isAfterCutoff = tx.date.isAfter(cutoff);
      final isBeforeOpening = tx.date.isBefore(account.openingDate);
      final isSuperseded =
          valuationDate != null && !tx.date.isAfter(valuationDate);

      if (isAfterCutoff) {
        entries.add(BalanceAuditEntry(
          date: tx.date,
          title: tx.title,
          kind: tx.effectiveKind,
          amount: tx.amount,
          isSkipped: true,
          skipReason:
              'Dated after cutoff (${DateFormat('yyyy-MM-dd').format(cutoff)})',
          refId: tx.id,
        ));
        continue;
      }

      if (isBeforeOpening) {
        entries.add(BalanceAuditEntry(
          date: tx.date,
          title: tx.title,
          kind: tx.effectiveKind,
          amount: tx.amount,
          isSkipped: true,
          skipReason:
              'Dated before opening date (${DateFormat('yyyy-MM-dd').format(account.openingDate)})',
          refId: tx.id,
        ));
        continue;
      }

      if (isSuperseded) {
        entries.add(BalanceAuditEntry(
          date: tx.date,
          title: tx.title,
          kind: tx.effectiveKind,
          amount: tx.amount,
          isSkipped: true,
          skipReason:
              'Superseded by valuation as of ${DateFormat('yyyy-MM-dd').format(valuationDate)}',
          refId: tx.id,
        ));
        continue;
      }

      final absAmount = tx.amount.abs();
      final kind = tx.effectiveKind;
      double delta = 0.0;

      if (tx.accountId == account.id) {
        switch (kind) {
          case 'expense':
          case 'transfer':
          case 'investment':
          case 'debt_payment':
            delta = -absAmount;
            break;
          case 'income':
          case 'refund':
          case 'reimbursement':
            delta = absAmount;
            break;
          case 'adjustment':
            delta = tx.amount >= 0 ? absAmount : -absAmount;
            break;
          default:
            delta = (tx.mode.toLowerCase() == 'expense' || tx.amount < 0)
                ? -absAmount
                : absAmount;
        }
      }

      if (tx.toAccountId == account.id) {
        switch (kind) {
          case 'transfer':
          case 'investment':
            delta += absAmount;
            break;
          case 'emi':
          case 'debt_payment':
            final rate = account.annualRate ?? 0.0;
            final interest =
                tx.interestAmount ?? (rate / 1200.0 * running.abs());
            final principal = (absAmount - interest).clamp(0.0, absAmount);
            delta += principal;
            break;
          default:
            break;
        }
      }

      running = Money.r2(running + delta);
      entries.add(BalanceAuditEntry(
        date: tx.date,
        title: tx.title,
        kind: kind,
        amount: tx.amount,
        delta: delta,
        runningBalance: running,
        isSkipped: false,
        refId: tx.id,
      ));
    }

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _controller.storage.accountBox.values.toList();
    final account = _currentAccount;

    if (account == null) {
      return Scaffold(
        backgroundColor: BentoTheme.background,
        appBar: AppBar(
          title: const Text('Balance Audit (Debug)'),
          backgroundColor: BentoTheme.surfaceElevated,
        ),
        body: const Center(child: Text('No accounts available for audit')),
      );
    }

    final ledgerBalance = LedgerEngine.balance(
      account,
      _controller.allTransactions,
      _controller.storage.valuationBox.values,
      asOf: _asOf,
    );

    final auditLog = _computeAuditLog(account, _asOf);
    final calculatedFinal = auditLog.reversed
            .firstWhere((e) => !e.isSkipped && e.runningBalance != null,
                orElse: () => auditLog.first)
            .runningBalance ??
        0.0;

    final isMatch = (calculatedFinal - ledgerBalance).abs() < 0.01;

    return Scaffold(
      backgroundColor: BentoTheme.background,
      appBar: AppBar(
        title: const Text(
          'Balance Audit',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: BentoTheme.surfaceElevated,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.calendar, size: 20),
            tooltip: 'Set As-Of Cutoff',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _asOf,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() {
                  _asOf = DateTime(
                    picked.year,
                    picked.month,
                    picked.day,
                    23,
                    59,
                    59,
                  );
                });
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Account selector and Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BentoTheme.surfaceElevated,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButton<String>(
                  value: _selectedAccountId,
                  isExpanded: true,
                  dropdownColor: BentoTheme.surfaceElevated,
                  underline: const SizedBox(),
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  items: accounts.map((acc) {
                    return DropdownMenuItem<String>(
                      value: acc.id,
                      child: Text('${acc.name} (${acc.kind.toUpperCase()})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedAccountId = val);
                    }
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Opening Date: ${DateFormat('yyyy-MM-dd').format(account.openingDate)}',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'As Of: ${DateFormat('yyyy-MM-dd HH:mm').format(_asOf)}',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RUNNING TOTAL',
                          style: TextStyle(
                            color: BentoTheme.textSecondary,
                            fontSize: 10,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          FormatUtils.formatCurrency(calculatedFinal),
                          style: TextStyle(
                            color: BentoTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LEDGER ENGINE',
                          style: TextStyle(
                            color: BentoTheme.textSecondary,
                            fontSize: 10,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          FormatUtils.formatCurrency(ledgerBalance),
                          style: TextStyle(
                            color: BentoTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isMatch
                            ? Colors.green.withOpacity(0.15)
                            : Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isMatch
                                ? LucideIcons.checkCircle
                                : LucideIcons.alertTriangle,
                            color: isMatch ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isMatch ? 'MATCH' : 'MISMATCH',
                            style: TextStyle(
                              color: isMatch ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Audit Log list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: auditLog.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = auditLog[index];
                final isOpening = entry.kind == 'opening';

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date column
                      SizedBox(
                        width: 75,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('MMM dd').format(entry.date),
                              style: TextStyle(
                                color: entry.isSkipped
                                    ? BentoTheme.textSecondary.withOpacity(0.5)
                                    : BentoTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              DateFormat('yyyy').format(entry.date),
                              style: TextStyle(
                                color: BentoTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Info column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: entry.isSkipped
                                          ? BentoTheme.textSecondary
                                              .withOpacity(0.6)
                                          : BentoTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      decoration: entry.isSkipped
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                                if (entry.isSkipped)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'SKIPPED',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            if (entry.isSkipped && entry.skipReason != null)
                              Text(
                                entry.skipReason!,
                                style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 11,
                                ),
                              )
                            else
                              Text(
                                entry.kind.toUpperCase(),
                                style: TextStyle(
                                  color: BentoTheme.textSecondary,
                                  fontSize: 10,
                                  letterSpacing: 0.8,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Amounts column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (entry.delta != null && !entry.isSkipped)
                            Text(
                              '${entry.delta! >= 0 ? '+' : ''}${FormatUtils.formatCurrency(entry.delta!)}',
                              style: TextStyle(
                                color: isOpening
                                    ? BentoTheme.textPrimary
                                    : (entry.delta! >= 0
                                        ? Colors.green
                                        : Colors.red),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            )
                          else
                            Text(
                              FormatUtils.formatCurrency(entry.amount),
                              style: TextStyle(
                                color:
                                    BentoTheme.textSecondary.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          if (entry.runningBalance != null && !entry.isSkipped)
                            Text(
                              'Bal: ${FormatUtils.formatCurrency(entry.runningBalance!)}',
                              style: TextStyle(
                                color: BentoTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
