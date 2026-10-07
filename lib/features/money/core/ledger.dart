import 'dart:math';
import 'account_group.dart';
import 'entry.dart';
import 'minor.dart';

/// Pure Dart valuation record for Funds.
class CoreValuation {
  final String id;
  final String accountId;
  final int valueMinor;
  final DateTime date;

  const CoreValuation({
    required this.id,
    required this.accountId,
    required this.valueMinor,
    required this.date,
  });
}

/// Fund summary metrics fulfilling Law L4.
class FundSummary {
  final String accountId;
  final int investedMinor;
  final int valueMinor;
  final int gainMinor;
  final bool hasValuationUpdate;
  final DateTime? lastValuationDate;

  const FundSummary({
    required this.accountId,
    required this.investedMinor,
    required this.valueMinor,
    required this.gainMinor,
    required this.hasValuationUpdate,
    this.lastValuationDate,
  });

  double get investedRupees => Minor.fromMinor(investedMinor);
  double get valueRupees => Minor.fromMinor(valueMinor);
  double get gainRupees => Minor.fromMinor(gainMinor);

  /// Return percentage return if invested > 0
  double get gainPercent {
    if (investedMinor <= 0) return 0.0;
    return (gainMinor / investedMinor) * 100.0;
  }
}

/// Loan summary metrics fulfilling Law L5.
class LoanSummary {
  final String accountId;
  final int outstandingMinor;
  final int totalPrincipalPaidMinor;
  final int totalInterestPaidMinor;
  final int? emiMinor;
  final double annualRatePct;

  const LoanSummary({
    required this.accountId,
    required this.outstandingMinor,
    required this.totalPrincipalPaidMinor,
    required this.totalInterestPaidMinor,
    this.emiMinor,
    this.annualRatePct = 0.0,
  });

  double get outstandingRupees => Minor.fromMinor(outstandingMinor);
  double get totalPaidRupees =>
      Minor.fromMinor(totalPrincipalPaidMinor + totalInterestPaidMinor);
}

/// Pure Dart ledger engine enforcing Laws L1, L2, L4, and L5.
class CoreLedger {
  CoreLedger._();

  /// Calculates loan payment split into principal and interest portions (Law L5).
  static ({int principalMinor, int interestMinor}) splitPayment({
    required int currentOutstandingMinor,
    required double annualRatePct,
    required int paymentAmountMinor,
  }) {
    if (currentOutstandingMinor <= 0 || paymentAmountMinor <= 0) {
      return (principalMinor: paymentAmountMinor, interestMinor: 0);
    }

    final monthlyRate = (annualRatePct / 100.0) / 12.0;
    final monthlyInterest = (currentOutstandingMinor * monthlyRate).round();

    if (paymentAmountMinor <= monthlyInterest) {
      return (principalMinor: 0, interestMinor: paymentAmountMinor);
    }

    final principalPortion =
        min(currentOutstandingMinor, paymentAmountMinor - monthlyInterest);
    final interestPortion = paymentAmountMinor - principalPortion;

    return (
      principalMinor: principalPortion,
      interestMinor: interestPortion,
    );
  }

  /// Calculates the current balance of an account as of [asOf].
  ///
  /// Enforces Law L1 (Immediate) & Law L2 (No Ignored Entries):
  /// `balance(A) = openingBalance + Σ effect of every entry on A dated up to cutoff`.
  /// `openingDate` is strictly ignored for balance calculations.
  static int balance({
    required CoreAccount account,
    required Iterable<Entry> entries,
    Iterable<CoreValuation> valuations = const [],
    DateTime? asOf,
  }) {
    final cutoff = asOf ?? DateTime.now();

    // Law L4 for Funds: Value = latest valuation + deposits made after it
    if (account.isValuedAsset) {
      final summary = fundSummary(
        account: account,
        entries: entries,
        valuations: valuations,
        asOf: cutoff,
      );
      return summary.valueMinor;
    }

    int current = account.openingBalanceMinor;

    // Filter candidate entries up to cutoff involving this account (Law L2)
    final candidateEntries = entries
        .where((e) =>
            !e.date.isAfter(cutoff) &&
            (e.fromAccountId == account.id || e.toAccountId == account.id))
        .toList()
      ..sort((a, b) {
        final d = a.date.compareTo(b.date);
        if (d != 0) return d;
        return a.createdAt.compareTo(b.createdAt);
      });

    for (final e in candidateEntries) {
      // Outflow from this account
      if (e.fromAccountId == account.id) {
        switch (e.kind) {
          case EntryKind.spent:
          case EntryKind.moved:
            current -= e.amountMinor;
            break;
          case EntryKind.received:
            // Symmetrical safety if signed fromAccountId
            current += e.amountMinor;
            break;
          case EntryKind.adjustment:
            current -= e.amountMinor;
            break;
        }
      }

      // Inflow into this account
      if (e.toAccountId == account.id) {
        switch (e.kind) {
          case EntryKind.received:
          case EntryKind.moved:
            if (account.isLoan) {
              // Law L5: Move into loan reduces outstanding by principal part only
              final split = splitPayment(
                currentOutstandingMinor: current.abs(),
                annualRatePct: account.annualRatePct ?? 0.0,
                paymentAmountMinor: e.amountMinor,
              );
              // Loans track liability: reduction brings balance closer to 0
              current += split.principalMinor;
            } else {
              current += e.amountMinor;
            }
            break;
          case EntryKind.spent:
            current -= e.amountMinor;
            break;
          case EntryKind.adjustment:
            current += e.amountMinor;
            break;
        }
      }
    }

    return current;
  }

  /// Calculates the fund metrics (Invested, Value, Gain) for a Fund account (Law L4).
  ///
  /// Invested = openingBalance + Σ deposits
  /// Value = latest value update + deposits made after it (or Invested if no update)
  /// Gain = Value - Invested
  static FundSummary fundSummary({
    required CoreAccount account,
    required Iterable<Entry> entries,
    required Iterable<CoreValuation> valuations,
    DateTime? asOf,
  }) {
    final cutoff = asOf ?? DateTime.now();

    // Check valuations up to cutoff
    final relevantValuations = valuations
        .where((v) => v.accountId == account.id && !v.date.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final hasValuation = relevantValuations.isNotEmpty;
    DateTime? latestValuationDate;
    int latestValuationMinor = 0;

    if (hasValuation) {
      final v = relevantValuations.first;
      latestValuationDate = v.date;
      latestValuationMinor = v.valueMinor;
    }

    // Collect deposits (all moved/received entries into this fund account)
    int totalInvested = account.openingBalanceMinor;
    int depositsAfterValuation = 0;

    final candidateEntries = entries
        .where((e) =>
            !e.date.isAfter(cutoff) &&
            (e.toAccountId == account.id || e.fromAccountId == account.id))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    for (final e in candidateEntries) {
      if (e.toAccountId == account.id) {
        totalInvested += e.amountMinor;

        if (hasValuation) {
          if (e.date.isAfter(latestValuationDate!)) {
            depositsAfterValuation += e.amountMinor;
          }
        }
      } else if (e.fromAccountId == account.id) {
        // Reductions/withdrawals from fund
        totalInvested -= e.amountMinor;
        if (hasValuation && e.date.isAfter(latestValuationDate!)) {
          depositsAfterValuation -= e.amountMinor;
        }
      }
    }

    final valueMinor = hasValuation
        ? latestValuationMinor + depositsAfterValuation
        : totalInvested;

    final gainMinor = valueMinor - totalInvested;

    return FundSummary(
      accountId: account.id,
      investedMinor: totalInvested,
      valueMinor: valueMinor,
      gainMinor: hasValuation ? gainMinor : 0,
      hasValuationUpdate: hasValuation,
      lastValuationDate: latestValuationDate,
    );
  }

  /// Calculates Loan metrics (Outstanding, Principal Paid, Interest Paid) (Law L5).
  static LoanSummary loanSummary({
    required CoreAccount account,
    required Iterable<Entry> entries,
    DateTime? asOf,
  }) {
    final cutoff = asOf ?? DateTime.now();
    int outstanding = account.openingBalanceMinor.abs();
    int principalPaid = 0;
    int interestPaid = 0;

    final candidateEntries = entries
        .where((e) => !e.date.isAfter(cutoff) && e.toAccountId == account.id)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    for (final e in candidateEntries) {
      final split = splitPayment(
        currentOutstandingMinor: outstanding,
        annualRatePct: account.annualRatePct ?? 0.0,
        paymentAmountMinor: e.amountMinor,
      );
      principalPaid += split.principalMinor;
      interestPaid += split.interestMinor;
      outstanding = max(0, outstanding - split.principalMinor);
    }

    return LoanSummary(
      accountId: account.id,
      outstandingMinor: outstanding,
      totalPrincipalPaidMinor: principalPaid,
      totalInterestPaidMinor: interestPaid,
      emiMinor: account.emiMinor,
      annualRatePct: account.annualRatePct ?? 0.0,
    );
  }
}
