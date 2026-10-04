import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/engine/budget_engine.dart';
import 'package:habit_tracker/features/finance/models/models.dart';
import 'package:habit_tracker/features/finance/ui/budget/budget_line_sheet.dart';
import 'package:habit_tracker/features/finance/ui/budget/budget_settings_sheet.dart';

class BudgetTab extends StatefulWidget {
  const BudgetTab({super.key});

  @override
  State<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<BudgetTab> {
  final FinanceController _controller = FinanceController();
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  void initState() {
    super.initState();
    // Trigger any pending budget alerts evaluation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.checkAndTriggerBudgetAlerts();
    });
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
    HapticFeedback.selectionClick();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
    HapticFeedback.selectionClick();
  }

  void _resetToCurrentMonth() {
    setState(() {
      _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    });
    HapticFeedback.selectionClick();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final mode = _controller.budgetMode;

        return Scaffold(
          backgroundColor: BentoTheme.background,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                // Header & Controls
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top bar: Title & Settings
                        Row(
                          children: [
                            Text(
                              'Budgets',
                              style: TextStyle(
                                color: BentoTheme.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(LucideIcons.sliders, size: 20),
                              color: BentoTheme.textSecondary,
                              tooltip: 'Budget Settings',
                              onPressed: () {
                                BudgetSettingsSheet.show(context, _controller);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Month Navigation Bar
                        _buildMonthSelector(),
                        const SizedBox(height: 16),

                        // Mode Switcher (Simple, 50/30/20, Zero-based)
                        _buildModeSelector(mode),
                      ],
                    ),
                  ),
                ),

                // Content based on Mode
                if (mode == '50_30_20') ...[
                  _build50_30_20Sliver(),
                ] else if (mode == 'zero_based') ...[
                  _buildZeroBasedSliver(),
                ] else ...[
                  _buildSimpleModeSliver(),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              BudgetLineSheet.show(
                context,
                controller: _controller,
                currentMonth: _selectedMonth,
              );
            },
            backgroundColor: BentoTheme.accent,
            foregroundColor: Colors.black,
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text(
              'Add Budget',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // MONTH SELECTOR & MODE SWITCHER
  // ---------------------------------------------------------------------------

  Widget _buildMonthSelector() {
    final monthFormat = DateFormat('MMMM yyyy');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(LucideIcons.chevronLeft, size: 20),
            color: BentoTheme.textPrimary,
            onPressed: _prevMonth,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                monthFormat.format(_selectedMonth),
                style: TextStyle(
                  color: BentoTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!_isCurrentMonth) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: _resetToCurrentMonth,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: BentoTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Current',
                      style: TextStyle(
                        color: BentoTheme.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          IconButton(
            icon: const Icon(LucideIcons.chevronRight, size: 20),
            color: BentoTheme.textPrimary,
            onPressed: _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(String currentMode) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          _buildModePill('Simple', 'simple', currentMode),
          _buildModePill('50/30/20', '50_30_20', currentMode),
          _buildModePill('Zero-Based', 'zero_based', currentMode),
        ],
      ),
    );
  }

  Widget _buildModePill(String title, String key, String currentMode) {
    final isSelected = currentMode == key;

    return Expanded(
      child: InkWell(
        onTap: () {
          _controller.setBudgetMode(key);
          HapticFeedback.selectionClick();
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? BentoTheme.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.black : BentoTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. SIMPLE MODE
  // ---------------------------------------------------------------------------

  Widget _buildSimpleModeSliver() {
    final lines = _controller.allBudgetLines;
    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);

    if (lines.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.walletCards, size: 48, color: BentoTheme.textSecondary),
                const SizedBox(height: 16),
                Text(
                  'No Budgets Set',
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Set monthly limits on your categories with optional rollover carryover.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    BudgetLineSheet.show(
                      context,
                      controller: _controller,
                      currentMonth: _selectedMonth,
                    );
                  },
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Create First Budget'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BentoTheme.accent,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Calculate totals
    double totalBudget = 0.0;
    double totalSpent = 0.0;

    for (final line in lines) {
      final eff = _controller.getEffectiveBudget(line, monthKey);
      final spent = _controller.getCategoryMonthSpent(line.categoryId ?? '', _selectedMonth);
      totalBudget += eff;
      totalSpent += spent;
    }

    final totalRemaining = totalBudget - totalSpent;
    final totalPct = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildListAdapter([
          // Summary Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: ExpressiveTokens.borderL,
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL BUDGETED',
                      style: TextStyle(
                        color: BentoTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      totalRemaining >= 0
                          ? '${FormatUtils.formatMoney(totalRemaining)} left'
                          : '${FormatUtils.formatMoney(totalRemaining.abs())} over',
                      style: TextStyle(
                        color: totalRemaining >= 0 ? const Color(0xFF10B981) : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      FormatUtils.formatMoney(totalSpent),
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'of ${FormatUtils.formatMoney(totalBudget)}',
                      style: TextStyle(color: BentoTheme.textSecondary, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: totalPct,
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      totalSpent > totalBudget
                          ? Colors.redAccent
                          : (totalPct > 0.8 ? Colors.amberAccent : BentoTheme.accent),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Text(
            'CATEGORY BUDGETS',
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),

          // List of Category Budget Cards
          ...lines.map((line) => _buildSimpleBudgetCard(line, monthKey)),
        ]),
      ),
    );
  }

  Widget _buildSimpleBudgetCard(BudgetLine line, String monthKey) {
    final category = line.categoryId != null
        ? _controller.storage.categoryBox.get(line.categoryId!)
        : null;

    final eff = _controller.getEffectiveBudget(line, monthKey);
    final spent = _controller.getCategoryMonthSpent(line.categoryId ?? '', _selectedMonth);
    final now = DateTime.now();
    final evalDate = _isCurrentMonth ? now : DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final proj = _controller.getCategoryProjectedSpend(line.categoryId ?? '', evalDate);
    final status = BudgetEngine.evaluateStatus(
      effectiveBudget: eff,
      spent: spent,
      projectedSpend: proj,
      currentDate: evalDate,
    );

    final cut = _controller.getRecommendedWeeklyCut(proj, eff, evalDate);
    final overrides = _controller.budgetOverrides;
    final hasOverride = overrides.containsKey('${line.id}_$monthKey');
    final carry = eff - (hasOverride ? overrides['${line.id}_$monthKey']! : line.amount);

    final pct = eff > 0 ? (spent / eff).clamp(0.0, 1.0) : 0.0;
    final catColor = Color(category?.colorValue ?? 0xFF00E5FF);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderM,
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            BudgetLineSheet.show(
              context,
              controller: _controller,
              existingLine: line,
              currentMonth: _selectedMonth,
            );
          },
          borderRadius: ExpressiveTokens.borderM,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Category icon, Name, Spent / Effective
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(LucideIcons.tag, size: 18, color: catColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  category?.name ?? 'Category',
                                  style: TextStyle(
                                    color: BentoTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (line.essential) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.amberAccent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Needs',
                                    style: TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${FormatUtils.formatMoney(spent)} of ${FormatUtils.formatMoney(eff)}',
                            style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    // Badges (Rollover, Override)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (line.rollover && carry.abs() > 0.01)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: carry > 0
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : Colors.redAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.repeat,
                                  size: 10,
                                  color: carry > 0 ? const Color(0xFF10B981) : Colors.redAccent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  carry > 0
                                      ? '+${FormatUtils.formatMoney(carry)}'
                                      : '-${FormatUtils.formatMoney(carry.abs())}',
                                  style: TextStyle(
                                    color: carry > 0 ? const Color(0xFF10B981) : Colors.redAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (hasOverride) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purpleAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Override',
                              style: TextStyle(
                                color: Colors.purpleAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      status.isOverBudget
                          ? Colors.redAccent
                          : (status.isProjectedOver
                              ? Colors.amberAccent
                              : (pct > 0.8 ? Colors.amberAccent : BentoTheme.accent)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Status & Pace Recommendations
                Row(
                  children: [
                    Icon(
                      status.isOverBudget
                          ? LucideIcons.alertCircle
                          : (status.isProjectedOver
                              ? LucideIcons.trendingUp
                              : LucideIcons.checkCircle2),
                      size: 13,
                      color: status.isOverBudget
                          ? Colors.redAccent
                          : (status.isProjectedOver ? Colors.amberAccent : const Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        status.statusCopy,
                        style: TextStyle(
                          color: status.isOverBudget
                              ? Colors.redAccent
                              : (status.isProjectedOver
                                  ? Colors.amberAccent
                                  : BentoTheme.textSecondary),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (cut > 0 && !status.isOverBudget) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Cut ~${FormatUtils.formatMoney(cut)}/wk',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. 50/30/20 MODE
  // ---------------------------------------------------------------------------

  Widget _build50_30_20Sliver() {
    final breakdown = _controller.get50_30_20Breakdown(_selectedMonth);
    final income = _controller.expectedIncome ?? 50000.0;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildListAdapter([
          // Expected Income Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: BentoTheme.surface,
              borderRadius: ExpressiveTokens.borderL,
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EXPECTED MONTHLY INCOME',
                        style: TextStyle(
                          color: BentoTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        FormatUtils.formatMoney(income),
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.pencil, size: 18),
                  color: BentoTheme.accent,
                  onPressed: () {
                    BudgetSettingsSheet.show(context, _controller);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Needs 50% Card
          _build50_30_20GroupCard(
            title: 'Needs (50%)',
            subtitle: 'Essential living: rent, groceries, bills, health, EMI',
            icon: LucideIcons.home,
            color: const Color(0xFF38BDF8),
            progress: breakdown['needs']!,
          ),
          const SizedBox(height: 12),

          // Wants 30% Card
          _build50_30_20GroupCard(
            title: 'Wants (30%)',
            subtitle: 'Discretionary lifestyle: dining out, shopping, OTT',
            icon: LucideIcons.shoppingBag,
            color: const Color(0xFFF472B6),
            progress: breakdown['wants']!,
          ),
          const SizedBox(height: 12),

          // Savings 20% Card
          _build50_30_20GroupCard(
            title: 'Savings & Debt (20%)',
            subtitle: 'Investments, goal contributions & sinking funds',
            icon: LucideIcons.trendingUp,
            color: const Color(0xFF34D399),
            progress: breakdown['savings']!,
            isSavings: true,
          ),
          const SizedBox(height: 16),

          // Explanatory info box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BentoTheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.info, size: 18, color: BentoTheme.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'The 50/30/20 framework splits take-home income into Essentials (50%), Lifestyle (30%), and Future Wealth (20%).',
                    style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _build50_30_20GroupCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required BudgetGroupProgress progress,
    bool isSavings = false,
  }) {
    final pct = progress.target > 0 ? (progress.actual / progress.target).clamp(0.0, 1.0) : 0.0;
    final isExceeded = progress.actual > progress.target;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderM,
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    FormatUtils.formatMoney(progress.actual),
                    style: TextStyle(
                      color: BentoTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Target: ${FormatUtils.formatMoney(progress.target)}',
                    style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                isSavings
                    ? (progress.actual >= progress.target
                        ? const Color(0xFF10B981)
                        : color)
                    : (isExceeded ? Colors.redAccent : color),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progress.percentUsed.toStringAsFixed(0)}% of target',
                style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
              ),
              Text(
                isSavings
                    ? (progress.actual >= progress.target
                        ? 'Goal reached!'
                        : '${FormatUtils.formatMoney(progress.target - progress.actual)} remaining')
                    : (isExceeded
                        ? 'Exceeded by ${FormatUtils.formatMoney(progress.actual - progress.target)}'
                        : '${FormatUtils.formatMoney(progress.target - progress.actual)} left'),
                style: TextStyle(
                  color: isSavings
                      ? (progress.actual >= progress.target
                          ? const Color(0xFF10B981)
                          : BentoTheme.textSecondary)
                      : (isExceeded ? Colors.redAccent : const Color(0xFF10B981)),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. ZERO-BASED MODE
  // ---------------------------------------------------------------------------

  Widget _buildZeroBasedSliver() {
    final leftToAssign = _controller.getZeroBasedLeftToAssign(_selectedMonth);
    final lines = _controller.allBudgetLines;
    final goals = _controller.storage.goalBox.values
        .where((g) => !g.archived && g.plannedMonthly != null && g.plannedMonthly! > 0)
        .toList();

    final isBalanced = leftToAssign.abs() < 0.01;
    final isUnder = leftToAssign > 0;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildListAdapter([
          // Zero-based Left to Assign Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isBalanced
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : (isUnder
                      ? Colors.amberAccent.withValues(alpha: 0.15)
                      : Colors.redAccent.withValues(alpha: 0.15)),
              borderRadius: ExpressiveTokens.borderL,
              border: Border.all(
                color: isBalanced
                    ? const Color(0xFF10B981).withValues(alpha: 0.4)
                    : (isUnder
                        ? Colors.amberAccent.withValues(alpha: 0.4)
                        : Colors.redAccent.withValues(alpha: 0.4)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isBalanced
                      ? LucideIcons.checkCircle2
                      : (isUnder ? LucideIcons.alertCircle : LucideIcons.alertTriangle),
                  size: 32,
                  color: isBalanced
                      ? const Color(0xFF10B981)
                      : (isUnder ? Colors.amberAccent : Colors.redAccent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBalanced
                            ? 'Zero-based Balanced!'
                            : (isUnder
                                ? '${FormatUtils.formatMoney(leftToAssign)} Left to Assign'
                                : 'Over-assigned by ${FormatUtils.formatMoney(leftToAssign.abs())}'),
                        style: TextStyle(
                          color: isBalanced
                              ? const Color(0xFF10B981)
                              : (isUnder ? Colors.amberAccent : Colors.redAccent),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isBalanced
                            ? 'Every single rupee has a defined job.'
                            : (isUnder
                                ? 'Allocate remaining income to categories or savings buckets.'
                                : 'Reduce category envelopes or goal reserves to reach zero.'),
                        style: TextStyle(color: BentoTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Envelopes List
          Text(
            'CATEGORY ENVELOPES',
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),

          ...lines.map((line) {
            final cat = line.categoryId != null
                ? _controller.storage.categoryBox.get(line.categoryId!)
                : null;
            final spent = _controller.getCategoryMonthSpent(
                line.categoryId ?? '', _selectedMonth);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BentoTheme.surface,
                borderRadius: ExpressiveTokens.borderM,
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Color(cat?.colorValue ?? 0xFF00E5FF),
                    child: const Icon(LucideIcons.tag, size: 12, color: Colors.black),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cat?.name ?? 'Category',
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        FormatUtils.formatMoney(line.amount),
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Spent: ${FormatUtils.formatMoney(spent)}',
                        style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          if (goals.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'SAVINGS & SINKING FUNDS',
              style: TextStyle(
                color: BentoTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),

            ...goals.map((g) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BentoTheme.surface,
                  borderRadius: ExpressiveTokens.borderM,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Color(g.colorValue),
                      child: const Icon(LucideIcons.target, size: 12, color: Colors.black),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        g.name,
                        style: TextStyle(
                          color: BentoTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      FormatUtils.formatMoney(g.plannedMonthly ?? 0),
                      style: TextStyle(
                        color: BentoTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ]),
      ),
    );
  }
}
