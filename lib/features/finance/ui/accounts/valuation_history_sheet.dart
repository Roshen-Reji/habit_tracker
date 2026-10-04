import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/models/account.dart';
import 'package:habit_tracker/features/finance/models/valuation.dart';

/// Bottom sheet displaying valuation history and allowing new valuation logging
/// for valued assets (stocks, mutual funds, gold, property, etc.).
class ValuationHistorySheet extends StatefulWidget {
  final Account account;
  final FinanceRepository? repository;
  final FinanceController? controller;

  const ValuationHistorySheet({
    super.key,
    required this.account,
    this.repository,
    this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    required Account account,
    FinanceRepository? repository,
    FinanceController? controller,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ValuationHistorySheet(
        account: account,
        repository: repository,
        controller: controller,
      ),
    );
  }

  @override
  State<ValuationHistorySheet> createState() => _ValuationHistorySheetState();
}

class _ValuationHistorySheetState extends State<ValuationHistorySheet> {
  late final FinanceRepository _repository;
  late final FinanceController _controller;

  bool _isAdding = false;
  final _valueController = TextEditingController();
  final _unitsController = TextEditingController();
  final _priceController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FinanceRepository();
    _controller = widget.controller ?? FinanceController();

    _unitsController.addListener(_recalculateFromUnitsAndPrice);
    _priceController.addListener(_recalculateFromUnitsAndPrice);
  }

  @override
  void dispose() {
    _valueController.dispose();
    _unitsController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _recalculateFromUnitsAndPrice() {
    final u = double.tryParse(_unitsController.text.trim());
    final p = double.tryParse(_priceController.text.trim());
    if (u != null && p != null) {
      final total = Money.r2(u * p);
      _valueController.text = total.toString();
    }
  }

  Future<void> _handleSaveValuation() async {
    final val = double.tryParse(_valueController.text.trim());
    if (val == null || val <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid valuation amount.')),
      );
      return;
    }

    final units = double.tryParse(_unitsController.text.trim());
    final price = double.tryParse(_priceController.text.trim());

    await _repository.addValuation(
      accountId: widget.account.id,
      value: val,
      units: units,
      unitPrice: price,
      date: _selectedDate,
    );

    setState(() {
      _isAdding = false;
      _valueController.clear();
      _unitsController.clear();
      _priceController.clear();
      _selectedDate = DateTime.now();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valuations = _controller.getValuationsForAccount(widget.account.id);
    final invested = _controller.getInvestedAmount(widget.account);
    final currentVal = _controller.getAccountBalance(widget.account);
    final gainLoss = _controller.getGainLoss(widget.account);
    final returnPct = _controller.getReturnPct(widget.account);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: BentoTheme.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Valuations & Holdings',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.account.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: BentoTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(_isAdding ? Icons.close : Icons.add_rounded),
                onPressed: () => setState(() => _isAdding = !_isAdding),
                tooltip: _isAdding ? 'Cancel' : 'Log Valuation',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Summary performance card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Value',
                      style: TextStyle(color: BentoTheme.textMuted, fontSize: 13),
                    ),
                    Text(
                      FormatUtils.formatMoney(currentVal),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Invested Capital',
                      style: TextStyle(color: BentoTheme.textMuted, fontSize: 13),
                    ),
                    Text(
                      FormatUtils.formatMoney(invested),
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Gain / Loss',
                      style: TextStyle(color: BentoTheme.textMuted, fontSize: 13),
                    ),
                    Row(
                      children: [
                        Text(
                          '${gainLoss >= 0 ? '+' : ''}${FormatUtils.formatMoney(gainLoss)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: gainLoss >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (gainLoss >= 0 ? Colors.green : Colors.red)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${returnPct >= 0 ? '+' : ''}${returnPct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: gainLoss >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Add Valuation Form
          if (_isAdding) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Log New Valuation',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _unitsController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Units (optional)',
                            hintText: 'e.g. 50.25',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Unit Price (optional)',
                            hintText: 'e.g. 210.50',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _valueController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Total Valuation Value',
                      hintText: 'e.g. 10577.62',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today_rounded, size: 16),
                        label: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                        onPressed: _pickDate,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _handleSaveValuation,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Save Valuation'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Valuation History List
          Text(
            'Valuation History (${valuations.length})',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: valuations.isEmpty
                ? Center(
                    child: Text(
                      'No manual valuations logged yet.\nCurrent balance reflects cumulative net invested capital.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: BentoTheme.textMuted, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    itemCount: valuations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final val = valuations[idx];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white10,
                          child: const Icon(Icons.assessment_outlined, size: 16, color: Colors.white70),
                        ),
                        title: Text(
                          FormatUtils.formatMoney(val.value),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          val.units != null && val.unitPrice != null
                              ? '${val.units} units @ ₹${val.unitPrice} • ${DateFormat('dd MMM yyyy').format(val.date)}'
                              : DateFormat('dd MMM yyyy').format(val.date),
                          style: TextStyle(color: BentoTheme.textMuted, fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                          onPressed: () async {
                            await _repository.deleteValuation(val.id);
                            setState(() {});
                          },
                          tooltip: 'Delete valuation',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
