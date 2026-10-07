import 'entry.dart';
import 'free_to_spend.dart';
import 'ledger.dart';
import 'minor.dart';
import 'plan_engine.dart';

/// Immutable snapshot representing the entire financial state at a point in time.
///
/// Implements Law L9:
/// "Single writer, single reader. Only MoneyService writes entries. Only MoneySnapshot
/// is read by screens. UI code never opens a Hive box and never computes a balance."
class MoneySnapshot {
  final DateTime asOf;
  final String mainAccountId;
  final int mainBalanceMinor;
  final Map<String, int> balancesByAccountMinor;
  final FreeToSpendResult freeToSpend;
  final int monthSpentMinor;
  final int monthReceivedMinor;
  final List<FundSummary> funds;
  final List<LoanSummary> loans;
  final List<PlanOccurrence> upcomingPlans;
  final List<PlanOccurrence> plansNeedingFunds;
  final List<Entry> recentEntries;

  const MoneySnapshot({
    required this.asOf,
    required this.mainAccountId,
    required this.mainBalanceMinor,
    required this.balancesByAccountMinor,
    required this.freeToSpend,
    required this.monthSpentMinor,
    required this.monthReceivedMinor,
    required this.funds,
    required this.loans,
    required this.upcomingPlans,
    required this.plansNeedingFunds,
    required this.recentEntries,
  });

  /// Rupee getters for display formatting
  double get mainBalanceRupees => Minor.fromMinor(mainBalanceMinor);
  double get monthSpentRupees => Minor.fromMinor(monthSpentMinor);
  double get monthReceivedRupees => Minor.fromMinor(monthReceivedMinor);

  /// Net worth calculation across all accounts (Assets - Liabilities)
  int get netWorthMinor {
    int total = 0;
    for (final entry in balancesByAccountMinor.entries) {
      total += entry.value;
    }
    return total;
  }

  double get netWorthRupees => Minor.fromMinor(netWorthMinor);

  /// Empty initial state before first load
  factory MoneySnapshot.empty({String mainAccountId = 'acc_main'}) {
    return MoneySnapshot(
      asOf: DateTime.now(),
      mainAccountId: mainAccountId,
      mainBalanceMinor: 0,
      balancesByAccountMinor: const {},
      freeToSpend: const FreeToSpendResult(
        availableMinor: 0,
        comingUpMinor: 0,
        freeToSpendMinor: 0,
        upcomingPlansThisMonth: [],
      ),
      monthSpentMinor: 0,
      monthReceivedMinor: 0,
      funds: const [],
      loans: const [],
      upcomingPlans: const [],
      plansNeedingFunds: const [],
      recentEntries: const [],
    );
  }
}
