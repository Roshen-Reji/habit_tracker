import 'dart:convert';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

/// Pure Dart ledger calculation engine implementing core accounting rules and invariants.
class LedgerEngine {
  /// Computes the balance of a specific [account] as of [asOf] (defaults to DateTime.now()).
  static double balance(
    Account account,
    Iterable<Transaction> transactions,
    Iterable<Valuation> valuations, {
    DateTime? asOf,
  }) {
    final cutoff = asOf ?? DateTime.now();

    // Valued accounts (investments, gold, property, etc.) check for valuations first
    if (account.isValuedAsset) {
      final relevantValuations = valuations
          .where((v) => v.accountId == account.id && !v.date.isAfter(cutoff))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      if (relevantValuations.isNotEmpty) {
        return Money.r2(relevantValuations.first.value);
      }
    }

    double currentBalance = account.openingBalance;

    for (final tx in transactions) {
      if (tx.date.isAfter(cutoff)) continue;
      if (tx.date.isBefore(account.openingDate)) continue;

      final absAmount = tx.amount.abs();
      final kind = tx.effectiveKind;

      // Effect when account is the primary accountId
      if (tx.accountId == account.id) {
        switch (kind) {
          case 'expense':
            currentBalance -= absAmount;
            break;
          case 'income':
            currentBalance += absAmount;
            break;
          case 'transfer':
            currentBalance -= absAmount;
            break;
          case 'investment':
            currentBalance -= absAmount;
            break;
          case 'debt_payment':
            currentBalance -= absAmount;
            break;
          case 'refund':
            currentBalance += absAmount;
            break;
          case 'reimbursement':
            currentBalance += absAmount;
            break;
          case 'adjustment':
            currentBalance += (tx.amount >= 0 ? absAmount : -absAmount);
            break;
          default:
            if (tx.mode.toLowerCase() == 'expense' || tx.amount < 0) {
              currentBalance -= absAmount;
            } else {
              currentBalance += absAmount;
            }
        }
      }

      // Effect when account is the destination toAccountId
      if (tx.toAccountId == account.id) {
        switch (kind) {
          case 'transfer':
            currentBalance += absAmount;
            break;
          case 'investment':
            currentBalance += absAmount;
            break;
          case 'debt_payment':
            // Principal part reduces liability / increases balance towards zero
            final interest = tx.interestAmount ?? 0.0;
            final principal = (absAmount - interest).clamp(0.0, absAmount);
            currentBalance += principal;
            break;
          default:
            break;
        }
      }
    }

    return Money.r2(currentBalance);
  }

  /// Invariant I2: Net worth = Σ balances of accounts with includeInNetWorth,
  /// plus unsettled receivables minus unsettled payables.
  static double netWorth(
    Iterable<Account> accounts,
    Iterable<Transaction> transactions,
    Iterable<Valuation> valuations, {
    DateTime? asOf,
    double unsettledReceivables = 0.0,
    double unsettledPayables = 0.0,
  }) {
    final cutoff = asOf ?? DateTime.now();
    double total = 0.0;

    for (final acc in accounts) {
      if (!acc.includeInNetWorth || acc.archived) continue;
      final bal = balance(acc, transactions, valuations, asOf: cutoff);
      total += bal;
    }

    total += unsettledReceivables;
    total -= unsettledPayables;

    return Money.r2(total);
  }

  /// Calculates total spending in a date window, optionally filtered by category or account.
  /// Invariant I3: Spending totals exclude transfer, investment, debt principal,
  /// adjustment, reimbursement, and owed split lines; refunds subtract.
  static double spending(
    Iterable<Transaction> transactions, {
    DateTime? from,
    DateTime? to,
    String? categoryId,
    String? accountId,
  }) {
    double total = 0.0;

    for (final tx in transactions) {
      if (from != null && tx.date.isBefore(from)) continue;
      if (to != null && tx.date.isAfter(to)) continue;
      if (accountId != null && tx.accountId != accountId) continue;

      final kind = tx.effectiveKind;

      if (kind == 'refund') {
        if (categoryId != null &&
            tx.categoryId != categoryId &&
            tx.category != categoryId) {
          continue;
        }
        total -= tx.amount.abs();
        continue;
      }

      if (kind == 'debt_payment') {
        // Only interest part counts as spending (category: Interest & fees)
        if (categoryId != null &&
            categoryId != 'cat_interest_fees' &&
            categoryId != 'Interest & fees') {
          continue;
        }
        final interest = tx.interestAmount ?? 0.0;
        total += interest;
        continue;
      }

      if (kind != 'expense') {
        continue;
      }

      // Handle split transactions
      if (tx.splits != null && tx.splits!.isNotEmpty) {
        try {
          final List parsed = jsonDecode(tx.splits!);
          for (final item in parsed) {
            if (item is Map) {
              final isOwed = item['isOwed'] == true;
              if (isOwed) continue; // Owed lines are not spending

              final itemCat = item['categoryId']?.toString();
              if (categoryId != null && itemCat != categoryId) continue;

              final itemAmount = Money.asDouble(item['amount']);
              total += itemAmount;
            }
          }
          continue;
        } catch (_) {
          // If split json fails to parse, fall back to whole transaction
        }
      }

      if (categoryId != null &&
          tx.categoryId != categoryId &&
          tx.category != categoryId) {
        continue;
      }

      total += tx.amount.abs();
    }

    return Money.r2(total);
  }

  /// Calculates total income in a date window.
  static double income(
    Iterable<Transaction> transactions, {
    DateTime? from,
    DateTime? to,
    String? accountId,
  }) {
    double total = 0.0;

    for (final tx in transactions) {
      if (from != null && tx.date.isBefore(from)) continue;
      if (to != null && tx.date.isAfter(to)) continue;
      if (accountId != null && tx.accountId != accountId) continue;

      if (tx.effectiveKind == 'income') {
        total += tx.amount.abs();
      }
    }

    return Money.r2(total);
  }

  /// Calculates spending breakdown by category.
  static Map<String, double> categorySpending(
    Iterable<Transaction> transactions, {
    DateTime? from,
    DateTime? to,
    String? accountId,
  }) {
    final result = <String, double>{};

    for (final tx in transactions) {
      if (from != null && tx.date.isBefore(from)) continue;
      if (to != null && tx.date.isAfter(to)) continue;
      if (accountId != null && tx.accountId != accountId) continue;

      final kind = tx.effectiveKind;

      if (kind == 'refund') {
        final cat = tx.categoryId ?? tx.category;
        result[cat] = (result[cat] ?? 0.0) - tx.amount.abs();
        continue;
      }

      if (kind == 'debt_payment') {
        final interest = tx.interestAmount ?? 0.0;
        if (interest > 0) {
          const cat = 'cat_interest_fees';
          result[cat] = (result[cat] ?? 0.0) + interest;
        }
        continue;
      }

      if (kind != 'expense') continue;

      if (tx.splits != null && tx.splits!.isNotEmpty) {
        try {
          final List parsed = jsonDecode(tx.splits!);
          for (final item in parsed) {
            if (item is Map) {
              final isOwed = item['isOwed'] == true;
              if (isOwed) continue;

              final cat = item['categoryId']?.toString() ?? 'Other';
              final amt = Money.asDouble(item['amount']);
              result[cat] = (result[cat] ?? 0.0) + amt;
            }
          }
          continue;
        } catch (_) {}
      }

      final cat = tx.categoryId ?? tx.category;
      result[cat] = (result[cat] ?? 0.0) + tx.amount.abs();
    }

    // Round all results
    return result.map((k, v) => MapEntry(k, Money.r2(v)));
  }

  /// Extracts unsettled receivables from owed split lines on transactions.
  static double receivablesFromSplits(Iterable<Transaction> transactions) {
    double total = 0.0;

    for (final tx in transactions) {
      if (tx.splits == null || tx.splits!.isEmpty) continue;
      try {
        final List parsed = jsonDecode(tx.splits!);
        for (final item in parsed) {
          if (item is Map && item['isOwed'] == true) {
            total += Money.asDouble(item['amount']);
          }
        }
      } catch (_) {}
    }

    return Money.r2(total);
  }
}
