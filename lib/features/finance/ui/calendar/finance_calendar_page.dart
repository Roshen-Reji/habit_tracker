import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:habit_tracker/core/theme/bento_theme.dart';
import 'package:habit_tracker/core/theme/expressive_tokens.dart';
import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/engine/recurring_engine.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

enum CalendarEventType {
  income,
  bill,
  subscription,
  sip,
  emi,
  cardDue,
  goal,
  transaction,
}

class CalendarEvent {
  final String title;
  final double amount;
  final CalendarEventType type;
  final DateTime date;
  final String? subtitle;

  const CalendarEvent({
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    this.subtitle,
  });

  Color get color {
    switch (type) {
      case CalendarEventType.income:
        return const Color(0xFF10B981);
      case CalendarEventType.bill:
        return Colors.orangeAccent;
      case CalendarEventType.subscription:
        return Colors.purpleAccent;
      case CalendarEventType.sip:
        return const Color(0xFF00E5FF);
      case CalendarEventType.emi:
      case CalendarEventType.cardDue:
        return Colors.redAccent;
      case CalendarEventType.goal:
        return Colors.amberAccent;
      case CalendarEventType.transaction:
        return Colors.white54;
    }
  }
}

class FinanceCalendarPage extends StatefulWidget {
  const FinanceCalendarPage({super.key});

  @override
  State<FinanceCalendarPage> createState() => _FinanceCalendarPageState();
}

class _FinanceCalendarPageState extends State<FinanceCalendarPage> {
  final FinanceController _controller = FinanceController();
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
    HapticFeedback.selectionClick();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
    HapticFeedback.selectionClick();
  }

  void _selectDate(DateTime dt) {
    setState(() => _selectedDate = dt);
    HapticFeedback.selectionClick();
  }

  Map<int, List<CalendarEvent>> _computeMonthEvents() {
    final map = <int, List<CalendarEvent>>{};
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final from = DateTime(year, month, 1);
    final to = DateTime(year, month + 1, 0, 23, 59, 59);

    // 1. Recurring Rules
    final rules = _controller.allRecurringRules.where((r) => r.status == 'active').toList();
    for (final rule in rules) {
      final dates = RecurringEngine.occurrences(rule, from, to);
      for (final d in dates) {
        CalendarEventType type = CalendarEventType.bill;
        if (rule.kind == 'income') type = CalendarEventType.income;
        else if (rule.kind == 'subscription') type = CalendarEventType.subscription;
        else if (rule.kind == 'sip') type = CalendarEventType.sip;
        else if (rule.kind == 'emi') type = CalendarEventType.emi;

        map.putIfAbsent(d.day, () => []).add(CalendarEvent(
          title: rule.name,
          amount: rule.amount,
          type: type,
          date: d,
          subtitle: '${rule.frequency.toUpperCase()} • ${rule.kind.toUpperCase()}',
        ));
      }
    }

    // 2. Credit Cards Due Dates
    final accounts = _controller.storage.accountBox.values;
    for (final acc in accounts) {
      if (acc.kind == 'credit_card' && acc.dueDay != null) {
        final daysInMonth = DateTime(year, month + 1, 0).day;
        final d = acc.dueDay!.clamp(1, daysInMonth);
        map.putIfAbsent(d, () => []).add(CalendarEvent(
          title: '${acc.name} Due Date',
          amount: 0,
          type: CalendarEventType.cardDue,
          date: DateTime(year, month, d),
          subtitle: 'Credit Card Payment Due',
        ));
      }
    }

    // 3. Goals Deadlines
    final goals = _controller.storage.goalBox.values.where((g) => !g.archived).toList();
    for (final g in goals) {
      final deadline = g.deadline ?? g.dueDate;
      if (deadline != null && deadline.year == year && deadline.month == month) {
        map.putIfAbsent(deadline.day, () => []).add(CalendarEvent(
          title: '${g.name} Target Due',
          amount: g.targetAmount,
          type: CalendarEventType.goal,
          date: deadline,
          subtitle: g.kind == 'sinking_fund' ? 'Sinking Fund Due' : 'Savings Goal Deadline',
        ));
      }
    }

    // 4. Actual Transactions
    final txs = _controller.getTransactionsForMonth(_currentMonth);
    for (final tx in txs) {
      final d = tx.date.day;
      final isInc = tx.effectiveKind == 'income' || tx.effectiveKind == 'refund';
      map.putIfAbsent(d, () => []).add(CalendarEvent(
        title: tx.title,
        amount: tx.amount.abs(),
        type: isInc ? CalendarEventType.income : CalendarEventType.transaction,
        date: tx.date,
        subtitle: tx.category,
      ));
    }

    return map;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final eventsByDay = _computeMonthEvents();
        final selectedDayEvents = eventsByDay[_selectedDate.day] ?? [];

        // Daily totals for selected date
        double dayInflow = 0.0;
        double dayOutflow = 0.0;
        for (final e in selectedDayEvents) {
          if (e.type == CalendarEventType.income) {
            dayInflow += e.amount;
          } else if (e.amount > 0 && e.type != CalendarEventType.goal) {
            dayOutflow += e.amount;
          }
        }

        return Scaffold(
          backgroundColor: BentoTheme.background,
          appBar: AppBar(
            backgroundColor: BentoTheme.background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, size: 20),
              color: BentoTheme.textPrimary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Financial Calendar',
              style: TextStyle(
                color: BentoTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              // Month Selector Header
              _buildMonthHeader(),
              const SizedBox(height: 16),

              // Calendar Grid Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BentoTheme.surface,
                  borderRadius: ExpressiveTokens.borderL,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  children: [
                    _buildWeekdayHeaders(),
                    const SizedBox(height: 12),
                    _buildMonthGrid(eventsByDay),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Legend
              _buildLegend(),
              const SizedBox(height: 20),

              // Selected Day Header & Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('EEEE, dd MMMM').format(_selectedDate).toUpperCase(),
                    style: TextStyle(
                      color: BentoTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    'In: +${FormatUtils.formatMoney(dayInflow)}  •  Out: -${FormatUtils.formatMoney(dayOutflow)}',
                    style: TextStyle(
                      color: dayInflow > 0 ? const Color(0xFF10B981) : BentoTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Events for Selected Day
              if (selectedDayEvents.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: BentoTheme.surface,
                    borderRadius: ExpressiveTokens.borderM,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Center(
                    child: Text(
                      'No bills, goals or transactions scheduled for this date.',
                      style: TextStyle(color: BentoTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                ),
              ] else ...[
                ...selectedDayEvents.map((e) => _buildEventTile(e)),
              ],

              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthHeader() {
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
          Text(
            DateFormat('MMMM yyyy').format(_currentMonth),
            style: TextStyle(
              color: BentoTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
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

  Widget _buildWeekdayHeaders() {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: days.map((d) {
        return SizedBox(
          width: 36,
          child: Text(
            d,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BentoTheme.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMonthGrid(Map<int, List<CalendarEvent>> eventsByDay) {
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // Weekday: 1 is Mon, 7 is Sun
    final leadingBlanks = (firstDay.weekday - 1) % 7;
    final totalCells = ((leadingBlanks + daysInMonth + 6) ~/ 7) * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.85,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        final dayNumber = index - leadingBlanks + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }

        final cellDate = DateTime(year, month, dayNumber);
        final isSelected = cellDate.year == _selectedDate.year &&
            cellDate.month == _selectedDate.month &&
            cellDate.day == _selectedDate.day;

        final isToday = cellDate.year == DateTime.now().year &&
            cellDate.month == DateTime.now().month &&
            cellDate.day == DateTime.now().day;

        final dayEvents = eventsByDay[dayNumber] ?? [];

        return InkWell(
          onTap: () => _selectDate(cellDate),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? BentoTheme.accent.withValues(alpha: 0.25)
                  : (isToday ? Colors.white.withValues(alpha: 0.05) : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? BentoTheme.accent
                    : (isToday ? BentoTheme.accent.withValues(alpha: 0.5) : Colors.transparent),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: TextStyle(
                    color: isSelected
                        ? BentoTheme.accent
                        : (isToday ? BentoTheme.textPrimary : BentoTheme.textPrimary),
                    fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                // Dots for events
                if (dayEvents.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: dayEvents.take(3).map((e) {
                      return Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: e.color,
                          shape: BoxShape.circle,
                        ),
                      );
                    }).toList(),
                  )
                else
                  const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildLegendItem('Income', const Color(0xFF10B981)),
          const SizedBox(width: 12),
          _buildLegendItem('Bills', Colors.orangeAccent),
          const SizedBox(width: 12),
          _buildLegendItem('Subs', Colors.purpleAccent),
          const SizedBox(width: 12),
          _buildLegendItem('SIP / Inv', const Color(0xFF00E5FF)),
          const SizedBox(width: 12),
          _buildLegendItem('EMI / Cards', Colors.redAccent),
          const SizedBox(width: 12),
          _buildLegendItem('Goals', Colors.amberAccent),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildEventTile(CalendarEvent event) {
    final isIncome = event.type == CalendarEventType.income;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: BentoTheme.surface,
        borderRadius: ExpressiveTokens.borderM,
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: event.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    color: BentoTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (event.subtitle != null)
                  Text(
                    event.subtitle!,
                    style: TextStyle(color: BentoTheme.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (event.amount > 0)
            Text(
              '${isIncome ? '+' : '-'}${FormatUtils.formatMoney(event.amount)}',
              style: TextStyle(
                color: isIncome ? const Color(0xFF10B981) : BentoTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }
}
