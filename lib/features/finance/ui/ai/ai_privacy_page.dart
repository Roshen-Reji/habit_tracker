import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/data/services/ai_service.dart';

class AiPrivacyPage extends StatefulWidget {
  const AiPrivacyPage({super.key});

  @override
  State<AiPrivacyPage> createState() => _AiPrivacyPageState();
}

class _AiPrivacyPageState extends State<AiPrivacyPage> {
  late final Box _settingsBox;
  bool _aiFinanceEnabled = true;
  bool _llmRewordingEnabled = false;

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('finance_settings');
    _aiFinanceEnabled =
        _settingsBox.get('ai_finance_privacy', defaultValue: true) as bool;
    _llmRewordingEnabled =
        _settingsBox.get('ai_insight_rewording', defaultValue: false) as bool;
  }

  void _updateAiFinance(bool val) {
    setState(() => _aiFinanceEnabled = val);
    _settingsBox.put('ai_finance_privacy', val);
    HapticFeedback.selectionClick();
  }

  void _updateLlmRewording(bool val) {
    setState(() => _llmRewordingEnabled = val);
    _settingsBox.put('ai_insight_rewording', val);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BentoTheme.background,
      appBar: AppBar(
        backgroundColor: BentoTheme.background,
        elevation: 0,
        title: Text(
          'AI & Privacy Controls',
          style: TextStyle(
            color: BentoTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: BentoTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: ExpressiveTokens.borderM,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BentoTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(LucideIcons.shieldCheck,
                      color: BentoTheme.accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Local-First Financial Privacy',
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your finances stay on your device. Antigravity calculates balances, forecasts, and health scores locally without uploading your ledger.',
                        style: TextStyle(
                          color: BentoTheme.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Toggles
          Text(
            'FEATURE CONTROLS',
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          _buildToggleTile(
            title: 'Finance AI Assistant',
            subtitle:
                'Allow AI chat to answer questions and draft transactions for your review.',
            icon: LucideIcons.sparkles,
            value: _aiFinanceEnabled,
            onChanged: _updateAiFinance,
          ),
          const SizedBox(height: 10),
          _buildToggleTile(
            title: 'Insight Natural Phrasing',
            subtitle:
                'Optionally rewrite rule-based financial insights via LLM. Off by default.',
            icon: LucideIcons.messageSquareText,
            value: _llmRewordingEnabled,
            onChanged: _updateLlmRewording,
          ),
          const SizedBox(height: 24),

          // Privacy Invariants (§6.9)
          Text(
            'WHAT IS SHARED WITH CLOUD AI',
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: ExpressiveTokens.borderM,
            ),
            child: Column(
              children: [
                _buildPrivacyCheckItem(
                  icon: LucideIcons.check,
                  color: BentoTheme.positive,
                  title: 'Raw transactions never leave your device',
                  desc:
                      'Dates, notes, payees, and receipt images are strictly kept in local storage.',
                ),
                Divider(color: BentoTheme.divider, height: 20),
                _buildPrivacyCheckItem(
                  icon: LucideIcons.check,
                  color: BentoTheme.positive,
                  title: 'Calculations run 100% locally',
                  desc:
                      'Safe-to-Spend, net worth, budgets, and what-if simulators run pure Dart on-device.',
                ),
                Divider(color: BentoTheme.divider, height: 20),
                _buildPrivacyCheckItem(
                  icon: LucideIcons.check,
                  color: BentoTheme.positive,
                  title: 'Aggregated context only',
                  desc:
                      'When AI chat is used, only monthly totals (income and expense) are supplied to assist responses.',
                ),
                Divider(color: BentoTheme.divider, height: 20),
                _buildPrivacyCheckItem(
                  icon: LucideIcons.check,
                  color: BentoTheme.positive,
                  title: 'Zero auto-posting',
                  desc:
                      'AI can only propose draft actions. Every single change requires your explicit confirmation.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          Center(
            child: TextButton.icon(
              onPressed: () {
                AiService.instance.resetChat();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('AI chat session cleared')),
                );
              },
              icon: Icon(LucideIcons.trash2,
                  size: 16, color: BentoTheme.textSecondary),
              label: Text(
                'Reset AI Chat Session',
                style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderM,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: BentoTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: BentoTheme.accent, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            activeColor: BentoTheme.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyCheckItem({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  color: BentoTheme.textSecondary,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
