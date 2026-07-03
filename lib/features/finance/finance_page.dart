import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/core/theme/neu_theme.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/data/services/global_xp_service.dart';



const List<Color> pieColors = [
  Color(0xFF00D4B8), Color(0xFF00B4A0), Color(0xFFFF6B6B),
  Color(0xFFFFD93D), Color(0xFF6C63FF), Color(0xFFFF9800),
  Color(0xFFE91E63), Color(0xFF00BCD4), Color(0xFF8BC34A),
];

// Unified Categories to guarantee Budgets and Transactions perfectly sync
const List<String> kExpenseCategories = [
  "Food", "Shopping", "Transport", "Utilities", 
  "Health", "Entertainment", "OTT", "Groceries", "EMI", "Other"
];

// Safely extract numbers from string (handles commas or accidental spaces)
double safeParse(String val) {
  String clean = val.replaceAll(RegExp(r'[^0-9.]'), '');
  return double.tryParse(clean) ?? 0.0;
}

class FinanceDashboard extends StatefulWidget {
  const FinanceDashboard({super.key});

  @override
  State<FinanceDashboard> createState() => _FinanceDashboardState();
}

class _FinanceDashboardState extends State<FinanceDashboard> {
  String _activeTab = "home";
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  late Box<Transaction> txBox;
  late Box<AssetVault> vaultBox;
  late Box settingsBox;

  @override
  void initState() {
    super.initState();
    txBox = Hive.box<Transaction>('finance_transactions');
    vaultBox = Hive.box<AssetVault>('finance_vaults');
    settingsBox = Hive.box('finance_settings');
    _initializeEmptyDefaults();
  }

  void _initializeEmptyDefaults() {
    if (settingsBox.get('budgets') == null) settingsBox.put('budgets', []);
    if (settingsBox.get('goals') == null) settingsBox.put('goals', []);
    if (settingsBox.get('planner') == null) {
      settingsBox.put('planner', {"fixedExpenses": [], "sips": []});
    }
  }

  void _showAddModal(String type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        if (type == 'transaction') return _AddEditTransactionModal(txBox: txBox, vaultBox: vaultBox);
        if (type == 'vault') return _AddVaultModal(vaultBox: vaultBox);
        if (type == 'budget') return _AddBudgetModal(settingsBox: settingsBox);
        if (type == 'planner') return _AddPlannerModal(settingsBox: settingsBox);
        return _AddGoalModal(settingsBox: settingsBox);
      },
    );
  }

  void _showEditTransactionModal(Transaction tx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AddEditTransactionModal(txBox: txBox, vaultBox: vaultBox, existingTx: tx),
    );
  }

  void _showUpdateGoalModal(int index, Map goal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _UpdateGoalModal(settingsBox: settingsBox, goalIndex: index, goal: goal),
    );
  }

  void _confirmDelete(BuildContext context, String title, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: NeuTheme.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: NeuTheme.accent.withValues(alpha: 0.15))),
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          content: Text("This action cannot be undone.", style: TextStyle(color: Colors.white54, fontSize: 14)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text("CANCEL", style: TextStyle(color: NeuTheme.accent))),
            Container(
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFD32F2F)]), borderRadius: BorderRadius.circular(8)),
              child: TextButton(
                onPressed: () { Navigator.pop(ctx); onConfirm(); },
                child: Text("DELETE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _calculateDynamicCashFlow(Iterable<Transaction> transactions) {
    Map<String, Map<String, double>> monthlyFlow = {};
    DateTime now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      DateTime d = DateTime(now.year, now.month - i, 1);
      String mKey = DateFormat('MMM yy').format(d);
      monthlyFlow[mKey] = {'income': 0.0, 'expense': 0.0};
    }

    for (var tx in transactions) {
      String mKey = DateFormat('MMM yy').format(tx.date);
      if (monthlyFlow.containsKey(mKey)) {
        if (tx.amount > 0) monthlyFlow[mKey]!['income'] = monthlyFlow[mKey]!['income']! + tx.amount;
        else monthlyFlow[mKey]!['expense'] = monthlyFlow[mKey]!['expense']! + tx.amount.abs();
      }
    }

    List<Map<String, dynamic>> trend = [];
    monthlyFlow.forEach((key, value) {
      trend.add({'month': key.split(' ')[0], 'income': value['income'], 'expense': value['expense']});
    });
    return trend;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned(top: -120, left: -80, child: Container(width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [NeuTheme.accent.withValues(alpha: 0.15), Colors.transparent], stops: [0.0, 0.7])))),
          Positioned(bottom: -100, right: -100, child: Container(width: 350, height: 350, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0x1E6C63FF), Colors.transparent], stops: [0.0, 0.7])))),

          SafeArea(
            child: ValueListenableBuilder(
              valueListenable: txBox.listenable(),
              builder: (context, Box<Transaction> tBox, _) {
                return ValueListenableBuilder(
                  valueListenable: vaultBox.listenable(),
                  builder: (context, Box<AssetVault> vBox, _) {
                    return ValueListenableBuilder(
                      valueListenable: settingsBox.listenable(),
                      builder: (context, Box sBox, _) {
                        
                        double vaultTotal = vBox.values.fold(0, (sum, item) => sum + item.balance);
                        double allTimeNet = tBox.values.fold(0.0, (sum, tx) => sum + tx.amount);
                        
                        List goals = sBox.get('goals', defaultValue: []);
                        double goalsSaved = goals.fold(0.0, (sum, g) => sum + (g['saved'] as double));
                        
                        Map planner = sBox.get('planner', defaultValue: {"fixedExpenses": [], "sips": []});
                        List sips = planner['sips'] ?? [];
                        double sipAmount = sips.fold(0.0, (sum, s) => sum + (s['amount'] as double));

                        double totalBalance = vaultTotal + allTimeNet + goalsSaved + sipAmount;
                        double monthIncome = 0;
                        double monthExpense = 0;
                        Map<String, double> categorySpentMap = {};

                        // Calculate selected month's totals AND category spends directly from transactions
                        DateTime now = _selectedMonth;
                        for (var tx in tBox.values) {
                          if (tx.date.month == now.month && tx.date.year == now.year) {
                            if (tx.amount > 0) {
                              monthIncome += tx.amount;
                            } else {
                              double exp = tx.amount.abs();
                              monthExpense += exp;
                              // This perfectly maps to the Budget tab!
                              categorySpentMap[tx.category] = (categorySpentMap[tx.category] ?? 0) + exp;
                            }
                          }
                        }

                        List<Map<String, dynamic>> categoryBreakdown = categorySpentMap.entries
                            .map((e) => {"name": e.key, "value": e.value})
                            .toList()..sort((a, b) => (b["value"] as double).compareTo(a["value"] as double));

                        double savingsRate = monthIncome > 0 ? ((monthIncome - monthExpense) / monthIncome * 100).clamp(0, 100) : 0;
                        
                        List budgets = sBox.get('budgets', defaultValue: []);
                        double totalBudgetLimit = budgets.fold(0.0, (sum, b) => sum + (b['total'] as double));
                        
                        // Total budget spent uses the categories mapped above
                        double totalBudgetSpent = 0;
                        for (var b in budgets) {
                          double spent = categorySpentMap[b['category']] ?? 0.0;
                          totalBudgetSpent += spent;
                        }

                        List<Map<String, dynamic>> spendingTrend = _calculateDynamicCashFlow(tBox.values);
                        Map plannerData = sBox.get('planner', defaultValue: {"fixedExpenses": [], "sips": []});

                        Widget currentTabWidget;
                        switch (_activeTab) {
                          case "transactions":
                            currentTabWidget = _TransactionsTab(
                              transactions: tBox.values.toList().reversed.toList(),
                              onAdd: () => _showAddModal('transaction'),
                              onDelete: (tx) => _confirmDelete(context, "Delete Transaction?", () => tx.delete()),
                              onEditTx: (tx) => _showEditTransactionModal(tx),
                            );
                            break;
                          case "budget":
                            currentTabWidget = _BudgetTab(
                              budgets: budgets, categorySpentMap: categorySpentMap,
                              totalSpent: totalBudgetSpent, totalLimit: totalBudgetLimit,
                              onAdd: () => _showAddModal('budget'),
                              onDelete: (idx) => _confirmDelete(context, "Delete Budget?", () {
                                List b = List.from(budgets); b.removeAt(idx); sBox.put('budgets', b);
                              }),
                            );
                            break;
                          case "planner":
                            currentTabWidget = _PlannerTab(
                              plannerData: plannerData, monthIncome: monthIncome, monthExpense: monthExpense,
                              onAdd: () => _showAddModal('planner'),
                              onDeleteFixed: (idx) => _confirmDelete(context, "Delete Fixed Expense?", () {
                                Map p = Map.from(plannerData); List f = List.from(p['fixedExpenses']); f.removeAt(idx); p['fixedExpenses'] = f; sBox.put('planner', p);
                              }),
                              onDeleteSip: (idx) => _confirmDelete(context, "Delete SIP?", () {
                                Map p = Map.from(plannerData); List s = List.from(p['sips']); s.removeAt(idx); p['sips'] = s; sBox.put('planner', p);
                              }),
                            );
                            break;
                          case "goals":
                            currentTabWidget = _GoalsTab(
                              goals: sBox.get('goals', defaultValue: []), settingsBox: sBox,
                              onAdd: () => _showAddModal('goal'),
                              onUpdate: (idx, goal) => _showUpdateGoalModal(idx, goal),
                              onDelete: (idx) => _confirmDelete(context, "Delete Goal?", () {
                                List g = List.from(sBox.get('goals', defaultValue: [])); g.removeAt(idx); sBox.put('goals', g);
                              }),
                            );
                            break;
                          default:
                            currentTabWidget = _HomeTab(
                              totalBalance: totalBalance, monthIncome: monthIncome, monthExpense: monthExpense,
                              savingsRate: savingsRate, leftover: monthIncome - monthExpense,
                              vaults: vBox.values.toList(), transactions: tBox.values.toList().reversed.toList(),
                              spendingTrend: spendingTrend, categoryBreakdown: categoryBreakdown,
                              onAddTx: () => _showAddModal('transaction'), onAddVault: () => _showAddModal('vault'),
                              onDeleteVault: (v) => _confirmDelete(context, "Delete Vault?", () => v.delete()),
                              onEditTx: (tx) => _showEditTransactionModal(tx),
                            );
                        }

                        return Column(
                          children: [
                            _buildTopNavDropdown(),
                            _buildMonthSelector(),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                switchInCurve: Curves.easeOut, switchOutCurve: Curves.easeIn,
                                transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.0, 0.05), end: Offset.zero).animate(animation), child: child)),
                                child: SingleChildScrollView(
                                  key: ValueKey(_activeTab),
                                  physics: const BouncingScrollPhysics(),
                                  padding: EdgeInsets.fromLTRB(16, 8, 16, 40),
                                  child: currentTabWidget
                                ),
                              )
                            ),
                          ],
                        );
                      }
                    );
                  }
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavDropdown() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("F I N A N C E", style: TextStyle(color: NeuTheme.accent, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16)),
          Theme(
            data: Theme.of(context).copyWith(
              popupMenuTheme: PopupMenuThemeData(
                color: NeuTheme.background.withValues(alpha: 0.95),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: NeuTheme.accent.withValues(alpha: 0.15), width: 1.5)),
              )
            ),
            child: PopupMenuButton<String>(
              onSelected: (val) => setState(() => _activeTab = val),
              offset: const Offset(0, 40),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: NeuTheme.accent.withValues(alpha: 0.15), width: 1.5)),
                child: Row(
                  children: [
                    Text(_activeTab[0].toUpperCase() + _activeTab.substring(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(width: 6),
                    Icon(LucideIcons.chevronDown, color: NeuTheme.accent, size: 18),
                  ],
                ),
              ),
              itemBuilder: (context) => [
                _buildMenuItem("home", "Home", LucideIcons.home),
                _buildMenuItem("transactions", "Transactions", LucideIcons.receipt),
                _buildMenuItem("budget", "Budget", LucideIcons.pieChart),
                _buildMenuItem("planner", "Planner", LucideIcons.calendar),
                _buildMenuItem("goals", "Goals", LucideIcons.flag),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    String monthStr = DateFormat('MMMM yyyy').format(_selectedMonth);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(LucideIcons.chevronLeft, color: NeuTheme.accent),
            onPressed: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1)),
          ),
          Text(monthStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(
            icon: Icon(LucideIcons.chevronRight, color: NeuTheme.accent),
            onPressed: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1)),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, String label, IconData icon) {
    bool isSel = _activeTab == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: isSel ? NeuTheme.accent : Colors.white54, size: 18),
          SizedBox(width: 12),
          Text(label, style: TextStyle(color: isSel ? NeuTheme.accent : Colors.white, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

// ==================== TABS ====================

class _HomeTab extends StatelessWidget {
  final double totalBalance, monthIncome, monthExpense, savingsRate, leftover;
  final List<AssetVault> vaults;
  final List<Transaction> transactions;
  final List<Map<String, dynamic>> spendingTrend;
  final List<Map<String, dynamic>> categoryBreakdown;
  final VoidCallback onAddTx, onAddVault;
  final Function(AssetVault) onDeleteVault;
  final Function(Transaction)? onEditTx;

  const _HomeTab({
    required this.totalBalance, required this.monthIncome, required this.monthExpense, required this.savingsRate, required this.leftover, required this.vaults, required this.transactions,
    required this.spendingTrend, required this.categoryBreakdown, required this.onAddTx, required this.onAddVault, required this.onDeleteVault, this.onEditTx
  });

  @override
  Widget build(BuildContext context) {
    String monthName = DateFormat('MMM').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          glow: true, padding: EdgeInsets.all(24),
          gradient: LinearGradient(colors: [NeuTheme.accent.withValues(alpha: 0.12), Colors.black.withValues(alpha: 0.2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("TOTAL NET WORTH", style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 3)),
              SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: totalBalance),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) => Text(FormatUtils.formatCurrency(value), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  _buildStatCard("↑ INCOME", FormatUtils.formatCompactCurrency(monthIncome), monthName, NeuTheme.accent),
                  SizedBox(width: 12),
                  _buildStatCard("↓ SPENT", FormatUtils.formatCompactCurrency(monthExpense), monthName, const Color(0xFFFF6B6B)),
                  SizedBox(width: 12),
                  _buildStatCard("💰 LEFT", FormatUtils.formatCompactCurrency(leftover), "Leftover", const Color(0xFFFFD93D)),
                ],
              )
            ],
          ),
        ),
        SizedBox(height: 16),

        GlassCard(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              AnimatedRingProgress(progress: savingsRate / 100, color: NeuTheme.accent, size: 72, stroke: 7, label: "${savingsRate.toInt()}%", sublabel: "SAVED"),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("SAVINGS RATE", style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                    Text("Great Job! 🎉", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 8),
                    AnimatedProgressBar(progress: savingsRate / 100, color1: NeuTheme.accent, color2: NeuTheme.accent),
                    SizedBox(height: 6),
                    Text("Target: 50% | ${FormatUtils.formatCompactCurrency(leftover)} saved", style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
                  ],
                ),
              )
            ],
          ),
        ),
        SizedBox(height: 16),

        SectionHeader(title: "ASSET VAULTS", onAdd: onAddVault),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(),
            itemCount: vaults.length + 1,
            itemBuilder: (context, i) {
              if (i == vaults.length) {
                return GestureDetector(onTap: onAddVault, child: Container(width: 120, margin: EdgeInsets.only(right: 12), child: NeuContainer(borderRadius: 24, child: Center(child: Icon(LucideIcons.plus, color: NeuTheme.textSecondary, size: 32)))));
              }
              final v = vaults[i]; Color vColor = Color(v.colorValue);
              return GestureDetector(
                onLongPress: () => onDeleteVault(v),
                child: Container(
                  width: 200, margin: EdgeInsets.only(right: 12),
                  child: NeuContainer(
                    padding: EdgeInsets.all(18), borderRadius: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(v.name, style: TextStyle(color: NeuTheme.textSecondary, fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.bold)), Text("🏦", style: TextStyle(fontSize: 20))]),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(FormatUtils.formatCompactCurrency(v.balance), style: TextStyle(color: NeuTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)), Text("${v.bank} · ${v.type}", style: TextStyle(color: NeuTheme.accent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))])
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 16),

        const SectionHeader(title: "CASH FLOW (LAST 6 MONTHS)"),
        GlassCard(
          padding: EdgeInsets.fromLTRB(0, 16, 16, 16),
          child: SizedBox(
            height: 160,
            child: LineChart(LineChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withValues(alpha: 0.04), strokeWidth: 1)),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, meta) {
                  if (v.toInt() >= 0 && v.toInt() < spendingTrend.length) return Padding(padding: EdgeInsets.only(top: 8), child: Text(spendingTrend[v.toInt()]['month'], style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)));
                  return SizedBox();
                })),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(spots: spendingTrend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['income'] as double)).toList(), isCurved: true, color: NeuTheme.accent, barWidth: 2.5, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [NeuTheme.accent.withValues(alpha: 0.3), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
                LineChartBarData(spots: spendingTrend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['expense'] as double)).toList(), isCurved: true, color: const Color(0xFFFF6B6B), barWidth: 2.5, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [const Color(0xFFFF6B6B).withValues(alpha: 0.3), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)))
              ]
            )),
          ),
        ),
        SizedBox(height: 16),

        if (categoryBreakdown.isNotEmpty) ...[
          const SectionHeader(title: "THIS MONTH'S SPEND"),
          GlassCard(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  height: 140, width: 140,
                  child: PieChart(PieChartData(
                    sectionsSpace: 4, centerSpaceRadius: 42,
                    sections: categoryBreakdown.asMap().entries.map((e) => PieChartSectionData(color: pieColors[e.key % pieColors.length], value: e.value['value'], radius: 26, showTitle: false)).toList(),
                  )),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: categoryBreakdown.take(5).toList().asMap().entries.map((e) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: pieColors[e.key % pieColors.length], borderRadius: BorderRadius.circular(2))),
                            SizedBox(width: 8),
                            Expanded(child: Text(e.value['name'], style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text(FormatUtils.formatCompactCurrency(e.value['value']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                )
              ],
            ),
          ),
          SizedBox(height: 16),
        ],

        SectionHeader(title: "RECENT ACTIVITY", onAdd: onAddTx),
        if (transactions.isEmpty) Padding(
          padding: EdgeInsets.all(32), 
          child: Center(
            child: Column(
              children: [
                Icon(LucideIcons.wind, size: 48, color: Colors.white24)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: -8, end: 8, duration: 2.seconds, curve: Curves.easeInOut),
                SizedBox(height: 16),
                Text("No transactions recorded yet.", style: TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        )
        else ...transactions.take(4).toList().asMap().entries.map((entry) => TxRow(tx: entry.value, onTap: () { if(onEditTx != null) onEditTx!(entry.value); })
          .animate().slideY(begin: 0.1, duration: 400.ms, delay: (50 * entry.key).ms, curve: Curves.easeOutBack).fade(duration: 400.ms)
        ).toList(),
      ],
    );
  }

  Widget _buildStatCard(String label, String amount, String subtitle, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)), SizedBox(height: 4),
          Text(amount, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
          Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
        ]),
      ),
    );
  }
}

class _TransactionsTab extends StatefulWidget {
  final List<Transaction> transactions;
  final VoidCallback onAdd;
  final Function(Transaction) onDelete;
  final Function(Transaction)? onEditTx;
  const _TransactionsTab({required this.transactions, required this.onAdd, required this.onDelete, this.onEditTx});

  @override
  State<_TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<_TransactionsTab> {
  String filter = "All";
  final List<String> cats = ["All", ...kExpenseCategories, "Income"];

  @override
  Widget build(BuildContext context) {
    List<Transaction> filtered = filter == "All" ? widget.transactions : widget.transactions.where((t) => t.category == filter).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("All Transactions", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            GestureDetector(onTap: widget.onAdd, child: Container(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(gradient: LinearGradient(colors: [NeuTheme.accent, NeuTheme.accent]), borderRadius: BorderRadius.circular(12)), child: Text("+ ADD", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12))))
          ],
        ),
        SizedBox(height: 16),
        SizedBox(
          height: 32,
          child: ListView.builder(
            scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), itemCount: cats.length,
            itemBuilder: (context, i) {
              bool isSel = filter == cats[i];
              return GestureDetector(
                onTap: () => setState(() => filter = cats[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(right: 8), padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: isSel ? NeuTheme.accent.withValues(alpha: 0.15) : Colors.transparent, border: Border.all(color: isSel ? NeuTheme.accent : NeuTheme.accent.withValues(alpha: 0.15), width: 1.5), borderRadius: BorderRadius.circular(20)),
                  alignment: Alignment.center, child: Text(cats[i], style: TextStyle(color: isSel ? NeuTheme.accent : Colors.white.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 16),
        if (filtered.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No transactions found.", style: TextStyle(color: Colors.white54))))
        else ...filtered.asMap().entries.map((entry) => Dismissible(
          key: Key(entry.value.key.toString()),
          direction: DismissDirection.endToStart,
          background: Container(alignment: Alignment.centerRight, padding: EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(24)), margin: EdgeInsets.only(bottom: 10), child: Icon(LucideIcons.trash, color: Colors.white)),
          confirmDismiss: (direction) async { widget.onDelete(entry.value); return false; },
          child: TxRow(tx: entry.value, onTap: () { if(widget.onEditTx != null) widget.onEditTx!(entry.value); }),
        ).animate().slideY(begin: 0.1, duration: 400.ms, delay: (50 * entry.key).ms, curve: Curves.easeOutBack).fade(duration: 400.ms)).toList(),
      ],
    );
  }
}

class _BudgetTab extends StatelessWidget {
  final List budgets;
  final Map<String, double> categorySpentMap;
  final double totalSpent, totalLimit;
  final VoidCallback onAdd;
  final Function(int) onDelete;
  const _BudgetTab({required this.budgets, required this.categorySpentMap, required this.totalSpent, required this.totalLimit, required this.onAdd, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    double totalPct = totalLimit > 0 ? (totalSpent / totalLimit).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        SectionHeader(title: "MONTHLY OVERVIEW", onAdd: onAdd),
        GlassCard(
          glow: true, padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Text("MONTHLY BUDGET USED", style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              RichText(text: TextSpan(children: [TextSpan(text: FormatUtils.formatCompactCurrency(totalSpent), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)), TextSpan(text: " / Limit: ${FormatUtils.formatCompactCurrency(totalLimit)}", style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.bold))])),
              SizedBox(height: 12),
              AnimatedProgressBar(progress: totalPct, color1: NeuTheme.accent, color2: const Color(0xFFFFD93D)),
              SizedBox(height: 8),
              Text("${(totalPct * 100).toStringAsFixed(1)}% used · ${FormatUtils.formatCompactCurrency(totalLimit > totalSpent ? totalLimit - totalSpent : 0)} remaining", style: TextStyle(color: NeuTheme.accent, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        SizedBox(height: 16),
        
        const SectionHeader(title: "INDIVIDUAL CATEGORIES"),
        if (budgets.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text("No budget categories setup.", style: TextStyle(color: Colors.white54)))
        else Wrap(
          spacing: 12, runSpacing: 12,
          children: budgets.asMap().entries.map((entry) {
            int idx = entry.key;
            Map b = entry.value;
            double limit = b['total'] as double;
            double spent = categorySpentMap[b['category']] ?? 0.0; // Automatically syncs with transactions!
            double pct = limit > 0 ? (spent / limit) : 0;
            Color col = pct > 0.9 ? const Color(0xFFFF6B6B) : Color(b['color']);
            
            return GestureDetector(
              onLongPress: () => onDelete(idx),
              child: SizedBox(
                width: (MediaQuery.of(context).size.width - 44) / 2,
                child: GlassCard(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      AnimatedRingProgress(progress: pct.clamp(0.0, 1.0), color: col, size: 72, stroke: 7, label: "${(pct * 100).toStringAsFixed(0)}%"),
                      SizedBox(height: 8),
                      Text("${b['icon']} ${b['category']}", style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1), textAlign: TextAlign.center),
                      SizedBox(height: 4),
                      Text("${FormatUtils.formatCompactCurrency(spent)} spent", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                      Text("Limit: ${FormatUtils.formatCompactCurrency(limit)}", style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
                      if (pct > 0.9) Container(margin: EdgeInsets.only(top: 4), padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0x33FF6B6B), border: Border.all(color: const Color(0x66FF6B6B)), borderRadius: BorderRadius.circular(8)), child: Text("ALERT", style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 9, fontWeight: FontWeight.bold))),
                    ],
                  )
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 16),

        if (totalSpent > 0 && budgets.isNotEmpty) ...[
          const SectionHeader(title: "DYNAMIC BREAKDOWN"),
          GlassCard(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              height: 200,
              child: PieChart(PieChartData(
                sectionsSpace: 3, centerSpaceRadius: 0,
                sections: budgets.asMap().entries.map((e) {
                  double spent = categorySpentMap[e.value['category']] ?? 0.0;
                  if (spent == 0) return PieChartSectionData(value: 0, radius: 0);
                  return PieChartSectionData(
                    color: pieColors[e.key % pieColors.length], value: spent, radius: 80,
                    title: "${((spent / totalSpent) * 100).toStringAsFixed(0)}%",
                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }).where((s) => s.value > 0).toList(),
              )),
            )
          )
        ]
      ],
    );
  }
}

class _PlannerTab extends StatelessWidget {
  final Map plannerData;
  final double monthIncome;
  final double monthExpense;
  final VoidCallback onAdd;
  final Function(int) onDeleteFixed;
  final Function(int) onDeleteSip;
  
  const _PlannerTab({required this.plannerData, required this.monthIncome, required this.monthExpense, required this.onAdd, required this.onDeleteFixed, required this.onDeleteSip});

  @override
  Widget build(BuildContext context) {
    List fixed = plannerData['fixedExpenses'] ?? [];
    List sips = plannerData['sips'] ?? [];
    double totalFixed = fixed.fold(0.0, (s, e) => s + (e['amount'] as double));
    double totalSIP = sips.fold(0.0, (s, e) => s + (e['amount'] as double));
    double committed = totalFixed + totalSIP;
    double actualVariable = monthExpense - committed;
    double actualSavings = monthIncome - monthExpense;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: "MONTHLY COMMITMENTS", onAdd: onAdd),
        GlassCard(
          glow: true, padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Text("COMMITTED THIS MONTH", style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: committed),
                duration: const Duration(milliseconds: 800),
                builder: (context, val, child) => Text(FormatUtils.formatCompactCurrency(val), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
              ),
              SizedBox(height: 12),
              Row(children: [_buildMiniCard("📋 FIXED", FormatUtils.formatCompactCurrency(totalFixed), const Color(0xFFFF6B6B)), SizedBox(width: 10), _buildMiniCard("📈 SIP", FormatUtils.formatCompactCurrency(totalSIP), NeuTheme.accent)]),
            ],
          ),
        ),
        SizedBox(height: 16),

        const SectionHeader(title: "DYNAMIC MONTHLY FLOW"),
        GlassCard(
          padding: EdgeInsets.fromLTRB(0, 16, 16, 16),
          child: SizedBox(
            height: 140,
            child: LineChart(LineChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withValues(alpha: 0.04), strokeWidth: 1)),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, meta) {
                  List labels = ["Inc", "Fix", "Var", "Sav"];
                  if (v.toInt() >= 0 && v.toInt() < labels.length) return Padding(padding: EdgeInsets.only(top: 8), child: Text(labels[v.toInt()], style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)));
                  return SizedBox();
                })),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: [FlSpot(0, monthIncome), FlSpot(1, monthIncome - totalFixed), FlSpot(2, (monthIncome - totalFixed) - (actualVariable > 0 ? actualVariable : 0)), FlSpot(3, actualSavings > 0 ? actualSavings : 0)],
                  isCurved: true, color: NeuTheme.accent, barWidth: 3, dotData: FlDotData(show: true, getDotPainter: (s,p,b,i) => FlDotCirclePainter(color: NeuTheme.accent, strokeWidth: 0, radius: 5)),
                )
              ]
            ))
          )
        ),
        SizedBox(height: 16),

        const SectionHeader(title: "FIXED EXPENSES & EMIs"),
        if (fixed.isEmpty) Text("No fixed expenses tracked.", style: TextStyle(color: Colors.white54)),
        ...fixed.asMap().entries.map((e) => Dismissible(
          key: UniqueKey(), direction: DismissDirection.endToStart,
          background: Container(alignment: Alignment.centerRight, padding: EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(24)), margin: EdgeInsets.only(bottom: 10), child: Icon(LucideIcons.trash, color: Colors.white)),
          confirmDismiss: (d) async { onDeleteFixed(e.key); return false; },
          child: _buildPlannerRow(e.value['category'] == "EMI" ? "🏦" : "🛡️", e.value['name'], "Due on ${e.value['due']}th · ${e.value['category']}", "-${FormatUtils.formatCompactCurrency(e.value['amount'])}", const Color(0xFFFF6B6B)),
        )).toList(),
        
        SizedBox(height: 16),
        const SectionHeader(title: "SIP / INVESTMENTS"),
        if (sips.isEmpty) Text("No SIPs tracked.", style: TextStyle(color: Colors.white54)),
        ...sips.asMap().entries.map((s) => Dismissible(
          key: UniqueKey(), direction: DismissDirection.endToStart,
          background: Container(alignment: Alignment.centerRight, padding: EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(24)), margin: EdgeInsets.only(bottom: 10), child: Icon(LucideIcons.trash, color: Colors.white)),
          confirmDismiss: (d) async { onDeleteSip(s.key); return false; },
          child: _buildPlannerRow("📈", s.value['name'], "Due ${s.value['due']}st · ${s.value['folio']}", FormatUtils.formatCompactCurrency(s.value['amount']), NeuTheme.accent),
        )).toList(),
      ],
    );
  }

  Widget _buildMiniCard(String title, String amount, Color color) {
    return Expanded(child: Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.bold)), SizedBox(height: 4), Text(amount, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16))])));
  }

  Widget _buildPlannerRow(String icon, String title, String sub, String amt, Color color) {
    return GlassCard(
      padding: EdgeInsets.all(16), margin: EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: Text(icon, style: const TextStyle(fontSize: 20))), SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), SizedBox(height: 2), Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11))])),
        Text(amt, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
      ])
    );
  }
}

class _GoalsTab extends StatelessWidget {
  final List goals;
  final Box settingsBox;
  final VoidCallback onAdd;
  final Function(int, Map) onUpdate;
  final Function(int) onDelete;
  const _GoalsTab({required this.goals, required this.settingsBox, required this.onAdd, required this.onUpdate, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: "SAVINGS GOALS", onAdd: onAdd),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text("Tap to add funds. Long press to delete.", style: TextStyle(color: Colors.white30, fontSize: 11)),
        ),
        if (goals.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text("No goals set yet.", style: TextStyle(color: Colors.white54)))
        else ...goals.asMap().entries.map((entry) {
          int idx = entry.key;
          Map g = entry.value;
          double target = g['target'] as double;
          double saved = g['saved'] as double;
          double pct = target > 0 ? (saved / target).clamp(0.0, 1.0) : 0.0;
          double rem = target - saved;
          Color c = Color(g['color']);
          return GestureDetector(
            onTap: () => onUpdate(idx, g),
            onLongPress: () => onDelete(idx),
            child: GlassCard(
              padding: EdgeInsets.all(20), margin: EdgeInsets.only(bottom: 14),
              borderColor: c.withValues(alpha: 0.2), gradient: LinearGradient(colors: [c.withValues(alpha: 0.05), Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight),
              child: Column(
                children: [
                  Row(children: [
                    Container(width: 52, height: 52, decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)), alignment: Alignment.center, child: Text(g['icon'], style: const TextStyle(fontSize: 26))), SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(g['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)), SizedBox(height: 2), Text("Target: ${FormatUtils.formatCurrency(target)} · Due ${g['deadline']}", style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11))])),
                    AnimatedRingProgress(progress: pct, color: c, size: 56, stroke: 6, label: "${(pct * 100).toStringAsFixed(0)}%")
                  ]),
                  SizedBox(height: 14),
                  AnimatedProgressBar(progress: pct, color1: c, color2: c.withValues(alpha: 0.5)),
                  SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Saved: ${FormatUtils.formatCompactCurrency(saved)}", style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.bold)), Text("Need: ${FormatUtils.formatCompactCurrency(rem > 0 ? rem : 0)}", style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12))])
                ],
              )
            ),
          );
        }).toList(),
      ],
    );
  }
}

// ==================== SHARED WIDGETS & ANIMATIONS ====================

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool glow;
  final Color? borderColor;
  final Gradient? gradient;
  final EdgeInsetsGeometry? margin;

  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.glow = false, this.borderColor, this.gradient, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: glow ? [BoxShadow(color: NeuTheme.accent.withValues(alpha: 0.15), blurRadius: 40, offset: Offset(0, 8)), BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))] : [BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 4))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: Container(padding: padding, decoration: BoxDecoration(color: NeuTheme.background, gradient: gradient, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor ?? NeuTheme.accent.withValues(alpha: 0.15), width: 1.5)), child: child)),
      ),
    );
  }
}

class AnimatedRingProgress extends StatelessWidget {
  final double progress; final Color color; final double size; final double stroke; final String label; final String? sublabel;
  const AnimatedRingProgress({super.key, required this.progress, required this.color, required this.size, required this.stroke, required this.label, this.sublabel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size, width: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress),
        duration: const Duration(milliseconds: 1000), curve: Curves.easeOutCubic,
        builder: (context, value, child) => CustomPaint(
          painter: RingProgressPainter(progress: value, color: color, strokeWidth: stroke),
          child: Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size > 60 ? 14 : 12)),
              if (sublabel != null) Text(sublabel!, style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 8, letterSpacing: 1)),
            ],
          )),
        ),
      ),
    );
  }
}

class AnimatedProgressBar extends StatelessWidget {
  final double progress; final Color color1; final Color color2;
  const AnimatedProgressBar({super.key, required this.progress, required this.color1, required this.color2});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)), alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 1000), curve: Curves.easeOutCubic,
        builder: (context, value, child) => FractionallySizedBox(
          widthFactor: value,
          child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [color1, color2]), borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: color1.withValues(alpha: 0.4), blurRadius: 8)])),
        ),
      ),
    );
  }
}

class TxRow extends StatelessWidget {
  final Transaction tx;
  final VoidCallback? onTap;
  const TxRow({super.key, required this.tx, this.onTap});

  @override
  Widget build(BuildContext context) {
    bool isIncome = tx.amount > 0;
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: EdgeInsets.all(14), margin: EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Text(tx.icon, style: const TextStyle(fontSize: 20))), SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tx.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), SizedBox(height: 2), Text("${DateFormat('MMM d').format(tx.date)} · ${tx.mode}", style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11))])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text("${isIncome ? '+' : '-'}${FormatUtils.formatCompactCurrency(tx.amount.abs())}", style: TextStyle(color: isIncome ? NeuTheme.accent : const Color(0xFFFF6B6B), fontWeight: FontWeight.w800, fontSize: 15)), SizedBox(height: 2), Text(tx.category, style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 10))])
        ])
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onAdd;
  const SectionHeader({super.key, required this.title, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: NeuTheme.accent.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
          if (onAdd != null) GestureDetector(onTap: onAdd, child: Container(width: 24, height: 24, decoration: BoxDecoration(color: NeuTheme.accent.withValues(alpha: 0.15), border: Border.all(color: NeuTheme.accent.withValues(alpha: 0.15)), shape: BoxShape.circle), child: Icon(LucideIcons.plus, color: NeuTheme.accent, size: 14)))
        ],
      ),
    );
  }
}

// --- Modals ---

class _AddEditTransactionModal extends StatefulWidget {
  final Box<Transaction> txBox;
  final Box<AssetVault> vaultBox;
  final Transaction? existingTx;
  const _AddEditTransactionModal({required this.txBox, required this.vaultBox, this.existingTx});
  @override
  State<_AddEditTransactionModal> createState() => _AddEditTransactionModalState();
}
class _AddEditTransactionModalState extends State<_AddEditTransactionModal> {
  String type = "expense", title = "", amount = "", category = "Food", upi = "";

  @override
  void initState() {
    super.initState();
    if (widget.existingTx != null) {
      final tx = widget.existingTx!;
      title = tx.title;
      amount = tx.amount.abs().toString();
      type = tx.amount > 0 ? "income" : "expense";
      category = tx.category;
      upi = tx.mode;
    }
  }
  void _save() {
    if (title.isEmpty || amount.isEmpty) return;
    double amt = safeParse(amount);
    if (amt == 0) return;
    
    String finalCat = type == "income" ? "Income" : category;
    
    if (widget.existingTx != null) {
      final tx = widget.existingTx!;
      tx.title = title;
      tx.amount = type == "expense" ? -amt.abs() : amt.abs();
      tx.category = finalCat;
      tx.mode = upi.isEmpty ? "UPI" : upi;
      tx.icon = type == "income" ? "💰" : "💸";
      tx.save();
    } else {
      widget.txBox.add(Transaction(title: title, amount: type == "expense" ? -amt.abs() : amt.abs(), category: finalCat, date: DateTime.now(), mode: upi.isEmpty ? "UPI" : upi, icon: type == "income" ? "💰" : "💸"));
    }
    Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    return _BaseModal(title: widget.existingTx != null ? "EDIT TRANSACTION" : "LOG TRANSACTION", onSave: _save, child: Column(children: [
      Row(children: ["expense", "income"].map((t) => Expanded(child: GestureDetector(onTap: () => setState(() => type = t), child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8), padding: EdgeInsets.all(10), decoration: BoxDecoration(color: type == t ? NeuTheme.accent.withValues(alpha: 0.15) : Colors.transparent, border: Border.all(color: type == t ? NeuTheme.accent : NeuTheme.accent.withValues(alpha: 0.15), width: 1.5), borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Text(t.toUpperCase(), style: TextStyle(color: type == t ? NeuTheme.accent : Colors.white54, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)))))).toList()),
      _ModalInput(hint: "Title (e.g., Swiggy, Salary)", initialValue: title, onChanged: (v) => title = v),
      _ModalInput(hint: "Amount (₹)", initialValue: amount, keyboardType: TextInputType.number, onChanged: (v) => amount = v),
      if (type == "expense") _ModalDropdown(value: category, items: kExpenseCategories, onChanged: (v) => setState(() => category = v!)),
      _ModalInput(hint: "Mode (e.g., UPI)", initialValue: upi, onChanged: (v) => upi = v),
    ]));
  }
}

class _AddVaultModal extends StatefulWidget {
  final Box<AssetVault> vaultBox;
  const _AddVaultModal({required this.vaultBox});
  @override
  State<_AddVaultModal> createState() => _AddVaultModalState();
}
class _AddVaultModalState extends State<_AddVaultModal> {
  String name = "", balance = "", type = "Savings";
  void _save() {
    if (name.isEmpty || balance.isEmpty) return;
    widget.vaultBox.add(AssetVault(name: name.toUpperCase(), balance: safeParse(balance), bank: type, type: type, colorValue: NeuTheme.accent.value));
    GlobalXPService.addXP(15);
    Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    return _BaseModal(title: "NEW VAULT", onSave: _save, child: Column(children: [
      _ModalInput(hint: "Vault Name", onChanged: (v) => name = v),
      _ModalInput(hint: "Balance (₹)", keyboardType: TextInputType.number, onChanged: (v) => balance = v),
      _ModalDropdown(value: type, items: const ["Savings", "Current", "UPI Wallet", "Investment", "Crypto"], onChanged: (v) => setState(() => type = v!)),
    ]));
  }
}

class _AddGoalModal extends StatefulWidget {
  final Box settingsBox;
  const _AddGoalModal({required this.settingsBox});
  @override
  State<_AddGoalModal> createState() => _AddGoalModalState();
}
class _AddGoalModalState extends State<_AddGoalModal> {
  String name = "", target = "", saved = "", deadline = "", icon = "🎯";
  final List<String> icons = ["🎯", "🏠", "📱", "✈️", "🎓", "💒", "🚗", "💻", "🏖️", "🛡️"];
  void _save() {
    if (name.isEmpty || target.isEmpty) return;
    List goals = widget.settingsBox.get('goals', defaultValue: []);
    goals.add({"name": name, "target": safeParse(target), "saved": safeParse(saved), "deadline": deadline, "icon": icon, "color": pieColors[goals.length % pieColors.length].value});
    widget.settingsBox.put('goals', goals);
    Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    return _BaseModal(title: "NEW GOAL", onSave: _save, child: Column(children: [
      Wrap(spacing: 8, runSpacing: 8, children: icons.map((e) => GestureDetector(onTap: () => setState(() => icon = e), child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 36, height: 36, decoration: BoxDecoration(color: icon == e ? NeuTheme.accent.withValues(alpha: 0.15) : Colors.transparent, border: Border.all(color: icon == e ? NeuTheme.accent : NeuTheme.accent.withValues(alpha: 0.15), width: 1.5), borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Text(e, style: const TextStyle(fontSize: 18))))).toList()),
      SizedBox(height: 12),
      _ModalInput(hint: "Goal Name", onChanged: (v) => name = v),
      _ModalInput(hint: "Target Amount (₹)", keyboardType: TextInputType.number, onChanged: (v) => target = v),
      _ModalInput(hint: "Already Saved (₹)", keyboardType: TextInputType.number, onChanged: (v) => saved = v),
      _ModalInput(hint: "Deadline (e.g., Dec 2025)", onChanged: (v) => deadline = v),
    ]));
  }
}

class _UpdateGoalModal extends StatefulWidget {
  final Box settingsBox;
  final int goalIndex;
  final Map goal;
  const _UpdateGoalModal({required this.settingsBox, required this.goalIndex, required this.goal});
  @override
  State<_UpdateGoalModal> createState() => _UpdateGoalModalState();
}
class _UpdateGoalModalState extends State<_UpdateGoalModal> {
  String amount = "";
  void _save() {
    double amt = safeParse(amount);
    if (amt <= 0) return;
    List goals = List.from(widget.settingsBox.get('goals', defaultValue: []));
    Map g = Map.from(goals[widget.goalIndex]);
    g['saved'] = (g['saved'] as double) + amt;
    goals[widget.goalIndex] = g;
    widget.settingsBox.put('goals', goals);
    GlobalXPService.addXP(20);
    Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    return _BaseModal(title: "ADD FUNDS TO ${widget.goal['name'].toUpperCase()}", onSave: _save, child: Column(children: [
      Text("Target: ${FormatUtils.formatCurrency(widget.goal['target'])} · Currently Saved: ${FormatUtils.formatCurrency(widget.goal['saved'])}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
      SizedBox(height: 16),
      _ModalInput(hint: "Amount to Add (₹)", keyboardType: TextInputType.number, onChanged: (v) => amount = v),
    ]));
  }
}

class _AddBudgetModal extends StatefulWidget {
  final Box settingsBox;
  const _AddBudgetModal({required this.settingsBox});
  @override
  State<_AddBudgetModal> createState() => _AddBudgetModalState();
}
class _AddBudgetModalState extends State<_AddBudgetModal> {
  String category = "Food", limit = "";
  void _save() {
    if (limit.isEmpty) return;
    List b = widget.settingsBox.get('budgets', defaultValue: []);
    String icon = "🛍️";
    if(category == "Food") icon = "🍔"; else if(category == "Transport") icon = "🚆"; else if(category == "Utilities") icon = "⚡";
    b.add({"category": category, "total": safeParse(limit), "icon": icon, "color": pieColors[b.length % pieColors.length].value});
    widget.settingsBox.put('budgets', b);
    Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    return _BaseModal(title: "NEW BUDGET", onSave: _save, child: Column(children: [
      _ModalDropdown(value: category, items: kExpenseCategories, onChanged: (v) => setState(() => category = v!)),
      _ModalInput(hint: "Monthly Limit (₹)", keyboardType: TextInputType.number, onChanged: (v) => limit = v),
    ]));
  }
}

class _AddPlannerModal extends StatefulWidget {
  final Box settingsBox;
  const _AddPlannerModal({required this.settingsBox});
  @override
  State<_AddPlannerModal> createState() => _AddPlannerModalState();
}
class _AddPlannerModalState extends State<_AddPlannerModal> {
  String type = "Fixed", name = "", amount = "", due = "1", extra = "EMI";
  void _save() {
    if (name.isEmpty || amount.isEmpty) return;
    Map p = widget.settingsBox.get('planner', defaultValue: {"fixedExpenses": [], "sips": []});
    if (type == "Fixed") {
      List f = List.from(p['fixedExpenses']);
      f.add({"name": name, "amount": safeParse(amount), "due": int.tryParse(due.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1, "category": extra});
      p['fixedExpenses'] = f;
    } else {
      List s = List.from(p['sips']);
      s.add({"name": name, "amount": safeParse(amount), "due": int.tryParse(due.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1, "folio": extra});
      p['sips'] = s;
    }
    widget.settingsBox.put('planner', p);
    Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    return _BaseModal(title: "NEW COMMITMENT", onSave: _save, child: Column(children: [
      Row(children: ["Fixed", "SIP"].map((t) => Expanded(child: GestureDetector(onTap: () => setState(() => type = t), child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8), padding: EdgeInsets.all(10), decoration: BoxDecoration(color: type == t ? NeuTheme.accent.withValues(alpha: 0.15) : Colors.transparent, border: Border.all(color: type == t ? NeuTheme.accent : NeuTheme.accent.withValues(alpha: 0.15), width: 1.5), borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Text(t.toUpperCase(), style: TextStyle(color: type == t ? NeuTheme.accent : Colors.white54, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)))))).toList()),
      _ModalInput(hint: "Name (e.g., Rent, Groww)", onChanged: (v) => name = v),
      _ModalInput(hint: "Amount (₹)", keyboardType: TextInputType.number, onChanged: (v) => amount = v),
      _ModalInput(hint: "Due Date (e.g., 5)", keyboardType: TextInputType.number, onChanged: (v) => due = v),
      _ModalInput(hint: type == "Fixed" ? "Category (e.g., EMI, Rent)" : "Folio/Platform (e.g., Zerodha)", onChanged: (v) => extra = v),
    ]));
  }
}

class _BaseModal extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onSave;
  const _BaseModal({required this.title, required this.child, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(color: const Color(0xFF0F1923), border: Border.all(color: NeuTheme.accent.withValues(alpha: 0.15), width: 1.5), borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), boxShadow: [BoxShadow(color: NeuTheme.accent.withValues(alpha: 0.15), blurRadius: 40, offset: Offset(0, -8))]),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: TextStyle(color: NeuTheme.accent, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2)), GestureDetector(onTap: () => Navigator.pop(context), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)), child: Icon(LucideIcons.x, color: Colors.white, size: 16)))]),
            SizedBox(height: 20), child, SizedBox(height: 8),
            Row(children: [
              Expanded(child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5), borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Text("CANCEL", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))))),
              SizedBox(width: 10),
              Expanded(flex: 2, child: GestureDetector(onTap: onSave, child: Container(padding: EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: LinearGradient(colors: [NeuTheme.accent, NeuTheme.accent]), borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Text("SAVE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1))))),
            ])
          ],
        ),
      ),
    );
  }
}

class _ModalInput extends StatelessWidget {
  final String hint; final ValueChanged<String> onChanged; final TextInputType keyboardType; final String? initialValue;
  const _ModalInput({required this.hint, required this.onChanged, this.keyboardType = TextInputType.text, this.initialValue});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: EdgeInsets.only(bottom: 10), child: TextFormField(initialValue: initialValue, onChanged: onChanged, keyboardType: keyboardType, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)), filled: true, fillColor: Colors.white.withValues(alpha: 0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: NeuTheme.accent.withValues(alpha: 0.15), width: 1.5)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: NeuTheme.accent.withValues(alpha: 0.15), width: 1.5)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: NeuTheme.accent, width: 1.5)), contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12))));
  }
}

class _ModalDropdown extends StatelessWidget {
  final String value; final List<String> items; final ValueChanged<String?> onChanged;
  const _ModalDropdown({required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: EdgeInsets.only(bottom: 10), child: Container(padding: EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), border: Border.all(color: NeuTheme.accent.withValues(alpha: 0.15), width: 1.5), borderRadius: BorderRadius.circular(12)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value, isExpanded: true, dropdownColor: NeuTheme.background, style: const TextStyle(color: Colors.white, fontSize: 14), icon: Icon(LucideIcons.chevronDown, color: Colors.white54), items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged))));
  }
}

// --- Custom Painters ---

class RingProgressPainter extends CustomPainter {
  final double progress; final Color color; final double strokeWidth;
  RingProgressPainter({required this.progress, required this.color, required this.strokeWidth});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    canvas.drawCircle(center, radius, Paint()..color = Colors.white.withValues(alpha: 0.05)..style = PaintingStyle.stroke..strokeWidth = strokeWidth);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * progress, false, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.15)..style = PaintingStyle.stroke..strokeWidth = 1.5;
    Path path = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(24)));
    for (PathMetric pathMetric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        canvas.drawPath(pathMetric.extractPath(distance, distance + 5.0), paint);
        distance += 5.0 + 5.0;
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
