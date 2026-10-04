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
import 'package:habit_tracker/features/finance/ui/debt/debt_page.dart';
import 'package:habit_tracker/features/finance/ui/networth/net_worth_page.dart';
import 'package:habit_tracker/features/finance/ui/recurring/recurring_page.dart';

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
      } else {
        // More sub-destinations
        setState(() => _currentIndex = 4);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
  }
}
