import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/finance/models/account.dart';
import 'package:habit_tracker/features/finance/engine/loan_engine.dart';

void main() {
  group('Phase 7 Debt and Loan Engine Unit Tests', () {
    test('Standard banking table EMI: ₹10L at 8.5% for 20y -> ₹8,678/mo', () {
      final emi = LoanEngine.calculateEmi(
        principal: 1000000.0,
        annualRatePct: 8.5,
        tenureMonths: 240, // 20 years
      );

      // Standard banking table: 8678.23
      expect(emi.round(), equals(8678));
      expect(emi, closeTo(8678.23, 0.5));
    });

    test('Non-amortising loan case flagged correctly', () {
      // Balance 10L, 12% interest -> monthly interest = 10,000
      // EMI = 8,000 is less than interest!
      final months = LoanEngine.remainingMonths(
        principal: 1000000.0,
        annualRatePct: 12.0,
        emi: 8000.0,
      );
      expect(months, equals(-1));

      final schedule = LoanEngine.generateSchedule(
        principal: 1000000.0,
        annualRatePct: 12.0,
        emi: 8000.0,
      );
      expect(schedule.neverAmortizes, isTrue);
    });

    test('Auto-splits debt payment into principal and interest', () {
      // 100,000 balance at 12% p.a. -> monthly interest = 1,000
      final split = LoanEngine.splitPayment(
        currentBalance: 100000.0,
        annualRatePct: 12.0,
        paymentAmount: 3500.0,
      );

      expect(split.interest, equals(1000.0));
      expect(split.principal, equals(2500.0));
    });

    test('Extra payment simulation: saves significant months and interest', () {
      final sim = LoanEngine.simulateExtraPayment(
        principal: 1000000.0,
        annualRatePct: 8.5,
        emi: 8678.23,
        extraPaymentPerMonth: 5000.0,
      );

      // Baseline: 240 months
      expect(sim.baselineMonths, equals(240));
      // Accelerated tenure: ~104 months
      expect(sim.newMonths, lessThan(120));
      expect(sim.monthsSaved, greaterThan(100));
      expect(sim.interestSaved, greaterThan(500000.0)); // Saves > ₹5 Lakhs in interest!
    });

    test('Credit card utilisation calculation and alerts', () {
      // Safe: 15%
      final uSafe = LoanEngine.cardUtilisation(
        currentBalance: 15000.0,
        creditLimit: 100000.0,
      );
      expect(uSafe.utilisationPct, equals(15.0));
      expect(uSafe.isWarning, isFalse);
      expect(uSafe.isDanger, isFalse);

      // Warning: 45% (> 30%)
      final uWarn = LoanEngine.cardUtilisation(
        currentBalance: 45000.0,
        creditLimit: 100000.0,
      );
      expect(uWarn.utilisationPct, equals(45.0));
      expect(uWarn.isWarning, isTrue);
      expect(uWarn.isDanger, isFalse);

      // Danger: 80% (> 70%)
      final uDanger = LoanEngine.cardUtilisation(
        currentBalance: 80000.0,
        creditLimit: 100000.0,
      );
      expect(uDanger.utilisationPct, equals(80.0));
      expect(uDanger.isWarning, isFalse);
      expect(uDanger.isDanger, isTrue);
    });

    test('Payoff strategies: Avalanche orders by rate, Snowball orders by balance', () {
      final loanCard = Account(
        id: 'acc_cc',
        name: 'HDFC Card',
        kind: 'credit_card',
        annualRate: 36.0, // High interest, higher balance
        openingBalance: -80000.0,
        openingDate: DateTime(2025, 1, 1),
        colorValue: 0xFF000000,
      );

      final loanSmall = Account(
        id: 'acc_small',
        name: 'Consumer Loan',
        kind: 'loan',
        annualRate: 14.0, // Lower interest, smaller balance
        openingBalance: -20000.0,
        openingDate: DateTime(2025, 1, 1),
        colorValue: 0xFF000000,
      );

      final loans = [loanCard, loanSmall];
      final balances = {
        'acc_cc': 80000.0,
        'acc_small': 20000.0,
      };

      final comparison = LoanEngine.comparePayoffStrategies(
        loans: loans,
        currentBalances: balances,
        totalMonthlyBudget: 15000.0,
        startDate: DateTime(2026, 1, 1),
      );

      // Avalanche prioritises 36% (HDFC Card) first
      expect(comparison.avalanche.payoffOrder.first, equals('HDFC Card'));

      // Snowball prioritises 20,000 (Consumer Loan) first
      expect(comparison.snowball.payoffOrder.first, equals('Consumer Loan'));

      // Avalanche results in equal or lower total interest
      expect(comparison.avalanche.totalInterest, lessThanOrEqualTo(comparison.snowball.totalInterest));
    });
  });
}
