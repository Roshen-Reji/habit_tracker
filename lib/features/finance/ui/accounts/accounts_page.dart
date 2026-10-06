import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/models/account.dart';
import 'package:habit_tracker/features/finance/ui/accounts/account_detail_page.dart';
import 'package:habit_tracker/features/finance/ui/accounts/account_edit_sheet.dart';
import 'package:habit_tracker/features/finance/ui/accounts/account_reconcile_dialog.dart';

/// Accounts list management screen grouped by Assets and Liabilities,
/// featuring summary cards, reconcile actions, and kind-specific metadata.
class AccountsPage extends StatefulWidget {
  final FinanceController? controller;
  final FinanceRepository? repository;

  const AccountsPage({
    super.key,
    this.controller,
    this.repository,
  });

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage>
    with SingleTickerProviderStateMixin {
  late final FinanceController _controller;
  late final FinanceRepository _repository;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? FinanceController();
    _repository = widget.repository ?? FinanceRepository();
    _tabController = TabController(length: 4, vsync: this);
    _controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

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
    final theme = Theme.of(context);
    final totalAssets = _controller.totalAssets;
    final totalLiabilities = _controller.totalLiabilities;
    final netWorth = _controller.getNetWorth();

    final allAccounts = _controller.storage.accountBox.values.toList();
    final activeAssets = _controller.assetAccounts;
    final activeLiabilities = _controller.liabilityAccounts;
    final archivedAccounts = allAccounts.where((a) => a.archived).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Accounts'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: BentoTheme.accentColor,
          tabs: [
            const Tab(text: 'All'),
            Tab(text: 'Assets (${activeAssets.length})'),
            Tab(text: 'Liabilities (${activeLiabilities.length})'),
            Tab(text: 'Archived (${archivedAccounts.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AccountEditSheet.show(
          context,
          repository: _repository,
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      ),
      body: Column(
        children: [
          // Total Balance Overview Header Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: BentoTheme.cardBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Net Assets',
                      style:
                          TextStyle(color: BentoTheme.textMuted, fontSize: 13),
                    ),
                    Text(
                      FormatUtils.formatMoney(netWorth),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: BentoTheme.accentColor,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Assets',
                            style: TextStyle(
                                color: BentoTheme.textMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            FormatUtils.formatMoney(totalAssets),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 30, width: 1, color: Colors.white12),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Liabilities',
                            style: TextStyle(
                                color: BentoTheme.textMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            FormatUtils.formatMoney(totalLiabilities),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.orangeAccent,
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

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // All Accounts (Grouped by Asset and Liability)
                _buildAllTab(activeAssets, activeLiabilities),

                // Assets Tab
                _buildAccountList(activeAssets, 'No asset accounts found.'),

                // Liabilities Tab
                _buildAccountList(
                    activeLiabilities, 'No liability accounts found.'),

                // Archived Tab
                _buildAccountList(archivedAccounts, 'No archived accounts.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllTab(List<Account> assets, List<Account> liabilities) {
    if (assets.isEmpty && liabilities.isEmpty) {
      return Center(
        child: Text(
          'No accounts found.\nTap + Add Account to get started.',
          textAlign: TextAlign.center,
          style: TextStyle(color: BentoTheme.textMuted),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (assets.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'ASSETS (${assets.length})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: BentoTheme.textMuted,
              ),
            ),
          ),
          ...assets.map((a) => _buildAccountTile(a)),
          const SizedBox(height: 20),
        ],
        if (liabilities.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'LIABILITIES (${liabilities.length})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: BentoTheme.textMuted,
              ),
            ),
          ),
          ...liabilities.map((a) => _buildAccountTile(a)),
          const SizedBox(height: 40),
        ],
      ],
    );
  }

  Widget _buildAccountList(List<Account> accounts, String emptyMessage) {
    if (accounts.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(color: BentoTheme.textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: accounts.length,
      itemBuilder: (ctx, idx) => _buildAccountTile(accounts[idx]),
    );
  }

  Widget _buildAccountTile(Account account) {
    final balance = _controller.getAccountBalance(account);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: BentoTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => AccountDetailPage(
                  accountId: account.id,
                  controller: _controller,
                  repository: _repository,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      Color(account.colorValue).withValues(alpha: 0.18),
                  child: Icon(
                    _iconForKind(account.kind),
                    color: Color(account.colorValue),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              account.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (account.id == _controller.primaryAccountId) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color:
                                    BentoTheme.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'MAIN',
                                style: TextStyle(
                                  color: BentoTheme.accent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        account.institution ?? account.kind.toUpperCase(),
                        style: TextStyle(
                            color: BentoTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      FormatUtils.formatMoney(balance.abs()),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: account.isLiability
                            ? Colors.orangeAccent
                            : Colors.white,
                      ),
                    ),
                    if (account.isCreditCard &&
                        account.creditLimit != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Limit: ${FormatUtils.formatMoney(account.creditLimit!)}',
                        style: TextStyle(
                            color: BentoTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      size: 20, color: Colors.white54),
                  onSelected: (val) async {
                    if (val == 'reconcile') {
                      AccountReconcileDialog.show(
                        context,
                        account: account,
                        controller: _controller,
                        repository: _repository,
                      );
                    } else if (val == 'edit') {
                      AccountEditSheet.show(
                        context,
                        account: account,
                        repository: _repository,
                      );
                    } else if (val == 'archive') {
                      account.archived = !account.archived;
                      await _repository.updateAccount(account);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'reconcile',
                      child: Row(
                        children: [
                          Icon(Icons.tune, size: 18),
                          SizedBox(width: 8),
                          Text('Reconcile'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'archive',
                      child: Row(
                        children: [
                          Icon(
                              account.archived
                                  ? Icons.unarchive
                                  : Icons.archive,
                              size: 18),
                          const SizedBox(width: 8),
                          Text(account.archived ? 'Unarchive' : 'Archive'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
