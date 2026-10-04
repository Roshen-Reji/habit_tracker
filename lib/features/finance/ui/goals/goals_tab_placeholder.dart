import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';

class GoalsTabPlaceholder extends StatelessWidget {
  const GoalsTabPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BentoTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Goals & Sinking Funds',
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Earmarks, savings targets and shortfall trims',
                style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: BentoTheme.surface,
                      borderRadius: ExpressiveTokens.borderL,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.target, size: 48, color: BentoTheme.accent),
                        const SizedBox(height: 16),
                        Text(
                          'Goals & Funds Engine',
                          style: TextStyle(
                            color: BentoTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Phase 5 introduces goal planner with trim suggestions, auto-contributions, and sinking funds.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
