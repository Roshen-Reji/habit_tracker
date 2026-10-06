import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

/// Modal sheet for creating or editing an account.
class AccountEditSheet extends StatefulWidget {
  final Account? account;
  final FinanceRepository? repository;

  const AccountEditSheet({
    super.key,
    this.account,
    this.repository,
  });

  static Future<Account?> show(
    BuildContext context, {
    Account? account,
    FinanceRepository? repository,
  }) {
    return showModalBottomSheet<Account>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AccountEditSheet(
        account: account,
        repository: repository,
      ),
    );
  }

  @override
  State<AccountEditSheet> createState() => _AccountEditSheetState();
}

class _AccountEditSheetState extends State<AccountEditSheet> {
  late final FinanceRepository _repository;
  bool _isEditing = false;

  final _nameController = TextEditingController();
  final _institutionController = TextEditingController();
  final _openingBalanceController = TextEditingController();

  // Credit card specific controllers
  final _creditLimitController = TextEditingController();
  final _statementDayController = TextEditingController();
  final _dueDayController = TextEditingController();

  // Loan specific controllers
  final _principalController = TextEditingController();
  final _rateController = TextEditingController();
  final _emiController = TextEditingController();
  final _tenureController = TextEditingController();

  String _kind = 'bank';
  DateTime _openingDate = DateTime.now();
  DateTime? _loanStartDate;
  int _colorValue = 0xFF4A90E2;
  bool _includeInNetWorth = true;
  bool _spendable = true;
  bool _archived = false;

  // SIP / EMI
  RecurringRule? _linkedRule;
  bool _enableSipEmi = false;
  final _sipAmountController = TextEditingController();
  final _sipDayController = TextEditingController();
  DateTime _sipStartDate = DateTime.now();
  String _sipPayFrom = 'acc_main';
  List<Account> _availableAccounts = [];

  static const List<int> _palette = [
    0xFF4A90E2, // Blue
    0xFF50E3C2, // Teal
    0xFFB8E986, // Light Green
    0xFF7ED321, // Green
    0xFFF8E71C, // Yellow
    0xFFF5A623, // Orange
    0xFFD0021B, // Red
    0xFF9013FE, // Purple
    0xFFBD10E0, // Magenta
    0xFF8B572A, // Brown
    0xFF607D8B, // Slate
    0xFF2C3E50, // Dark Navy
  ];

  static const List<Map<String, String>> _accountKinds = [
    {'key': 'bank', 'label': 'Bank Account'},
    {'key': 'cash', 'label': 'Cash in Hand'},
    {'key': 'wallet', 'label': 'Digital Wallet (UPI)'},
    {'key': 'credit_card', 'label': 'Credit Card'},
    {'key': 'loan', 'label': 'Loan / Mortgage'},
    {'key': 'bnpl', 'label': 'Buy Now Pay Later'},
    {'key': 'investment', 'label': 'Stocks / Mutual Funds'},
    {'key': 'gold', 'label': 'Gold / Precious Metals'},
    {'key': 'property', 'label': 'Real Estate / Property'},
    {'key': 'vehicle', 'label': 'Vehicle / Auto'},
    {'key': 'fd', 'label': 'Fixed Deposit'},
    {'key': 'crypto', 'label': 'Cryptocurrency'},
    {'key': 'other_asset', 'label': 'Other Asset'},
    {'key': 'other_debt', 'label': 'Other Liability'},
  ];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FinanceRepository();
    _availableAccounts = FinanceController().activeAccounts;
    final acc = widget.account;

    if (acc != null) {
      _linkedRule =
          _repository.getAllRecurringRules().cast<RecurringRule?>().firstWhere(
                (r) =>
                    r?.toAccountId == acc.id &&
                    (r?.kind == 'sip' || r?.kind == 'emi'),
                orElse: () => null,
              );
      if (_linkedRule != null) {
        _enableSipEmi = true;
        _sipAmountController.text = _linkedRule!.amount.toString();
        _sipDayController.text = _linkedRule!.dayOfMonth.toString();
        _sipStartDate = _linkedRule!.startDate;
        _sipPayFrom = _linkedRule!.accountId ?? 'acc_main';
      } else {
        _sipDayController.text = '1';
      }
      _isEditing = true;
      _nameController.text = acc.name;
      _institutionController.text = acc.institution ?? '';
      _openingBalanceController.text = acc.openingBalance.toString();
      _kind = acc.kind;
      _openingDate = acc.openingDate;
      _colorValue = acc.colorValue;
      _includeInNetWorth = acc.includeInNetWorth;
      _spendable = acc.spendable;
      _archived = acc.archived;

      if (acc.creditLimit != null) {
        _creditLimitController.text = acc.creditLimit.toString();
      }
      if (acc.statementDay != null) {
        _statementDayController.text = acc.statementDay.toString();
      }
      if (acc.dueDay != null) {
        _dueDayController.text = acc.dueDay.toString();
      }

      if (acc.principal != null) {
        _principalController.text = acc.principal.toString();
      }
      if (acc.annualRate != null) {
        _rateController.text = acc.annualRate.toString();
      }
      if (acc.emi != null) {
        _emiController.text = acc.emi.toString();
      }
      if (acc.tenureMonths != null) {
        _tenureController.text = acc.tenureMonths.toString();
      }
      _loanStartDate = acc.startDate;
    } else {
      _spendable = _defaultSpendableForKind(_kind);
      _sipDayController.text = '1';
      final allTxs = FinanceController().allTransactions;
      if (allTxs.isNotEmpty) {
        final earliestDate =
            allTxs.map((t) => t.date).reduce((a, b) => a.isBefore(b) ? a : b);
        _openingDate = earliestDate;
      } else {
        _openingDate = DateTime.now();
      }
    }
  }

  bool _defaultSpendableForKind(String k) {
    return k == 'bank' || k == 'cash' || k == 'wallet';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _openingBalanceController.dispose();
    _creditLimitController.dispose();
    _statementDayController.dispose();
    _dueDayController.dispose();
    _principalController.dispose();
    _rateController.dispose();
    _emiController.dispose();
    _tenureController.dispose();
    _sipAmountController.dispose();
    _sipDayController.dispose();
    super.dispose();
  }

  void _onKindChanged(String newKind) {
    setState(() {
      _kind = newKind;
      if (!_isEditing) {
        _spendable = _defaultSpendableForKind(newKind);
      }
    });
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an account name.')),
      );
      return;
    }

    final openingBal =
        double.tryParse(_openingBalanceController.text.trim()) ?? 0.0;
    final inst = _institutionController.text.trim().isEmpty
        ? null
        : _institutionController.text.trim();

    double? creditLimit = double.tryParse(_creditLimitController.text.trim());
    int? statementDay = int.tryParse(_statementDayController.text.trim());
    int? dueDay = int.tryParse(_dueDayController.text.trim());

    double? principal = double.tryParse(_principalController.text.trim());
    double? annualRate = double.tryParse(_rateController.text.trim());
    double? emi = double.tryParse(_emiController.text.trim());
    int? tenureMonths = int.tryParse(_tenureController.text.trim());

    if (_isEditing) {
      final acc = widget.account!;
      acc.name = name;
      acc.kind = _kind;
      acc.institution = inst;
      acc.openingBalance = openingBal;
      acc.openingDate = _openingDate;
      acc.colorValue = _colorValue;
      acc.includeInNetWorth = _includeInNetWorth;
      acc.spendable = _spendable;
      acc.archived = _archived;

      acc.creditLimit = creditLimit;
      acc.statementDay = statementDay;
      acc.dueDay = dueDay;

      acc.principal = principal;
      acc.annualRate = annualRate;
      acc.emi = emi;
      acc.tenureMonths = tenureMonths;
      acc.startDate = _loanStartDate;

      await _repository.updateAccount(acc);
    } else {
      final id = 'acc_${DateTime.now().millisecondsSinceEpoch}';
      final newAcc = Account(
        id: id,
        name: name,
        kind: _kind,
        institution: inst,
        openingBalance: openingBal,
        openingDate: _openingDate,
        colorValue: _colorValue,
        includeInNetWorth: _includeInNetWorth,
        spendable: _spendable,
        archived: _archived,
        creditLimit: creditLimit,
        statementDay: statementDay,
        dueDay: dueDay,
        principal: principal,
        annualRate: annualRate,
        emi: emi,
        tenureMonths: tenureMonths,
        startDate: _loanStartDate,
      );

      await _repository.addAccount(newAcc);
    }

    final savedAcc =
        _isEditing ? widget.account! : FinanceController().activeAccounts.last;

    // Handle SIP / EMI rule
    final isInvestment = ['investment', 'gold', 'fd', 'crypto', 'other_asset']
        .contains(savedAcc.kind);
    final isLoan = savedAcc.kind == 'loan';

    if ((isInvestment || isLoan) && _enableSipEmi) {
      final ruleKind = isLoan ? 'emi' : 'sip';
      final ruleName =
          isLoan ? 'EMI for ${savedAcc.name}' : 'SIP for ${savedAcc.name}';
      final ruleAmt = isLoan
          ? (savedAcc.emi ?? 0.0)
          : (double.tryParse(_sipAmountController.text.trim()) ?? 0.0);
      final ruleDay = int.tryParse(_sipDayController.text.trim()) ?? 1;

      if (_linkedRule != null) {
        _linkedRule!.name = ruleName;
        _linkedRule!.kind = ruleKind;
        _linkedRule!.amount = ruleAmt;
        _linkedRule!.dayOfMonth = ruleDay;
        _linkedRule!.accountId = _sipPayFrom;
        _linkedRule!.startDate = _sipStartDate;
        _linkedRule!.autoPost = true;
        await _repository.updateRecurringRule(_linkedRule!);
      } else {
        final newRule = RecurringRule(
          id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
          name: ruleName,
          kind: ruleKind,
          amount: ruleAmt,
          amountIsVariable: false,
          accountId: _sipPayFrom,
          toAccountId: savedAcc.id,
          frequency: 'monthly',
          dayOfMonth: ruleDay,
          startDate: _sipStartDate,
          autoPost: true,
          status: 'active',
          createdAt: DateTime.now(),
        );
        await _repository.addRecurringRule(newRule);
      }
    } else if (_linkedRule != null) {
      await _repository.deleteRecurringRule(_linkedRule!.id);
    }

    if (mounted) {
      Navigator.of(context).pop(savedAcc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCreditCard = _kind == 'credit_card';
    final isLoan = _kind == 'loan';

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
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

          // Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isEditing ? 'Edit Account' : 'New Account',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Scrollable fields
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Account Name
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Account Name',
                      hintText:
                          'e.g. Salary Account, Emergency Fund, HDFC Millennia',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Kind Dropdown
                  DropdownButtonFormField<String>(
                    value: _kind,
                    decoration: InputDecoration(
                      labelText: 'Account Type',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _accountKinds
                        .map((k) => DropdownMenuItem(
                              value: k['key'],
                              child: Text(k['label']!),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) _onKindChanged(val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Institution / Bank Name (Defect 3 fix!)
                  TextField(
                    controller: _institutionController,
                    decoration: InputDecoration(
                      labelText: 'Institution / Bank Name',
                      hintText: 'e.g. HDFC Bank, SBI, ICICI, Zerodha, Axis',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Opening Balance & Date
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _openingBalanceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Opening Balance',
                            hintText: '0.00',
                            prefixText: '${FormatUtils.getCurrencySymbol()} ',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _openingDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _openingDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Opening Date',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                                DateFormat('dd MMM yyyy').format(_openingDate)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Transactions before this date are not counted',
                    style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Credit Card Specific Fields
                  if (isCreditCard) ...[
                    Text(
                      'Credit Card Details',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: BentoTheme.accentColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _creditLimitController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Credit Limit',
                        hintText: 'e.g. 150000',
                        prefixText: '${FormatUtils.getCurrencySymbol()} ',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _statementDayController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Statement Day',
                              hintText: '1 - 31',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _dueDayController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Due Day',
                              hintText: '1 - 31',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Loan Specific Fields
                  if (isLoan) ...[
                    Text(
                      'Loan Details',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: BentoTheme.accentColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _principalController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Principal Amount',
                              prefixText: '${FormatUtils.getCurrencySymbol()} ',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _rateController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Annual Rate',
                              suffixText: '% p.a.',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _emiController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Monthly EMI',
                              prefixText: '${FormatUtils.getCurrencySymbol()} ',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _tenureController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Tenure (Months)',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // SIP or EMI Section
                  if (['investment', 'gold', 'fd', 'crypto', 'other_asset']
                          .contains(_kind) ||
                      isLoan) ...[
                    const Divider(height: 32, color: Colors.white10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isLoan ? 'Monthly EMI Auto-Post' : 'Monthly SIP',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: BentoTheme.accentColor,
                          ),
                        ),
                        Switch(
                          value: _enableSipEmi,
                          onChanged: (val) =>
                              setState(() => _enableSipEmi = val),
                        ),
                      ],
                    ),
                    if (_enableSipEmi) ...[
                      const SizedBox(height: 8),
                      if (!isLoan) ...[
                        TextField(
                          controller: _sipAmountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Monthly Amount',
                            prefixText: '${FormatUtils.getCurrencySymbol()} ',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _sipDayController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Day of Month',
                                hintText: '1 - 31',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _sipPayFrom,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Pay From',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              items: _availableAccounts
                                  .where((a) => a.spendable)
                                  .map((a) => DropdownMenuItem(
                                        value: a.id,
                                        child: Text(a.name,
                                            overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => _sipPayFrom = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _sipStartDate,
                            firstDate: DateTime(2000),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => _sipStartDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Start Date',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                              DateFormat('dd MMM yyyy').format(_sipStartDate)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],

                  // Color Picker
                  Text(
                    'Color Accent',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _palette.map((colorHex) {
                      final isSelected = _colorValue == colorHex;
                      return GestureDetector(
                        onTap: () => setState(() => _colorValue = colorHex),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(colorHex),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                        color: Color(colorHex)
                                            .withValues(alpha: 0.5),
                                        blurRadius: 8)
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  size: 20, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Options Switches
                  SwitchListTile(
                    title: const Text('Include in Net Worth'),
                    subtitle: const Text(
                        'Account balance will contribute to your net worth calculation'),
                    value: _includeInNetWorth,
                    onChanged: (val) =>
                        setState(() => _includeInNetWorth = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Spendable Account'),
                    subtitle: const Text(
                        'Available for daily expenses and safe-to-spend calculations'),
                    value: _spendable,
                    onChanged: (val) => setState(() => _spendable = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_isEditing)
                    SwitchListTile(
                      title: const Text('Archive Account'),
                      subtitle: const Text(
                          'Hide this account from active lists without deleting transactions'),
                      value: _archived,
                      onChanged: (val) => setState(() => _archived = val),
                      contentPadding: EdgeInsets.zero,
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Save button
          ElevatedButton(
            onPressed: _handleSave,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_isEditing ? 'Save Changes' : 'Create Account'),
          ),
        ],
      ),
    );
  }
}
