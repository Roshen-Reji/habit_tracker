import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _handleDeepLink(widget.deepLink);
  }

  void _handleDeepLink(String? link) {
    if (link == null) return;
    final lower = link.toLowerCase();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (lower == 'overview' || lower == 'home') {
        setState(() => _currentIndex = 0);
      } else if (lower == 'transactions' || lower == 'txns') {
        setState(() => _currentIndex = 1);
      } else if (lower == 'budget' || lower == 'budgets') {
        setState(() => _currentIndex = 2);
      } else if (lower == 'goals' || lower == 'goal') {
        setState(() => _currentIndex = 3);
      } else if (lower == 'more') {
        setState(() => _currentIndex = 4);
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
      } else if (lower == 'recurring' || lower == 'bills' || lower == 'subscriptions' || lower == 'subs') {
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
      } else if (lower == 'insights' || lower == 'insight' || lower == 'alerts') {
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
      } else if (lower == 'privacy' || lower == 'security' || lower == 'backup') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FinancePrivacyDataPage()),
        );
      } else {
        // More sub-destinations
        setState(() => _currentIndex = 4);
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
          return _buildLockScreen(lockService);
        }

        final tabs = [
          MoneyOverviewTab(
            onSeeAllTransactions: () {
              setState(() => _currentIndex = 1);
            },
          ),
          const TransactionsTab(),
          const BudgetTab(),
          const GoalsTab(),
          MoreTab(
            onNavigate: (link) => _handleDeepLink(link),
          ),
        ];

        return Scaffold(
          backgroundColor: BentoTheme.background,
          body: IndexedStack(
            index: _currentIndex.clamp(0, tabs.length - 1),
            children: tabs,
          ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: BentoTheme.surface,
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            HapticFeedback.selectionClick();
            setState(() => _currentIndex = index);
          },
          backgroundColor: BentoTheme.surface,
          indicatorColor: BentoTheme.accent.withValues(alpha: 0.25),
          elevation: 0,
          destinations: [
            NavigationDestination(
              icon: Icon(LucideIcons.layoutDashboard, color: BentoTheme.textSecondary),
              selectedIcon: Icon(LucideIcons.layoutDashboard, color: BentoTheme.accent),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.arrowRightLeft, color: BentoTheme.textSecondary),
              selectedIcon: Icon(LucideIcons.arrowRightLeft, color: BentoTheme.accent),
              label: 'Transactions',
            ),
            if (MoneyFeature.isBudgetTabEnabled)
              NavigationDestination(
                icon: Icon(LucideIcons.pieChart, color: BentoTheme.textSecondary),
                selectedIcon: Icon(LucideIcons.pieChart, color: BentoTheme.accent),
                label: 'Budget',
              ),
            if (MoneyFeature.isGoalsTabEnabled)
              NavigationDestination(
                icon: Icon(LucideIcons.target, color: BentoTheme.textSecondary),
                selectedIcon: Icon(LucideIcons.target, color: BentoTheme.accent),
                label: 'Goals',
              ),
            NavigationDestination(
              icon: Icon(LucideIcons.moreHorizontal, color: BentoTheme.textSecondary),
              selectedIcon: Icon(LucideIcons.moreHorizontal, color: BentoTheme.accent),
              label: 'More',
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildLockScreen(FinanceLockService lockService) {
    return Scaffold(
      backgroundColor: BentoTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: BentoTheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: BentoTheme.accent.withValues(alpha: 0.3)),
                  ),
                  child: Icon(LucideIcons.lock, size: 48, color: BentoTheme.accent),
                ),
                const SizedBox(height: 24),
                Text(
                  'Money OS is Locked',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Authenticate with your fingerprint, face, or device PIN to access your financial data.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
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
                    backgroundColor: BentoTheme.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
