import 'package:flutter/material.dart';

/// Placeholder / Foundation widget for the Plans tab (Tab 2).
///
/// Will be expanded in Milestone M6 with SIP, EMI, Bills, Income segments,
/// Next execution dates, and "Needs funds" status badges.
class PlansTab extends StatelessWidget {
  const PlansTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: PageStorageKey<String>('money_tab_plans'),
      child: Center(
        child: Text('Plans Tab'),
      ),
    );
  }
}
