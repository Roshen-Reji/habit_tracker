import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/engine/what_if_engine.dart';

class WhatIfSheet extends StatefulWidget {
  final double? initialAmount;

  const WhatIfSheet({super.key, this.initialAmount});

  static Future<void> show(BuildContext context, {double? initialAmount}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WhatIfSheet(initialAmount: initialAmount),
    );
  }

  @override
  State<WhatIfSheet> createState() => _WhatIfSheetState();
}

class _WhatIfSheetState extends State<WhatIfSheet> {
  final FinanceController _controller = FinanceController();
  final TextEditingController _amountController = TextEditingController();

  double _amount = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _amount = widget.initialAmount!;
      _amountController.text = _amount.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    final parsed = double.tryParse(val) ?? 0.0;
    setState(() {
      _amount = parsed;
    });
  }

  void _setPreset(double val) {
    HapticFeedback.selectionClick();
    _amountController.text = val.toStringAsFixed(0);
    setState(() {
      _amount = val;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    WhatIfResult? result;
    if (_amount > 0) {
      result = _controller.simulateWhatIf(_amount);
    }

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: BentoTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(LucideIcons.sparkles, color: BentoTheme.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What-If Simulator',
                        style: BentoTheme.titleMedium.copyWith(color: BentoTheme.textPrimary),
                      ),
                      Text(
                        'Can I safely afford this purchase?',
                        style: BentoTheme.bodySmall.copyWith(color: BentoTheme.textSecondary),
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

            // Amount input
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: BentoTheme.headlineLarge.copyWith(
                color: BentoTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              onChanged: _onAmountChanged,
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: BentoTheme.headlineLarge.copyWith(
                  color: BentoTheme.accent,
                  fontWeight: FontWeight.bold,
                ),
                hintText: '0',
                hintStyle: BentoTheme.headlineLarge.copyWith(
                  color: BentoTheme.textSecondary.withValues(alpha: 0.3),
                ),
                filled: true,
                fillColor: BentoTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
            const SizedBox(height: 12),

            // Preset chips
            Wrap(
              spacing: 8,
              children: [5000.0, 15000.0, 30000.0, 50000.0, 100000.0].map((val) {
                final isSelected = (_amount - val).abs() < 1;
                return ChoiceChip(
                  label: Text('₹${FormatUtils.formatCurrency(val, decimals: 0)}'),
                  selected: isSelected,
                  onSelected: (_) => _setPreset(val),
                  backgroundColor: BentoTheme.background,
                  selectedColor: BentoTheme.accent.withValues(alpha: 0.2),
                  labelStyle: BentoTheme.bodySmall.copyWith(
                    color: isSelected ? BentoTheme.accent : BentoTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? BentoTheme.accent : Colors.white.withValues(alpha: 0.05),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Simulation Result
            if (result != null) ...[
              _buildResultCard(result),
              const SizedBox(height: 16),
              _buildBreakdownCard(result),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: BentoTheme.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    Icon(LucideIcons.calculator, color: BentoTheme.textSecondary, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      'Enter an expense amount above to check affordability against your forecast, upcoming bills, and emergency buffer.',
                      textAlign: TextAlign.center,
                      style: BentoTheme.bodySmall.copyWith(color: BentoTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: BentoTheme.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(WhatIfResult res) {
    Color badgeBg;
    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    switch (res.status) {
      case AffordabilityStatus.comfortable:
        badgeBg = ExpressiveTokens.semanticSuccess.withValues(alpha: 0.15);
        badgeColor = ExpressiveTokens.semanticSuccess;
        badgeIcon = LucideIcons.checkCircle;
        badgeText = 'COMFORTABLE';
        break;
      case AffordabilityStatus.tight:
        badgeBg = ExpressiveTokens.semanticWarning.withValues(alpha: 0.15);
        badgeColor = ExpressiveTokens.semanticWarning;
        badgeIcon = LucideIcons.alertTriangle;
        badgeText = 'TIGHT BUFFER';
        break;
      case AffordabilityStatus.notNow:
        badgeBg = ExpressiveTokens.semanticError.withValues(alpha: 0.15);
        badgeColor = ExpressiveTokens.semanticError;
        badgeIcon = LucideIcons.xCircle;
        badgeText = 'NOT RECOMMENDED NOW';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BentoTheme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, color: badgeColor, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      badgeText,
                      style: BentoTheme.bodySmall.copyWith(
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            res.title,
            style: BentoTheme.titleMedium.copyWith(
              color: BentoTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            res.explanation,
            style: BentoTheme.bodySmall.copyWith(color: BentoTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.lightbulb, color: BentoTheme.accent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    res.recommendation,
                    style: BentoTheme.bodySmall.copyWith(
                      color: BentoTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(WhatIfResult res) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BentoTheme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Month-End Cash Impact',
            style: BentoTheme.bodySmall.copyWith(
              color: BentoTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildRow('Projected Balance (before)', '₹${FormatUtils.formatCurrency(res.forecastMonthEnd)}', false),
          const SizedBox(height: 8),
          _buildRow('This Expense', '-₹${FormatUtils.formatCurrency(res.amount)}', true, isNegative: true),
          const Divider(height: 16, color: Colors.white12),
          _buildRow(
            'Projected Balance (after)',
            '₹${FormatUtils.formatCurrency(res.projectedAfter)}',
            true,
            color: res.projectedAfter >= 0 ? ExpressiveTokens.semanticSuccess : ExpressiveTokens.semanticError,
          ),
          const SizedBox(height: 8),
          _buildRow('Target Emergency Buffer', '₹${FormatUtils.formatCurrency(res.emergencyBuffer)}', false),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, bool isBold, {Color? color, bool isNegative = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: BentoTheme.bodySmall.copyWith(
            color: BentoTheme.textSecondary,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: BentoTheme.bodyMedium.copyWith(
            color: color ?? (isNegative ? ExpressiveTokens.semanticError : BentoTheme.textPrimary),
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
