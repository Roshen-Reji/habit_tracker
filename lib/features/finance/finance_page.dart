import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/data/services/global_xp_service.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:habit_tracker/data/services/sip_service.dart';
import 'package:habit_tracker/data/services/finance_calculator.dart';

const List<String> kExpenseCategories = [
  'Food',
  'Shopping',
  'Transport',
  'Utilities',
  'Health',
  'Entertainment',
  'OTT',
  'Groceries',
  'EMI',
  'Investment',
  'Other',
];

const List<Color> _chartColors = [
  Color(0xFF2DD4BF),
  Color(0xFF60A5FA),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF22C55E),
  Color(0xFFA78BFA),
  Color(0xFFF97316),
  Color(0xFF14B8A6),
  Color(0xFFE879F9),
  Color(0xFF94A3B8),
];

double safeParse(String value) {
  final clean = value.replaceAll(RegExp(r'[^0-9.]'), '');
  return double.tryParse(clean) ?? 0.0;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

int _asInt(dynamic value, {int fallback = 1}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _isExpense(Transaction tx) {
  final mode = tx.mode.toLowerCase();
  return mode == 'expense' || tx.amount < 0;
}

String _money(double amount) => FormatUtils.formatCurrency(amount);
String _compactMoney(double amount) =>
    FormatUtils.formatCompactCurrency(amount);

class FinanceDashboard extends StatefulWidget {
  const FinanceDashboard({super.key});

  @override
  State<FinanceDashboard> createState() => _FinanceDashboardState();
}

class _FinanceDashboardState extends State<FinanceDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  late Box<Transaction> txBox;
  late Box<AssetVault> vaultBox;
  late Box settingsBox;

  static const _tabs = [
    _FinanceTab('overview', 'OVERVIEW', LucideIcons.layoutDashboard),
    _FinanceTab('transactions', 'TXNS', LucideIcons.arrowRightLeft),
    _FinanceTab('budget', 'BUDGET', LucideIcons.pieChart),
    _FinanceTab('planner', 'PLAN', LucideIcons.calendar),
    _FinanceTab('goals', 'GOALS', LucideIcons.flag),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    txBox = Hive.box<Transaction>('finance_transactions');
    vaultBox = Hive.box<AssetVault>('finance_vaults');
    settingsBox = Hive.box('finance_settings');
    _initializeDefaults();
    _migrateFinanceDataFromLegacySettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initializeDefaults() {
    settingsBox.put(
        'budgets', List.from(settingsBox.get('budgets', defaultValue: [])));
    settingsBox.put(
        'goals', List.from(settingsBox.get('goals', defaultValue: [])));
    settingsBox.put(
      'planner',
      Map.from(settingsBox.get(
        'planner',
        defaultValue: {'fixedExpenses': [], 'sips': []},
      )),
    );
  }

  void _migrateFinanceDataFromLegacySettings() {
    final legacy = Hive.box('settings');
    var changed = false;

    final legacyBudgets = List.from(legacy.get('budgets', defaultValue: []));
    if (legacyBudgets.isNotEmpty) {
      final budgets = List.from(settingsBox.get('budgets', defaultValue: []));
      for (final item in legacyBudgets) {
        final budget = Map.from(item as Map);
        final category = budget['category']?.toString() ?? 'Other';
        final exists = budgets.any((b) =>
            (Map.from(b as Map)['category']?.toString() ?? '') == category);
        if (!exists) budgets.add(budget);
      }
      settingsBox.put('budgets', budgets);
      changed = true;
    }

    final legacyGoals = List.from(legacy.get('goals', defaultValue: []));
    if (legacyGoals.isNotEmpty) {
      final goals = List.from(settingsBox.get('goals', defaultValue: []));
      for (final item in legacyGoals) {
        final goal = Map.from(item as Map);
        final name = goal['name']?.toString() ?? '';
        final target = _asDouble(goal['target']);
        final exists = goals.any((g) {
          final map = Map.from(g as Map);
          return map['name']?.toString() == name &&
              _asDouble(map['target']) == target;
        });
        if (!exists) goals.add(goal);
      }
      settingsBox.put('goals', goals);
      changed = true;
    }

    final legacyPlanner = Map.from(legacy.get(
      'planner',
      defaultValue: {'fixedExpenses': [], 'sips': []},
    ));
    final legacyFixed = List.from(legacyPlanner['fixedExpenses'] ?? []);
    final legacySips = List.from(legacyPlanner['sips'] ?? []);
    if (legacyFixed.isNotEmpty || legacySips.isNotEmpty) {
      final planner = Map.from(settingsBox.get(
        'planner',
        defaultValue: {'fixedExpenses': [], 'sips': []},
      ));
      final fixed = List.from(planner['fixedExpenses'] ?? []);
      final sips = List.from(planner['sips'] ?? []);

      for (final item in legacyFixed) {
        final entry = Map.from(item as Map);
        if (!_containsNamedAmount(fixed, entry)) fixed.add(entry);
      }
      for (final item in legacySips) {
        final entry = Map.from(item as Map);
        if (!_containsNamedAmount(sips, entry)) sips.add(entry);
      }

      planner['fixedExpenses'] = fixed;
      planner['sips'] = sips;
      settingsBox.put('planner', planner);
      changed = true;
    }

    if (changed) settingsBox.flush();
  }

  bool _containsNamedAmount(List items, Map entry) {
    final name = entry['name']?.toString() ?? '';
    final amount = _asDouble(entry['amount']);
    return items.any((item) {
      final map = Map.from(item as Map);
      return map['name']?.toString() == name &&
          _asDouble(map['amount']) == amount;
    });
  }

  void _showAddModal(String type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        switch (type) {
          case 'transaction':
            return _AddEditTransactionModal(txBox: txBox);
          case 'vault':
            return _AddVaultModal(vaultBox: vaultBox);
          case 'budget':
            return _AddBudgetModal(settingsBox: settingsBox);
          case 'planner':
            return _AddPlannerModal(settingsBox: settingsBox);
          default:
            return _AddGoalModal(settingsBox: settingsBox);
        }
      },
    );
  }

  void _showEditTransactionModal(Transaction tx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          _AddEditTransactionModal(txBox: txBox, existingTx: tx),
    );
  }

  void _showUpdateGoalModal(int index, Map goal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _UpdateGoalModal(
        settingsBox: settingsBox,
        goalIndex: index,
        goal: goal,
      ),
    );
  }

  void _confirmDelete(String title, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BentoTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: BentoTheme.textSecondary.withValues(alpha: 0.12)),
        ),
        title: Text(title, style: TextStyle(color: BentoTheme.textPrimary)),
        content: Text(
          'This cannot be undone.',
          style: TextStyle(color: BentoTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: BentoTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  FinanceSnapshot _buildSnapshot(
    Iterable<Transaction> transactions,
    Iterable<AssetVault> vaults,
    Box settings,
  ) {
    return FinanceCalculator.calculate(
      transactions: transactions,
      vaults: vaults,
      settings: settings,
      selectedMonth: _selectedMonth,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: txBox.listenable(),
          builder: (context, Box<Transaction> tBox, _) {
            return ValueListenableBuilder(
              valueListenable: vaultBox.listenable(),
              builder: (context, Box<AssetVault> vBox, _) {
                return ValueListenableBuilder(
                  valueListenable: settingsBox.listenable(),
                  builder: (context, Box sBox, _) {
                    final snapshot =
                        _buildSnapshot(tBox.values, vBox.values, sBox);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FinanceHeader(
                          selectedMonth: _selectedMonth,
                          tabs: _tabs,
                          tabController: _tabController,
                          onPreviousMonth: () => setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month - 1,
                            );
                          }),
                          onNextMonth: () => setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month + 1,
                            );
                          }),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: _tabs.map((tab) {
                              return SingleChildScrollView(
                                key: ValueKey(tab.id),
                                physics: const BouncingScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 36),
                                child: _buildTabForId(
                                  tab.id,
                                  snapshot,
                                  vBox.values.toList(),
                                  tBox.values.toList(),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabForId(
    String tabId,
    FinanceSnapshot snapshot,
    List<AssetVault> vaults,
    List<Transaction> allTransactions,
  ) {
    switch (tabId) {
      case 'transactions':
        return _TransactionsTab(
          transactions: snapshot.monthTransactions,
          selectedMonth: _selectedMonth,
          onAdd: () => _showAddModal('transaction'),
          onEdit: _showEditTransactionModal,
          onDelete: (tx) => _confirmDelete('Delete transaction?', tx.delete),
        );
      case 'budget':
        return _BudgetTab(
          snapshot: snapshot,
          onAdd: () => _showAddModal('budget'),
          onDelete: (index) => _confirmDelete('Delete budget?', () {
            final budgets = List.from(snapshot.budgets);
            budgets.removeAt(index);
            settingsBox.put('budgets', budgets);
          }),
        );
      case 'planner':
        return _PlannerTab(
          snapshot: snapshot,
          onAdd: () => _showAddModal('planner'),
          onDeleteFixed: (index) => _confirmDelete('Delete commitment?', () {
            final planner = Map.from(snapshot.planner);
            final fixed = List.from(planner['fixedExpenses'] ?? []);
            fixed.removeAt(index);
            planner['fixedExpenses'] = fixed;
            settingsBox.put('planner', planner);
          }),
          onDeleteSip: (index) => _confirmDelete('Delete SIP?', () {
            final planner = Map.from(snapshot.planner);
            final sips = List.from(planner['sips'] ?? []);
            if (index < sips.length) {
              final removed = Map.from(sips.removeAt(index) as Map);
              planner['sips'] = sips;
              settingsBox.put('planner', planner);
              final id = removed['id']?.toString();
              if (id != null) {
                final ledger = Map<String, dynamic>.from(
                    settingsBox.get('sip_ledger', defaultValue: {}));
                ledger.remove(id);
                settingsBox.put('sip_ledger', ledger);
              }
            }
          }),
        );
      case 'goals':
        return _GoalsTab(
          goals: snapshot.goals,
          onAdd: () => _showAddModal('goal'),
          onUpdate: _showUpdateGoalModal,
          onDelete: (index) => _confirmDelete('Delete goal?', () {
            final goals = List.from(snapshot.goals);
            goals.removeAt(index);
            settingsBox.put('goals', goals);
          }),
        );
      default:
        return _OverviewTab(
          snapshot: snapshot,
          vaults: vaults,
          transactions: allTransactions
            ..sort((a, b) => b.date.compareTo(a.date)),
          onAddTransaction: () => _showAddModal('transaction'),
          onAddVault: () => _showAddModal('vault'),
          onEditTransaction: _showEditTransactionModal,
          onDeleteVault: (vault) =>
              _confirmDelete('Delete vault?', vault.delete),
        );
    }
  }
}

class _FinanceTab {
  final String id;
  final String label;
  final IconData icon;
  const _FinanceTab(this.id, this.label, this.icon);
}

class _FinanceHeader extends StatelessWidget {
  final DateTime selectedMonth;
  final List<_FinanceTab> tabs;
  final TabController tabController;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const _FinanceHeader({
    required this.selectedMonth,
    required this.tabs,
    required this.tabController,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TabBar(
            controller: tabController,
            isScrollable: true,
            indicatorColor: BentoTheme.accent,
            labelColor: BentoTheme.accent,
            unselectedLabelColor: BentoTheme.textSecondary,
            indicatorWeight: 3,
            tabs: tabs.map((t) => Tab(text: t.label)).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _IconButton(
                  icon: LucideIcons.chevronLeft, onTap: onPreviousMonth),
              SizedBox(
                width: 150,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Text(
                    DateFormat('MMMM yyyy').format(selectedMonth),
                    key: ValueKey(DateFormat('yyyy-MM').format(selectedMonth)),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
              _IconButton(icon: LucideIcons.chevronRight, onTap: onNextMonth),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final FinanceSnapshot snapshot;
  final List<AssetVault> vaults;
  final List<Transaction> transactions;
  final VoidCallback onAddTransaction;
  final VoidCallback onAddVault;
  final ValueChanged<Transaction> onEditTransaction;
  final ValueChanged<AssetVault> onDeleteVault;

  const _OverviewTab({
    required this.snapshot,
    required this.vaults,
    required this.transactions,
    required this.onAddTransaction,
    required this.onAddVault,
    required this.onEditTransaction,
    required this.onDeleteVault,
  });

  @override
  Widget build(BuildContext context) {
    final recent = transactions.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BalancePanel(snapshot: snapshot, onAddTransaction: onAddTransaction),
        const SizedBox(height: 12),
        _MetricGrid(cards: [
          _MetricData('Income', _money(snapshot.monthIncome),
              LucideIcons.trendingUp, const Color(0xFF22C55E)),
          _MetricData('Expenses', _money(snapshot.monthExpense),
              LucideIcons.trendingDown, const Color(0xFFEF4444)),
          _MetricData('Saved', _money(snapshot.monthNet), LucideIcons.wallet,
              BentoTheme.accent),
          _MetricData('SIP / mo', _money(snapshot.sipTotal),
              LucideIcons.lineChart, const Color(0xFF60A5FA)),
        ]),
        const SizedBox(height: 18),
        _SectionHeader(title: 'Overview graph'),
        _OverviewGraphPanel(snapshot: snapshot),
        const SizedBox(height: 18),
        _SectionHeader(title: 'Spending by category'),
        snapshot.categoryBreakdown.isEmpty
            ? const _EmptyState(text: 'No expenses in this month.')
            : _CategoryList(items: snapshot.categoryBreakdown),
        const SizedBox(height: 18),
        _SectionHeader(
            title: 'Vaults', actionLabel: 'Add', onAction: onAddVault),
        vaults.isEmpty
            ? const _EmptyState(text: 'No vaults yet.')
            : Column(
                children: vaults
                    .map((vault) => _VaultTile(
                        vault: vault, onDelete: () => onDeleteVault(vault)))
                    .toList(),
              ),
        const SizedBox(height: 18),
        _SectionHeader(title: 'Recent transactions'),
        recent.isEmpty
            ? const _EmptyState(text: 'No transactions yet.')
            : Column(
                children: recent
                    .map((tx) => _TransactionTile(
                          tx: tx,
                          onTap: () => onEditTransaction(tx),
                        ))
                    .toList(),
              ),
      ],
    );
  }
}

class _TransactionsTab extends StatefulWidget {
  final List<Transaction> transactions;
  final DateTime selectedMonth;
  final VoidCallback onAdd;
  final ValueChanged<Transaction> onEdit;
  final ValueChanged<Transaction> onDelete;

  const _TransactionsTab({
    required this.transactions,
    required this.selectedMonth,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<_TransactionsTab> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.transactions.where((tx) {
      if (_filter == 'income') return !_isExpense(tx);
      if (_filter == 'expense') return _isExpense(tx);
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: DateFormat('MMMM transactions').format(widget.selectedMonth),
          actionLabel: 'Log',
          onAction: widget.onAdd,
        ),
        _SegmentedControl(
          values: const {
            'all': 'All',
            'income': 'Income',
            'expense': 'Expense'
          },
          selected: _filter,
          onChanged: (value) => setState(() => _filter = value),
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          const _EmptyState(text: 'No matching transactions.')
        else
          Column(
            children: filtered
                .map((tx) => Dismissible(
                      key: ValueKey(
                          '${tx.key}-${tx.date.microsecondsSinceEpoch}'),
                      direction: DismissDirection.endToStart,
                      background: const _DismissBackground(),
                      onDismissed: (_) => widget.onDelete(tx),
                      child: _TransactionTile(
                          tx: tx, onTap: () => widget.onEdit(tx)),
                    ))
                .toList(),
          ),
      ],
    );
  }
}

class _BudgetTab extends StatelessWidget {
  final FinanceSnapshot snapshot;
  final VoidCallback onAdd;
  final ValueChanged<int> onDelete;

  const _BudgetTab({
    required this.snapshot,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = snapshot.budgetLimit <= 0
        ? 0.0
        : (snapshot.budgetSpent / snapshot.budgetLimit).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
            title: 'Budget control', actionLabel: 'Add', onAction: onAdd),
        _SummaryPanel(
          title: 'Monthly budget',
          amount: _money(snapshot.budgetSpent),
          subtitle: snapshot.budgetLimit > 0
              ? '${_money(snapshot.budgetLimit - snapshot.budgetSpent)} remaining'
              : 'No monthly limits set',
          progress: progress,
          progressColor: progress > 0.9
              ? const Color(0xFFEF4444)
              : const Color(0xFF22C55E),
        ),
        const SizedBox(height: 16),
        snapshot.budgets.isEmpty
            ? const _EmptyState(text: 'No budget categories set.')
            : Column(
                children: snapshot.budgets.asMap().entries.map((entry) {
                  final budget = Map.from(entry.value as Map);
                  final category = budget['category']?.toString() ?? 'Other';
                  final limit = _asDouble(budget['total']);
                  final spent = snapshot.categorySpent[category] ?? 0.0;
                  return _BudgetTile(
                    category: category,
                    spent: spent,
                    limit: limit,
                    color: _chartColors[entry.key % _chartColors.length],
                    onDelete: () => onDelete(entry.key),
                  );
                }).toList(),
              ),
        if (snapshot.budgetSpent > 0 && snapshot.budgets.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionHeader(title: 'Budget allocation'),
          _ChartPanel(
            height: 220,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 54,
                sectionsSpace: 2,
                sections: snapshot.budgets.asMap().entries.map((entry) {
                  final budget = Map.from(entry.value as Map);
                  final category = budget['category']?.toString() ?? 'Other';
                  final spent = snapshot.categorySpent[category] ?? 0.0;
                  return PieChartSectionData(
                    value: spent <= 0 ? 0.01 : spent,
                    color: _chartColors[entry.key % _chartColors.length],
                    radius: 46,
                    title: spent <= 0 ? '' : _compactMoney(spent),
                    titleStyle: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PlannerTab extends StatelessWidget {
  final FinanceSnapshot snapshot;
  final VoidCallback onAdd;
  final ValueChanged<int> onDeleteFixed;
  final ValueChanged<int> onDeleteSip;

  const _PlannerTab({
    required this.snapshot,
    required this.onAdd,
    required this.onDeleteFixed,
    required this.onDeleteSip,
  });

  @override
  Widget build(BuildContext context) {
    final fixed = List.from(snapshot.planner['fixedExpenses'] ?? []);
    final sips = List.from(snapshot.planner['sips'] ?? []);
    final plannedTotal = snapshot.fixedTotal + snapshot.sipTotal;

    // Fix double-count: only subtract SIPs not yet posted this month
    final settingsBox = Hive.box('finance_settings');
    final ledger = Map<String, dynamic>.from(
        settingsBox.get('sip_ledger', defaultValue: {}));
    final now = DateTime.now();
    final currentMonthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    double unpostedSipTotal = 0;
    for (final s in sips) {
      final item = Map.from(s as Map);
      final id = item['id']?.toString() ?? '';
      final lastPosted = ledger[id]?.toString();
      final isPosted =
          lastPosted != null && lastPosted.compareTo(currentMonthKey) >= 0;
      if (!isPosted) {
        unpostedSipTotal += _asDouble(item['amount']);
      }
    }

    final afterPlan = snapshot.monthIncome -
        snapshot.monthExpense -
        snapshot.fixedTotal -
        unpostedSipTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
            title: 'Monthly planner', actionLabel: 'Add', onAction: onAdd),
        _MetricGrid(cards: [
          _MetricData('Fixed', _money(snapshot.fixedTotal),
              LucideIcons.calendar, const Color(0xFFF59E0B)),
          _MetricData('SIP', _money(snapshot.sipTotal), LucideIcons.lineChart,
              const Color(0xFF60A5FA)),
          _MetricData('Planned', _money(plannedTotal), LucideIcons.pieChart,
              BentoTheme.accent),
          _MetricData(
              'After plan',
              _money(afterPlan),
              LucideIcons.wallet,
              afterPlan >= 0
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFEF4444)),
        ]),
        const SizedBox(height: 18),
        _SectionHeader(title: 'Fixed expenses'),
        fixed.isEmpty
            ? const _EmptyState(text: 'No fixed expenses set.')
            : Column(
                children: fixed.asMap().entries.map((entry) {
                  final item = Map.from(entry.value as Map);
                  return _PlannerTile(
                    title: item['name']?.toString() ?? 'Commitment',
                    label: item['category']?.toString() ?? 'Fixed',
                    amount: _asDouble(item['amount']),
                    due: _asInt(item['due']),
                    icon: LucideIcons.calendar,
                    color: const Color(0xFFF59E0B),
                    onDelete: () => onDeleteFixed(entry.key),
                  );
                }).toList(),
              ),
        const SizedBox(height: 18),
        _SectionHeader(title: 'SIP schedule'),
        sips.isEmpty
            ? const _EmptyState(text: 'No SIPs set.')
            : Column(
                children: sips.asMap().entries.map((entry) {
                  final item = Map.from(entry.value as Map);
                  final nextDebitDate = SipService.getNextDebitDate(item);
                  final nextDebitStr =
                      DateFormat('MMM d').format(nextDebitDate);
                  return _PlannerTile(
                    title: item['name']?.toString() ?? 'SIP',
                    label: item['folio']?.toString() ?? 'Investment',
                    amount: _asDouble(item['amount']),
                    due: _asInt(item['due'], fallback: 5),
                    nextDebit: nextDebitStr,
                    icon: LucideIcons.lineChart,
                    color: const Color(0xFF60A5FA),
                    onDelete: () => onDeleteSip(entry.key),
                  );
                }).toList(),
              ),
      ],
    );
  }
}

class _GoalsTab extends StatelessWidget {
  final List goals;
  final VoidCallback onAdd;
  final void Function(int index, Map goal) onUpdate;
  final ValueChanged<int> onDelete;

  const _GoalsTab({
    required this.goals,
    required this.onAdd,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final target = goals.fold<double>(
        0, (sum, item) => sum + _asDouble((item as Map)['target']));
    final saved = goals.fold<double>(
        0, (sum, item) => sum + _asDouble((item as Map)['saved']));
    final progress = target <= 0 ? 0.0 : (saved / target).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
            title: 'Finance goals', actionLabel: 'Add', onAction: onAdd),
        _SummaryPanel(
          title: 'Saved toward goals',
          amount: _money(saved),
          subtitle: target > 0
              ? '${_money(target - saved)} remaining'
              : 'No target set',
          progress: progress,
          progressColor: const Color(0xFF2DD4BF),
        ),
        const SizedBox(height: 16),
        goals.isEmpty
            ? const _EmptyState(text: 'No finance goals set.')
            : Column(
                children: goals.asMap().entries.map((entry) {
                  final goal = Map.from(entry.value as Map);
                  return _GoalTile(
                    goal: goal,
                    color: _chartColors[entry.key % _chartColors.length],
                    onUpdate: () => onUpdate(entry.key, goal),
                    onDelete: () => onDelete(entry.key),
                  );
                }).toList(),
              ),
      ],
    );
  }
}

class _OverviewGraphPanel extends StatefulWidget {
  final FinanceSnapshot snapshot;

  const _OverviewGraphPanel({required this.snapshot});

  @override
  State<_OverviewGraphPanel> createState() => _OverviewGraphPanelState();
}

class _OverviewGraphPanelState extends State<_OverviewGraphPanel> {
  String _mode = 'flow';

  @override
  Widget build(BuildContext context) {
    Widget chart;
    switch (_mode) {
      case 'net':
        chart = _NetTrendChart(data: widget.snapshot.cashFlowTrend);
        break;
      case 'categories':
        chart = widget.snapshot.categoryBreakdown.isEmpty
            ? const _InlineGraphEmpty(text: 'No category spending this month.')
            : _CategoryDonutChart(items: widget.snapshot.categoryBreakdown);
        break;
      default:
        chart = _CashFlowChart(data: widget.snapshot.cashFlowTrend);
    }

    return _Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _SegmentedControl(
            values: const {
              'flow': 'Flow',
              'net': 'Net',
              'categories': 'Categories',
            },
            selected: _mode,
            onChanged: (value) => setState(() => _mode = value),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_mode),
                child: chart,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineGraphEmpty extends StatelessWidget {
  final String text;

  const _InlineGraphEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.info, color: BentoTheme.textSecondary, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _BalancePanel extends StatelessWidget {
  final FinanceSnapshot snapshot;
  final VoidCallback onAddTransaction;

  const _BalancePanel({required this.snapshot, required this.onAddTransaction});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tracked balance',
                  style: TextStyle(
                    color: BentoTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _SmallActionButton(
                  label: 'Log',
                  icon: LucideIcons.plus,
                  onTap: onAddTransaction),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _money(snapshot.totalBalance),
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: snapshot.savingsRate,
              color: snapshot.savingsRate >= 0.2
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFF59E0B),
              backgroundColor: BentoTheme.textSecondary.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Savings rate ${(snapshot.savingsRate * 100).toStringAsFixed(0)}%',
            style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final List<_MetricData> cards;
  const _MetricGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 620 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: columns == 4 ? 1.7 : 1.45,
          ),
          itemBuilder: (context, index) => _MetricCard(data: cards[index]),
        );
      },
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MetricData(this.label, this.value, this.icon, this.color);
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;
  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: data.color, size: 18),
          const Spacer(),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  final String title;
  final String amount;
  final String subtitle;
  final double progress;
  final Color progressColor;

  const _SummaryPanel({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.progress,
    required this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              color: progressColor,
              backgroundColor: BentoTheme.textSecondary.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 8),
          Text(subtitle,
              style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _CashFlowChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _CashFlowChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxValue = data.fold<double>(0, (max, item) {
      final income = _asDouble(item['income']);
      final expense = _asDouble(item['expense']);
      return [max, income, expense].reduce((a, b) => a > b ? a : b);
    });

    return BarChart(
      BarChartData(
        maxY: maxValue <= 0 ? 100 : maxValue * 1.18,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => BentoTheme.background,
            tooltipBorderRadius: BorderRadius.circular(8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = rodIndex == 0 ? 'Income' : 'Expense';
              return BarTooltipItem(
                '$label\n${_money(rod.toY)}',
                TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: BentoTheme.textSecondary.withValues(alpha: 0.08),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length)
                  return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    data[index]['month'].toString(),
                    style: TextStyle(
                        color: BentoTheme.textSecondary, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: data.asMap().entries.map((entry) {
          final item = entry.value;
          return BarChartGroupData(
            x: entry.key,
            barsSpace: 4,
            barRods: [
              BarChartRodData(
                toY: _asDouble(item['income']),
                width: 8,
                borderRadius: BorderRadius.circular(4),
                color: const Color(0xFF22C55E),
              ),
              BarChartRodData(
                toY: _asDouble(item['expense']),
                width: 8,
                borderRadius: BorderRadius.circular(4),
                color: const Color(0xFFEF4444),
              ),
            ],
          );
        }).toList(),
      ),
      duration: const Duration(milliseconds: 350),
    );
  }
}

class _NetTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _NetTrendChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = data.asMap().entries.map((entry) {
      final income = _asDouble(entry.value['income']);
      final expense = _asDouble(entry.value['expense']);
      return FlSpot(entry.key.toDouble(), income - expense);
    }).toList();

    final minValue =
        spots.fold<double>(0, (min, spot) => spot.y < min ? spot.y : min);
    final maxValue =
        spots.fold<double>(0, (max, spot) => spot.y > max ? spot.y : max);
    final padding = ((maxValue - minValue).abs() * 0.18).clamp(100.0, 100000.0);

    return LineChart(
      LineChartData(
        minY: minValue - padding,
        maxY: maxValue + padding,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => BentoTheme.background,
            tooltipBorderRadius: BorderRadius.circular(8),
            getTooltipItems: (spots) {
              return spots.map((spot) {
                return LineTooltipItem(
                  _money(spot.y),
                  TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: value == 0
                ? BentoTheme.accent.withValues(alpha: 0.26)
                : BentoTheme.textSecondary.withValues(alpha: 0.08),
            strokeWidth: value == 0 ? 1.4 : 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    data[index]['month'].toString(),
                    style: TextStyle(
                        color: BentoTheme.textSecondary, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.28,
            color: BentoTheme.accent,
            barWidth: 2.6,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final color = spot.y >= 0
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444);
                return FlDotCirclePainter(
                  radius: 3.2,
                  color: color,
                  strokeWidth: 1.5,
                  strokeColor: BentoTheme.background,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  BentoTheme.accent.withValues(alpha: 0.20),
                  BentoTheme.accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 350),
    );
  }
}

class _CategoryDonutChart extends StatefulWidget {
  final List<Map<String, dynamic>> items;

  const _CategoryDonutChart({required this.items});

  @override
  State<_CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<_CategoryDonutChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final total = widget.items
        .fold<double>(0, (sum, item) => sum + _asDouble(item['value']));
    final selected = _touchedIndex >= 0 && _touchedIndex < widget.items.length
        ? widget.items[_touchedIndex]
        : (widget.items.isNotEmpty ? widget.items.first : null);

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 52,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  final section = response?.touchedSection;
                  if (!event.isInterestedForInteractions || section == null) {
                    setState(() => _touchedIndex = -1);
                    return;
                  }
                  setState(() => _touchedIndex = section.touchedSectionIndex);
                },
              ),
              sections: widget.items.asMap().entries.map((entry) {
                final amount = _asDouble(entry.value['value']);
                final selected = entry.key == _touchedIndex;
                final percent = total <= 0 ? 0 : amount / total * 100;
                return PieChartSectionData(
                  value: amount <= 0 ? 0.01 : amount,
                  color: _chartColors[entry.key % _chartColors.length],
                  radius: selected ? 58 : 48,
                  title: percent < 7 ? '' : '${percent.toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                );
              }).toList(),
            ),
            duration: const Duration(milliseconds: 350),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: selected == null
              ? const SizedBox.shrink()
              : Row(
                  key: ValueKey(selected['name']),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      selected['name'].toString(),
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _money(_asDouble(selected['value'])),
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CategoryList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _CategoryList({required this.items});

  @override
  Widget build(BuildContext context) {
    final total =
        items.fold<double>(0, (sum, item) => sum + _asDouble(item['value']));
    return Column(
      children: items.asMap().entries.map((entry) {
        final item = entry.value;
        final amount = _asDouble(item['value']);
        final progress = total <= 0 ? 0.0 : (amount / total).clamp(0.0, 1.0);
        return _ProgressRow(
          title: item['name'].toString(),
          trailing: _money(amount),
          progress: progress,
          color: _chartColors[entry.key % _chartColors.length],
        );
      }).toList(),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  final String category;
  final double spent;
  final double limit;
  final Color color;
  final VoidCallback onDelete;

  const _BudgetTile({
    required this.category,
    required this.spent,
    required this.limit,
    required this.color,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
    return Dismissible(
      key: ValueKey('budget-$category-$limit'),
      direction: DismissDirection.endToStart,
      background: const _DismissBackground(),
      onDismissed: (_) => onDelete(),
      child: _ProgressRow(
        title: category,
        trailing: '${_money(spent)} / ${_money(limit)}',
        progress: progress,
        color: progress > 0.9 ? const Color(0xFFEF4444) : color,
      ),
    );
  }
}

class _PlannerTile extends StatelessWidget {
  final String title;
  final String label;
  final double amount;
  final int due;
  final IconData icon;
  final Color color;
  final VoidCallback onDelete;
  final String? nextDebit;

  const _PlannerTile({
    required this.title,
    required this.label,
    required this.amount,
    required this.due,
    required this.icon,
    required this.color,
    required this.onDelete,
    this.nextDebit,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('planner-$title-$amount-$due'),
      direction: DismissDirection.endToStart,
      background: const _DismissBackground(),
      onDismissed: (_) => onDelete(),
      child: _Panel(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _TileIcon(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    nextDebit != null
                        ? '$label · Next debit: $nextDebit'
                        : '$label - due day $due',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: BentoTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _money(amount),
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final Map goal;
  final Color color;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  const _GoalTile({
    required this.goal,
    required this.color,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = goal['name']?.toString() ?? 'Goal';
    final target = _asDouble(goal['target']);
    final saved = _asDouble(goal['saved']);
    final progress = target <= 0 ? 0.0 : (saved / target).clamp(0.0, 1.0);
    final deadline = goal['deadline']?.toString() ?? '';

    return Dismissible(
      key: ValueKey('goal-$name-$target'),
      direction: DismissDirection.endToStart,
      background: const _DismissBackground(),
      onDismissed: (_) => onDelete(),
      child: _Panel(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TileIcon(icon: LucideIcons.flag, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (deadline.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          deadline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: BentoTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                _SmallActionButton(
                    label: 'Add', icon: LucideIcons.plus, onTap: onUpdate),
              ],
            ),
            const SizedBox(height: 12),
            _ProgressLine(progress: progress, color: color),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _money(saved),
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _money(target),
                  style:
                      TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VaultTile extends StatelessWidget {
  final AssetVault vault;
  final VoidCallback onDelete;

  const _VaultTile({required this.vault, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('vault-${vault.key}-${vault.name}'),
      direction: DismissDirection.endToStart,
      background: const _DismissBackground(),
      onDismissed: (_) => onDelete(),
      child: _Panel(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _TileIcon(icon: LucideIcons.wallet, color: Color(vault.colorValue)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vault.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    vault.type,
                    style: TextStyle(
                        color: BentoTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              _money(vault.balance),
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction tx;
  final VoidCallback onTap;

  const _TransactionTile({required this.tx, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final expense = _isExpense(tx);
    final color = expense ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
    return GestureDetector(
      onTap: onTap,
      child: _Panel(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _TileIcon(
              icon: expense ? LucideIcons.trendingDown : LucideIcons.trendingUp,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${DateFormat('MMM d').format(tx.date)} - ${tx.category}',
                    style: TextStyle(
                        color: BentoTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '${expense ? '-' : '+'}${_money(tx.amount.abs())}',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String title;
  final String trailing;
  final double progress;
  final Color color;

  const _ProgressRow({
    required this.title,
    required this.trailing,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                trailing,
                style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ProgressLine(progress: progress, color: color),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final double progress;
  final Color color;
  const _ProgressLine({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        minHeight: 7,
        value: progress,
        color: color,
        backgroundColor: BentoTheme.textSecondary.withValues(alpha: 0.12),
      ),
    );
  }
}

class _ChartPanel extends StatelessWidget {
  final Widget child;
  final double height;
  const _ChartPanel({required this.child, this.height = 210});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(14),
      child: SizedBox(height: height, child: child),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (onAction != null && actionLabel != null)
            _SmallActionButton(
                label: actionLabel!, icon: LucideIcons.plus, onTap: onAction!),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: BentoTheme.textSecondary.withValues(alpha: 0.10)),
      ),
      child: child,
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SmallActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: BentoTheme.accent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: BentoTheme.background),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: BentoTheme.background,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: BentoTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: BentoTheme.textSecondary.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, color: BentoTheme.textPrimary, size: 18),
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _TileIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(LucideIcons.info, color: BentoTheme.textSecondary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 18),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(LucideIcons.trash, color: Colors.white, size: 20),
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  final Map<String, String> values;
  final String selected;
  final ValueChanged<String> onChanged;

  const _SegmentedControl({
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: BentoTheme.textSecondary.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: values.entries.map((entry) {
          final active = selected == entry.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? BentoTheme.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color: active
                        ? BentoTheme.background
                        : BentoTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AddEditTransactionModal extends StatefulWidget {
  final Box<Transaction> txBox;
  final Transaction? existingTx;

  const _AddEditTransactionModal({required this.txBox, this.existingTx});

  @override
  State<_AddEditTransactionModal> createState() =>
      _AddEditTransactionModalState();
}

class _AddEditTransactionModalState extends State<_AddEditTransactionModal> {
  String type = 'expense';
  String title = '';
  String amount = '';
  String category = 'Food';
  String mode = 'UPI';

  @override
  void initState() {
    super.initState();
    final tx = widget.existingTx;
    if (tx != null) {
      type = _isExpense(tx) ? 'expense' : 'income';
      title = tx.title;
      amount = tx.amount.abs().toString();
      category = tx.category;
      mode = tx.mode;
    }
  }

  void _save() {
    final parsed = safeParse(amount);
    if (title.trim().isEmpty || parsed <= 0) return;

    final tx = widget.existingTx;
    final finalCategory = type == 'income' ? 'Income' : category;
    if (tx != null) {
      tx.title = title.trim();
      tx.amount = type == 'expense' ? -parsed.abs() : parsed.abs();
      tx.category = finalCategory;
      tx.mode = type;
      tx.icon = type;
      tx.save();
    } else {
      widget.txBox.add(Transaction(
        title: title.trim(),
        amount: type == 'expense' ? -parsed.abs() : parsed.abs(),
        category: finalCategory,
        date: DateTime.now(),
        mode: type,
        icon: type,
      ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _BaseModal(
      title: widget.existingTx == null ? 'Log transaction' : 'Edit transaction',
      onSave: _save,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentedControl(
            values: const {'expense': 'Expense', 'income': 'Income'},
            selected: type,
            onChanged: (value) => setState(() => type = value),
          ),
          const SizedBox(height: 12),
          _ModalInput(
              label: 'Title',
              initialValue: title,
              onChanged: (value) => title = value),
          _ModalInput(
            label: 'Amount',
            initialValue: amount,
            keyboardType: TextInputType.number,
            onChanged: (value) => amount = value,
          ),
          if (type == 'expense')
            _ModalDropdown(
              label: 'Category',
              value: kExpenseCategories.contains(category) ? category : 'Other',
              items: kExpenseCategories,
              onChanged: (value) => setState(() => category = value ?? 'Other'),
            ),
          _ModalInput(
              label: 'Mode',
              initialValue: mode,
              onChanged: (value) => mode = value),
        ],
      ),
    );
  }
}

class _AddVaultModal extends StatefulWidget {
  final Box<AssetVault> vaultBox;
  const _AddVaultModal({required this.vaultBox});

  @override
  State<_AddVaultModal> createState() => _AddVaultModalState();
}

class _AddVaultModalState extends State<_AddVaultModal> {
  String name = '';
  String balance = '';
  String type = 'Savings';

  void _save() {
    final parsed = safeParse(balance);
    if (name.trim().isEmpty || parsed <= 0) return;
    widget.vaultBox.add(AssetVault(
      name: name.trim(),
      balance: parsed,
      bank: type,
      type: type,
      colorValue:
          _chartColors[widget.vaultBox.length % _chartColors.length].toARGB32(),
    ));
    GlobalXPService.addXP(15);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _BaseModal(
      title: 'New vault',
      onSave: _save,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModalInput(label: 'Vault name', onChanged: (value) => name = value),
          _ModalInput(
            label: 'Balance',
            keyboardType: TextInputType.number,
            onChanged: (value) => balance = value,
          ),
          _ModalDropdown(
            label: 'Type',
            value: type,
            items: const [
              'Savings',
              'Current',
              'UPI Wallet',
              'Investment',
              'Cash'
            ],
            onChanged: (value) => setState(() => type = value ?? 'Savings'),
          ),
        ],
      ),
    );
  }
}

class _AddBudgetModal extends StatefulWidget {
  final Box settingsBox;
  const _AddBudgetModal({required this.settingsBox});

  @override
  State<_AddBudgetModal> createState() => _AddBudgetModalState();
}

class _AddBudgetModalState extends State<_AddBudgetModal> {
  String category = 'Food';
  String limit = '';

  void _save() {
    final parsed = safeParse(limit);
    if (parsed <= 0) return;
    final budgets =
        List.from(widget.settingsBox.get('budgets', defaultValue: []));
    final index = budgets.indexWhere((item) {
      final map = Map.from(item as Map);
      return map['category']?.toString() == category;
    });
    final entry = {
      'category': category,
      'total': parsed,
      'color': _chartColors[
              (index >= 0 ? index : budgets.length) % _chartColors.length]
          .toARGB32(),
    };
    if (index >= 0) {
      budgets[index] = entry;
    } else {
      budgets.add(entry);
    }
    widget.settingsBox.put('budgets', budgets);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _BaseModal(
      title: 'Budget category',
      onSave: _save,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModalDropdown(
            label: 'Category',
            value: category,
            items: kExpenseCategories,
            onChanged: (value) => setState(() => category = value ?? 'Other'),
          ),
          _ModalInput(
            label: 'Monthly limit',
            keyboardType: TextInputType.number,
            onChanged: (value) => limit = value,
          ),
        ],
      ),
    );
  }
}

class _AddPlannerModal extends StatefulWidget {
  final Box settingsBox;
  const _AddPlannerModal({required this.settingsBox});

  @override
  State<_AddPlannerModal> createState() => _AddPlannerModalState();
}

class _AddPlannerModalState extends State<_AddPlannerModal> {
  String type = 'fixed';
  String name = '';
  String amount = '';
  String due = '1';
  String label = 'EMI';

  void _save() {
    final parsed = safeParse(amount);
    if (name.trim().isEmpty || parsed <= 0) return;

    final planner = Map.from(widget.settingsBox.get(
      'planner',
      defaultValue: {'fixedExpenses': [], 'sips': []},
    ));
    if (type == 'fixed') {
      final fixed = List.from(planner['fixedExpenses'] ?? []);
      fixed.add({
        'name': name.trim(),
        'amount': parsed,
        'due': int.tryParse(due.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1,
        'category': label.trim().isEmpty ? 'Fixed' : label.trim(),
      });
      planner['fixedExpenses'] = fixed;
    } else {
      final sips = List.from(planner['sips'] ?? []);
      final now = DateTime.now();
      sips.add({
        'id': 'sip_${now.millisecondsSinceEpoch}',
        'createdAt': now.toIso8601String(),
        'name': name.trim(),
        'amount': parsed,
        'due': int.tryParse(due.replaceAll(RegExp(r'[^0-9]'), '')) ?? 5,
        'folio': label.trim().isEmpty ? 'Investment' : label.trim(),
      });
      planner['sips'] = sips;
    }
    widget.settingsBox.put('planner', planner);
    SipService.runDue();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _BaseModal(
      title: 'Monthly planner item',
      onSave: _save,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentedControl(
            values: const {'fixed': 'Fixed', 'sip': 'SIP'},
            selected: type,
            onChanged: (value) => setState(() {
              type = value;
              label = value == 'fixed' ? 'EMI' : 'Investment';
            }),
          ),
          const SizedBox(height: 12),
          _ModalInput(label: 'Name', onChanged: (value) => name = value),
          _ModalInput(
            label: 'Amount',
            keyboardType: TextInputType.number,
            onChanged: (value) => amount = value,
          ),
          _ModalInput(
            label: 'Due day',
            initialValue: due,
            keyboardType: TextInputType.number,
            onChanged: (value) => due = value,
          ),
          _ModalInput(
            label: type == 'fixed' ? 'Category' : 'Platform',
            initialValue: label,
            onChanged: (value) => label = value,
          ),
        ],
      ),
    );
  }
}

class _AddGoalModal extends StatefulWidget {
  final Box settingsBox;
  const _AddGoalModal({required this.settingsBox});

  @override
  State<_AddGoalModal> createState() => _AddGoalModalState();
}

class _AddGoalModalState extends State<_AddGoalModal> {
  String name = '';
  String target = '';
  String saved = '';
  String deadline = '';

  void _save() {
    final targetAmount = safeParse(target);
    if (name.trim().isEmpty || targetAmount <= 0) return;
    final goals = List.from(widget.settingsBox.get('goals', defaultValue: []));
    goals.add({
      'name': name.trim(),
      'target': targetAmount,
      'saved': safeParse(saved),
      'deadline': deadline.trim(),
      'color': _chartColors[goals.length % _chartColors.length].toARGB32(),
    });
    widget.settingsBox.put('goals', goals);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _BaseModal(
      title: 'Finance goal',
      onSave: _save,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModalInput(label: 'Goal name', onChanged: (value) => name = value),
          _ModalInput(
            label: 'Target amount',
            keyboardType: TextInputType.number,
            onChanged: (value) => target = value,
          ),
          _ModalInput(
            label: 'Already saved',
            keyboardType: TextInputType.number,
            onChanged: (value) => saved = value,
          ),
          _ModalInput(
              label: 'Deadline', onChanged: (value) => deadline = value),
        ],
      ),
    );
  }
}

class _UpdateGoalModal extends StatefulWidget {
  final Box settingsBox;
  final int goalIndex;
  final Map goal;

  const _UpdateGoalModal({
    required this.settingsBox,
    required this.goalIndex,
    required this.goal,
  });

  @override
  State<_UpdateGoalModal> createState() => _UpdateGoalModalState();
}

class _UpdateGoalModalState extends State<_UpdateGoalModal> {
  String amount = '';

  void _save() {
    final parsed = safeParse(amount);
    if (parsed <= 0) return;
    final goals = List.from(widget.settingsBox.get('goals', defaultValue: []));
    final goal = Map.from(goals[widget.goalIndex] as Map);
    goal['saved'] = _asDouble(goal['saved']) + parsed;
    goals[widget.goalIndex] = goal;
    widget.settingsBox.put('goals', goals);
    GlobalXPService.addXP(20);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _BaseModal(
      title: 'Add funds',
      onSave: _save,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.goal['name']?.toString() ?? 'Goal',
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_money(_asDouble(widget.goal['saved']))} saved of ${_money(_asDouble(widget.goal['target']))}',
            style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          _ModalInput(
            label: 'Amount to add',
            keyboardType: TextInputType.number,
            onChanged: (value) => amount = value,
          ),
        ],
      ),
    );
  }
}

class _BaseModal extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onSave;

  const _BaseModal({
    required this.title,
    required this.child,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: BentoTheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border:
            Border.all(color: BentoTheme.textSecondary.withValues(alpha: 0.12)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _IconButton(
                        icon: LucideIcons.x,
                        onTap: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 18),
                child,
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _OutlineButton(
                          label: 'Cancel', onTap: () => Navigator.pop(context)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _PrimaryButton(label: 'Save', onTap: onSave),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModalInput extends StatelessWidget {
  final String label;
  final ValueChanged<String> onChanged;
  final TextInputType keyboardType;
  final String? initialValue;

  const _ModalInput({
    required this.label,
    required this.onChanged,
    this.keyboardType = TextInputType.text,
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: initialValue,
        onChanged: onChanged,
        keyboardType: keyboardType,
        style: TextStyle(color: BentoTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: BentoTheme.textSecondary),
          filled: true,
          fillColor: BentoTheme.surface,
          border: _inputBorder(),
          enabledBorder: _inputBorder(),
          focusedBorder: _inputBorder(color: BentoTheme.accent),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

class _ModalDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _ModalDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        dropdownColor: BentoTheme.surface,
        icon: Icon(LucideIcons.chevronDown,
            color: BentoTheme.textSecondary, size: 18),
        style: TextStyle(color: BentoTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: BentoTheme.textSecondary),
          filled: true,
          fillColor: BentoTheme.surface,
          border: _inputBorder(),
          enabledBorder: _inputBorder(),
          focusedBorder: _inputBorder(color: BentoTheme.accent),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        items: items
            .map((item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

OutlineInputBorder _inputBorder({Color? color}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(
      color: color ?? BentoTheme.textSecondary.withValues(alpha: 0.12),
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BentoTheme.accent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: BentoTheme.background,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OutlineButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: BentoTheme.textSecondary.withValues(alpha: 0.16)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: BentoTheme.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
