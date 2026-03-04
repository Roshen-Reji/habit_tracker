import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/models/finance_model.dart';

// --- Constants ---
const Color kTeal = Color(0xFF00D4B8);
const Color kTeal2 = Color(0xFF00B4A0);
const Color kTealDark = Color(0xFF007A6E);
const Color kTealGlow = Color(0x4000D4B8);
const Color kDarkBg = Color(0xFF0A0F14);
const Color kCardBg = Color(0x0AFFFFFF); 
const Color kGlassBorder = Color(0x2E00D4B8);

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

String formatINR(double n) {
  if (n >= 10000000) return '₹${(n / 10000000).toStringAsFixed(2)}Cr';
  if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(2)}L';
  if (n >= 1000) return '₹${(n / 1000).toStringAsFixed(1)}K';
  return '₹${n.toStringAsFixed(0)}';
}

String formatINRFull(double n) {
  final format = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  return format.format(n.abs());
}

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
        if (type == 'transaction') return _AddTransactionModal(txBox: txBox, vaultBox: vaultBox);
        if (type == 'vault') return _AddVaultModal(vaultBox: vaultBox);
        if (type == 'budget') return _AddBudgetModal(settingsBox: settingsBox);
        if (type == 'planner') return _AddPlannerModal(settingsBox: settingsBox);
        return _AddGoalModal(settingsBox: settingsBox);
      },
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
          backgroundColor: kDarkBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: kGlassBorder)),
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          content: const Text("This action cannot be undone.", style: TextStyle(color: Colors.white54, fontSize: 14)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: kTeal))),
            Container(
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFD32F2F)]), borderRadius: BorderRadius.circular(8)),
              child: TextButton(
                onPressed: () { Navigator.pop(ctx); onConfirm(); },
                child: const Text("DELETE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      backgroundColor: kDarkBg,
      body: Stack(
        children: [
          Positioned(top: -120, left: -80, child: Container(width: 400, height: 400, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [kTealGlow, Colors.transparent], stops: [0.0, 0.7])))),
          Positioned(bottom: -100, right: -100, child: Container(width: 350, height: 350, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0x1E6C63FF), Colors.transparent], stops: [0.0, 0.7])))),

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
                        
                        double totalBalance = vBox.values.fold(0, (sum, item) => sum + item.balance);
                        double monthIncome = 0;
                        double monthExpense = 0;
                        Map<String, double> categorySpentMap = {};

                        // Calculate current month's totals AND category spends directly from transactions
                        DateTime now = DateTime.now();
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
                            );
                        }

                        return Column(
                          children: [
                            _buildTopNavDropdown(),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                switchInCurve: Curves.easeOut, switchOutCurve: Curves.easeIn,
                                transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.0, 0.05), end: Offset.zero).animate(animation), child: child)),
                                child: SingleChildScrollView(
                                  key: ValueKey(_activeTab),
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("F I N A N C E", style: TextStyle(color: kTeal, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16)),
          Theme(
            data: Theme.of(context).copyWith(
              popupMenuTheme: PopupMenuThemeData(
                color: kDarkBg.withOpacity(0.95),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: kGlassBorder, width: 1.5)),
              )
            ),
            child: PopupMenuButton<String>(
              onSelected: (val) => setState(() => _activeTab = val),
              offset: const Offset(0, 40),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: kGlassBorder, width: 1.5)),
                child: Row(
                  children: [
                    Text(_activeTab[0].toUpperCase() + _activeTab.substring(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 6),
                    const Icon(Icons.keyboard_arrow_down, color: kTeal, size: 18),
                  ],
                ),
              ),
              itemBuilder: (context) => [
                _buildMenuItem("home", "Home", Icons.home_filled),
                _buildMenuItem("transactions", "Transactions", Icons.receipt_long),
                _buildMenuItem("budget", "Budget", Icons.pie_chart),
                _buildMenuItem("planner", "Planner", Icons.calendar_today),
                _buildMenuItem("goals", "Goals", Icons.flag),
              ],
            ),
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
          Icon(icon, color: isSel ? kTeal : Colors.white54, size: 18),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: isSel ? kTeal : Colors.white, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
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

  const _HomeTab({
    required this.totalBalance, required this.monthIncome, required this.monthExpense, required this.savingsRate, required this.leftover, required this.vaults, required this.transactions,
    required this.spendingTrend, required this.categoryBreakdown, required this.onAddTx, required this.onAddVault, required this.onDeleteVault
  });

  @override
  Widget build(BuildContext context) {
    String monthName = DateFormat('MMM').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          glow: true, padding: const EdgeInsets.all(24),
          gradient: LinearGradient(colors: [kTeal.withOpacity(0.12), Colors.black.withOpacity(0.2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("TOTAL NET WORTH", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 3)),
              const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: totalBalance),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) => Text(formatINRFull(value), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildStatCard("↑ INCOME", formatINR(monthIncome), monthName, kTeal),
                  const SizedBox(width: 12),
                  _buildStatCard("↓ SPENT", formatINR(monthExpense), monthName, const Color(0xFFFF6B6B)),
                  const SizedBox(width: 12),
                  _buildStatCard("💰 LEFT", formatINR(leftover), "Leftover", const Color(0xFFFFD93D)),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 16),

        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AnimatedRingProgress(progress: savingsRate / 100, color: kTeal, size: 72, stroke: 7, label: "${savingsRate.toInt()}%", sublabel: "SAVED"),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("SAVINGS RATE", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                    const Text("Great Job! 🎉", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    AnimatedProgressBar(progress: savingsRate / 100, color1: kTeal, color2: kTeal2),
                    const SizedBox(height: 6),
                    Text("Target: 50% | ${formatINR(leftover)} saved", style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
                  ],
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 16),

        SectionHeader(title: "ASSET VAULTS", onAdd: onAddVault),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(),
            itemCount: vaults.length + 1,
            itemBuilder: (context, i) {
              if (i == vaults.length) {
                return GestureDetector(onTap: onAddVault, child: Container(width: 120, margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(border: Border.all(color: Colors.white.withOpacity(0.15), style: BorderStyle.none), borderRadius: BorderRadius.circular(24)), child: CustomPaint(painter: DashedBorderPainter(), child: Center(child: Text("+", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 32, fontWeight: FontWeight.w300))))));
              }
              final v = vaults[i]; Color vColor = Color(v.colorValue);
              return GestureDetector(
                onLongPress: () => onDeleteVault(v),
                child: Container(
                  width: 200, margin: const EdgeInsets.only(right: 12),
                  child: GlassCard(
                    padding: const EdgeInsets.all(18), borderColor: vColor.withOpacity(0.2), gradient: LinearGradient(colors: [vColor.withOpacity(0.1), Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(v.name, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.bold)), const Text("🏦", style: TextStyle(fontSize: 20))]),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(formatINR(v.balance), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)), Text("${v.bank} · ${v.type}", style: TextStyle(color: vColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))])
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        const SectionHeader(title: "CASH FLOW (LAST 6 MONTHS)"),
        GlassCard(
          padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
          child: SizedBox(
            height: 160,
            child: LineChart(LineChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withOpacity(0.04), strokeWidth: 1)),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, meta) {
                  if (v.toInt() >= 0 && v.toInt() < spendingTrend.length) return Padding(padding: const EdgeInsets.only(top: 8), child: Text(spendingTrend[v.toInt()]['month'], style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)));
                  return const SizedBox();
                })),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(spots: spendingTrend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['income'] as double)).toList(), isCurved: true, color: kTeal, barWidth: 2.5, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [kTeal.withOpacity(0.3), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
                LineChartBarData(spots: spendingTrend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['expense'] as double)).toList(), isCurved: true, color: const Color(0xFFFF6B6B), barWidth: 2.5, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [const Color(0xFFFF6B6B).withOpacity(0.3), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)))
              ]
            )),
          ),
        ),
        const SizedBox(height: 16),

        if (categoryBreakdown.isNotEmpty) ...[
          const SectionHeader(title: "THIS MONTH'S SPEND"),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  height: 140, width: 140,
                  child: PieChart(PieChartData(
                    sectionsSpace: 4, centerSpaceRadius: 42,
                    sections: categoryBreakdown.asMap().entries.map((e) => PieChartSectionData(color: pieColors[e.key % pieColors.length], value: e.value['value'], radius: 26, showTitle: false)).toList(),
                  )),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: categoryBreakdown.take(5).toList().asMap().entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: pieColors[e.key % pieColors.length], borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 8),
                            Expanded(child: Text(e.value['name'], style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text(formatINR(e.value['value']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        SectionHeader(title: "RECENT ACTIVITY", onAdd: onAddTx),
        if (transactions.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("No transactions recorded yet.", style: TextStyle(color: Colors.white54))))
        else ...transactions.take(4).map((tx) => TxRow(tx: tx)).toList(),
      ],
    );
  }

  Widget _buildStatCard(String label, String amount, String subtitle, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
          Text(amount, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
          Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
        ]),
      ),
    );
  }
}

class _TransactionsTab extends StatefulWidget {
  final List<Transaction> transactions;
  final VoidCallback onAdd;
  final Function(Transaction) onDelete;
  const _TransactionsTab({required this.transactions, required this.onAdd, required this.onDelete});

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
            const Text("All Transactions", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            GestureDetector(onTap: widget.onAdd, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(gradient: const LinearGradient(colors: [kTeal, kTeal2]), borderRadius: BorderRadius.circular(12)), child: const Text("+ ADD", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12))))
          ],
        ),
        const SizedBox(height: 16),
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
                  margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: isSel ? kTeal.withOpacity(0.15) : Colors.transparent, border: Border.all(color: isSel ? kTeal : kGlassBorder, width: 1.5), borderRadius: BorderRadius.circular(20)),
                  alignment: Alignment.center, child: Text(cats[i], style: TextStyle(color: isSel ? kTeal : Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("No transactions found.", style: TextStyle(color: Colors.white54))))
        else ...filtered.map((t) => Dismissible(
          key: Key(t.key.toString()),
          direction: DismissDirection.endToStart,
          background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(24)), margin: const EdgeInsets.only(bottom: 10), child: const Icon(Icons.delete, color: Colors.white)),
          confirmDismiss: (direction) async { widget.onDelete(t); return false; },
          child: TxRow(tx: t),
        )).toList(),
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
          glow: true, padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text("MONTHLY BUDGET USED", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              RichText(text: TextSpan(children: [TextSpan(text: formatINR(totalSpent), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)), TextSpan(text: " / Limit: ${formatINR(totalLimit)}", style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.bold))])),
              const SizedBox(height: 12),
              AnimatedProgressBar(progress: totalPct, color1: kTeal, color2: const Color(0xFFFFD93D)),
              const SizedBox(height: 8),
              Text("${(totalPct * 100).toStringAsFixed(1)}% used · ${formatINR(totalLimit > totalSpent ? totalLimit - totalSpent : 0)} remaining", style: const TextStyle(color: kTeal, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      AnimatedRingProgress(progress: pct.clamp(0.0, 1.0), color: col, size: 72, stroke: 7, label: "${(pct * 100).toStringAsFixed(0)}%"),
                      const SizedBox(height: 8),
                      Text("${b['icon']} ${b['category']}", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1), textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text("${formatINR(spent)} spent", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                      Text("Limit: ${formatINR(limit)}", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
                      if (pct > 0.9) Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0x33FF6B6B), border: Border.all(color: const Color(0x66FF6B6B)), borderRadius: BorderRadius.circular(8)), child: const Text("ALERT", style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 9, fontWeight: FontWeight.bold))),
                    ],
                  )
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        if (totalSpent > 0 && budgets.isNotEmpty) ...[
          const SectionHeader(title: "DYNAMIC BREAKDOWN"),
          GlassCard(
            padding: const EdgeInsets.all(16),
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
          glow: true, padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text("COMMITTED THIS MONTH", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: committed),
                duration: const Duration(milliseconds: 800),
                builder: (context, val, child) => Text(formatINR(val), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 12),
              Row(children: [_buildMiniCard("📋 FIXED", formatINR(totalFixed), const Color(0xFFFF6B6B)), const SizedBox(width: 10), _buildMiniCard("📈 SIP", formatINR(totalSIP), kTeal)]),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const SectionHeader(title: "DYNAMIC MONTHLY FLOW"),
        GlassCard(
          padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
          child: SizedBox(
            height: 140,
            child: LineChart(LineChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withOpacity(0.04), strokeWidth: 1)),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, meta) {
                  List labels = ["Inc", "Fix", "Var", "Sav"];
                  if (v.toInt() >= 0 && v.toInt() < labels.length) return Padding(padding: const EdgeInsets.only(top: 8), child: Text(labels[v.toInt()], style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)));
                  return const SizedBox();
                })),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: [FlSpot(0, monthIncome), FlSpot(1, monthIncome - totalFixed), FlSpot(2, (monthIncome - totalFixed) - (actualVariable > 0 ? actualVariable : 0)), FlSpot(3, actualSavings > 0 ? actualSavings : 0)],
                  isCurved: true, color: kTeal, barWidth: 3, dotData: FlDotData(show: true, getDotPainter: (s,p,b,i) => FlDotCirclePainter(color: kTeal, strokeWidth: 0, radius: 5)),
                )
              ]
            ))
          )
        ),
        const SizedBox(height: 16),

        const SectionHeader(title: "FIXED EXPENSES & EMIs"),
        if (fixed.isEmpty) const Text("No fixed expenses tracked.", style: TextStyle(color: Colors.white54)),
        ...fixed.asMap().entries.map((e) => Dismissible(
          key: UniqueKey(), direction: DismissDirection.endToStart,
          background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(24)), margin: const EdgeInsets.only(bottom: 10), child: const Icon(Icons.delete, color: Colors.white)),
          confirmDismiss: (d) async { onDeleteFixed(e.key); return false; },
          child: _buildPlannerRow(e.value['category'] == "EMI" ? "🏦" : "🛡️", e.value['name'], "Due on ${e.value['due']}th · ${e.value['category']}", "-${formatINR(e.value['amount'])}", const Color(0xFFFF6B6B)),
        )).toList(),
        
        const SizedBox(height: 16),
        const SectionHeader(title: "SIP / INVESTMENTS"),
        if (sips.isEmpty) const Text("No SIPs tracked.", style: TextStyle(color: Colors.white54)),
        ...sips.asMap().entries.map((s) => Dismissible(
          key: UniqueKey(), direction: DismissDirection.endToStart,
          background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(24)), margin: const EdgeInsets.only(bottom: 10), child: const Icon(Icons.delete, color: Colors.white)),
          confirmDismiss: (d) async { onDeleteSip(s.key); return false; },
          child: _buildPlannerRow("📈", s.value['name'], "Due ${s.value['due']}st · ${s.value['folio']}", formatINR(s.value['amount']), kTeal),
        )).toList(),
      ],
    );
  }

  Widget _buildMiniCard(String title, String amount, Color color) {
    return Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(amount, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16))])));
  }

  Widget _buildPlannerRow(String icon, String title, String sub, String amt, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: Text(icon, style: const TextStyle(fontSize: 20))), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), const SizedBox(height: 2), Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11))])),
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
              padding: const EdgeInsets.all(20), margin: const EdgeInsets.only(bottom: 14),
              borderColor: c.withOpacity(0.2), gradient: LinearGradient(colors: [c.withOpacity(0.05), Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight),
              child: Column(
                children: [
                  Row(children: [
                    Container(width: 52, height: 52, decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(16)), alignment: Alignment.center, child: Text(g['icon'], style: const TextStyle(fontSize: 26))), const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(g['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 2), Text("Target: ${formatINRFull(target)} · Due ${g['deadline']}", style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11))])),
                    AnimatedRingProgress(progress: pct, color: c, size: 56, stroke: 6, label: "${(pct * 100).toStringAsFixed(0)}%")
                  ]),
                  const SizedBox(height: 14),
                  AnimatedProgressBar(progress: pct, color1: c, color2: c.withOpacity(0.5)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Saved: ${formatINR(saved)}", style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.bold)), Text("Need: ${formatINR(rem > 0 ? rem : 0)}", style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12))])
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
      margin: margin ?? const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: glow ? const [BoxShadow(color: kTealGlow, blurRadius: 40, offset: Offset(0, 8)), BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))] : const [BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 4))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: Container(padding: padding, decoration: BoxDecoration(color: kCardBg, gradient: gradient, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor ?? kGlassBorder, width: 1.5)), child: child)),
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
              if (sublabel != null) Text(sublabel!, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 8, letterSpacing: 1)),
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
      height: 8, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 1000), curve: Curves.easeOutCubic,
        builder: (context, value, child) => FractionallySizedBox(
          widthFactor: value,
          child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [color1, color2]), borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: color1.withOpacity(0.4), blurRadius: 8)])),
        ),
      ),
    );
  }
}

class TxRow extends StatelessWidget {
  final Transaction tx;
  const TxRow({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    bool isIncome = tx.amount > 0;
    return GlassCard(
      padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Text(tx.icon, style: const TextStyle(fontSize: 20))), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tx.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), const SizedBox(height: 2), Text("${DateFormat('MMM d').format(tx.date)} · ${tx.mode}", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11))])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text("${isIncome ? '+' : '-'}${formatINR(tx.amount.abs())}", style: TextStyle(color: isIncome ? kTeal : const Color(0xFFFF6B6B), fontWeight: FontWeight.w800, fontSize: 15)), const SizedBox(height: 2), Text(tx.category, style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 10))])
      ])
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: kTeal.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
          if (onAdd != null) GestureDetector(onTap: onAdd, child: Container(width: 24, height: 24, decoration: BoxDecoration(color: kTeal.withOpacity(0.15), border: Border.all(color: kGlassBorder), shape: BoxShape.circle), child: const Icon(Icons.add, color: kTeal, size: 14)))
        ],
      ),
    );
  }
}

// --- Modals ---

class _AddTransactionModal extends StatefulWidget {
  final Box<Transaction> txBox;
  final Box<AssetVault> vaultBox;
  const _AddTransactionModal({required this.txBox, required this.vaultBox});
  @override
  State<_AddTransactionModal> createState() => _AddTransactionModalState();
}
class _AddTransactionModalState extends State<_AddTransactionModal> {
  String type = "expense", title = "", amount = "", category = "Food", upi = "";
  void _save() {
    if (title.isEmpty || amount.isEmpty) return;
    double amt = safeParse(amount);
    if (amt == 0) return;
    
    String finalCat = type == "income" ? "Income" : category;
    
    widget.txBox.add(Transaction(title: title, amount: type == "expense" ? -amt.abs() : amt.abs(), category: finalCat, date: DateTime.now(), mode: upi.isEmpty ? "UPI" : upi, icon: type == "income" ? "💰" : "💸"));
    Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    return _BaseModal(title: "LOG TRANSACTION", onSave: _save, child: Column(children: [
      Row(children: ["expense", "income"].map((t) => Expanded(child: GestureDetector(onTap: () => setState(() => type = t), child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: type == t ? kTeal.withOpacity(0.15) : Colors.transparent, border: Border.all(color: type == t ? kTeal : kGlassBorder, width: 1.5), borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Text(t.toUpperCase(), style: TextStyle(color: type == t ? kTeal : Colors.white54, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)))))).toList()),
      _ModalInput(hint: "Title (e.g., Swiggy, Salary)", onChanged: (v) => title = v),
      _ModalInput(hint: "Amount (₹)", keyboardType: TextInputType.number, onChanged: (v) => amount = v),
      if (type == "expense") _ModalDropdown(value: category, items: kExpenseCategories, onChanged: (v) => setState(() => category = v!)),
      _ModalInput(hint: "Mode (e.g., UPI)", onChanged: (v) => upi = v),
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
    widget.vaultBox.add(AssetVault(name: name.toUpperCase(), balance: safeParse(balance), bank: type, type: type, colorValue: kTeal.value));
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
      Wrap(spacing: 8, runSpacing: 8, children: icons.map((e) => GestureDetector(onTap: () => setState(() => icon = e), child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 36, height: 36, decoration: BoxDecoration(color: icon == e ? kTeal.withOpacity(0.15) : Colors.transparent, border: Border.all(color: icon == e ? kTeal : kGlassBorder, width: 1.5), borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Text(e, style: const TextStyle(fontSize: 18))))).toList()),
      const SizedBox(height: 12),
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
    Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    return _BaseModal(title: "ADD FUNDS TO ${widget.goal['name'].toUpperCase()}", onSave: _save, child: Column(children: [
      Text("Target: ${formatINRFull(widget.goal['target'])} · Currently Saved: ${formatINRFull(widget.goal['saved'])}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 16),
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
      Row(children: ["Fixed", "SIP"].map((t) => Expanded(child: GestureDetector(onTap: () => setState(() => type = t), child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: type == t ? kTeal.withOpacity(0.15) : Colors.transparent, border: Border.all(color: type == t ? kTeal : kGlassBorder, width: 1.5), borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Text(t.toUpperCase(), style: TextStyle(color: type == t ? kTeal : Colors.white54, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)))))).toList()),
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
      decoration: BoxDecoration(color: const Color(0xFF0F1923), border: Border.all(color: kGlassBorder, width: 1.5), borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), boxShadow: const [BoxShadow(color: kTealGlow, blurRadius: 40, offset: Offset(0, -8))]),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(color: kTeal, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2)), GestureDetector(onTap: () => Navigator.pop(context), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.close, color: Colors.white, size: 16)))]),
            const SizedBox(height: 20), child, const SizedBox(height: 8),
            Row(children: [
              Expanded(child: GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5), borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: const Text("CANCEL", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: GestureDetector(onTap: onSave, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: const LinearGradient(colors: [kTeal, kTeal2]), borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: const Text("SAVE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1))))),
            ])
          ],
        ),
      ),
    );
  }
}

class _ModalInput extends StatelessWidget {
  final String hint; final ValueChanged<String> onChanged; final TextInputType keyboardType;
  const _ModalInput({required this.hint, required this.onChanged, this.keyboardType = TextInputType.text});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(onChanged: onChanged, keyboardType: keyboardType, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGlassBorder, width: 1.5)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGlassBorder, width: 1.5)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kTeal, width: 1.5)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))));
  }
}

class _ModalDropdown extends StatelessWidget {
  final String value; final List<String> items; final ValueChanged<String?> onChanged;
  const _ModalDropdown({required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), border: Border.all(color: kGlassBorder, width: 1.5), borderRadius: BorderRadius.circular(12)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value, isExpanded: true, dropdownColor: kDarkBg, style: const TextStyle(color: Colors.white, fontSize: 14), icon: const Icon(Icons.arrow_drop_down, color: Colors.white54), items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged))));
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
    canvas.drawCircle(center, radius, Paint()..color = Colors.white.withOpacity(0.05)..style = PaintingStyle.stroke..strokeWidth = strokeWidth);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * progress, false, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.15)..style = PaintingStyle.stroke..strokeWidth = 1.5;
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