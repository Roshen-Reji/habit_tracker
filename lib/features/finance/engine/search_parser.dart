import 'package:habit_tracker/models/finance_model.dart';
import 'package:habit_tracker/features/finance/models/category.dart';
import 'package:habit_tracker/features/finance/models/account.dart';

class FreeTextToken {
  final String text;
  final double? numLow;
  final double? numHigh;

  const FreeTextToken(this.text, {this.numLow, this.numHigh});
}

/// Parsed filter criteria for transactions.
class TransactionQuery {
  final double? minAmount;
  final double? maxAmount;
  final double? exactAmount;
  final String? merchant;
  final String? category;
  final String? tag;
  final String? account;
  final int? month; // 1 - 12
  final int? year;
  final String? kind;
  final List<String> freeTextTokens;
  final List<FreeTextToken> parsedTokens;

  const TransactionQuery({
    this.minAmount,
    this.maxAmount,
    this.exactAmount,
    this.merchant,
    this.category,
    this.tag,
    this.account,
    this.month,
    this.year,
    this.kind,
    this.freeTextTokens = const [],
    this.parsedTokens = const [],
  });

  bool get isEmpty =>
      minAmount == null &&
      maxAmount == null &&
      exactAmount == null &&
      merchant == null &&
      category == null &&
      tag == null &&
      account == null &&
      month == null &&
      year == null &&
      kind == null &&
      freeTextTokens.isEmpty &&
      parsedTokens.isEmpty;
}

/// Pure Dart search parser and matcher for transactions.
/// Supports operators:
/// - `>2000`, `<500`, `>=1000`, `<=300`, `=500`
/// - `merchant:<term>`
/// - `cat:<term>` or `category:<term>`
/// - `tag:<term>`
/// - `acct:<term>` or `account:<term>`
/// - `month:<term>` (e.g. `sep`, `september`, `09`, `9`)
/// - `year:<term>` (e.g. `2026`)
/// - `kind:<term>` (e.g. `expense`, `income`, `transfer`, etc.)
/// Free text tokens:
/// - Words match merchant, title, notes, tags, category name, or account name.
/// - If a word is numeric (e.g. `500`), it also matches amounts within ±10%.
class SearchParser {
  static const Map<String, int> _monthNames = {
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };

  static TransactionQuery parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const TransactionQuery();

    double? minAmount;
    double? maxAmount;
    double? exactAmount;
    String? merchant;
    String? category;
    String? tag;
    String? account;
    int? month;
    int? year;
    String? kind;
    final freeText = <String>[];

    // Split on whitespace
    final tokens = text.split(RegExp(r'\s+'));

    for (final token in tokens) {
      if (token.isEmpty) continue;
      final lower = token.toLowerCase();

      // Comparison operators: >100, >=100, <500, <=500, =500
      if (lower.startsWith('>=') && lower.length > 2) {
        final val = double.tryParse(lower.substring(2));
        if (val != null) {
          minAmount = val;
          continue;
        }
      } else if (lower.startsWith('<=') && lower.length > 2) {
        final val = double.tryParse(lower.substring(2));
        if (val != null) {
          maxAmount = val;
          continue;
        }
      } else if (lower.startsWith('>') && lower.length > 1) {
        final val = double.tryParse(lower.substring(1));
        if (val != null) {
          minAmount = val + 0.0001; // strictly greater
          continue;
        }
      } else if (lower.startsWith('<') && lower.length > 1) {
        final val = double.tryParse(lower.substring(1));
        if (val != null) {
          maxAmount = val - 0.0001; // strictly less
          continue;
        }
      } else if (lower.startsWith('=') && lower.length > 1) {
        final val = double.tryParse(lower.substring(1));
        if (val != null) {
          exactAmount = val;
          continue;
        }
      }

      // Prefixed operators: key:val
      if (lower.contains(':')) {
        final parts = token.split(':');
        final key = parts[0].toLowerCase();
        final val = parts.sublist(1).join(':').trim();
        if (val.isNotEmpty) {
          if (key == 'merchant' || key == 'm') {
            merchant = val.toLowerCase();
            continue;
          }
          if (key == 'cat' || key == 'category' || key == 'c') {
            category = val.toLowerCase();
            continue;
          }
          if (key == 'tag' || key == 't') {
            tag = val.toLowerCase();
            continue;
          }
          if (key == 'acct' || key == 'account' || key == 'acc' || key == 'a') {
            account = val.toLowerCase();
            continue;
          }
          if (key == 'month') {
            final parsedMonth = _parseMonth(val);
            if (parsedMonth != null) {
              month = parsedMonth;
              continue;
            }
          }
          if (key == 'year' || key == 'y') {
            final parsedYear = int.tryParse(val);
            if (parsedYear != null) {
              year = parsedYear;
              continue;
            }
          }
          if (key == 'kind' || key == 'type' || key == 'k') {
            kind = val.toLowerCase();
            continue;
          }
        }
      }

      freeText.add(lower);
    }

    final parsedTokens = _computeTokens(freeText);

    return TransactionQuery(
      minAmount: minAmount,
      maxAmount: maxAmount,
      exactAmount: exactAmount,
      merchant: merchant,
      category: category,
      tag: tag,
      account: account,
      month: month,
      year: year,
      kind: kind,
      freeTextTokens: freeText,
      parsedTokens: parsedTokens,
    );
  }

  static List<FreeTextToken> _computeTokens(List<String> tokens) {
    if (tokens.isEmpty) return const [];
    return tokens.map((t) {
      final num = double.tryParse(t);
      if (num != null && num > 0) {
        return FreeTextToken(t, numLow: num * 0.90, numHigh: num * 1.10);
      }
      return FreeTextToken(t);
    }).toList(growable: false);
  }

  static int? _parseMonth(String val) {
    final lower = val.toLowerCase();
    if (_monthNames.containsKey(lower)) {
      return _monthNames[lower];
    }
    final numVal = int.tryParse(val);
    if (numVal != null && numVal >= 1 && numVal <= 12) {
      return numVal;
    }
    return null;
  }

  /// Filters [transactions] using [query].
  /// [categories] and [accounts] provide lookup for name resolution.
  static List<Transaction> filter({
    required List<Transaction> transactions,
    required TransactionQuery query,
    Map<String, Category>? categories,
    Map<String, Account>? accounts,
  }) {
    if (query.isEmpty) return transactions;

    final results = <Transaction>[];
    final len = transactions.length;
    for (var i = 0; i < len; i++) {
      final tx = transactions[i];
      if (matches(
        tx: tx,
        query: query,
        categories: categories,
        accounts: accounts,
      )) {
        results.add(tx);
      }
    }
    return results;
  }

  /// Determines if [tx] satisfies [query].
  static bool matches({
    required Transaction tx,
    required TransactionQuery query,
    Map<String, Category>? categories,
    Map<String, Account>? accounts,
  }) {
    final mag = tx.amount.abs();

    if (query.minAmount != null && mag < query.minAmount!) {
      return false;
    }
    if (query.maxAmount != null && mag > query.maxAmount!) {
      return false;
    }
    if (query.exactAmount != null && (mag - query.exactAmount!).abs() > 0.001) {
      return false;
    }

    if (query.month != null && tx.date.month != query.month) {
      return false;
    }
    if (query.year != null && tx.date.year != query.year) {
      return false;
    }

    if (query.kind != null && tx.effectiveKind != query.kind) {
      return false;
    }

    if (query.merchant != null) {
      final txMerchant = (tx.merchant ?? '').toLowerCase();
      if (!txMerchant.contains(query.merchant!)) {
        return false;
      }
    }

    if (query.tag != null) {
      final tags = (tx.tags ?? []).map((t) => t.toLowerCase());
      if (!tags.any((t) => t.contains(query.tag!))) {
        return false;
      }
    }

    String? catName;
    if (query.category != null) {
      catName = _resolveCategoryName(tx, categories).toLowerCase();
      if (!catName.contains(query.category!)) {
        return false;
      }
    }

    String? accName;
    if (query.account != null) {
      accName = _resolveAccountName(tx, accounts).toLowerCase();
      if (!accName.contains(query.account!)) {
        return false;
      }
    }

    // Free text matching
    final tokens = query.parsedTokens.isNotEmpty
        ? query.parsedTokens
        : (query.freeTextTokens.isNotEmpty
            ? _computeTokens(query.freeTextTokens)
            : const <FreeTextToken>[]);

    for (final token in tokens) {
      var matched = false;

      if (token.numLow != null &&
          mag >= token.numLow! &&
          mag <= token.numHigh!) {
        matched = true;
      }

      if (!matched) {
        final t = token.text;
        if (tx.title.toLowerCase().contains(t)) {
          matched = true;
        } else if (tx.merchant != null &&
            tx.merchant!.toLowerCase().contains(t)) {
          matched = true;
        } else if (tx.notes != null && tx.notes!.toLowerCase().contains(t)) {
          matched = true;
        } else {
          catName ??= _resolveCategoryName(tx, categories).toLowerCase();
          if (catName.contains(t)) {
            matched = true;
          } else {
            accName ??= _resolveAccountName(tx, accounts).toLowerCase();
            if (accName.contains(t)) {
              matched = true;
            } else if ((tx.tags ?? [])
                .any((tag) => tag.toLowerCase().contains(t))) {
              matched = true;
            }
          }
        }
      }

      if (!matched) return false;
    }

    return true;
  }

  static String _resolveCategoryName(
      Transaction tx, Map<String, Category>? categories) {
    if (tx.categoryId != null && categories != null) {
      final cat = categories[tx.categoryId];
      if (cat != null) return cat.name;
    }
    return tx.category;
  }

  static String _resolveAccountName(
      Transaction tx, Map<String, Account>? accounts) {
    if (tx.accountId != null && accounts != null) {
      final acc = accounts[tx.accountId];
      if (acc != null) return acc.name;
    }
    return tx.accountId ?? '';
  }
}
