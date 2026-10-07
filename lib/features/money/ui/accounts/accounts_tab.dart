import 'package:flutter/material.dart';

/// Placeholder / Foundation widget for the Accounts tab (Tab 3).
///
/// Will be expanded in Milestone M6 with Main account pinned on top,
/// Funds with Invested/Value/Gain and Update Value button, Loans with
/// principal/interest split, Cards, and More links.
class AccountsTab extends StatelessWidget {
  const AccountsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: PageStorageKey<String>('money_tab_accounts'),
      child: Center(
        child: Text('Accounts Tab'),
      ),
    );
  }
}
