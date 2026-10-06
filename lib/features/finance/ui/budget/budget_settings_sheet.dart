import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';

class BudgetSettingsSheet extends StatefulWidget {
  final FinanceController controller;

  const BudgetSettingsSheet({
    super.key,
    required this.controller,
  });

  static Future<void> show(BuildContext context, FinanceController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BudgetSettingsSheet(controller: controller),
    );
  }

  @override
  State<BudgetSettingsSheet> createState() => _BudgetSettingsSheetState();
}

class _BudgetSettingsSheetState extends State<BudgetSettingsSheet> {
  late TextEditingController _incomeController;
  late bool _rolloverCarryNegative;
  late bool _alertsEnabled;

  @override
  void initState() {
    super.initState();
    final income = widget.controller.expectedIncome;
    _incomeController = TextEditingController(
      text: income != null && income > 0
          ? (income.truncateToDouble() == income
              ? income.toInt().toString()
              : income.toStringAsFixed(2))
          : '',
    );
    _rolloverCarryNegative = widget.controller.rolloverCarryNegative;
    _alertsEnabled = widget.controller.storage.settingsBox
        .get('budget_alerts_enabled', defaultValue: true);
  }

  @override
  void dispose() {
    _incomeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final incomeVal = double.tryParse(_incomeController.text.trim());
    if (incomeVal != null && incomeVal > 0) {
      await widget.controller.setExpectedIncome(incomeVal);
    }
    await widget.controller.setRolloverCarryNegative(_rolloverCarryNegative);
    await widget.controller.storage.settingsBox
        .put('budget_alerts_enabled', _alertsEnabled);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(LucideIcons.sliders, color: BentoTheme.accent, size: 22),
              const SizedBox(width: 10),
              Text(
                'Budget Settings',
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Expected monthly income
          Text(
            'EXPECTED MONTHLY INCOME',
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: BentoTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all( // allowed: input focus
                  color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Text(
                  FormatUtils.getCurrencySymbol(),
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _incomeController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'e.g. 60000',
                      hintStyle: TextStyle(color: Colors.white24),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Used for 50/30/20 target breakdown and zero-based budgeting.',
            style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Negative rollover carryover toggle
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BentoTheme.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Carry Negative Rollovers',
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'If you overspend a rollover category, deduct the deficit from next month\'s limit.',
                        style: TextStyle(
                            color: BentoTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _rolloverCarryNegative,
                  activeColor: BentoTheme.accent,
                  onChanged: (val) {
                    setState(() => _rolloverCarryNegative = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Budget alerts toggle
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BentoTheme.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget & Pace Alerts',
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Receive notifications at 80%, 100%, and when paced to exceed a budget.',
                        style: TextStyle(
                            color: BentoTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _alertsEnabled,
                  activeColor: BentoTheme.accent,
                  onChanged: (val) {
                    setState(() => _alertsEnabled = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: BentoTheme.accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: ExpressiveTokens.borderM,
                ),
              ),
              child: const Text(
                'Save Settings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
