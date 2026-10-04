import 'package:flutter/material.dart';
import 'package:habit_tracker/features/finance/ui/shell/money_shell_page.dart';

/// Legacy FinanceDashboard wrapper forwarding to the unified MoneyShellPage (P13-5).
class FinanceDashboard extends StatelessWidget {
  const FinanceDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const MoneyShellPage();
  }
}
