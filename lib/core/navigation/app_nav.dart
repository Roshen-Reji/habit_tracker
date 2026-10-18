import 'package:flutter/material.dart';
import 'package:habit_tracker/features/finance/ui/accounts/account_detail_page.dart';
import 'package:habit_tracker/features/finance/ui/accounts/accounts_page.dart';
import 'package:habit_tracker/features/finance/ui/calendar/finance_calendar_page.dart';
import 'package:habit_tracker/features/finance/ui/cashflow/cash_flow_page.dart';
import 'package:habit_tracker/features/finance/ui/debt/debt_page.dart';
import 'package:habit_tracker/features/finance/ui/insights/insights_page.dart';
import 'package:habit_tracker/features/finance/ui/networth/net_worth_page.dart';
import 'package:habit_tracker/features/finance/ui/recurring/recurring_page.dart';
import 'package:habit_tracker/features/finance/ui/reports/reports_page.dart';
import 'package:habit_tracker/features/finance/ui/split/split_groups_page.dart';
import 'package:habit_tracker/screens/settings_page.dart';
import 'package:hive/hive.dart';
import 'package:habit_tracker/core/utils/page_transitions.dart';
import 'package:habit_tracker/features/finance/ui/shell/money_shell_page.dart';
import 'package:habit_tracker/features/money/ui/shell/money_shell.dart';

enum AppTab {
  home,
  health,
  diet,
  tasks,
  finance,
}

enum TasksSubview {
  missions,
  academic,
  upcoming,
  inbox,
  board,
}

/// Central application navigation coordinator.
/// Exposes current tab and tasks subview as a ChangeNotifier,
/// allowing deep navigation from cards, notifications, and AI handlers.
class AppNav extends ChangeNotifier {
  static final AppNav instance = AppNav._();
  factory AppNav() => instance;
  AppNav._();

  int _currentTab = 0;
  String _tasksSubview = 'missions';

  int get currentTab => _currentTab;
  int get tab => _currentTab;
  String get tasksSubview => _tasksSubview;

  void setTab(int index) {
    if (_currentTab != index) {
      _currentTab = index;
      notifyListeners();
    }
  }

  void setTasksSubview(String subview) {
    if (_tasksSubview != subview) {
      _tasksSubview = subview;
      notifyListeners();
    }
  }

  /// Navigates to a specific tab and optional sub-view.
  /// Accepts [AppTab], [int], or [String] for tab.
  /// Accepts [TasksSubview] or [String] for sub.
  static void goTo(dynamic targetTab, {dynamic sub}) {
    int index;
    if (targetTab is int) {
      index = targetTab;
    } else if (targetTab is AppTab) {
      index = targetTab.index;
    } else {
      final name = targetTab.toString().toLowerCase();
      if (name.contains('health')) {
        index = 1;
      } else if (name.contains('diet') || name.contains('nutri')) {
        index = 2;
      } else if (name.contains('task')) {
        index = 3;
      } else if (name.contains('finan') || name.contains('money')) {
        index = 4;
      } else {
        index = 0;
      }
    }

    instance._currentTab = index;

    if (sub != null) {
      String subStr;
      if (sub is TasksSubview) {
        subStr = sub.name;
      } else {
        subStr = sub.toString().toLowerCase();
        if (subStr.contains('.')) {
          subStr = subStr.split('.').last;
        }
      }
      instance._tasksSubview = subStr;
    }

    instance.notifyListeners();
  }

  /// Opens the full-screen Money OS shell with optional deep-linking.
  static Future<void> openMoney(
    BuildContext context, {
    int initialTab = 0,
    String? deepLink,
  }) async {
    final useLegacy = Hive.isBoxOpen('finance_settings') &&
        (Hive.box('finance_settings')
                .get('money2_use_legacy', defaultValue: false) ==
            true);

    if (useLegacy) {
      await Navigator.of(context).push(
        PageTransitions.containerTransform(
          MoneyShellPage(
            initialTab: initialTab,
            deepLink: deepLink,
          ),
        ),
      );
    } else {
      await Navigator.of(context).push(
        PageTransitions.containerTransform(
          MoneyShell(
            initialTab: initialTab,
            deepLink: deepLink,
          ),
        ),
      );
    }
  }

  /// Opens the Accounts management screen.
  static Future<void> openAccounts(BuildContext context) async {
    final useLegacy = Hive.isBoxOpen('finance_settings') &&
        (Hive.box('finance_settings')
                .get('money2_use_legacy', defaultValue: false) ==
            true);
    if (useLegacy) {
      await Navigator.of(context).push(
        PageTransitions.containerTransform(
          const AccountsPage(),
        ),
      );
    } else {
      await openMoney(context, deepLink: 'accounts');
    }
  }

  /// Opens the Net Worth screen.
  static Future<void> openNetWorth(BuildContext context) async {
    await Navigator.of(context).push(
      PageTransitions.containerTransform(
        const NetWorthPage(),
      ),
    );
  }

  /// Opens the Account Detail screen.
  static Future<void> openAccountDetail(
    BuildContext context,
    String accountId,
  ) async {
    await Navigator.of(context).push(
      PageTransitions.containerTransform(
        AccountDetailPage(accountId: accountId),
      ),
    );
  }

  /// Opens the Bills & Subscriptions recurring management screen.
  static Future<void> openBills(BuildContext context) async {
    final useLegacy = Hive.isBoxOpen('finance_settings') &&
        (Hive.box('finance_settings')
                .get('money2_use_legacy', defaultValue: false) ==
            true);
    if (useLegacy) {
      await Navigator.of(context).push(
        PageTransitions.containerTransform(
          const RecurringPage(),
        ),
      );
    } else {
      await openMoney(context, deepLink: 'plans');
    }
  }

  /// Opens the Financial Calendar screen.
  static Future<void> openCalendar(BuildContext context) async {
    await Navigator.of(context).push(
      PageTransitions.containerTransform(
        const FinanceCalendarPage(),
      ),
    );
  }

  /// Opens the Debt & Credit Cards dashboard.
  static Future<void> openDebt(BuildContext context) async {
    await Navigator.of(context).push(
      PageTransitions.containerTransform(
        const DebtPage(),
      ),
    );
  }

  /// Opens the Financial Insights page.
  static Future<void> openInsights(BuildContext context) async {
    await Navigator.of(context).push(
      PageTransitions.containerTransform(
        const InsightsPage(),
      ),
    );
  }

  /// Opens the Cash Flow Analysis page.
  static Future<void> openCashFlow(BuildContext context) async {
    await Navigator.of(context).push(
      PageTransitions.containerTransform(
        const CashFlowPage(),
      ),
    );
  }

  /// Opens the Financial Reports & Export page.
  static Future<void> openReports(BuildContext context) async {
    await Navigator.of(context).push(
      PageTransitions.containerTransform(
        const ReportsPage(),
      ),
    );
  }

  /// Opens the Split & Settle dashboard.
  static Future<void> openSplitGroups(BuildContext context) async {
    await Navigator.of(context).push(
      PageTransitions.containerTransform(
        const SplitGroupsPage(),
      ),
    );
  }

  /// Opens the global Settings page.
  static Future<void> openSettings(BuildContext context) async {
    await Navigator.of(context).push(
      PageTransitions.containerTransform(
        const SettingsPage(),
      ),
    );
  }
}
