import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import '../../core/account_group.dart';
import '../../core/minor.dart';
import '../../core/plan_engine.dart';
import '../../data/money_service.dart';
import '../../data/plan_runner.dart';
import '../../state/money_state.dart';
import '../motion/press_scale.dart';
import 'package:habit_tracker/core/widgets/tactile_button.dart';

/// Sheet to create or configure scheduled Plans (SIP, EMI, Bills, Income).
///
/// Complies with Section 5 & Section 6 of AGENTS.md:
/// - One sheet asks: what kind, how much, which day, from where to where.
/// - Inline Fund creation for SIPs.
/// - Past start date prompt: "Start from today" (default) or "Post missed". Never back-charges silently.
class AddPlanSheet extends StatefulWidget {
  final PlanKind initialKind;

  const AddPlanSheet({
    super.key,
    this.initialKind = PlanKind.sip,
  });

  static Future<void> show(BuildContext context,
      {PlanKind initialKind = PlanKind.sip}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddPlanSheet(initialKind: initialKind),
    );
  }

  @override
  State<AddPlanSheet> createState() => _AddPlanSheetState();
}

class _AddPlanSheetState extends State<AddPlanSheet> {
  late PlanKind _kind;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  int _dayOfMonth = 5;
  String? _fromAccountId;
  String? _toAccountId;
  DateTime _startDate = DateTime.now();
  bool _pastStartConfirmed = false;
  bool _postMissedPast = false;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    final state = MoneyState();
    _fromAccountId = state.mainAccountId;

    // Pick initial destination account based on kind
    if (_kind == PlanKind.sip) {
      final funds = state.accounts.where((a) => a.isFund).toList();
      if (funds.isNotEmpty) _toAccountId = funds.first.id;
    } else if (_kind == PlanKind.emi) {
      final loans = state.accounts.where((a) => a.isLoan).toList();
      if (loans.isNotEmpty) _toAccountId = loans.first.id;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _createFundInline() async {
    final nameCtrl = TextEditingController();
    final created = await showDialog<CoreAccount>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BentoTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Create Investment Fund',
            style: TextStyle(color: BentoTheme.textPrimary, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Fund Name (e.g. Nifty 50 Index)',
                filled: true,
                fillColor: BentoTheme.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              style: TextStyle(color: BentoTheme.textPrimary),
            ),
          ],
        ),
        actions: [
          TactileButton(
            size: TactileButtonSize.small,
            variant: TactileButtonVariant.ghost,
            label: 'Cancel',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TactileButton(
            size: TactileButtonSize.small,
            variant: TactileButtonVariant.primary,
            label: 'Create',
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final acc = await MoneyService().createAccount(
                name: name,
                rawKind: 'mutual_fund',
                openingBalanceMinor: 0,
              );
              if (ctx.mounted) Navigator.of(ctx).pop(acc);
            },
          ),
        ],
      ),
    );

    if (created != null && mounted) {
      setState(() {
        _toAccountId = created.id;
      });
    }
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a plan name')));
      return;
    }

    final amountRupees = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final amountMinor = Minor.toMinor(amountRupees);
    if (amountMinor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid amount')));
      return;
    }

    // SIP must have a destination fund
    if (_kind == PlanKind.sip &&
        (_toAccountId == null || _toAccountId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('A SIP requires a destination fund. Create one inline.')),
      );
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startsInPast = _startDate.isBefore(today);

    // Past Start Prompt (Law L6 / Section 6)
    if (startsInPast && !_pastStartConfirmed) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: BentoTheme.surfaceElevated,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Start Date in the Past',
              style: TextStyle(color: BentoTheme.textPrimary, fontSize: 16)),
          content: Text(
            'This plan has a start date before today (${DateFormat('dd MMM yyyy').format(_startDate)}).\n\n'
            'Would you like to start posting from today, or post past missed occurrences (up to 24)?',
            style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
          ),
          actions: [
            TactileButton(
              size: TactileButtonSize.small,
              variant: TactileButtonVariant.outline,
              label: 'Post missed',
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            TactileButton(
              size: TactileButtonSize.small,
              variant: TactileButtonVariant.primary,
              label: 'Start from today',
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      );

      if (choice == null) return;
      _pastStartConfirmed = true;
      _postMissedPast = choice;
    }

    final effectiveStartDate =
        (startsInPast && !_postMissedPast) ? today : _startDate;

    final plan = CorePlan(
      id: 'plan_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      kind: _kind,
      amountMinor: amountMinor,
      dayOfMonth: _dayOfMonth,
      fromAccountId: _fromAccountId,
      toAccountId: _toAccountId,
      startDate: effectiveStartDate,
    );

    Navigator.of(context).pop();
    HapticFeedback.lightImpact();

    await MoneyService().addPlan(plan);
    // Run due occurrences immediately
    await PlanRunner().runDuePlans();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plan "${plan.title}" saved successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final state = MoneyState();
    final funds = state.accounts.where((a) => a.isFund).toList();
    final loans = state.accounts.where((a) => a.isLoan).toList();

    return Container(
      decoration: BoxDecoration(
        color: BentoTheme.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: 24 + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: BentoTheme.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Add Plan',
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),

            // Kind Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _buildKindTab(PlanKind.sip, 'SIP'),
                  _buildKindTab(PlanKind.emi, 'EMI'),
                  _buildKindTab(PlanKind.bill, 'Bill'),
                  _buildKindTab(PlanKind.income, 'Income'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Plan Title
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Plan Name',
                hintText: _kind == PlanKind.sip
                    ? 'e.g. Index Fund SIP'
                    : (_kind == PlanKind.emi
                        ? 'e.g. Home Loan EMI'
                        : 'e.g. Netflix / Rent'),
                labelStyle:
                    TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
                filled: true,
                fillColor: BentoTheme.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
              style: TextStyle(color: BentoTheme.textPrimary, fontSize: 14),
            ),
            const SizedBox(height: 12),

            // Amount Field
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                hintText: '0.00',
                prefixText: '₹ ',
                prefixStyle: TextStyle(
                    color: BentoTheme.textPrimary, fontWeight: FontWeight.bold),
                labelStyle:
                    TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
                filled: true,
                fillColor: BentoTheme.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
              style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Day of month picker & Start date
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: BentoTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _dayOfMonth,
                        dropdownColor: BentoTheme.surfaceElevated,
                        isExpanded: true,
                        items: List.generate(31, (i) => i + 1).map((day) {
                          return DropdownMenuItem(
                            value: day,
                            child: Text('Every $day of month',
                                style: TextStyle(
                                    color: BentoTheme.textPrimary,
                                    fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _dayOfMonth = val);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                PressScale(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _startDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: BentoTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.calendar,
                            size: 16, color: BentoTheme.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('dd MMM yyyy').format(_startDate),
                          style: TextStyle(
                              color: BentoTheme.textPrimary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Accounts: From and To
            if (_kind == PlanKind.sip) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Destination Fund',
                      style: TextStyle(
                          color: BentoTheme.textSecondary, fontSize: 12)),
                  GestureDetector(
                    onTap: _createFundInline,
                    child: Text('+ Create new fund',
                        style: TextStyle(
                            color: BentoTheme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: BentoTheme.surface,
                    borderRadius: BorderRadius.circular(14)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: funds.any((f) => f.id == _toAccountId)
                        ? _toAccountId
                        : null,
                    hint: Text('Select Fund',
                        style: TextStyle(
                            color: BentoTheme.textMuted, fontSize: 13)),
                    dropdownColor: BentoTheme.surfaceElevated,
                    isExpanded: true,
                    items: funds.map((f) {
                      return DropdownMenuItem(
                        value: f.id,
                        child: Text(f.name,
                            style: TextStyle(
                                color: BentoTheme.textPrimary, fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _toAccountId = val);
                    },
                  ),
                ),
              ),
            ] else if (_kind == PlanKind.emi) ...[
              Text('Destination Loan',
                  style:
                      TextStyle(color: BentoTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: BentoTheme.surface,
                    borderRadius: BorderRadius.circular(14)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: loans.any((l) => l.id == _toAccountId)
                        ? _toAccountId
                        : null,
                    hint: Text('Select Loan',
                        style: TextStyle(
                            color: BentoTheme.textMuted, fontSize: 13)),
                    dropdownColor: BentoTheme.surfaceElevated,
                    isExpanded: true,
                    items: loans.map((l) {
                      return DropdownMenuItem(
                        value: l.id,
                        child: Text(l.name,
                            style: TextStyle(
                                color: BentoTheme.textPrimary, fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _toAccountId = val);
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Save Plan Button
            PressScale(
              onTap: _handleSave,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: BentoTheme.accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    'Save Plan',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKindTab(PlanKind kind, String label) {
    final isSelected = _kind == kind;
    return Expanded(
      child: PressScale(
        onTap: () {
          setState(() {
            _kind = kind;
            if (kind == PlanKind.sip) {
              final funds =
                  MoneyState().accounts.where((a) => a.isFund).toList();
              _toAccountId = funds.isNotEmpty ? funds.first.id : null;
            } else if (kind == PlanKind.emi) {
              final loans =
                  MoneyState().accounts.where((a) => a.isLoan).toList();
              _toAccountId = loans.isNotEmpty ? loans.first.id : null;
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? BentoTheme.surfaceElevated : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? BentoTheme.textPrimary
                    : BentoTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
