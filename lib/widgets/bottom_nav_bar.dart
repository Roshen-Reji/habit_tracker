import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/neu_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return NeuContainer(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.symmetric(vertical: 8),
      borderRadius: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNeuTab(LucideIcons.home, "HOME", 0),
          _buildNeuTab(LucideIcons.target, "GOALS", 1),
          _buildNeuTab(LucideIcons.utensils, "DIET", 2),
          _buildNeuTab(LucideIcons.music, "AUDIO", 3),
        ],
      ),
    );
  }

  Widget _buildNeuTab(IconData icon, String label, int index) {
    final bool isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60,
        height: 55,
        child: NeuContainer(
          borderRadius: 20,
          isPressed: false,
          padding: EdgeInsets.zero,
          customColor: isSelected ? NeuTheme.accent.withValues(alpha: 0.15) : Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? NeuTheme.accent : NeuTheme.textSecondary,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
