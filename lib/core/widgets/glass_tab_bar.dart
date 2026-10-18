import 'package:flutter/material.dart';
import 'package:habit_tracker/widgets/bottom_nav_bar.dart';

/// Single item descriptor for [GlassTabBar] and [BottomNavBar].
class GlassTabItem {
  final IconData icon;
  final String label;
  final String? tooltip;

  const GlassTabItem({
    required this.icon,
    required this.label,
    this.tooltip,
  });
}

/// Floating glass tab bar adhering to Apple-style floating capsule navigation,
/// unified with the Tactile Precision Floating Adaptive Dock (AGENTS.md Phase 4).
class GlassTabBar extends StatelessWidget {
  final int selectedIndex;
  final List<GlassTabItem> items;
  final ValueChanged<int> onItemSelected;
  final bool isVisible;
  final double height;
  final bool showMiniPlayer;

  const GlassTabBar({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onItemSelected,
    this.isVisible = true,
    this.height = 62.0,
    this.showMiniPlayer = false,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavBar(
      selectedIndex: selectedIndex,
      onItemTapped: onItemSelected,
      items: items,
      showMiniPlayer: showMiniPlayer,
      isVisible: isVisible,
      height: height,
    );
  }
}
