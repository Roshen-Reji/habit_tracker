import 'package:flutter/material.dart';

/// Placeholder / Foundation widget for the Today tab (Tab 0).
///
/// Will be expanded in Milestone M5 with Hero Main balance, Free to Spend card,
/// Quick action buttons (Spent, Received, Moved), Coming Up plans, and Funds strip.
class TodayTab extends StatelessWidget {
  final VoidCallback? onQuickAdd;
  final ValueChanged<int>? onSelectTab;

  const TodayTab({
    super.key,
    this.onQuickAdd,
    this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: PageStorageKey<String>('money_tab_today'),
      child: Center(
        child: Text('Today Tab'),
      ),
    );
  }
}
