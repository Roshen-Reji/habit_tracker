import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/app_tokens.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/widgets/depth_card.dart';
import 'package:habit_tracker/core/widgets/glass_tab_bar.dart';
import 'package:habit_tracker/features/finance/engine/money_feature.dart';
import 'package:habit_tracker/features/finance/ui/overview/money_overview_tab.dart';
import 'package:habit_tracker/features/finance/ui/transactions/transactions_tab.dart';
import 'package:habit_tracker/features/finance/ui/budget/budget_tab.dart';
import 'package:habit_tracker/features/finance/ui/goals/goals_tab.dart';
import 'package:habit_tracker/features/finance/ui/more/more_tab.dart';
import 'package:habit_tracker/features/finance/ui/categories/categories_page.dart';
import 'package:habit_tracker/features/finance/ui/accounts/accounts_page.dart';
import 'package:habit_tracker/features/finance/ui/calendar/finance_calendar_page.dart';
import 'package:habit_tracker/features/finance/ui/cashflow/cash_flow_page.dart';
import 'package:habit_tracker/features/finance/ui/debt/debt_page.dart';
import 'package:habit_tracker/features/finance/ui/insights/insights_page.dart';
import 'package:habit_tracker/features/finance/ui/networth/net_worth_page.dart';
import 'package:habit_tracker/features/finance/ui/recurring/recurring_page.dart';
import 'package:habit_tracker/features/finance/ui/reports/reports_page.dart';
import 'package:habit_tracker/features/finance/ui/split/split_groups_page.dart';
import 'package:habit_tracker/features/finance/ui/settings/finance_privacy_data_page.dart';
import 'package:habit_tracker/features/finance/data/finance_lock_service.dart';

class _KeepAliveTab extends StatefulWidget {
  final Widget child;
  const _KeepAliveTab({super.key, required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class MoneyTabSpec {
  final String id;
  final IconData icon;
  final String label;
  final Widget Function(BuildContext context, VoidCallback onSeeAllTransactions,
      void Function(String?) onNavigate) builder;

  const MoneyTabSpec({
    required this.id,
    required this.icon,
    required this.label,
    required this.builder,
  });
}

class MoneyShellPage extends StatefulWidget {
  final int initialTab;
  final String? deepLink;

  const MoneyShellPage({
    super.key,
    this.initialTab = 0,
    this.deepLink,
  });

  @override
  State<MoneyShellPage> createState() => _MoneyShellPageState();
}

class _MoneyShellPageState extends State<MoneyShellPage> {
  late int _currentIndex;
  final Set<int> _loadedTabs = <int>{};
  bool _isTabBarVisible = true;

  List<MoneyTabSpec> _getTabSpecs() {
    return [
      MoneyTabSpec(
        id: 'overview',
        icon: LucideIcons.layoutDashboard,
        label: 'Overview',
        builder: (ctx, onSeeAll, onNav) =>
            MoneyOverviewTab(onSeeAllTransactions: onSeeAll),
      ),
      MoneyTabSpec(
        id: 'transactions',
        icon: LucideIcons.arrowRightLeft,
        label: 'Transactions',
        builder: (ctx, onSeeAll, onNav) => const TransactionsTab(),
      ),
      if (MoneyFeature.isBudgetTabEnabled)
        MoneyTabSpec(
          id: 'budget',
          icon: LucideIcons.pieChart,
          label: 'Budget',
          builder: (ctx, onSeeAll, onNav) => const BudgetTab(),
        ),
      if (MoneyFeature.isGoalsTabEnabled)
        MoneyTabSpec(
          id: 'goals',
          icon: LucideIcons.target,
          label: 'Goals',
          builder: (ctx, onSeeAll, onNav) => const GoalsTab(),
        ),
      MoneyTabSpec(
        id: 'more',
        icon: LucideIcons.grid2x2,
        label: 'More',
        builder: (ctx, onSeeAll, onNav) => MoreTab(onNavigate: onNav),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _loadedTabs.add(_currentIndex);
    _handleDeepLink(widget.deepLink);
  }

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
      _loadedTabs.add(index);
      _isTabBarVisible = true;
    });
  }

  void _handleDeepLink(String? link) {
    if (link == null) return;
    final lower = link.toLowerCase();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final specs = _getTabSpecs();

      int findTabIndex(String id) => specs.indexWhere((s) => s.id == id);

      if (lower == 'overview' || lower == 'home') {
        final idx = findTabIndex('overview');
        if (idx != -1) _selectTab(idx);
      } else if (lower == 'transactions' || lower == 'txns') {
        final idx = findTabIndex('transactions');
        if (idx != -1) _selectTab(idx);
      } else if (lower == 'budget' || lower == 'budgets') {
        final idx = findTabIndex('budget');
        if (idx != -1) _selectTab(idx);
      } else if (lower == 'goals' || lower == 'goal') {
        final idx = findTabIndex('goals');
        if (idx != -1) _selectTab(idx);
      } else if (lower == 'more') {
        final idx = findTabIndex('more');
        if (idx != -1) _selectTab(idx);
      } else if (lower == 'categories') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CategoriesPage()),
        );
      } else if (lower == 'accounts' || lower == 'account') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AccountsPage()),
        );
      } else if (lower == 'networth' || lower == 'net_worth') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NetWorthPage()),
        );
      } else if (lower == 'recurring' ||
          lower == 'bills' ||
          lower == 'subscriptions' ||
          lower == 'subs') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RecurringPage()),
        );
      } else if (lower == 'calendar') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FinanceCalendarPage()),
        );
      } else if (lower == 'debt' || lower == 'loans' || lower == 'cards') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DebtPage()),
        );
      } else if (lower == 'insights' ||
          lower == 'insight' ||
          lower == 'alerts') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const InsightsPage()),
        );
      } else if (lower == 'cashflow' || lower == 'cash_flow') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CashFlowPage()),
        );
      } else if (lower == 'reports' || lower == 'report' || lower == 'export') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ReportsPage()),
        );
      } else if (lower == 'split' || lower == 'splits' || lower == 'settle') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SplitGroupsPage()),
        );
      } else if (lower == 'privacy' ||
          lower == 'security' ||
          lower == 'backup') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FinancePrivacyDataPage()),
        );
      } else {
        // More sub-destinations fallback
        final idx = findTabIndex('more');
        if (idx != -1) _selectTab(idx);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lockService = FinanceLockService.instance;

    return ValueListenableBuilder<bool>(
      valueListenable: lockService.isUnlocked,
      builder: (context, isUnlocked, child) {
        if (lockService.isLockEnabled && !isUnlocked) {
          return _buildLockScreen(context, lockService);
        }

        final specs = _getTabSpecs();
        final safeIndex =
            _currentIndex.clamp(0, specs.isNotEmpty ? specs.length - 1 : 0);
        if (!_loadedTabs.contains(safeIndex)) {
          _loadedTabs.add(safeIndex);
        }

        return Scaffold(
          backgroundColor: BentoTheme.background,
          body: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                final delta = notification.scrollDelta ?? 0;
                if (delta > 6 && _isTabBarVisible) {
                  setState(() => _isTabBarVisible = false);
                } else if (delta < -6 && !_isTabBarVisible) {
                  setState(() => _isTabBarVisible = true);
                }
              }
              return false;
            },
            child: Stack(
              children: [
                IndexedStack(
                  index: safeIndex,
                  children: List.generate(specs.length, (i) {
                    if (!_loadedTabs.contains(i)) {
                      return const SizedBox.shrink();
                    }
                    final spec = specs[i];
                    return _KeepAliveTab(
                      key: ValueKey(spec.id),
                      child: spec.builder(
                        context,
                        () {
                          final txIdx =
                              specs.indexWhere((x) => x.id == 'transactions');
                          if (txIdx != -1) _selectTab(txIdx);
                        },
                        (link) => _handleDeepLink(link),
                      ),
                    );
                  }),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: GlassTabBar(
                    selectedIndex: safeIndex,
                    items: specs
                        .map((spec) => GlassTabItem(
                              icon: spec.icon,
                              label: spec.label,
                            ))
                        .toList(),
                    isVisible: _isTabBarVisible,
                    onItemSelected: (index) {
                      _selectTab(index);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLockScreen(
      BuildContext context, FinanceLockService lockService) {
    final tokens = AppTokens.of(context);

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: DepthCard(
              elevation: DepthElevation.e3,
              radius: 28,
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: tokens.surfaceRaised,
                      shape: BoxShape.circle,
                      boxShadow: AppElevation.shadows(DepthElevation.e2,
                          isDark: tokens.isDark),
                    ),
                    child: Icon(LucideIcons.lock,
                        size: 44, color: tokens.textPrimary),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Money OS is Locked',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Authenticate with your fingerprint, face, or device PIN to access your financial data.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => lockService.authenticateAndUnlock(),
                    icon: const Icon(LucideIcons.fingerprint, size: 20),
                    label: const Text('Unlock with Biometrics / PIN'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.textPrimary,
                      foregroundColor: tokens.background,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
