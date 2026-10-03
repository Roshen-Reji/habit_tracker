import 'package:flutter/material.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BentoTheme.surface, // #1C1C1E
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: _buildBentoTab(LucideIcons.home, 0)),
          const SizedBox(width: 8),
          Expanded(child: _buildBentoTab(LucideIcons.target, 1)),
          const SizedBox(width: 8),
          Expanded(child: _buildBentoTab(LucideIcons.utensils, 2)),
          const SizedBox(width: 8),
          Expanded(child: _buildBentoTab(LucideIcons.music, 3)),
        ],
      ),
    );
  }

  Widget _buildBentoTab(IconData icon, int index) {
    final bool isSelected = selectedIndex == index;
    
    return GestureDetector(
      onTap: () => onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        height: 60,
        decoration: BoxDecoration(
          color: isSelected ? BentoTheme.accent : BentoTheme.surface,
          borderRadius: BorderRadius.circular(16),
          // Inner glow effect simulated with a bright, subtle top/left border
          border: isSelected ? Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.0) : null,
          boxShadow: isSelected ? [
             BoxShadow(
              color: Colors.white.withValues(alpha: 0.15),
              blurRadius: 10,
              spreadRadius: -2,
            )
          ] : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? BentoTheme.background : const Color(0xFFE1E1E6),
              size: 26,
            ),
          ],
        ).animate(target: isSelected ? 1 : 0)
         .scaleXY(end: 1.1, duration: 400.ms, curve: Curves.easeOutBack),
      ),
    );
  }
}
