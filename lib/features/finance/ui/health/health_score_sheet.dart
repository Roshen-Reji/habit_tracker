import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/widgets/progress_bar_x.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/engine/health_score_engine.dart';

class HealthScoreSheet extends StatelessWidget {
  const HealthScoreSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const HealthScoreSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = FinanceController();
    final health = controller.getHealthScore();

    Color scoreColor;
    String scoreGrade;
    if (health.overallScore >= 80) {
      scoreColor = Colors.green;
      scoreGrade = 'Excellent';
    } else if (health.overallScore >= 60) {
      scoreColor = BentoTheme.accent;
      scoreGrade = 'Good';
    } else if (health.overallScore >= 40) {
      scoreColor = Colors.orange;
      scoreGrade = 'Fair';
    } else {
      scoreColor = Colors.red;
      scoreGrade = 'Needs Attention';
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 24),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(LucideIcons.heartPulse, color: scoreColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Financial Health Score',
                      style: TextStyle(color: BentoTheme.textPrimary),
                    ),
                    Text(
                      'Holistic financial vitality index (0-100)',
                      style: TextStyle(color: BentoTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(LucideIcons.x, color: BentoTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero score card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: BentoTheme.background,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: scoreColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        // Circle gauge
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: scoreColor, width: 4),
                          ),
                          child: Center(
                            child: Text(
                              health.overallScore.toStringAsFixed(0),
                              style: TextStyle(
                                color: scoreColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                scoreGrade,
                                style: TextStyle(
                                  color: scoreColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Based on 5 core pillars: budgeting, savings rate, debt safety, emergency buffer, and spend consistency.',
                                style: TextStyle(
                                  color: BentoTheme.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Next milestone card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: BentoTheme.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: BentoTheme.accent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.flag,
                            color: BentoTheme.accent, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Next Milestone',
                                style: TextStyle(
                                  color: BentoTheme.accent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                health.nextMilestone,
                                style: TextStyle(
                                  color: BentoTheme.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Weakest area banner if available
                  if (health.weakestComponent != null &&
                      health.weakestComponent!.score < 70) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(LucideIcons.alertCircle,
                              color: Colors.orange, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Focus Area: ${health.weakestComponent!.name}',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  health.weakestComponent!.description,
                                  style: TextStyle(
                                      color: BentoTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  Text(
                    'Pillars Breakdown',
                    style: TextStyle(color: BentoTheme.textPrimary),
                  ),
                  const SizedBox(height: 12),

                  ...health.components.map((comp) => _buildComponentTile(comp)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentTile(HealthScoreComponent comp) {
    Color barColor;
    if (comp.score >= 80) {
      barColor = Colors.green;
    } else if (comp.score >= 50) {
      barColor = BentoTheme.accent;
    } else {
      barColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BentoTheme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                comp.name,
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Text(
                    '${comp.score.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: barColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    ' / 100',
                    style: TextStyle(color: BentoTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProgressBarX(
            value: ProgressMath.ratio(comp.score, 100),
            height: 6,
            customColor: barColor,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  comp.description,
                  style: TextStyle(color: BentoTheme.textSecondary),
                ),
              ),
              Text(
                'Weight: ${comp.baseWeight.toStringAsFixed(0)}%',
                style: TextStyle(
                    color: BentoTheme.textSecondary.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
