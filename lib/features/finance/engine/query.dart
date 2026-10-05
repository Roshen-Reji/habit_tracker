import 'package:habit_tracker/core/utils/format_utils.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:habit_tracker/features/finance/models/account.dart';
import 'package:habit_tracker/features/finance/models/category.dart';
import 'package:habit_tracker/features/finance/engine/ledger.dart';

enum QueryMetric { sum, count, avg, list, top }

enum QuerySubject { spending, income, net, balance, networth }

enum QueryPeriod {
  all,
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  thisYear,
  lastYear,
  custom,
}

enum QueryGroupBy { none, category, merchant, month, account }

class QueryFilters {
  final String? merchant;
  final String? category;
  final String? tag;
  final String? account;
  final double? amountMin;
  final double? amountMax;
  final QueryPeriod period;
  final DateTime? startDate;
  final DateTime? endDate;

  const QueryFilters({
    this.merchant,
    this.category,
    this.tag,
    this.account,
    this.amountMin,
    this.amountMax,
    this.period = QueryPeriod.all,
    this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toJson() => {
        if (merchant != null) 'merchant': merchant,
        if (category != null) 'category': category,
        if (tag != null) 'tag': tag,
        if (account != null) 'account': account,
        if (amountMin != null) 'amountMin': amountMin,
        if (amountMax != null) 'amountMax': amountMax,
        'period': period.name,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
      };

  factory QueryFilters.fromJson(Map<String, dynamic> json) {
    QueryPeriod p = QueryPeriod.all;
    if (json['period'] != null) {
      p = QueryPeriod.values.firstWhere(
        (v) => v.name == json['period'].toString().toLowerCase(),
        orElse: () => QueryPeriod.all,
      );
    }

    return QueryFilters(
      merchant: json['merchant']?.toString(),
      category: json['category']?.toString(),
      tag: json['tag']?.toString(),
      account: json['account']?.toString(),
      amountMin: json['amountMin'] != null ? (json['amountMin'] as num).toDouble() : null,
      amountMax: json['amountMax'] != null ? (json['amountMax'] as num).toDouble() : null,
      period: p,
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate']) : null,
    );
  }
}

class FinanceQuery {
  final QueryMetric metric;
  final QuerySubject subject;
  final QueryFilters filters;
  final QueryGroupBy groupBy;
  final QueryPeriod? compareTo;
  final int topN;

  const FinanceQuery({
    this.metric = QueryMetric.sum,
    this.subject = QuerySubject.spending,
    this.filters = const QueryFilters(),
    this.groupBy = QueryGroupBy.none,
    this.compareTo,
    this.topN = 5,
  });

  Map<String, dynamic> toJson() => {
        'metric': metric.name,
        'subject': subject.name,
        'filters': filters.toJson(),
        'groupBy': groupBy.name,
        if (compareTo != null) 'compareTo': compareTo!.name,
        'topN': topN,
      };

  factory FinanceQuery.fromJson(Map<String, dynamic> json) {
    final metricStr = (json['metric'] ?? 'sum').toString().toLowerCase();
    final subjectStr = (json['subject'] ?? 'spending').toString().toLowerCase();
    final groupByStr = (json['groupBy'] ?? 'none').toString().toLowerCase();

    final metric = QueryMetric.values.firstWhere(
      (m) => m.name == metricStr,
      orElse: () => QueryMetric.sum,
    );
    final subject = QuerySubject.values.firstWhere(
      (s) => s.name == subjectStr,
      orElse: () => QuerySubject.spending,
    );
    final groupBy = QueryGroupBy.values.firstWhere(
      (g) => g.name == groupByStr,
      orElse: () => QueryGroupBy.none,
    );

    QueryPeriod? compareTo;
    if (json['compareTo'] != null) {
      compareTo = QueryPeriod.values.firstWhere(
        (p) => p.name == json['compareTo'].toString().toLowerCase(),
        orElse: () => QueryPeriod.lastMonth,
      );
    }

    final filtersJson = json['filters'] != null && json['filters'] is Map
        ? Map<String, dynamic>.from(json['filters'] as Map)
        : <String, dynamic>{};

    return FinanceQuery(
      metric: metric,
      subject: subject,
      filters: QueryFilters.fromJson(filtersJson),
      groupBy: groupBy,
      compareTo: compareTo,
      topN: json['topN'] is int ? json['topN'] : int.tryParse(json['topN']?.toString() ?? '5') ?? 5,
    );
  }
}

class FinanceQueryResult {
  final double value;
  final int count;
  final List<Transaction> transactions;
  final Map<String, double> groups;
  final double? comparedValue;
  final String formattedAnswer;

  const FinanceQueryResult({
    required this.value,
    this.count = 0,
    this.transactions = const [],
    this.groups = const {},
    this.comparedValue,
    required this.formattedAnswer,
  });
}

class FinanceQueryExecutor {
  /// Deterministically executes a query against local repository models
  static FinanceQueryResult execute({
    required FinanceQuery query,
    required List<Transaction> transactions,
    required List<Account> accounts,
    required DateTime today,
    List<Category> categories = const [],
  }) {
    // 1. Balance and Net Worth shortcuts
    if (query.subject == QuerySubject.networth) {
      final nw = _calculateNetWorth(accounts, transactions, today);
      final ans = 'Your current net worth is ${FormatUtils.formatMoney(nw, decimals: 2)}.';
      return FinanceQueryResult(value: nw, count: 1, formattedAnswer: ans);
    }

    if (query.subject == QuerySubject.balance) {
      double bal = 0.0;
      final accFilter = query.filters.account?.toLowerCase();
      final targetAccounts = accFilter != null
          ? accounts.where((a) => a.name.toLowerCase().contains(accFilter))
          : accounts.where((a) => a.spendable && !a.archived);

      for (final a in targetAccounts) {
        bal += LedgerEngine.balance(a, transactions, const [], asOf: today);
      }
      final accountDesc = accFilter != null ? targetAccounts.map((a) => a.name).join(', ') : 'spendable accounts';
      final ans = 'The total balance for $accountDesc as of today is ${FormatUtils.formatMoney(bal, decimals: 2)}.';
      return FinanceQueryResult(value: bal, count: targetAccounts.length, formattedAnswer: ans);
    }

    // 2. Filter transactions by period, subject and criteria
    final dateRange = _resolveDateRange(query.filters.period, query.filters.startDate, query.filters.endDate, today);
    final filteredTxs = _filterTransactions(
      transactions: transactions,
      subject: query.subject,
      filters: query.filters,
      range: dateRange,
      categories: categories,
      accounts: accounts,
    );

    // 3. CompareTo calculation if requested
    double? compValue;
    if (query.compareTo != null) {
      final compRange = _resolveDateRange(query.compareTo!, null, null, today);
      final compTxs = _filterTransactions(
        transactions: transactions,
        subject: query.subject,
        filters: query.filters,
        range: compRange,
        categories: categories,
        accounts: accounts,
      );
      compValue = _computeMetricValue(query.metric, query.subject, compTxs);
    }

    // 4. GroupBy and Top N logic
    if (query.groupBy != QueryGroupBy.none || query.metric == QueryMetric.top) {
      final Map<String, double> groupMap = {};
      for (final tx in filteredTxs) {
        final key = _extractGroupKey(tx, query.groupBy != QueryGroupBy.none ? query.groupBy : QueryGroupBy.merchant, categories, accounts);
        final amt = _effectiveAmountForSubject(tx, query.subject);
        groupMap[key] = (groupMap[key] ?? 0.0) + amt;
      }

      // Sort descending
      final sortedEntries = groupMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final Map<String, double> topGroups = {};
      final limit = query.metric == QueryMetric.top ? query.topN : sortedEntries.length;
      for (var i = 0; i < sortedEntries.length && i < limit; i++) {
        topGroups[sortedEntries[i].key] = sortedEntries[i].value;
      }

      final totalSum = _computeMetricValue(QueryMetric.sum, query.subject, filteredTxs);
      final buffer = StringBuffer();
      buffer.writeln('Found ${filteredTxs.length} transactions totaling ${FormatUtils.formatMoney(totalSum, decimals: 2)}:');
      for (final entry in topGroups.entries) {
        buffer.writeln('• ${entry.key}: ${FormatUtils.formatMoney(entry.value, decimals: 2)}');
      }

      return FinanceQueryResult(
        value: totalSum,
        count: filteredTxs.length,
        transactions: filteredTxs,
        groups: topGroups,
        comparedValue: compValue,
        formattedAnswer: buffer.toString().trim(),
      );
    }

    // 5. Standard aggregate metric
    final computedValue = _computeMetricValue(query.metric, query.subject, filteredTxs);
    final count = filteredTxs.length;

    String answer;
    final subjectName = query.subject == QuerySubject.spending ? 'spending' : (query.subject == QuerySubject.income ? 'income' : 'net amount');
    final periodDesc = _describePeriod(query.filters.period);

    switch (query.metric) {
      case QueryMetric.count:
        answer = 'There are $count $subjectName transactions $periodDesc.';
        break;
      case QueryMetric.avg:
        answer = 'Average $subjectName transaction $periodDesc is ${FormatUtils.formatMoney(computedValue, decimals: 2)} (across $count transactions).';
        break;
      case QueryMetric.list:
        final preview = filteredTxs.take(5).map((t) => '${t.title}: ${FormatUtils.formatMoney(t.amount.abs(), decimals: 2)}').join(', ');
        answer = 'Found $count transactions totaling ${FormatUtils.formatMoney(computedValue, decimals: 2)}. $preview${count > 5 ? '...' : ''}';
        break;
      case QueryMetric.sum:
      default:
        if (query.filters.merchant != null) {
          answer = 'You spent ${FormatUtils.formatMoney(computedValue, decimals: 2)} at ${query.filters.merchant} $periodDesc.';
        } else if (query.filters.category != null) {
          answer = 'Total $subjectName on ${query.filters.category} $periodDesc is ${FormatUtils.formatMoney(computedValue, decimals: 2)}.';
        } else {
          answer = 'Total $subjectName $periodDesc is ${FormatUtils.formatMoney(computedValue, decimals: 2)}.';
        }
        if (compValue != null) {
          final diff = computedValue - compValue;
          final pct = compValue > 0 ? (diff / compValue * 100).toStringAsFixed(1) : '0';
          final dir = diff >= 0 ? 'up' : 'down';
          answer += ' (Compared to ${compValue.toStringAsFixed(2)}, $dir $pct%).';
        }
        break;
    }

    return FinanceQueryResult(
      value: computedValue,
      count: count,
      transactions: filteredTxs,
      comparedValue: compValue,
      formattedAnswer: answer,
    );
  }

  static double _calculateNetWorth(List<Account> accounts, List<Transaction> transactions, DateTime today) {
    double total = 0.0;
    for (final a in accounts) {
      if (!a.includeInNetWorth || a.archived) continue;
      final bal = LedgerEngine.balance(a, transactions, const [], asOf: today);
      if (a.isLiability) {
        total -= bal.abs();
      } else {
        total += bal;
      }
    }
    return total;
  }

  static double _computeMetricValue(QueryMetric metric, QuerySubject subject, List<Transaction> txs) {
    if (txs.isEmpty) return 0.0;
    if (metric == QueryMetric.count) return txs.length.toDouble();

    double sum = 0.0;
    for (final tx in txs) {
      sum += _effectiveAmountForSubject(tx, subject);
    }

    if (metric == QueryMetric.avg) {
      return sum / txs.length;
    }
    return sum;
  }

  static double _effectiveAmountForSubject(Transaction tx, QuerySubject subject) {
    final kind = tx.effectiveKind;
    final amt = tx.amount.abs();

    if (subject == QuerySubject.spending) {
      if (kind == 'refund') return -amt;
      if (kind == 'debt_payment') return tx.interestAmount ?? 0.0;
      return amt;
    }

    if (subject == QuerySubject.income) {
      return amt;
    }

    if (subject == QuerySubject.net) {
      if (kind == 'income' || kind == 'refund' || kind == 'reimbursement') {
        return amt;
      } else if (kind == 'expense') {
        return -amt;
      }
    }

    return amt;
  }

  static String _extractGroupKey(
    Transaction tx,
    QueryGroupBy groupBy,
    List<Category> categories,
    List<Account> accounts,
  ) {
    switch (groupBy) {
      case QueryGroupBy.merchant:
        return (tx.merchant != null && tx.merchant!.trim().isNotEmpty)
            ? tx.merchant!.trim()
            : (tx.title.trim().isNotEmpty ? tx.title.trim() : 'Unknown');
      case QueryGroupBy.category:
        if (tx.categoryId != null) {
          final cat = categories.cast<Category?>().firstWhere(
                (c) => c?.id == tx.categoryId,
                orElse: () => null,
              );
          if (cat != null) return cat.name;
        }
        return tx.category ?? 'Other';
      case QueryGroupBy.account:
        if (tx.accountId != null) {
          final acc = accounts.cast<Account?>().firstWhere(
                (a) => a?.id == tx.accountId,
                orElse: () => null,
              );
          if (acc != null) return acc.name;
        }
        return 'Account';
      case QueryGroupBy.month:
        return '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}';
      case QueryGroupBy.none:
        return 'All';
    }
  }

  static List<Transaction> _filterTransactions({
    required List<Transaction> transactions,
    required QuerySubject subject,
    required QueryFilters filters,
    required _DateRange? range,
    required List<Category> categories,
    required List<Account> accounts,
  }) {
    final catMap = {for (var c in categories) c.id: c.name.toLowerCase()};
    final accMap = {for (var a in accounts) a.id: a.name.toLowerCase()};

    final merchantFilter = filters.merchant?.toLowerCase().trim();
    final categoryFilter = filters.category?.toLowerCase().trim();
    final tagFilter = filters.tag?.toLowerCase().trim();
    final accountFilter = filters.account?.toLowerCase().trim();

    return transactions.where((tx) {
      final kind = tx.effectiveKind;

      // Subject filtering per ledger Invariant I3
      if (subject == QuerySubject.spending) {
        // Exclude transfer, investment, debt principal (except interest), adjustment, reimbursement
        if (kind == 'transfer' ||
            kind == 'investment' ||
            kind == 'adjustment' ||
            kind == 'reimbursement') {
          return false;
        }
        if (kind == 'income') return false;
      } else if (subject == QuerySubject.income) {
        if (kind != 'income' && kind != 'refund' && kind != 'reimbursement') {
          return false;
        }
      }

      // Date range filtering
      if (range != null) {
        if (tx.date.isBefore(range.start) || tx.date.isAfter(range.end)) {
          return false;
        }
      }

      // Amount filter
      final amt = tx.amount.abs();
      if (filters.amountMin != null && amt < filters.amountMin!) return false;
      if (filters.amountMax != null && amt > filters.amountMax!) return false;

      // Merchant filter
      if (merchantFilter != null && merchantFilter.isNotEmpty) {
        final m = (tx.merchant ?? tx.title).toLowerCase();
        if (!m.contains(merchantFilter)) return false;
      }

      // Category filter
      if (categoryFilter != null && categoryFilter.isNotEmpty) {
        String cName = (tx.category ?? '').toLowerCase();
        if (tx.categoryId != null && catMap.containsKey(tx.categoryId)) {
          cName = catMap[tx.categoryId]!;
        }
        if (!cName.contains(categoryFilter)) return false;
      }

      // Tag filter
      if (tagFilter != null && tagFilter.isNotEmpty) {
        final tags = tx.tags?.map((t) => t.toLowerCase()).toList() ?? [];
        if (!tags.contains(tagFilter)) return false;
      }

      // Account filter
      if (accountFilter != null && accountFilter.isNotEmpty) {
        final aName = tx.accountId != null ? (accMap[tx.accountId] ?? '') : '';
        if (!aName.contains(accountFilter)) return false;
      }

      return true;
    }).toList();
  }

  static _DateRange? _resolveDateRange(
    QueryPeriod period,
    DateTime? customStart,
    DateTime? customEnd,
    DateTime today,
  ) {
    switch (period) {
      case QueryPeriod.today:
        final start = DateTime(today.year, today.month, today.day);
        final end = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);
        return _DateRange(start, end);
      case QueryPeriod.yesterday:
        final y = today.subtract(const Duration(days: 1));
        final start = DateTime(y.year, y.month, y.day);
        final end = DateTime(y.year, y.month, y.day, 23, 59, 59, 999);
        return _DateRange(start, end);
      case QueryPeriod.thisWeek:
        final weekday = today.weekday; // 1 = Monday
        final start = DateTime(today.year, today.month, today.day).subtract(Duration(days: weekday - 1));
        final end = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);
        return _DateRange(start, end);
      case QueryPeriod.lastWeek:
        final weekday = today.weekday;
        final thisMonday = DateTime(today.year, today.month, today.day).subtract(Duration(days: weekday - 1));
        final lastMonday = thisMonday.subtract(const Duration(days: 7));
        final lastSunday = thisMonday.subtract(const Duration(milliseconds: 1));
        return _DateRange(lastMonday, lastSunday);
      case QueryPeriod.thisMonth:
        final start = DateTime(today.year, today.month, 1);
        final end = DateTime(today.year, today.month + 1, 0, 23, 59, 59, 999);
        return _DateRange(start, end);
      case QueryPeriod.lastMonth:
        final start = DateTime(today.year, today.month - 1, 1);
        final end = DateTime(today.year, today.month, 0, 23, 59, 59, 999);
        return _DateRange(start, end);
      case QueryPeriod.thisYear:
        final start = DateTime(today.year, 1, 1);
        final end = DateTime(today.year, 12, 31, 23, 59, 59, 999);
        return _DateRange(start, end);
      case QueryPeriod.lastYear:
        final start = DateTime(today.year - 1, 1, 1);
        final end = DateTime(today.year - 1, 12, 31, 23, 59, 59, 999);
        return _DateRange(start, end);
      case QueryPeriod.custom:
        if (customStart != null && customEnd != null) {
          return _DateRange(customStart, customEnd);
        }
        return null;
      case QueryPeriod.all:
        return null;
    }
  }

  static String _describePeriod(QueryPeriod period) {
    switch (period) {
      case QueryPeriod.today: return 'today';
      case QueryPeriod.yesterday: return 'yesterday';
      case QueryPeriod.thisWeek: return 'this week';
      case QueryPeriod.lastWeek: return 'last week';
      case QueryPeriod.thisMonth: return 'this month';
      case QueryPeriod.lastMonth: return 'last month';
      case QueryPeriod.thisYear: return 'this year';
      case QueryPeriod.lastYear: return 'last year';
      case QueryPeriod.custom: return 'in the selected period';
      case QueryPeriod.all: return 'overall';
    }
  }
}

class _DateRange {
  final DateTime start;
  final DateTime end;
  _DateRange(this.start, this.end);
}
