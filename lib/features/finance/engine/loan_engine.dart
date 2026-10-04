import 'dart:math';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

class AmortizationMonth {
  final int monthIndex;
  final double payment;
  final double principal;
  final double interest;
  final double remainingBalance;

  const AmortizationMonth({
    required this.monthIndex,
    required this.payment,
    required this.principal,
    required this.interest,
    required this.remainingBalance,
  });
}

class LoanSchedule {
  final double emi;
  final int totalMonths;
  final double totalInterest;
  final double totalPayment;
  final bool neverAmortizes;
  final List<AmortizationMonth> months;

  const LoanSchedule({
    required this.emi,
    required this.totalMonths,
    required this.totalInterest,
    required this.totalPayment,
    required this.neverAmortizes,
    required this.months,
  });
}

class ExtraPaymentSimulation {
  final double extraPaymentPerMonth;
  final int baselineMonths;
  final int newMonths;
  final int monthsSaved;
  final double baselineInterest;
  final double newInterest;
  final double interestSaved;

  const ExtraPaymentSimulation({
    required this.extraPaymentPerMonth,
    required this.baselineMonths,
    required this.newMonths,
    required this.monthsSaved,
    required this.baselineInterest,
    required this.newInterest,
    required this.interestSaved,
  });
}

class PayoffComparison {
  final String strategyName; // 'Avalanche' or 'Snowball'
  final int totalMonths;
  final double totalInterest;
  final DateTime debtFreeDate;
  final List<String> payoffOrder;

  const PayoffComparison({
    required this.strategyName,
    required this.totalMonths,
    required this.totalInterest,
    required this.debtFreeDate,
    required this.payoffOrder,
  });
}

class LoanEngine {
  /// Computes standard EMI given principal [P], annual percentage rate [annualRatePct] (e.g. 8.5 for 8.5%),
  /// and tenure in months [n].
  /// Formula: `emi = P * r * (1+r)^n / ((1+r)^n - 1)`
  static double calculateEmi({
    required double principal,
    required double annualRatePct,
    required int tenureMonths,
  }) {
    if (principal <= 0 || tenureMonths <= 0) return 0.0;
    if (annualRatePct <= 0) {
      return Money.r2(principal / tenureMonths);
    }

    final r = (annualRatePct / 100.0) / 12.0;
    final factor = pow(1.0 + r, tenureMonths);
    final emi = principal * r * factor / (factor - 1.0);
    return Money.r2(emi);
  }

  /// Computes remaining months given current principal [P], annual percentage rate [annualRatePct],
  /// and monthly EMI [emi].
  /// Formula: `months = ceil(-ln(1 - r * P / emi) / ln(1 + r))`
  /// Returns -1 if it never amortizes (i.e. `emi <= r * P`).
  static int remainingMonths({
    required double principal,
    required double annualRatePct,
    required double emi,
  }) {
    if (principal <= 0) return 0;
    if (annualRatePct <= 0) {
      if (emi <= 0) return -1;
      return (principal / emi).ceil();
    }

    final r = (annualRatePct / 100.0) / 12.0;
    final monthlyInterest = principal * r;

    if (emi <= monthlyInterest) {
      // Never amortizes
      return -1;
    }

    final fraction = 1.0 - (r * principal / emi);
    if (fraction <= 0) return -1;

    final n = -log(fraction) / log(1.0 + r);
    return n.ceil();
  }

  /// Auto-splits a debt payment into principal and interest portions:
  /// `interest = balance * r`
  /// `principal = payment - interest`
  static ({double principal, double interest}) splitPayment({
    required double currentBalance,
    required double annualRatePct,
    required double paymentAmount,
  }) {
    if (currentBalance <= 0 || paymentAmount <= 0) {
      return (principal: Money.r2(paymentAmount), interest: 0.0);
    }

    final r = (annualRatePct / 100.0) / 12.0;
    final monthlyInterest = Money.r2(currentBalance * r);

    if (paymentAmount <= monthlyInterest) {
      return (principal: 0.0, interest: Money.r2(paymentAmount));
    }

    final principalPortion = Money.r2(min(currentBalance, paymentAmount - monthlyInterest));
    return (principal: principalPortion, interest: monthlyInterest);
  }

  /// Generates the month-by-month amortization schedule.
  static LoanSchedule generateSchedule({
    required double principal,
    required double annualRatePct,
    required double emi,
    double extraPayment = 0.0,
    int maxMonths = 360,
  }) {
    final r = (annualRatePct / 100.0) / 12.0;
    final monthlyInterest = principal * r;

    final totalPaymentPerMonth = emi + extraPayment;
    if (annualRatePct > 0 && totalPaymentPerMonth <= monthlyInterest) {
      return LoanSchedule(
        emi: emi,
        totalMonths: -1,
        totalInterest: double.infinity,
        totalPayment: double.infinity,
        neverAmortizes: true,
        months: const [],
      );
    }

    final monthsList = <AmortizationMonth>[];
    double balance = principal;
    double totalInterest = 0.0;
    double totalPaid = 0.0;
    int idx = 0;

    while (balance > 0.01 && idx < maxMonths) {
      idx++;
      final interest = Money.r2(balance * r);
      final principalPaid = Money.r2(min(balance, totalPaymentPerMonth - interest));
      final actualPayment = principalPaid + interest;

      balance = Money.r2(balance - principalPaid);
      totalInterest = Money.r2(totalInterest + interest);
      totalPaid = Money.r2(totalPaid + actualPayment);

      monthsList.add(AmortizationMonth(
        monthIndex: idx,
        payment: actualPayment,
        principal: principalPaid,
        interest: interest,
        remainingBalance: balance,
      ));
    }

    return LoanSchedule(
      emi: emi,
      totalMonths: idx,
      totalInterest: totalInterest,
      totalPayment: totalPaid,
      neverAmortizes: false,
      months: monthsList,
    );
  }

  /// Simulates extra monthly payments to calculate months and interest saved.
  static ExtraPaymentSimulation simulateExtraPayment({
    required double principal,
    required double annualRatePct,
    required double emi,
    required double extraPaymentPerMonth,
  }) {
    final baseline = generateSchedule(
      principal: principal,
      annualRatePct: annualRatePct,
      emi: emi,
      extraPayment: 0.0,
    );

    final accelerated = generateSchedule(
      principal: principal,
      annualRatePct: annualRatePct,
      emi: emi,
      extraPayment: extraPaymentPerMonth,
    );

    final monthsSaved = max(0, baseline.totalMonths - accelerated.totalMonths);
    final interestSaved = Money.r2(max(0.0, baseline.totalInterest - accelerated.totalInterest));

    return ExtraPaymentSimulation(
      extraPaymentPerMonth: extraPaymentPerMonth,
      baselineMonths: baseline.totalMonths,
      newMonths: accelerated.totalMonths,
      monthsSaved: monthsSaved,
      baselineInterest: baseline.totalInterest,
      newInterest: accelerated.totalInterest,
      interestSaved: interestSaved,
    );
  }

  /// Compares Avalanche vs Snowball payoff strategies for a set of loans.
  /// Avalanche: highest interest rate first.
  /// Snowball: lowest balance first.
  static ({PayoffComparison avalanche, PayoffComparison snowball}) comparePayoffStrategies({
    required List<Account> loans,
    required Map<String, double> currentBalances,
    required double totalMonthlyBudget,
    required DateTime startDate,
  }) {
    final validLoans = loans.where((l) {
      final bal = (currentBalances[l.id] ?? 0.0).abs();
      return bal > 0.01;
    }).toList();

    // 1. Avalanche: sort by annualRate descending
    final avalancheLoans = List<Account>.from(validLoans)
      ..sort((a, b) => (b.annualRate ?? 0.0).compareTo(a.annualRate ?? 0.0));

    final avalancheRes = _simulateDebtFreeStrategy(
      loans: avalancheLoans,
      initialBalances: currentBalances,
      totalBudget: totalMonthlyBudget,
      startDate: startDate,
      strategyName: 'Avalanche (Highest Interest First)',
    );

    // 2. Snowball: sort by balance ascending
    final snowballLoans = List<Account>.from(validLoans)
      ..sort((a, b) => (currentBalances[a.id] ?? 0.0).abs().compareTo((currentBalances[b.id] ?? 0.0).abs()));

    final snowballRes = _simulateDebtFreeStrategy(
      loans: snowballLoans,
      initialBalances: currentBalances,
      totalBudget: totalMonthlyBudget,
      startDate: startDate,
      strategyName: 'Snowball (Lowest Balance First)',
    );

    return (avalanche: avalancheRes, snowball: snowballRes);
  }

  static PayoffComparison _simulateDebtFreeStrategy({
    required List<Account> loans,
    required Map<String, double> initialBalances,
    required double totalBudget,
    required DateTime startDate,
    required String strategyName,
  }) {
    final balances = <String, double>{
      for (final l in loans) l.id: (initialBalances[l.id] ?? 0.0).abs(),
    };

    final order = loans.map((l) => l.name).toList();
    double totalInterestAccumulated = 0.0;
    int months = 0;

    // Minimum EMI obligations
    final emis = <String, double>{
      for (final l in loans) l.id: l.emi ?? calculateEmi(
        principal: balances[l.id] ?? 0.0,
        annualRatePct: l.annualRate ?? 10.0,
        tenureMonths: l.tenureMonths ?? 60,
      ),
    };

    while (balances.values.any((b) => b > 0.01) && months < 360) {
      months++;
      double remainingBudget = totalBudget;

      // 1. Apply interest to each active loan
      for (final l in loans) {
        final bal = balances[l.id] ?? 0.0;
        if (bal <= 0.01) continue;

        final r = ((l.annualRate ?? 10.0) / 100.0) / 12.0;
        final interest = Money.r2(bal * r);
        balances[l.id] = bal + interest;
        totalInterestAccumulated = Money.r2(totalInterestAccumulated + interest);
      }

      // 2. Pay minimum EMIs on all active loans
      for (final l in loans) {
        final bal = balances[l.id] ?? 0.0;
        if (bal <= 0.01) continue;

        final minEmi = emis[l.id] ?? 1000.0;
        final payAmt = min(bal, min(minEmi, remainingBudget));
        balances[l.id] = Money.r2(bal - payAmt);
        remainingBudget -= payAmt;
      }

      // 3. Put any leftover budget onto the target loan (top of sorted list)
      if (remainingBudget > 0.01) {
        for (final l in loans) {
          final bal = balances[l.id] ?? 0.0;
          if (bal <= 0.01) continue;

          final payAmt = min(bal, remainingBudget);
          balances[l.id] = Money.r2(bal - payAmt);
          remainingBudget -= payAmt;
          if (remainingBudget <= 0.01) break;
        }
      }
    }

    final debtFreeDate = DateTime(startDate.year, startDate.month + months, startDate.day);

    return PayoffComparison(
      strategyName: strategyName,
      totalMonths: months,
      totalInterest: totalInterestAccumulated,
      debtFreeDate: debtFreeDate,
      payoffOrder: order,
    );
  }

  /// Calculates credit card utilisation % and alert status:
  /// Alert if > 30%, Danger if > 70%.
  static ({double utilisationPct, bool isWarning, bool isDanger}) cardUtilisation({
    required double currentBalance,
    required double creditLimit,
  }) {
    if (creditLimit <= 0) {
      return (utilisationPct: 0.0, isWarning: false, isDanger: false);
    }

    final bal = currentBalance.abs();
    final pct = Money.r2((bal / creditLimit) * 100);
    return (
      utilisationPct: pct,
      isWarning: pct > 30.0 && pct <= 70.0,
      isDanger: pct > 70.0,
    );
  }

  /// Calculates credit card minimum due:
  /// Defaults to 5% of statement balance (min ₹100).
  static double minimumDue({
    required double statementBalance,
    double minDuePct = 5.0,
  }) {
    if (statementBalance <= 0) return 0.0;
    final due = statementBalance * (minDuePct / 100.0);
    return Money.r2(max(100.0, due));
  }
}
