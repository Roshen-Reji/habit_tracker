import 'package:flutter/material.dart';

/// Placeholder / Foundation widget for the Activity tab (Tab 1).
///
/// Will be expanded in Milestone M5 with sticky daily headers, search,
/// swipe to delete with 5-second Undo, and tap to edit.
class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: PageStorageKey<String>('money_tab_activity'),
      child: Center(
        child: Text('Activity Tab'),
      ),
    );
  }
}
