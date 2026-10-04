import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/engine/capture_engine.dart';

class SmsImportSheet extends StatefulWidget {
  const SmsImportSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SmsImportSheet(),
    );
  }

  @override
  State<SmsImportSheet> createState() => _SmsImportSheetState();
}

class _SmsImportSheetState extends State<SmsImportSheet> {
  final FinanceController _controller = FinanceController();
  final FinanceRepository _repository = FinanceRepository();
  final TextEditingController _smsController = TextEditingController();

  TransactionDraft? _parsedDraft;
  String? _selectedAccountId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final spendable = _controller.activeAccounts.where((a) => a.spendable).toList();
    if (spendable.isNotEmpty) {
      _selectedAccountId = spendable.first.id;
    }
  }

  @override
  void dispose() {
    _smsController.dispose();
    super.dispose();
  }

  void _parseSms() {
    final text = _smsController.text.trim();
    if (text.isEmpty) return;

    final draft = SmsTransactionParser.parseSms(text);
    if (draft != null) {
      // Categorize if rule matches
      draft.categoryId = CategorizationRulesEngine.matchCategory(
        rawTitle: draft.title,
        rawMerchant: draft.merchant,
        rules: _controller.storage.ruleBox.values.toList(),
      );
      draft.accountId = _selectedAccountId;
      setState(() => _parsedDraft = draft);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not detect bank or UPI transaction pattern in this SMS.')),
      );
    }
  }

  Future<void> _saveTransaction() async {
    if (_parsedDraft == null) return;
    setState(() => _isSaving = true);

    try {
      final d = _parsedDraft!;
      await _repository.addTransaction(
        TxDraft(
          title: d.title,
          amount: d.amount,
          category: d.categoryId != null ? (_controller.getCategory(d.categoryId!)?.name ?? 'Other') : 'Other',
          date: d.date,
          mode: d.kind,
          kind: d.kind,
          accountId: _selectedAccountId,
          categoryId: d.categoryId,
          merchant: d.merchant,
          paymentMethod: d.paymentMethod ?? 'UPI',
          notes: d.notes,
        ),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction saved: ${d.title} (₹${FormatUtils.formatCurrency(d.amount.abs())})'),
            backgroundColor: ExpressiveTokens.semanticSuccess,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 24,
      ),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  child: Icon(LucideIcons.messageSquare, color: BentoTheme.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parse Bank / UPI SMS',
                        style: BentoTheme.titleMedium.copyWith(color: BentoTheme.textPrimary),
                      ),
                      Text(
                        'Paste bank SMS to extract amount, merchant & date locally',
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
            const SizedBox(height: 16),

            // SMS text input
            TextField(
              controller: _smsController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Paste SMS here, e.g.:\n"Rs 450.00 spent on your card ending 1234 at SWIGGY on 04-Oct-26..."',
              ),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _parseSms,
              icon: const Icon(LucideIcons.search, size: 16),
              label: const Text('Parse SMS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: BentoTheme.background,
                foregroundColor: BentoTheme.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            if (_parsedDraft != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BentoTheme.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ExpressiveTokens.semanticSuccess.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _parsedDraft!.title,
                          style: BentoTheme.titleSmall.copyWith(color: BentoTheme.textPrimary, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_parsedDraft!.amount >= 0 ? '+' : ''}₹${FormatUtils.formatCurrency(_parsedDraft!.amount.abs())}',
                          style: BentoTheme.titleMedium.copyWith(
                            color: _parsedDraft!.amount >= 0 ? ExpressiveTokens.semanticSuccess : ExpressiveTokens.semanticError,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Merchant: ${_parsedDraft!.merchant ?? "None"} · Payment: ${_parsedDraft!.paymentMethod}',
                      style: BentoTheme.bodySmall.copyWith(color: BentoTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),

                    // Destination account
                    DropdownButtonFormField<String>(
                      value: _selectedAccountId,
                      decoration: const InputDecoration(labelText: 'Assign to Account'),
                      dropdownColor: BentoTheme.surface,
                      items: _controller.activeAccounts.map((a) {
                        return DropdownMenuItem(value: a.id, child: Text(a.name));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedAccountId = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: _isSaving ? null : _saveTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BentoTheme.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Confirm & Save Transaction', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
