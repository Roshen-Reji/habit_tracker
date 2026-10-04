import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/engine/capture_engine.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

class CategoryRuleDialog extends StatefulWidget {
  final String initialPattern;
  final String? initialCategoryId;

  const CategoryRuleDialog({
    super.key,
    required this.initialPattern,
    this.initialCategoryId,
  });

  static Future<void> show(
    BuildContext context, {
    required String initialPattern,
    String? initialCategoryId,
  }) {
    return showDialog(
      context: context,
      builder: (_) => CategoryRuleDialog(
        initialPattern: initialPattern,
        initialCategoryId: initialCategoryId,
      ),
    );
  }

  @override
  State<CategoryRuleDialog> createState() => _CategoryRuleDialogState();
}

class _CategoryRuleDialogState extends State<CategoryRuleDialog> {
  final FinanceController _controller = FinanceController();
  final FinanceRepository _repository = FinanceRepository();

  late TextEditingController _patternController;
  String? _selectedCategoryId;
  String _matchType = 'contains'; // 'contains', 'exact', 'regex'
  bool _applyToPast = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final norm = MerchantNormalizer.normalize(widget.initialPattern);
    _patternController = TextEditingController(text: norm.isNotEmpty ? norm : widget.initialPattern);
    _selectedCategoryId = widget.initialCategoryId ?? _controller.activeCategories.firstOrNull?.id;
  }

  @override
  void dispose() {
    _patternController.dispose();
    super.dispose();
  }

  Future<void> _saveRule() async {
    final pattern = _patternController.text.trim();
    if (pattern.isEmpty || _selectedCategoryId == null) return;

    setState(() => _isSaving = true);

    try {
      final rule = CategoryRule(
        id: 'rule_${DateTime.now().millisecondsSinceEpoch}',
        pattern: pattern,
        matchType: _matchType,
        categoryId: _selectedCategoryId!,
        priority: 10,
        createdFromCorrection: true,
      );

      await _repository.addCategoryRule(rule);

      if (_applyToPast) {
        final cat = _controller.getCategory(_selectedCategoryId!);
        final catName = cat?.name ?? 'Other';
        final allTxs = _controller.allTransactions;

        for (final tx in allTxs) {
          final norm = MerchantNormalizer.normalize(tx.merchant ?? tx.title);
          final matches = norm.contains(pattern.toLowerCase()) || tx.title.toLowerCase().contains(pattern.toLowerCase());

          if (matches && tx.categoryId != _selectedCategoryId) {
            tx.categoryId = _selectedCategoryId;
            tx.category = catName;
            await tx.save();
          }
        }
        _controller.storage.transactionBox.flush();
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rule saved! "$pattern" will auto-categorize to ${_controller.getCategory(_selectedCategoryId!)?.name ?? ''}'),
            backgroundColor: ExpressiveTokens.semanticSuccess,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save rule: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BentoTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: BentoTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(LucideIcons.sparkles, color: BentoTheme.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Auto-Categorize Rule', style: BentoTheme.titleMedium.copyWith(color: BentoTheme.textPrimary)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Whenever a transaction matches this merchant or keyword, automatically set its category.',
              style: BentoTheme.bodySmall.copyWith(color: BentoTheme.textSecondary),
            ),
            const SizedBox(height: 16),

            // Pattern input
            TextField(
              controller: _patternController,
              decoration: const InputDecoration(
                labelText: 'Merchant Keyword / Pattern',
                hintText: 'e.g. swiggy, uber, amazon',
              ),
            ),
            const SizedBox(height: 12),

            // Category picker
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(labelText: 'Assign Category'),
              dropdownColor: BentoTheme.surface,
              items: _controller.activeCategories.map((c) {
                return DropdownMenuItem(value: c.id, child: Text(c.name));
              }).toList(),
              onChanged: (val) => setState(() => _selectedCategoryId = val),
            ),
            const SizedBox(height: 12),

            // Match type
            DropdownButtonFormField<String>(
              value: _matchType,
              decoration: const InputDecoration(labelText: 'Match Mode'),
              dropdownColor: BentoTheme.surface,
              items: const [
                DropdownMenuItem(value: 'contains', child: Text('Contains (Recommended)')),
                DropdownMenuItem(value: 'exact', child: Text('Exact match only')),
                DropdownMenuItem(value: 'regex', child: Text('Regular Expression')),
              ],
              onChanged: (val) => setState(() => _matchType = val ?? 'contains'),
            ),
            const SizedBox(height: 12),

            // Apply to past checkbox
            CheckboxListTile(
              title: const Text('Apply to existing past transactions', style: TextStyle(color: Colors.white, fontSize: 13)),
              value: _applyToPast,
              activeColor: BentoTheme.accent,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (val) => setState(() => _applyToPast = val ?? true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: BentoTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveRule,
          style: ElevatedButton.styleFrom(
            backgroundColor: BentoTheme.accent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSaving
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save Rule', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
