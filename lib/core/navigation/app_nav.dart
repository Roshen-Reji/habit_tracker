import 'package:flutter/material.dart';
import 'package:habit_tracker/features/finance/ui/accounts/account_detail_page.dart';
import 'package:habit_tracker/features/finance/ui/accounts/accounts_page.dart';
import 'package:habit_tracker/features/finance/ui/networth/net_worth_page.dart';
import 'package:habit_tracker/features/finance/ui/shell/money_shell_page.dart';

enum AppTab {
  home,
  tasks,
  diet,
}

enum TasksSubview {
  missions,
  finance,
  vault,
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
      if (name.contains('task')) {
        index = 1;
      } else if (name.contains('diet')) {
        index = 2;
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MoneyShellPage(
          initialTab: initialTab,
          deepLink: deepLink,
        ),
      ),
    );
  }

  /// Opens the Accounts management screen.
  static Future<void> openAccounts(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AccountsPage(),
      ),
    );
  }

  /// Opens the Net Worth screen.
  static Future<void> openNetWorth(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NetWorthPage(),
      ),
    );
  }

  /// Opens the Account Detail screen.
  static Future<void> openAccountDetail(
    BuildContext context,
    String accountId,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountDetailPage(accountId: accountId),
      ),
    );
  }
}

