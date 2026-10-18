import 'package:flutter/material.dart';
import 'package:habit_tracker/features/finance/ui/shell/money_shell_page.dart';
import 'package:habit_tracker/features/money/ui/shell/money_shell.dart';
import 'package:hive/hive.dart';

/// Top-level FinancePage mounted at Index 4 in the main navigation.
class FinancePage extends StatelessWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final useLegacy = Hive.isBoxOpen('finance_settings') &&
        (Hive.box('finance_settings')
                .get('money2_use_legacy', defaultValue: false) ==
            true);
    if (useLegacy) {
      return const MoneyShellPage();
    }
    return const MoneyShell();
  }
}

/// Legacy FinanceDashboard wrapper forwarding to the unified MoneyShellPage (P13-5).
class FinanceDashboard extends StatelessWidget {
  final Widget? child;
  const FinanceDashboard({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return child ?? const MoneyShellPage();
  }
}
