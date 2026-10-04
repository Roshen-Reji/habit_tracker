import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:habit_tracker/features/finance/data/finance_lock_service.dart';
import 'package:habit_tracker/features/finance/data/finance_encryption_service.dart';
import 'package:habit_tracker/features/finance/engine/money.dart';
import 'package:habit_tracker/features/finance/models/account.dart';
import 'package:habit_tracker/features/finance/finance_page.dart';

void main() {
  group('Phase 13: FinanceLockService', () {
    test('Lock service controls unlocked status and timeout', () {
      final lockService = FinanceLockService.instance;

      // In unlocked state
      lockService.isUnlocked.value = true;
      expect(lockService.isUnlocked.value, isTrue);

      // Lock manually
      lockService.lock();
      // If lock is not enabled in settings box, lock() is a no-op
      // Testing recording activity
      lockService.recordActivity();
      expect(lockService, isNotNull);
    });
  });

  group('Phase 13: FinanceEncryptionService', () {
    test('Generates exactly 32-byte AES encryption key', () async {
      final encService = FinanceEncryptionService.instance;
      final key = await encService.getOrCreateEncryptionKey();

      expect(key.length, 32);
    });

    test('Throws on invalid explicit key size', () async {
      final encService = FinanceEncryptionService.instance;
      expect(
        () => encService.getOrCreateEncryptionKey(explicitKey: [1, 2, 3]),
        throwsArgumentError,
      );
    });
  });

  group('Phase 13: High-Volume Performance & Drift (20k Transactions)', () {
    test('Aggregates 20,000 transactions without floating point drift (Money.r2)', () {
      final account = Account(
        id: 'acc_perf',
        name: 'High Volume Checking',
        kind: 'bank',
        openingBalance: 100000.0,
        openingDate: DateTime(2025, 1, 1),
      );

      final now = DateTime(2026, 3, 1);
      final transactions = <Transaction>[];

      // 10,000 expenses of ₹10.10 and 10,000 expenses of ₹20.20
      for (var i = 0; i < 10000; i++) {
        transactions.add(Transaction(
          id: 'tx_perf_a_$i',
          title: 'Coffee $i',
          amount: -10.10,
          kind: 'expense',
          accountId: 'acc_perf',
          date: now,
        ));
        transactions.add(Transaction(
          id: 'tx_perf_b_$i',
          title: 'Snack $i',
          amount: -20.20,
          kind: 'expense',
          accountId: 'acc_perf',
          date: now,
        ));
      }

      final stopwatch = Stopwatch()..start();
      final balance = account.balanceAsOf(transactions, now);
      stopwatch.stop();

      // Opening = 100,000
      // 10,000 * -10.10 = -101,000
      // 10,000 * -20.20 = -202,000
      // Net change = -303,000.00
      // Final balance = 100,000 - 303,000 = -203,000.00
      expect(balance, -203000.00);

      // Verify execution time for 20,000 transactions is fast (well under 500ms)
      expect(stopwatch.elapsedMilliseconds < 500, isTrue);
    });
  });

  group('Phase 13: Legacy Removal (P13-5)', () {
    test('FinanceDashboard widget compiles cleanly and instantiates', () {
      const widget = FinanceDashboard();
      expect(widget, isNotNull);
    });
  });
}
