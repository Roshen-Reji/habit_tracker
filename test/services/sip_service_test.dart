import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:habit_tracker/data/services/sip_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Box financeSettingsBox;
  late Box<Transaction> transactionsBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sip_service_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(TransactionAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    financeSettingsBox = await Hive.openBox(
        'finance_settings_test_${DateTime.now().microsecondsSinceEpoch}');
    transactionsBox = await Hive.openBox<Transaction>(
        'transactions_test_${DateTime.now().microsecondsSinceEpoch}');
  });

  tearDown(() async {
    await financeSettingsBox.close();
    await transactionsBox.close();
  });

  group('SipService Tests (P0-3)', () {
    test('Migration sets id and createdAt for legacy SIP without back-charging',
        () async {
      final legacySip = {
        'name': 'HDFC Index',
        'amount': 5000.0,
        'due': 5,
        'folio': '12345',
      };
      await financeSettingsBox.put('planner', {
        'fixedExpenses': [],
        'sips': [legacySip],
      });

      final migrationDate = DateTime(2026, 10, 10);
      SipService.migrateSips(
          settingsBox: financeSettingsBox, now: migrationDate);

      final planner =
          Map<String, dynamic>.from(financeSettingsBox.get('planner'));
      final sips = List.from(planner['sips']);
      expect(sips.length, 1);
      final migrated = sips.first as Map;
      expect(migrated['id'], isNotNull);
      expect(migrated['createdAt'], migrationDate.toIso8601String());

      // If runDue is executed on 2026-10-10, since due was 5 (< 10), it should NOT back-charge for Oct 5
      final posted = await SipService.runDue(
        now: migrationDate,
        financeSettingsBox: financeSettingsBox,
        txBox: transactionsBox,
      );
      expect(posted, 0);
      expect(transactionsBox.isEmpty, isTrue);
    });

    test('due = 31 in Feb 2027 posts on Feb 28', () async {
      final sip = {
        'id': 'sip_feb27',
        'name': 'Nifty 50',
        'amount': 2000.0,
        'due': 31,
        'createdAt': DateTime(2027, 2, 1).toIso8601String(),
      };
      await financeSettingsBox.put('planner', {
        'sips': [sip]
      });

      final posted = await SipService.runDue(
        now: DateTime(2027, 2, 28, 12, 0),
        financeSettingsBox: financeSettingsBox,
        txBox: transactionsBox,
      );

      expect(posted, 1);
      expect(transactionsBox.length, 1);
      final tx = transactionsBox.values.first;
      expect(tx.date.year, 2027);
      expect(tx.date.month, 2);
      expect(tx.date.day, 28);
      expect(tx.amount, -2000.0);
    });

    test('due = 30 in Feb 2028 (leap year) posts on Feb 29', () async {
      final sip = {
        'id': 'sip_feb28_leap',
        'name': 'Midcap Fund',
        'amount': 3000.0,
        'due': 30,
        'createdAt': DateTime(2028, 2, 1).toIso8601String(),
      };
      await financeSettingsBox.put('planner', {
        'sips': [sip]
      });

      final posted = await SipService.runDue(
        now: DateTime(2028, 2, 29, 10, 0),
        financeSettingsBox: financeSettingsBox,
        txBox: transactionsBox,
      );

      expect(posted, 1);
      final tx = transactionsBox.values.first;
      expect(tx.date.year, 2028);
      expect(tx.date.month, 2);
      expect(tx.date.day, 29);
      expect(tx.amount, -3000.0);
    });

    test('SIP created 2026-10-15 with due = 5 -> first debit is 2026-11-05',
        () async {
      final sip = {
        'id': 'sip_oct15',
        'name': 'Smallcap Fund',
        'amount': 1500.0,
        'due': 5,
        'createdAt': DateTime(2026, 10, 15).toIso8601String(),
      };
      await financeSettingsBox.put('planner', {
        'sips': [sip]
      });

      // Check on Oct 20 -> should NOT debit (due 5 already passed before createdAt)
      var posted = await SipService.runDue(
        now: DateTime(2026, 10, 20),
        financeSettingsBox: financeSettingsBox,
        txBox: transactionsBox,
      );
      expect(posted, 0);
      expect(transactionsBox.isEmpty, isTrue);

      // Check on Nov 4 -> should NOT debit yet
      posted = await SipService.runDue(
        now: DateTime(2026, 11, 4),
        financeSettingsBox: financeSettingsBox,
        txBox: transactionsBox,
      );
      expect(posted, 0);

      // Check on Nov 5 -> should debit
      posted = await SipService.runDue(
        now: DateTime(2026, 11, 5),
        financeSettingsBox: financeSettingsBox,
        txBox: transactionsBox,
      );
      expect(posted, 1);
      final tx = transactionsBox.values.first;
      expect(tx.date.year, 2026);
      expect(tx.date.month, 11);
      expect(tx.date.day, 5);
      expect(tx.amount, -1500.0);
    });

    test(
        'App not opened for 3 months -> 3 transactions each dated on its due date',
        () async {
      final sip = {
        'id': 'sip_3mo',
        'name': 'Flexi Cap',
        'amount': 1000.0,
        'due': 10,
        'createdAt': DateTime(2026, 8, 1).toIso8601String(),
      };
      await financeSettingsBox.put('planner', {
        'sips': [sip]
      });

      // App opened on Nov 12, 2026 (Aug, Sep, Oct, Nov)
      // Aug 10, Sep 10, Oct 10, Nov 10 are all due! That's 4 months.
      // Let's create it on Aug 15 with due = 10 so Aug is skipped, then Sep, Oct, Nov = 3 months.
      final sipAug15 = {
        'id': 'sip_3mo_exact',
        'name': 'Flexi Cap Exact',
        'amount': 1000.0,
        'due': 10,
        'createdAt': DateTime(2026, 8, 15).toIso8601String(),
      };
      await financeSettingsBox.put('planner', {
        'sips': [sipAug15]
      });

      final posted = await SipService.runDue(
        now: DateTime(2026, 11, 12),
        financeSettingsBox: financeSettingsBox,
        txBox: transactionsBox,
      );

      expect(posted, 3);
      expect(transactionsBox.length, 3);

      final dates = transactionsBox.values
          .map((t) => '${t.date.year}-${t.date.month}-${t.date.day}')
          .toList();
      expect(dates, contains('2026-9-10'));
      expect(dates, contains('2026-10-10'));
      expect(dates, contains('2026-11-10'));
    });

    test('runDue twice on the same day -> no duplicates', () async {
      final sip = {
        'id': 'sip_idemp',
        'name': 'Tax Saver ELSS',
        'amount': 2500.0,
        'due': 7,
        'createdAt': DateTime(2026, 10, 1).toIso8601String(),
      };
      await financeSettingsBox.put('planner', {
        'sips': [sip]
      });

      final clock = DateTime(2026, 10, 7, 9, 30);
      final firstRun = await SipService.runDue(
        now: clock,
        financeSettingsBox: financeSettingsBox,
        txBox: transactionsBox,
      );
      expect(firstRun, 1);
      expect(transactionsBox.length, 1);

      final secondRun = await SipService.runDue(
        now: clock.add(const Duration(hours: 4)),
        financeSettingsBox: financeSettingsBox,
        txBox: transactionsBox,
      );
      expect(secondRun, 0);
      expect(transactionsBox.length, 1);
    });

    test('December -> January rollover works seamlessly', () async {
      final sip = {
        'id': 'sip_dec_jan',
        'name': 'Gold ETF',
        'amount': 1200.0,
        'due': 2,
        'createdAt': DateTime(2026, 12, 1).toIso8601String(),
      };
      await financeSettingsBox.put('planner', {
        'sips': [sip]
      });

      // Run on Dec 3
      var posted = await SipService.runDue(
        now: DateTime(2026, 12, 3),
        financeSettingsBox: financeSettingsBox,
        txBox: transactionsBox,
      );
      expect(posted, 1);

      // Run on Jan 2
      posted = await SipService.runDue(
        now: DateTime(2027, 1, 2),
        financeSettingsBox: financeSettingsBox,
        txBox: transactionsBox,
      );
      expect(posted, 1);
      expect(transactionsBox.length, 2);

      final dates = transactionsBox.values
          .map((t) => '${t.date.year}-${t.date.month}-${t.date.day}')
          .toList();
      expect(dates, contains('2026-12-2'));
      expect(dates, contains('2027-1-2'));
    });

    test('Overview balance drops by SIP amount when debited', () async {
      final sip = {
        'id': 'sip_balance_drop',
        'name': 'Index Fund',
        'amount': 4000.0,
        'due': 1,
        'createdAt': DateTime(2026, 10, 1).toIso8601String(),
      };
      await financeSettingsBox.put('planner', {
        'sips': [sip]
      });

      // Initial income of 50000
      final incomeTx = Transaction(
        title: 'Salary',
        amount: 50000.0,
        category: 'Salary',
        date: DateTime(2026, 10, 1),
        mode: 'income',
        icon: 'income',
      );
      await transactionsBox.add(incomeTx);

      double computeBalance() {
        double allTimeNet = 0;
        for (final tx in transactionsBox.values) {
          final isExpense = tx.mode.toLowerCase() == 'expense' || tx.amount < 0;
          final signedAmount = isExpense ? -tx.amount.abs() : tx.amount.abs();
          allTimeNet += signedAmount;
        }
        return allTimeNet;
      }

      expect(computeBalance(), 50000.0);

      // Post the SIP debit
      await SipService.runDue(
        now: DateTime(2026, 10, 1),
        financeSettingsBox: financeSettingsBox,
        txBox: transactionsBox,
      );

      expect(transactionsBox.length, 2);
      expect(computeBalance(), 46000.0);
    });

    test('getNextDebitDate calculates proper upcoming due dates', () {
      final sip = {
        'id': 'sip_test',
        'name': 'Test',
        'amount': 1000.0,
        'due': 15,
        'createdAt': DateTime(2026, 10, 1).toIso8601String(),
      };

      // Before due date in October
      final next1 =
          SipService.getNextDebitDate(sip, now: DateTime(2026, 10, 10));
      expect(next1, DateTime(2026, 10, 15));

      // On due date
      final next2 =
          SipService.getNextDebitDate(sip, now: DateTime(2026, 10, 15));
      expect(next2, DateTime(2026, 10, 15));

      // After due date in October -> rolls to November
      final next3 =
          SipService.getNextDebitDate(sip, now: DateTime(2026, 10, 16));
      expect(next3, DateTime(2026, 11, 15));

      // December roll to January
      final next4 =
          SipService.getNextDebitDate(sip, now: DateTime(2026, 12, 20));
      expect(next4, DateTime(2027, 1, 15));
    });

    test('isPostedForMonth correctly inspects ledger', () async {
      await financeSettingsBox.put('sip_ledger', {
        'sip_1': '2026-10',
      });

      expect(
          SipService.isPostedForMonth('sip_1', '2026-10', financeSettingsBox),
          isTrue);
      expect(
          SipService.isPostedForMonth('sip_1', '2026-11', financeSettingsBox),
          isFalse);
      expect(
          SipService.isPostedForMonth('sip_2', '2026-10', financeSettingsBox),
          isFalse);
    });
  });
}
