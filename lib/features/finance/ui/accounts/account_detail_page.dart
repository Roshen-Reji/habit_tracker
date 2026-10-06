import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/models/models.dart';
import 'package:habit_tracker/features/finance/ui/accounts/account_edit_sheet.dart';
import 'package:habit_tracker/features/finance/ui/accounts/account_reconcile_dialog.dart';
import 'package:habit_tracker/features/finance/ui/accounts/valuation_history_sheet.dart';
import 'package:habit_tracker/features/finance/ui/transactions/transaction_sheet.dart';
import 'package:habit_tracker/features/finance/ui/recurring/recurring_edit_sheet.dart';
import 'package:habit_tracker/features/finance/ui/widgets/charts/net_worth_history_chart.dart';

/// Comprehensive account details screen with kind-specific analytics,
/// balance-over-time chart, and transaction history.
class AccountDetailPage extends StatefulWidget {
  final String accountId;
  final FinanceController? controller;
  final FinanceRepository? repository;

  const AccountDetailPage({
    super.key,
    required this.accountId,
    this.controller,
    this.repository,
  });

  @override
  State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {
  late final FinanceController _controller;
  late final FinanceRepository _repository;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? FinanceController();
    _repository = widget.repository ?? FinanceRepository();
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

  Account? get _account => _controller.getAccount(widget.accountId);

  IconData _iconForKind(String kind) {
    switch (kind) {
      case 'bank':
        return Icons.account_balance_rounded;
      case 'cash':
        return Icons.payments_rounded;
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'credit_card':
        return Icons.credit_card_rounded;
      case 'loan':
        return Icons.real_estate_agent_rounded;
      case 'bnpl':
        return Icons.shopping_bag_outlined;
      case 'investment':
        return Icons.trending_up_rounded;
      case 'gold':
        return Icons.monetization_on_rounded;
      case 'property':
        return Icons.home_work_rounded;
      case 'vehicle':
        return Icons.directions_car_rounded;
      case 'fd':
        return Icons.lock_clock_rounded;
      case 'crypto':
        return Icons.currency_bitcoin_rounded;
      default:
        return Icons.account_balance_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    final theme = Theme.of(context);

    if (account == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account Details')),
        body: const Center(child: Text('Account not found.')),
      );
    }

    final balance = _controller.getAccountBalance(account);
    final history = _controller.getAccountBalanceHistory(account, months: 6);
    final transactions = _controller.getTransactionsForAccount(account.id);
    final isCreditCard = account.isCreditCard;
    final isLoan = account.isLoan;
    final isValued = account.isValuedAsset;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Reconcile Account',
            onPressed: () => AccountReconcileDialog.show(
              context,
              account: account,
              controller: _controller,
              repository: _repository,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Account',
            onPressed: () => AccountEditSheet.show(
              context,
              account: account,
              repository: _repository,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => TransactionSheet.show(
          context,
          initialAccountId: account.id,
        ),
        icon: const Icon(Icons.add),
        label: const Text('Transaction'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Account Hero Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: BentoTheme.cardBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor:
                            Color(account.colorValue).withValues(alpha: 0.2),
                        child: Icon(
                          _iconForKind(account.kind),
                          color: Color(account.colorValue),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.institution ?? account.kind.toUpperCase(),
                              style: TextStyle(
                                color: BentoTheme.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              account.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (account.archived)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: BentoTheme.warning.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Archived',
                            style: TextStyle(
                              color: BentoTheme.warning,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isCreditCard
                        ? 'Outstanding Debt'
                        : isLoan
                            ? 'Remaining Principal'
                            : 'Current Balance',
                    style: TextStyle(color: BentoTheme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    FormatUtils.formatMoney(balance.abs()),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: account.isLiability
                          ? BentoTheme.warning
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Tag badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildChip(
                        icon: account.spendable
                            ? Icons.check_circle_outline
                            : Icons.block_outlined,
                        label:
                            account.spendable ? 'Spendable' : 'Non-spendable',
                        color: account.spendable
                            ? BentoTheme.positive
                            : Colors.grey,
                      ),
                      _buildChip(
                        icon: account.includeInNetWorth
                            ? Icons.account_balance_outlined
                            : Icons.visibility_off_outlined,
                        label: account.includeInNetWorth
                            ? 'In Net Worth'
                            : 'Excluded from Net Worth',
                        color: account.includeInNetWorth
                            ? BentoTheme.accent
                            : Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Kind Specific Section: Credit Card Details
            if (isCreditCard) ...[
              _buildCreditCardCard(context, account, balance),
              const SizedBox(height: 16),
            ],

            // Kind Specific Section: Loan Details
            if (isLoan) ...[
              _buildLoanCard(context, account, balance),
              const SizedBox(height: 16),
            ],

            // Kind Specific Section: Valued Asset Details
            if (isValued) ...[
              _buildValuedAssetCard(context, account),
              const SizedBox(height: 16),
            ],

            // Balance History Chart
            Container(
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
                      Text(
                        'Balance Trend (6M)',
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
                    height: 160,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Transactions Header & List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Account Activity (${transactions.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Reconcile'),
                  onPressed: () => AccountReconcileDialog.show(
                    context,
                    account: account,
                    controller: _controller,
                    repository: _repository,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (transactions.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BentoTheme.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'No transactions recorded for this account yet.',
                  style: TextStyle(color: BentoTheme.textMuted, fontSize: 13),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, idx) {
                  final tx = transactions[idx];
                  final isOutflow = (tx.accountId == account.id &&
                          (tx.isExpenseKind ||
                              tx.effectiveKind == 'transfer' ||
                              tx.effectiveKind == 'investment' ||
                              tx.effectiveKind == 'debt_payment')) ||
                      tx.amount < 0;

                  return Container(
                    decoration: BoxDecoration(
                      color: BentoTheme.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      onTap: () => TransactionSheet.show(
                        context,
                        existingTransaction: tx,
                      ),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white10,
                        child: Icon(
                          isOutflow
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 18,
                          color:
                              isOutflow ? BentoTheme.negative : BentoTheme.positive,
                        ),
                      ),
                      title: Text(
                        tx.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${tx.category} • ${DateFormat('dd MMM yyyy').format(tx.date)}',
                        style: TextStyle(
                            color: BentoTheme.textMuted, fontSize: 12),
                      ),
                      trailing: Text(
                        '${isOutflow ? '-' : '+'}${FormatUtils.formatMoney(tx.amount.abs())}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color:
                              isOutflow ? BentoTheme.textPrimary : BentoTheme.positive,
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCardCard(
      BuildContext context, Account account, double balance) {
    final limit = account.creditLimit ?? 0.0;
    final debt = balance.abs();
    final available = limit > 0 ? (limit - debt).clamp(0.0, limit) : 0.0;
    final utilization =
        limit > 0 ? ((debt / limit) * 100).clamp(0.0, 100.0) : 0.0;

    final utilColor = utilization > 70
        ? BentoTheme.negative
        : utilization > 30
            ? BentoTheme.warning
            : BentoTheme.positive;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BentoTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Credit Utilization',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                '${utilization.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: utilColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ProgressBarX(
            value: ProgressMath.ratio(utilization, 100),
            height: 8,
            customColor: utilColor,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Credit Limit',
                      style:
                          TextStyle(color: BentoTheme.textMuted, fontSize: 12)),
                  Text(FormatUtils.formatMoney(limit),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Available Credit',
                      style:
                          TextStyle(color: BentoTheme.textMuted, fontSize: 12)),
                  Text(FormatUtils.formatMoney(available),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          if (account.statementDay != null || account.dueDay != null) ...[
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (account.statementDay != null)
                  Text(
                    'Statement Day: ${account.statementDay}th',
                    style: TextStyle(color: BentoTheme.textMuted, fontSize: 12),
                  ),
                if (account.dueDay != null)
                  Text(
                    'Due Day: ${account.dueDay}th',
                    style: TextStyle(color: BentoTheme.textMuted, fontSize: 12),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          ElevatedButton.icon(
            icon: const Icon(Icons.payment_rounded, size: 18),
            label: const Text('Pay Credit Card'),
            style: ElevatedButton.styleFrom(
              backgroundColor: BentoTheme.accentColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              TransactionSheet.show(
                context,
                initialKind: 'transfer',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoanCard(BuildContext context, Account account, double balance) {
    final loanSummary = _controller.getLoanSummary(account);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BentoTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Loan Details & Schedule',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              if (loanSummary.nextDueDate != null)
                Text(
                  'Next: ${DateFormat('d MMM').format(loanSummary.nextDueDate!)}',
                  style: TextStyle(
                    color: BentoTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Metrics Grid: Outstanding, Principal Paid, Interest Paid
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Outstanding',
                        style: TextStyle(
                            color: BentoTheme.textMuted, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      FormatUtils.formatMoney(loanSummary.outstanding),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: BentoTheme.warning,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Principal Paid',
                        style: TextStyle(
                            color: BentoTheme.textMuted, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      FormatUtils.formatMoney(loanSummary.principalPaid),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: BentoTheme.positive,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Interest Paid',
                        style: TextStyle(
                            color: BentoTheme.textMuted, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      FormatUtils.formatMoney(loanSummary.interestPaid),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: BentoTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 12),
          // Terms Row: Principal, Rate, Monthly EMI
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (account.principal != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sanctioned',
                        style: TextStyle(
                            color: BentoTheme.textMuted, fontSize: 11)),
                    Text(FormatUtils.formatMoney(account.principal!),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              if (account.annualRate != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Interest Rate',
                        style: TextStyle(
                            color: BentoTheme.textMuted, fontSize: 11)),
                    Text('${account.annualRate}% p.a.',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              if (account.emi != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Monthly EMI',
                        style: TextStyle(
                            color: BentoTheme.textMuted, fontSize: 11)),
                    Text(FormatUtils.formatMoney(account.emi!),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            icon: const Icon(Icons.handshake_outlined, size: 18),
            label: const Text('Make Debt Payment'),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              TransactionSheet.show(
                context,
                initialKind: 'debt_payment',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildValuedAssetCard(BuildContext context, Account account) {
    final deposited = _controller.getInvestedAmount(account);
    final currentValue = _controller.getAccountBalance(account);
    final gainLoss = _controller.getGainLoss(account);
    final returnPct = _controller.getReturnPct(account);

    final linkedSipRule = _controller.allRecurringRules
        .where((r) =>
            (r.kind == 'sip' || r.kind == 'investment') &&
            r.toAccountId == account.id)
        .firstOrNull;

    final allAccountTxs = _controller.getTransactionsForAccount(account.id);
    final deposits = allAccountTxs
        .where((tx) =>
            tx.toAccountId == account.id &&
            (tx.effectiveKind == 'investment' ||
                tx.effectiveKind == 'transfer'))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final depositCount = deposits.length;
    final totalDepositedFromTxs =
        deposits.fold<double>(0.0, (sum, tx) => sum + tx.amount.abs());

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BentoTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Investment Overview',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              TextButton.icon(
                icon: const Icon(Icons.history, size: 16),
                label: const Text('History'),
                onPressed: () => ValuationHistorySheet.show(
                  context,
                  account: account,
                  controller: _controller,
                  repository: _repository,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Top to Bottom:
          // 1. Deposited
          // 2. Current value
          // 3. Gain / loss
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Deposited',
                      style: TextStyle(
                        color: BentoTheme.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      FormatUtils.formatMoney(deposited),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Value',
                      style: TextStyle(
                        color: BentoTheme.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      FormatUtils.formatMoney(currentValue),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Gain / Loss',
                      style: TextStyle(
                        color: BentoTheme.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${gainLoss >= 0 ? '+' : ''}${FormatUtils.formatMoney(gainLoss)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: gainLoss >= 0
                                ? BentoTheme.positive
                                : BentoTheme.negative,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${returnPct >= 0 ? '+' : ''}${returnPct.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: gainLoss >= 0
                                ? BentoTheme.positive
                                : BentoTheme.negative,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Linked SIP with Pause, Resume, Edit, Stop
          if (linkedSipRule != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.autorenew_rounded,
                              size: 16, color: BentoTheme.accent),
                          const SizedBox(width: 6),
                          Text(
                            linkedSipRule.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (linkedSipRule.status == 'active'
                                  ? BentoTheme.positive
                                  : linkedSipRule.status == 'paused'
                                      ? BentoTheme.warning
                                      : Colors.grey)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          linkedSipRule.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: linkedSipRule.status == 'active'
                                ? BentoTheme.positive
                                : linkedSipRule.status == 'paused'
                                    ? BentoTheme.warning
                                    : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${FormatUtils.formatMoney(linkedSipRule.amount)}/month on day ${linkedSipRule.dayOfMonth ?? linkedSipRule.startDate.day}',
                    style: TextStyle(
                      color: BentoTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (linkedSipRule.status == 'active')
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              minimumSize: const Size(0, 32),
                            ),
                            onPressed: () =>
                                _updateSipStatus(linkedSipRule, 'paused'),
                            child: const Text('Pause',
                                style: TextStyle(fontSize: 12)),
                          ),
                        )
                      else if (linkedSipRule.status == 'paused')
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              minimumSize: const Size(0, 32),
                            ),
                            onPressed: () =>
                                _updateSipStatus(linkedSipRule, 'active'),
                            child: const Text('Resume',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            minimumSize: const Size(0, 32),
                          ),
                          onPressed: () {
                            RecurringEditSheet.show(
                              context,
                              controller: _controller,
                              existingRule: linkedSipRule,
                            );
                          },
                          child: const Text('Edit',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: BentoTheme.negative,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            minimumSize: const Size(0, 32),
                          ),
                          onPressed: () => _confirmStopSip(linkedSipRule),
                          child: const Text('Stop',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 5. Short list of the last deposits ('12 instalments, ₹12,000 deposited')
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      depositCount > 0
                          ? '$depositCount instalment${depositCount == 1 ? '' : 's'}, ${FormatUtils.formatMoney(totalDepositedFromTxs)} deposited'
                          : 'No deposit instalments yet',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    if (deposits.isNotEmpty)
                      Text(
                        'Recent',
                        style: TextStyle(
                          color: BentoTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                if (deposits.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 6),
                  ...deposits.take(3).map((tx) {
                    final sourceAcc = tx.accountId != null
                        ? _controller.getAccount(tx.accountId!)
                        : null;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('d MMM yyyy').format(tx.date),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (sourceAcc != null)
                                Text(
                                  'From ${sourceAcc.name}',
                                  style: TextStyle(
                                    color: BentoTheme.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            '+${FormatUtils.formatMoney(tx.amount.abs())}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: BentoTheme.positive,
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
          const SizedBox(height: 16),

          // 6. Existing "Update current value" action
          OutlinedButton.icon(
            icon: const Icon(Icons.add_chart_rounded, size: 18),
            label: const Text('Update Current Value'),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => ValuationHistorySheet.show(
              context,
              account: account,
              controller: _controller,
              repository: _repository,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSipStatus(RecurringRule rule, String status) async {
    final updated = RecurringRule(
      id: rule.id,
      name: rule.name,
      kind: rule.kind,
      amount: rule.amount,
      amountIsVariable: rule.amountIsVariable,
      categoryId: rule.categoryId,
      accountId: rule.accountId,
      toAccountId: rule.toAccountId,
      frequency: rule.frequency,
      interval: rule.interval,
      anchorDate: rule.anchorDate,
      dayOfMonth: rule.dayOfMonth,
      startDate: rule.startDate,
      endDate: rule.endDate,
      autoPost: rule.autoPost,
      reminderDaysBefore: rule.reminderDaysBefore,
      status: status,
      folio: rule.folio,
      notes: rule.notes,
      createdAt: rule.createdAt,
    );
    await _repository.updateRecurringRule(updated);
    if (mounted) setState(() {});
  }

  Future<void> _confirmStopSip(RecurringRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop SIP?'),
        content: Text('Are you sure you want to stop SIP "${rule.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: BentoTheme.negative),
            child: const Text('Stop SIP'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _updateSipStatus(rule, 'ended');
    }
  }
}
