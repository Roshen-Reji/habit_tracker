import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/finance/ui/budget/budget_tab.dart';
import 'package:habit_tracker/features/finance/ui/cashflow/cash_flow_page.dart';
import 'package:habit_tracker/features/finance/ui/insights/insights_page.dart';
import 'package:habit_tracker/features/finance/ui/networth/net_worth_page.dart';
import 'package:habit_tracker/features/finance/ui/reports/reports_page.dart';
import 'package:habit_tracker/features/finance/ui/settings/finance_privacy_data_page.dart';
import 'package:habit_tracker/features/finance/ui/calendar/finance_calendar_page.dart';
import 'package:habit_tracker/features/finance/ui/categories/categories_page.dart';
import 'package:habit_tracker/features/finance/ui/debt/debt_page.dart';
import 'package:habit_tracker/features/finance/ui/split/split_groups_page.dart';
import 'package:habit_tracker/features/finance/ui/settings/reminders_settings_page.dart';
import '../../core/account_group.dart';
import '../../core/ledger.dart';
import '../../core/minor.dart';
import '../../core/snapshot.dart';
import '../../data/money_service.dart';
import '../../state/money_state.dart';
import '../motion/animated_money_text.dart';
import '../motion/press_scale.dart';
import 'fund_detail_page.dart';
import 'loan_detail_page.dart';

/// The Accounts Tab: Main account pinned on top, Funds, Loans, Cards,
/// and the retained "More" section.
class AccountsTab extends StatelessWidget {
  const AccountsTab({super.key});

  Future<void> _showAddAccountDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();
    String rawKind = 'checking';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: BentoTheme.surfaceElevated,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Add Account',
              style: TextStyle(color: BentoTheme.textPrimary, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Account Name',
                    hintText: 'e.g. Savings Bank, Index Fund',
                    filled: true,
                    fillColor: BentoTheme.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  style: TextStyle(color: BentoTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balanceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Opening Balance (₹)',
                    hintText: '0.00',
                    filled: true,
                    fillColor: BentoTheme.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  style: TextStyle(color: BentoTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                Text('Account Type',
                    style: TextStyle(
                        color: BentoTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      color: BentoTheme.surface,
                      borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: rawKind,
                      dropdownColor: BentoTheme.surfaceElevated,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                            value: 'checking', child: Text('Bank / Checking')),
                        DropdownMenuItem(
                            value: 'mutual_fund',
                            child: Text('Fund / Investment')),
                        DropdownMenuItem(
                            value: 'loan', child: Text('Loan / Liability')),
                        DropdownMenuItem(
                            value: 'credit_card', child: Text('Credit Card')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => rawKind = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: BentoTheme.accent,
                  foregroundColor: Colors.white),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final opening = double.tryParse(balanceCtrl.text.trim()) ?? 0.0;
                await MoneyService().createAccount(
                  name: name,
                  rawKind: rawKind,
                  openingBalanceMinor: Minor.toMinor(opening),
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const PageStorageKey<String>('money_tab_accounts'),
      child: ValueListenableBuilder<MoneySnapshot>(
        valueListenable: MoneyState(),
        builder: (context, snapshot, _) {
          final topPadding = MediaQuery.of(context).padding.top;
          final bottomPadding = MediaQuery.of(context).padding.bottom + 90.0;

          final allAccounts = MoneyState().accounts;
          final mainAccount = allAccounts.firstWhere(
            (a) => a.id == snapshot.mainAccountId,
            orElse: () => CoreAccount(
              id: 'acc_main',
              name: 'Main Account',
              group: AccountGroup.main,
              rawKind: 'checking',
              openingBalanceMinor: 0,
              openingDate: DateTime(2020),
            ),
          );

          final funds = allAccounts.where((a) => a.isFund).toList();
          final loans = allAccounts.where((a) => a.isLoan).toList();
          final cards = allAccounts.where((a) => a.isCard).toList();

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              // Header Sliver
              SliverPadding(
                padding: EdgeInsets.only(
                    top: topPadding + 16, left: 20, right: 20, bottom: 12),
                sliver: SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PORTFOLIO',
                              style: TextStyle(
                                color: BentoTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Accounts',
                              style: TextStyle(
                                color: BentoTheme.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        PressScale(
                          onTap: () => _showAddAccountDialog(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: BentoTheme.accent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              children: [
                                Icon(LucideIcons.plus,
                                    size: 16, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Add',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Pinned Main Account (Section 5)
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                sliver: SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: BentoTheme.surface,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: BentoTheme.accent
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(LucideIcons.landmark,
                                        size: 20, color: BentoTheme.accent),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mainAccount.name,
                                        style: TextStyle(
                                            color: BentoTheme.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text('Main Account • Pinned',
                                          style: TextStyle(
                                              color: BentoTheme.textSecondary,
                                              fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: BentoTheme.surfaceElevated,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('PRIMARY',
                                    style: TextStyle(
                                        color: BentoTheme.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text('Available Balance',
                              style: TextStyle(
                                  color: BentoTheme.textSecondary,
                                  fontSize: 12)),
                          const SizedBox(height: 4),
                          AnimatedMoneyText(
                            amountMinor: snapshot.mainBalanceMinor,
                            style: TextStyle(
                                color: BentoTheme.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Funds & Investments Section (Law L4)
              if (funds.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: Text('Funds & Investments',
                          style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) {
                        final fAcc = funds[idx];
                        final fund = snapshot.funds.firstWhere(
                          (f) => f.accountId == fAcc.id,
                          orElse: () => FundSummary(
                            accountId: fAcc.id,
                            investedMinor: 0,
                            valueMinor: 0,
                            gainMinor: 0,
                            hasValuationUpdate: false,
                          ),
                        );
                        final isPositive = fund.gainMinor >= 0;

                        return RepaintBoundary(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        FundDetailPage(accountId: fAcc.id)),
                              ),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: BentoTheme.surface,
                                    borderRadius: BorderRadius.circular(16)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(fAcc.name,
                                            style: TextStyle(
                                                color: BentoTheme.textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14)),
                                        Icon(LucideIcons.chevronRight,
                                            size: 16,
                                            color: BentoTheme.textMuted),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildColumn(
                                            'Invested',
                                            Minor.format(fund.investedMinor),
                                            BentoTheme.textSecondary),
                                        _buildColumn(
                                            'Value',
                                            Minor.format(fund.valueMinor),
                                            BentoTheme.textPrimary),
                                        _buildColumn(
                                          'Gain',
                                          '${isPositive ? '+' : ''}${Minor.format(fund.gainMinor)}',
                                          isPositive
                                              ? BentoTheme.positive
                                              : BentoTheme.negative,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: funds.length,
                    ),
                  ),
                ),
              ],

              // Loans & Liabilities Section (Law L5)
              if (loans.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: Text('Loans & Liabilities',
                          style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) {
                        final lAcc = loans[idx];
                        final loan = snapshot.loans.firstWhere(
                          (l) => l.accountId == lAcc.id,
                          orElse: () => LoanSummary(
                            accountId: lAcc.id,
                            outstandingMinor: 0,
                            totalPrincipalPaidMinor: 0,
                            totalInterestPaidMinor: 0,
                            annualRatePct: 0.0,
                          ),
                        );

                        return RepaintBoundary(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        LoanDetailPage(accountId: lAcc.id)),
                              ),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: BentoTheme.surface,
                                    borderRadius: BorderRadius.circular(16)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(lAcc.name,
                                            style: TextStyle(
                                                color: BentoTheme.textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14)),
                                        Icon(LucideIcons.chevronRight,
                                            size: 16,
                                            color: BentoTheme.textMuted),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildColumn(
                                            'Principal Paid',
                                            Minor.format(
                                                loan.totalPrincipalPaidMinor),
                                            BentoTheme.positive),
                                        _buildColumn(
                                            'Interest Paid',
                                            Minor.format(
                                                loan.totalInterestPaidMinor),
                                            BentoTheme.negative),
                                        _buildColumn(
                                            'Outstanding',
                                            Minor.format(loan.outstandingMinor),
                                            BentoTheme.textPrimary),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: loans.length,
                    ),
                  ),
                ),
              ],

              // Cards Section
              if (cards.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: Text('Credit Cards',
                          style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) {
                        final c = cards[idx];
                        final bal = snapshot.balancesByAccountMinor[c.id] ?? 0;

                        return RepaintBoundary(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: BentoTheme.surface,
                                  borderRadius: BorderRadius.circular(16)),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(LucideIcons.creditCard,
                                          size: 18, color: BentoTheme.accent),
                                      const SizedBox(width: 10),
                                      Text(c.name,
                                          style: TextStyle(
                                              color: BentoTheme.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14)),
                                    ],
                                  ),
                                  Text(Minor.format(bal),
                                      style: TextStyle(
                                          color: BentoTheme.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: cards.length,
                    ),
                  ),
                ),
              ],

              // Retained "More" Section (Section 5)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: Text('Tools & Reports',
                        style: TextStyle(
                            color: BentoTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: RepaintBoundary(
                    child: Container(
                      decoration: BoxDecoration(
                          color: BentoTheme.surface,
                          borderRadius: BorderRadius.circular(18)),
                      child: Column(
                        children: [
                          _buildMoreTile(
                              context, 'Budget', LucideIcons.pieChart, () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => Scaffold(
                                  appBar: AppBar(title: const Text('Budget')),
                                  body: const BudgetTab()),
                            ));
                          }),
                          Divider(
                              height: 1,
                              indent: 48,
                              color: BentoTheme.divider.withValues(alpha: 0.3)),
                          _buildMoreTile(context, 'Reports & Analytics',
                              LucideIcons.barChart3, () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const ReportsPage()));
                          }),
                          Divider(
                              height: 1,
                              indent: 48,
                              color: BentoTheme.divider.withValues(alpha: 0.3)),
                          _buildMoreTile(
                              context, 'Cash Flow', LucideIcons.activity, () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const CashFlowPage()));
                          }),
                          Divider(
                              height: 1,
                              indent: 48,
                              color: BentoTheme.divider.withValues(alpha: 0.3)),
                          _buildMoreTile(
                              context, 'Net Worth', LucideIcons.trendingUp, () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const NetWorthPage()));
                          }),
                          Divider(
                              height: 1,
                              indent: 48,
                              color: BentoTheme.divider.withValues(alpha: 0.3)),
                          _buildMoreTile(context, 'Financial Insights',
                              LucideIcons.sparkles, () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const InsightsPage()));
                          }),
                          Divider(
                              height: 1,
                              indent: 48,
                              color: BentoTheme.divider.withValues(alpha: 0.3)),
                          _buildMoreTile(context, 'Financial Calendar',
                              LucideIcons.calendar, () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const FinanceCalendarPage()));
                          }),
                          Divider(
                              height: 1,
                              indent: 48,
                              color: BentoTheme.divider.withValues(alpha: 0.3)),
                          _buildMoreTile(context, 'Debt & Credit Cards',
                              LucideIcons.creditCard, () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const DebtPage()));
                          }),
                          Divider(
                              height: 1,
                              indent: 48,
                              color: BentoTheme.divider.withValues(alpha: 0.3)),
                          _buildMoreTile(context, 'Split & Settle',
                              LucideIcons.users, () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const SplitGroupsPage()));
                          }),
                          Divider(
                              height: 1,
                              indent: 48,
                              color: BentoTheme.divider.withValues(alpha: 0.3)),
                          _buildMoreTile(context, 'Categories & Rules',
                              LucideIcons.tag, () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const CategoriesPage()));
                          }),
                          Divider(
                              height: 1,
                              indent: 48,
                              color: BentoTheme.divider.withValues(alpha: 0.3)),
                          _buildMoreTile(context, 'Reminders & Alarms',
                              LucideIcons.bellRing, () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const RemindersSettingsPage()));
                          }),
                          Divider(
                              height: 1,
                              indent: 48,
                              color: BentoTheme.divider.withValues(alpha: 0.3)),
                          _buildMoreTile(context, 'Privacy & Data Backup',
                              LucideIcons.shieldCheck, () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) =>
                                    const FinancePrivacyDataPage()));
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Padding
              SliverToBoxAdapter(
                child: SizedBox(height: bottomPadding),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildMoreTile(
      BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: BentoTheme.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(LucideIcons.chevronRight,
                size: 16, color: BentoTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
