import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/engine/search_parser.dart';
import 'package:habit_tracker/features/finance/models/category.dart';
import 'package:habit_tracker/features/finance/ui/import/csv_import_page.dart';
import 'package:habit_tracker/features/finance/ui/import/sms_import_sheet.dart';
import 'package:habit_tracker/features/finance/ui/transactions/transaction_sheet.dart';

class TransactionsTab extends StatefulWidget {
  const TransactionsTab({super.key});

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  final FinanceController _controller = FinanceController();
  late final FinanceRepository _repository = _controller.repository;

  final TextEditingController _searchController = TextEditingController();
  TransactionQuery _query = const TransactionQuery();

  // Multi-select state
  bool _isMultiSelect = false;
  final Set<String> _selectedTxIds = {};

  // Additional manual filters
  String? _filterKind;
  String? _filterAccountId;
  String? _filterCategoryId;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged() {
    setState(() {
      _query = SearchParser.parse(_searchController.text);
    });
  }

  String _txId(Transaction tx) => tx.id ?? tx.key.toString();

  void _toggleSelect(Transaction tx) {
    final id = _txId(tx);
    setState(() {
      if (_selectedTxIds.contains(id)) {
        _selectedTxIds.remove(id);
        if (_selectedTxIds.isEmpty) _isMultiSelect = false;
      } else {
        _selectedTxIds.add(id);
      }
    });
    HapticFeedback.selectionClick();
  }

  void _enterMultiSelect(Transaction tx) {
    setState(() {
      _isMultiSelect = true;
      _selectedTxIds.add(_txId(tx));
    });
    HapticFeedback.heavyImpact();
  }

  void _exitMultiSelect() {
    setState(() {
      _isMultiSelect = false;
      _selectedTxIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedTxIds.isEmpty) return;

    final count = _selectedTxIds.length;
    final idsToDelete = List<String>.from(_selectedTxIds);
    _exitMultiSelect();

    for (final id in idsToDelete) {
      await _repository.deleteTransaction(id);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted $count transactions'),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: BentoTheme.accent,
          onPressed: () async {
            for (var i = 0; i < count; i++) {
              await _repository.undo();
            }
          },
        ),
      ),
    );
  }

  Future<void> _recategorizeSelected() async {
    if (_selectedTxIds.isEmpty) return;

    final categories = _controller.activeCategories;
    if (categories.isEmpty) return;

    final selectedCategory = await showModalBottomSheet<Category>(
      context: context,
      backgroundColor: BentoTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose New Category',
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (_, idx) {
                    final cat = categories[idx];
                    return ListTile(
                      title: Text(cat.name,
                          style: TextStyle(color: BentoTheme.textPrimary)),
                      onTap: () => Navigator.of(ctx).pop(cat),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedCategory == null || !mounted) return;

    final idsToUpdate = List<String>.from(_selectedTxIds);
    _exitMultiSelect();

    for (final id in idsToUpdate) {
      final tx = _controller.allTransactions.firstWhere((t) => _txId(t) == id);
      final draft = TxDraft(
        title: tx.title,
        amount: tx.amount,
        kind: tx.effectiveKind,
        accountId: tx.accountId,
        toAccountId: tx.toAccountId,
        categoryId: selectedCategory.id,
        category: selectedCategory.name,
        date: tx.date,
        merchant: tx.merchant,
        paymentMethod: tx.paymentMethod,
        notes: tx.notes,
        tags: tx.tags,
        splits: tx.splits,
        interestAmount: tx.interestAmount,
        refundOfId: tx.refundOfId,
      );
      await _repository.updateTransaction(id, draft);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Updated ${idsToUpdate.length} transactions to ${selectedCategory.name}')),
      );
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: BentoTheme.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final accounts = _controller.activeAccounts;
            final categories = _controller.activeCategories;

            return Container(
              padding: EdgeInsets.only(
                top: 14,
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
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: BentoTheme.textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Transactions',
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _filterKind = null;
                            _filterAccountId = null;
                            _filterCategoryId = null;
                            _dateRange = null;
                          });
                          setModalState(() {});
                          Navigator.of(ctx).pop();
                        },
                        child: Text('Reset',
                            style: TextStyle(color: BentoTheme.accent)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Kind selector
                  DropdownButtonFormField<String>(
                    value: _filterKind,
                    dropdownColor: BentoTheme.surface,
                    style:
                        TextStyle(color: BentoTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Kind',
                      labelStyle: TextStyle(color: BentoTheme.textSecondary),
                      filled: true,
                      fillColor: BentoTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Kinds')),
                      DropdownMenuItem(
                          value: 'expense', child: Text('Expense')),
                      DropdownMenuItem(value: 'income', child: Text('Income')),
                      DropdownMenuItem(
                          value: 'transfer', child: Text('Transfer')),
                      DropdownMenuItem(value: 'refund', child: Text('Refund')),
                      DropdownMenuItem(
                          value: 'investment', child: Text('Investment')),
                      DropdownMenuItem(
                          value: 'debt_payment', child: Text('Debt Payment')),
                      DropdownMenuItem(
                          value: 'adjustment', child: Text('Adjustment')),
                      DropdownMenuItem(
                          value: 'reimbursement', child: Text('Reimbursement')),
                    ],
                    onChanged: (val) {
                      setModalState(() => _filterKind = val);
                      setState(() => _filterKind = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Account selector
                  DropdownButtonFormField<String>(
                    value: _filterAccountId,
                    dropdownColor: BentoTheme.surface,
                    style:
                        TextStyle(color: BentoTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Account',
                      labelStyle: TextStyle(color: BentoTheme.textSecondary),
                      filled: true,
                      fillColor: BentoTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All Accounts')),
                      ...accounts.map((a) =>
                          DropdownMenuItem(value: a.id, child: Text(a.name))),
                    ],
                    onChanged: (val) {
                      setModalState(() => _filterAccountId = val);
                      setState(() => _filterAccountId = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Category selector
                  DropdownButtonFormField<String>(
                    value: _filterCategoryId,
                    dropdownColor: BentoTheme.surface,
                    style:
                        TextStyle(color: BentoTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: TextStyle(color: BentoTheme.textSecondary),
                      filled: true,
                      fillColor: BentoTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All Categories')),
                      ...categories.map((c) =>
                          DropdownMenuItem(value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (val) {
                      setModalState(() => _filterCategoryId = val);
                      setState(() => _filterCategoryId = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BentoTheme.accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Apply Filters',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Transaction> _getFilteredTransactions() {
    var list = _controller.allTransactions;

    // Apply manual filters
    if (_filterKind != null) {
      list = list.where((tx) => tx.effectiveKind == _filterKind).toList();
    }
    if (_filterAccountId != null) {
      list = list
          .where((tx) =>
              tx.accountId == _filterAccountId ||
              tx.toAccountId == _filterAccountId)
          .toList();
    }
    if (_filterCategoryId != null) {
      list = list.where((tx) => tx.categoryId == _filterCategoryId).toList();
    }
    if (_dateRange != null) {
      list = list
          .where((tx) =>
              tx.date.isAfter(
                  _dateRange!.start.subtract(const Duration(seconds: 1))) &&
              tx.date.isBefore(_dateRange!.end.add(const Duration(days: 1))))
          .toList();
    }

    // Apply parsed query
    list = SearchParser.filter(
      transactions: list,
      query: _query,
      categories: _controller.categoriesMap,
      accounts: _controller.accountsMap,
    );

    return list;
  }

  Map<String, List<Transaction>> _groupByDay(List<Transaction> transactions) {
    final map = <String, List<Transaction>>{};
    for (final tx in transactions) {
      final dayKey = DateFormat('yyyy-MM-dd').format(tx.date);
      map.putIfAbsent(dayKey, () => []).add(tx);
    }
    return map;
  }

  double _dayNet(List<Transaction> dayTxs) {
    double net = 0.0;
    for (final tx in dayTxs) {
      final kind = tx.effectiveKind;
      if (kind == 'income' || kind == 'refund' || kind == 'reimbursement') {
        net += tx.amount.abs();
      } else if (kind == 'expense') {
        net -= tx.amount.abs();
      }
    }
    return net;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredTransactions();
    final grouped = _groupByDay(filtered);
    final dayKeys = grouped.keys.toList();

    return Scaffold(
      backgroundColor: BentoTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar / Multi-select header
            _isMultiSelect ? _buildMultiSelectBar() : _buildSearchBar(),

            // Content
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : CustomScrollView(
                      slivers: [
                        for (final dayKey in dayKeys) ...[
                          _buildDayHeader(dayKey, grouped[dayKey]!),
                          _buildDayList(grouped[dayKey]!),
                        ],
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 100),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => TransactionSheet.show(context),
        backgroundColor: BentoTheme.accent,
        foregroundColor: Colors.black,
        icon: const Icon(LucideIcons.plus, size: 20),
        label: const Text('Add Transaction',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSearchBar() {
    final hasActiveFilters = _filterKind != null ||
        _filterAccountId != null ||
        _filterCategoryId != null ||
        _dateRange != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: ExpressiveTokens.borderM,
                border: Border.all(
                  // allowed: input focus
                  color: BentoTheme.textSecondary.withValues(alpha: 0.12),
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: BentoTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search or filter (>500, cat:food, sep)...',
                  hintStyle: TextStyle(
                    color: BentoTheme.textSecondary.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                  prefixIcon: Icon(LucideIcons.search,
                      size: 16, color: BentoTheme.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x,
                              size: 14, color: Colors.white70),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _showFilterSheet,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  LucideIcons.slidersHorizontal,
                  size: 20,
                  color: hasActiveFilters
                      ? BentoTheme.accent
                      : BentoTheme.textSecondary,
                ),
                if (hasActiveFilters)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: BentoTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(LucideIcons.moreVertical,
                size: 20, color: BentoTheme.textSecondary),
            color: BentoTheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == 'csv') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CsvImportPage()),
                );
              } else if (val == 'sms') {
                SmsImportSheet.show(context);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(LucideIcons.fileSpreadsheet,
                        size: 16, color: BentoTheme.accent),
                    const SizedBox(width: 10),
                    Text('Import Bank CSV',
                        style: TextStyle(
                            color: BentoTheme.textPrimary, fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sms',
                child: Row(
                  children: [
                    Icon(LucideIcons.messageSquare,
                        size: 16, color: BentoTheme.accent),
                    const SizedBox(width: 10),
                    Text('Paste SMS Alert',
                        style: TextStyle(
                            color: BentoTheme.textPrimary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: BentoTheme.surface,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.x, color: Colors.white70),
            onPressed: _exitMultiSelect,
          ),
          const SizedBox(width: 8),
          Text(
            '${_selectedTxIds.length} Selected',
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(LucideIcons.tag, color: BentoTheme.accent),
            tooltip: 'Re-categorize',
            onPressed: _recategorizeSelected,
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2, color: Colors.redAccent),
            tooltip: 'Delete',
            onPressed: _deleteSelected,
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(String dayKey, List<Transaction> txs) {
    final date = DateTime.parse(dayKey);
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.subtract(const Duration(days: 1)).day;

    final dateLabel = isToday
        ? 'Today · ${DateFormat('MMM d').format(date)}'
        : isYesterday
            ? 'Yesterday · ${DateFormat('MMM d').format(date)}'
            : DateFormat('EEE, MMM d, yyyy').format(date);

    final net = _dayNet(txs);
    final isPositive = net > 0;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              dateLabel.toUpperCase(),
              style: TextStyle(
                color: BentoTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            if (net != 0)
              Text(
                '${isPositive ? '+' : ''}${FormatUtils.formatCurrency(net)}',
                style: TextStyle(
                  color: isPositive
                      ? const Color(0xFF22C55E)
                      : BentoTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayList(List<Transaction> dayTxs) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final tx = dayTxs[index];
            return _buildTransactionCard(tx);
          },
          childCount: dayTxs.length,
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Transaction tx) {
    final id = _txId(tx);
    final isSelected = _selectedTxIds.contains(id);
    final kind = tx.effectiveKind;
    final isIncome =
        kind == 'income' || kind == 'refund' || kind == 'reimbursement';
    final category = _controller.getCategory(tx.categoryId);
    final account = _controller.getAccount(tx.accountId);
    final toAccount = _controller.getAccount(tx.toAccountId);
    final hasSplits = tx.splits != null && tx.splits!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? BentoTheme.accent.withValues(alpha: 0.15)
            : BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderM,
      ),
      child: InkWell(
        onTap: () {
          if (_isMultiSelect) {
            _toggleSelect(tx);
          } else {
            TransactionSheet.show(context, existingTransaction: tx);
          }
        },
        onLongPress: () {
          if (!_isMultiSelect) {
            _enterMultiSelect(tx);
          } else {
            _toggleSelect(tx);
          }
        },
        borderRadius: ExpressiveTokens.borderM,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (_isMultiSelect)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    isSelected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                    size: 20,
                    color: isSelected
                        ? BentoTheme.accent
                        : BentoTheme.textSecondary,
                  ),
                ),
              // Category / Kind Icon Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (category != null && category.colorValue != 0
                          ? Color(category.colorValue)
                          : BentoTheme.accent)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconForKind(kind, category?.iconKey),
                  size: 18,
                  color: category != null && category.colorValue != 0
                      ? Color(category.colorValue)
                      : BentoTheme.accent,
                ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            tx.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: BentoTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (hasSplits) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: BentoTheme.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SPLIT',
                              style: TextStyle(
                                color: BentoTheme.accent,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          category?.name ?? tx.category,
                          style: TextStyle(
                            color: BentoTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (account != null)
                          Text(
                            ' · ${kind == 'transfer' && toAccount != null ? '${account.name} → ${toAccount.name}' : account.name}',
                            style: TextStyle(
                              color: BentoTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        if (tx.paymentMethod != null &&
                            tx.paymentMethod!.isNotEmpty)
                          Text(
                            ' · ${tx.paymentMethod!}',
                            style: TextStyle(
                              color: BentoTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIncome ? '+' : '-'}${FormatUtils.formatCurrency(tx.amount.abs())}',
                    style: TextStyle(
                      color: isIncome
                          ? const Color(0xFF22C55E)
                          : BentoTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('hh:mm a').format(tx.date),
                    style: TextStyle(
                      color: BentoTheme.textSecondary.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForKind(String kind, String? iconKey) {
    if (kind == 'transfer') return LucideIcons.arrowRightLeft;
    if (kind == 'refund') return LucideIcons.rotateCcw;
    if (kind == 'investment') return LucideIcons.trendingUp;
    if (kind == 'debt_payment') return LucideIcons.landmark;
    if (kind == 'reimbursement') return LucideIcons.badgePercent;
    if (kind == 'adjustment') return LucideIcons.scale;

    switch (iconKey) {
      case 'utensils':
        return LucideIcons.utensils;
      case 'shopping_cart':
        return LucideIcons.shoppingCart;
      case 'car':
        return LucideIcons.car;
      case 'bolt':
        return LucideIcons.zap;
      case 'heart_pulse':
        return LucideIcons.heartPulse;
      case 'film':
        return LucideIcons.film;
      case 'tv':
        return LucideIcons.tv;
      case 'apple':
        return LucideIcons.apple;
      case 'home':
        return LucideIcons.home;
      case 'graduation_cap':
        return LucideIcons.graduationCap;
      case 'plane':
        return LucideIcons.plane;
      case 'repeat':
        return LucideIcons.repeat;
      case 'shield':
        return LucideIcons.shield;
      case 'gift':
        return LucideIcons.gift;
      case 'sparkles':
        return LucideIcons.sparkles;
      default:
        return LucideIcons.tag;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.inbox,
              size: 48, color: BentoTheme.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            'No transactions found',
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
