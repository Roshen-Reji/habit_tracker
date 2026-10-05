import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:habit_tracker/features/finance/engine/ledger.dart';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

class MonthlySummaryReport {
  final DateTime month;
  final double income;
  final double spending;
  final double saved;
  final double invested;
  final double net;
  final double savingsRate;
  final double netWorthStart;
  final double netWorthEnd;
  final double netWorthChange;

  const MonthlySummaryReport({
    required this.month,
    required this.income,
    required this.spending,
    required this.saved,
    required this.invested,
    required this.net,
    required this.savingsRate,
    required this.netWorthStart,
    required this.netWorthEnd,
    required this.netWorthChange,
  });
}

class CategoryReportItem {
  final String categoryId;
  final String categoryName;
  final double amount;
  final double percentage; // 0 to 100
  final double lastMonthAmount;
  final double changePct; // e.g. +15.5%

  const CategoryReportItem({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.percentage,
    required this.lastMonthAmount,
    required this.changePct,
  });
}

class MerchantReportItem {
  final String merchant;
  final double totalSpent;
  final int transactionCount;
  final double avgAmount;

  const MerchantReportItem({
    required this.merchant,
    required this.totalSpent,
    required this.transactionCount,
    required this.avgAmount,
  });
}

class MonthComparisonItem {
  final String categoryId;
  final String categoryName;
  final double month1Amount;
  final double month2Amount;
  final double difference; // month2 - month1
  final double changePct;

  const MonthComparisonItem({
    required this.categoryId,
    required this.categoryName,
    required this.month1Amount,
    required this.month2Amount,
    required this.difference,
    required this.changePct,
  });
}

class MonthComparisonReport {
  final DateTime month1;
  final DateTime month2;
  final double month1Income;
  final double month2Income;
  final double month1Spending;
  final double month2Spending;
  final double month1Net;
  final double month2Net;
  final List<MonthComparisonItem> categoryComparisons;

  const MonthComparisonReport({
    required this.month1,
    required this.month2,
    required this.month1Income,
    required this.month2Income,
    required this.month1Spending,
    required this.month2Spending,
    required this.month1Net,
    required this.month2Net,
    required this.categoryComparisons,
  });
}

class TrendPoint {
  final DateTime month;
  final String label;
  final double income;
  final double spending;
  final double net;
  final double savingsRate;
  final double netWorth;

  const TrendPoint({
    required this.month,
    required this.label,
    required this.income,
    required this.spending,
    required this.net,
    required this.savingsRate,
    required this.netWorth,
  });
}

class ReportEngine {
  /// Generate monthly financial summary report
  static MonthlySummaryReport generateMonthlySummary({
    required DateTime month,
    required List<Transaction> transactions,
    required List<Account> accounts,
    required List<Valuation> valuations,
    required List<GoalEntry> goalEntries,
  }) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    final prevMonthEnd = DateTime(month.year, month.month, 0, 23, 59, 59);

    final txsThisMonth = transactions.where((t) =>
        t.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
        t.date.isBefore(endOfMonth.add(const Duration(seconds: 1)))).toList();

    final income = LedgerEngine.income(txsThisMonth);
    final spending = LedgerEngine.spending(txsThisMonth);
    final net = Money.r2(income - spending);
    final savingsRate = income > 0 ? (net / income).clamp(0.0, 1.0) : 0.0;

    // Invested: investment transactions this month
    double invested = 0.0;
    for (final tx in txsThisMonth) {
      if (tx.effectiveKind == 'investment') {
        invested += tx.amount.abs();
      }
    }

    // Goal savings contributions this month
    double goalSavings = 0.0;
    for (final entry in goalEntries) {
      if (entry.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
          entry.date.isBefore(endOfMonth.add(const Duration(seconds: 1)))) {
        if (entry.amount > 0) {
          goalSavings += entry.amount;
        }
      }
    }
    final saved = Money.r2(goalSavings + invested);

    // Net worth change
    final nwStart = LedgerEngine.netWorth(accounts, transactions, valuations, asOf: prevMonthEnd);
    final nwEnd = LedgerEngine.netWorth(accounts, transactions, valuations, asOf: endOfMonth);
    final nwChange = Money.r2(nwEnd - nwStart);

    return MonthlySummaryReport(
      month: month,
      income: Money.r2(income),
      spending: Money.r2(spending),
      saved: saved,
      invested: Money.r2(invested),
      net: net,
      savingsRate: Money.r2(savingsRate),
      netWorthStart: Money.r2(nwStart),
      netWorthEnd: Money.r2(nwEnd),
      netWorthChange: nwChange,
    );
  }

  /// Generate category spending report with month-over-month comparison
  static List<CategoryReportItem> generateCategoryReport({
    required DateTime month,
    required List<Transaction> transactions,
    required List<Category> categories,
  }) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final prevMonth = DateTime(month.year, month.month - 1);
    final startOfPrevMonth = DateTime(prevMonth.year, prevMonth.month, 1);
    final endOfPrevMonth = DateTime(prevMonth.year, prevMonth.month + 1, 0, 23, 59, 59);

    final txsThisMonth = transactions.where((t) =>
        t.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
        t.date.isBefore(endOfMonth.add(const Duration(seconds: 1)))).toList();

    final txsPrevMonth = transactions.where((t) =>
        t.date.isAfter(startOfPrevMonth.subtract(const Duration(seconds: 1))) &&
        t.date.isBefore(endOfPrevMonth.add(const Duration(seconds: 1)))).toList();

    final curBreakdown = LedgerEngine.categorySpending(txsThisMonth);
    final prevBreakdown = LedgerEngine.categorySpending(txsPrevMonth);

    final totalSpending = curBreakdown.values.fold(0.0, (sum, val) => sum + val);
    final catMap = {for (final c in categories) c.id: c.name};

    final items = <CategoryReportItem>[];
    for (final entry in curBreakdown.entries) {
      final catId = entry.key;
      final amount = entry.value;
      final prevAmount = prevBreakdown[catId] ?? 0.0;
      final pct = totalSpending > 0 ? (amount / totalSpending) * 100.0 : 0.0;
      final changePct = prevAmount > 0
          ? ((amount - prevAmount) / prevAmount) * 100.0
          : (amount > 0 ? 100.0 : 0.0);

      items.add(CategoryReportItem(
        categoryId: catId,
        categoryName: catMap[catId] ?? catId,
        amount: Money.r2(amount),
        percentage: Money.r2(pct),
        lastMonthAmount: Money.r2(prevAmount),
        changePct: Money.r2(changePct),
      ));
    }

    items.sort((a, b) => b.amount.compareTo(a.amount));
    return items;
  }

  /// Generate merchant spending breakdown
  static List<MerchantReportItem> generateMerchantReport({
    required DateTime month,
    required List<Transaction> transactions,
  }) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final txsThisMonth = transactions.where((t) =>
        t.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
        t.date.isBefore(endOfMonth.add(const Duration(seconds: 1))) &&
        t.effectiveKind == 'expense').toList();

    final totals = <String, double>{};
    final counts = <String, int>{};

    for (final tx in txsThisMonth) {
      final merchant = (tx.merchant != null && tx.merchant!.trim().isNotEmpty)
          ? tx.merchant!.trim()
          : (tx.title.isNotEmpty ? tx.title : 'Uncategorised Merchant');
      totals[merchant] = (totals[merchant] ?? 0.0) + tx.amount.abs();
      counts[merchant] = (counts[merchant] ?? 0) + 1;
    }

    final items = totals.entries.map((e) {
      final count = counts[e.key] ?? 1;
      return MerchantReportItem(
        merchant: e.key,
        totalSpent: Money.r2(e.value),
        transactionCount: count,
        avgAmount: Money.r2(e.value / count),
      );
    }).toList();

    items.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
    return items;
  }

  /// Compare two calendar months
  static MonthComparisonReport compareMonths({
    required DateTime month1,
    required DateTime month2,
    required List<Transaction> transactions,
    required List<Category> categories,
  }) {
    final start1 = DateTime(month1.year, month1.month, 1);
    final end1 = DateTime(month1.year, month1.month + 1, 0, 23, 59, 59);
    final start2 = DateTime(month2.year, month2.month, 1);
    final end2 = DateTime(month2.year, month2.month + 1, 0, 23, 59, 59);

    final txs1 = transactions.where((t) => t.date.isAfter(start1.subtract(const Duration(seconds: 1))) && t.date.isBefore(end1.add(const Duration(seconds: 1)))).toList();
    final txs2 = transactions.where((t) => t.date.isAfter(start2.subtract(const Duration(seconds: 1))) && t.date.isBefore(end2.add(const Duration(seconds: 1)))).toList();

    final inc1 = LedgerEngine.income(txs1);
    final sp1 = LedgerEngine.spending(txs1);
    final inc2 = LedgerEngine.income(txs2);
    final sp2 = LedgerEngine.spending(txs2);

    final b1 = LedgerEngine.categorySpending(txs1);
    final b2 = LedgerEngine.categorySpending(txs2);

    final allCatIds = {...b1.keys, ...b2.keys};
    final catMap = {for (final c in categories) c.id: c.name};

    final catComps = <MonthComparisonItem>[];
    for (final catId in allCatIds) {
      final a1 = b1[catId] ?? 0.0;
      final a2 = b2[catId] ?? 0.0;
      final diff = a2 - a1;
      final chg = a1 > 0 ? (diff / a1) * 100.0 : (a2 > 0 ? 100.0 : 0.0);
      catComps.add(MonthComparisonItem(
        categoryId: catId,
        categoryName: catMap[catId] ?? catId,
        month1Amount: Money.r2(a1),
        month2Amount: Money.r2(a2),
        difference: Money.r2(diff),
        changePct: Money.r2(chg),
      ));
    }

    catComps.sort((a, b) => b.month2Amount.compareTo(a.month2Amount));

    return MonthComparisonReport(
      month1: month1,
      month2: month2,
      month1Income: Money.r2(inc1),
      month2Income: Money.r2(inc2),
      month1Spending: Money.r2(sp1),
      month2Spending: Money.r2(sp2),
      month1Net: Money.r2(inc1 - sp1),
      month2Net: Money.r2(inc2 - sp2),
      categoryComparisons: catComps,
    );
  }

  /// Generate multi-month trend points (e.g. 3, 6, or 12 months)
  static List<TrendPoint> generateTrends({
    required int monthsBack,
    required DateTime currentMonth,
    required List<Transaction> transactions,
    required List<Account> accounts,
    required List<Valuation> valuations,
  }) {
    final points = <TrendPoint>[];
    for (var i = monthsBack - 1; i >= 0; i--) {
      final m = DateTime(currentMonth.year, currentMonth.month - i);
      final start = DateTime(m.year, m.month, 1);
      final end = DateTime(m.year, m.month + 1, 0, 23, 59, 59);

      final txs = transactions.where((t) =>
          t.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
          t.date.isBefore(end.add(const Duration(seconds: 1)))).toList();

      final inc = LedgerEngine.income(txs);
      final sp = LedgerEngine.spending(txs);
      final net = inc - sp;
      final rate = inc > 0 ? (net / inc).clamp(0.0, 1.0) : 0.0;
      final nw = LedgerEngine.netWorth(accounts, transactions, valuations, asOf: end);

      points.add(TrendPoint(
        month: m,
        label: DateFormat('MMM yy').format(m),
        income: Money.r2(inc),
        spending: Money.r2(sp),
        net: Money.r2(net),
        savingsRate: Money.r2(rate),
        netWorth: Money.r2(nw),
      ));
    }
    return points;
  }
}

/// RFC 4180 compliant CSV generator for P9-2
class CsvExporter {
  static String escapeCell(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  static String encodeRows(List<List<dynamic>> rows) {
    return rows.map((row) => row.map(escapeCell).join(',')).join('\r\n');
  }

  /// Export transactions to CSV
  static String exportTransactionsToCsv(List<Transaction> transactions, Map<String, Category> categories, Map<String, Account> accounts) {
    final headers = [
      'ID',
      'Date',
      'Time',
      'Title',
      'Merchant',
      'Kind',
      'Amount',
      'Category',
      'Account',
      'ToAccount',
      'PaymentMethod',
      'Notes',
      'Tags',
      'RecurringRuleID',
    ];

    final rows = <List<dynamic>>[headers];
    for (final tx in transactions) {
      final cat = tx.categoryId != null ? categories[tx.categoryId]?.name : tx.category;
      final acc = tx.accountId != null ? accounts[tx.accountId]?.name : '';
      final toAcc = tx.toAccountId != null ? accounts[tx.toAccountId]?.name : '';

      rows.add([
        tx.id,
        DateFormat('yyyy-MM-dd').format(tx.date),
        DateFormat('HH:mm:ss').format(tx.date),
        tx.title,
        tx.merchant ?? '',
        tx.effectiveKind,
        tx.amount,
        cat ?? '',
        acc ?? '',
        toAcc ?? '',
        tx.paymentMethod ?? '',
        tx.notes ?? '',
        tx.tags?.join(';') ?? '',
        tx.recurringRuleId ?? '',
      ]);
    }

    return encodeRows(rows);
  }

  /// Export monthly summary report to CSV
  static String exportMonthlySummaryToCsv(List<MonthlySummaryReport> reports) {
    final headers = [
      'Month',
      'Income',
      'Spending',
      'Net',
      'SavingsRatePct',
      'TotalSaved',
      'Invested',
      'NetWorthStart',
      'NetWorthEnd',
      'NetWorthChange',
    ];

    final rows = <List<dynamic>>[headers];
    for (final rep in reports) {
      rows.add([
        DateFormat('yyyy-MM').format(rep.month),
        rep.income,
        rep.spending,
        rep.net,
        (rep.savingsRate * 100).toStringAsFixed(1),
        rep.saved,
        rep.invested,
        rep.netWorthStart,
        rep.netWorthEnd,
        rep.netWorthChange,
      ]);
    }

    return encodeRows(rows);
  }

  /// Export category breakdown report to CSV
  static String exportCategoryReportToCsv(DateTime month, List<CategoryReportItem> items) {
    final headers = [
      'Month',
      'Category',
      'Amount',
      'Percentage',
      'LastMonthAmount',
      'ChangePct',
    ];

    final monthStr = DateFormat('yyyy-MM').format(month);
    final rows = <List<dynamic>>[headers];
    for (final item in items) {
      rows.add([
        monthStr,
        item.categoryName,
        item.amount,
        item.percentage,
        item.lastMonthAmount,
        item.changePct,
      ]);
    }

    return encodeRows(rows);
  }
}
