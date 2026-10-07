import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/finance/engine/capture_engine.dart';
import 'package:habit_tracker/features/finance/models/category_rule.dart';

void main() {
  group('Phase 10: CSV Parsing & RFC 4180', () {
    test('Tokenizes standard comma-separated lines', () {
      const csv = 'Date,Description,Amount\n2026-03-01,Coffee,-150.00\n2026-03-02,Salary,50000.00';
      final rows = CsvParser.tokenize(csv, ',');
      expect(rows.length, 3);
      expect(rows[0], ['Date', 'Description', 'Amount']);
      expect(rows[1], ['2026-03-01', 'Coffee', '-150.00']);
      expect(rows[2], ['2026-03-02', 'Salary', '50000.00']);
    });

    test('Handles quoted fields with commas and escaped quotes', () {
      const csv = 'Date,Description,Amount\n2026-03-01,"Coffee, Tea & ""More""",-250.00';
      final rows = CsvParser.tokenize(csv, ',');
      expect(rows.length, 2);
      expect(rows[1][1], 'Coffee, Tea & "More"');
      expect(rows[1][2], '-250.00');
    });

    test('Auto-detects semicolon and tab delimiters', () {
      const semiCsv = 'Date;Description;Amount\n2026-03-01;Groceries;-450';
      expect(CsvParser.detectDelimiter(semiCsv), ';');

      const tabCsv = 'Date\tDescription\tAmount\n2026-03-01\tGroceries\t-450';
      expect(CsvParser.detectDelimiter(tabCsv), '\t');
    });

    test('Parses CSV records into TransactionDraft with dedupe keys', () {
      const csv = '''Date,Description,Debit,Credit
01/03/2026,Swiggy Order,350.00,
02/03/2026,UPI-PAYTM-REFUND,,100.00
03/03/2026,Salary Transfer,,45000.00''';

      const profile = CsvMappingProfile(
        hasHeader: true,
        delimiter: ',',
        dateColumn: 0,
        descriptionColumn: 1,
        debitColumn: 2,
        creditColumn: 3,
        dateFormat: 'dd/MM/yyyy',
      );

      final drafts = CsvParser.parseToDrafts(
        csvContent: csv,
        profile: profile,
        targetAccountId: 'acc_hdfc',
        allCategories: [],
        rules: [],
      );

      expect(drafts.length, 3);

      // Record 1: Expense
      expect(drafts[0].kind, 'expense');
      expect(drafts[0].amount, 350.0);
      expect(drafts[0].source, TransactionSource.csv);
      expect(drafts[0].sourceRef, startsWith('import:'));

      // Record 2: Income / Refund
      expect(drafts[1].kind, 'income');
      expect(drafts[1].amount, 100.0);

      // Record 3: Salary
      expect(drafts[2].kind, 'income');
      expect(drafts[2].amount, 45000.0);
    });

    test('Detects potential transfer pairs', () {
      final now = DateTime(2026, 3, 10, 14, 0);
      final drafts = [
        TransactionDraft(
          title: 'Transfer to Savings',
          amount: 5000.0,
          kind: 'expense',
          accountId: 'acc_checking',
          date: now,
          source: TransactionSource.csv,
        ),
        TransactionDraft(
          title: 'Deposit from Checking',
          amount: 5000.0,
          kind: 'income',
          accountId: 'acc_savings',
          date: now.add(const Duration(hours: 12)),
          source: TransactionSource.csv,
        ),
        TransactionDraft(
          title: 'Lunch',
          amount: 300.0,
          kind: 'expense',
          accountId: 'acc_checking',
          date: now,
          source: TransactionSource.csv,
        ),
      ];

      final pairs = CsvParser.detectTransferPairs(drafts);
      expect(pairs.length, 1);
      expect(pairs.first.fromDraft.accountId, 'acc_checking');
      expect(pairs.first.toDraft.accountId, 'acc_savings');
      expect(pairs.first.fromDraft.amount, 5000.0);
    });
  });

  group('Phase 10: Merchant Normalizer & Rules Engine', () {
    test('Normalizes merchant strings by stripping UPI patterns and noise', () {
      expect(
        MerchantNormalizer.normalize('UPI-SWIGGY-12345@icici'),
        'SWIGGY',
      );
      expect(
        MerchantNormalizer.normalize('AMAZON PAY INDIA PVT LTD'),
        'AMAZON PAY INDIA',
      );
      expect(
        MerchantNormalizer.normalize('POS 987654 NETFLIX.COM MUMBAI'),
        'NETFLIX',
      );
    });

    test('Categorization rules match by priority and matchType', () {
      final rules = [
        CategoryRule(
          id: 'rule_1',
          categoryId: 'cat_food',
          matchType: 'contains',
          pattern: 'SWIGGY',
          priority: 10,
        ),
        CategoryRule(
          id: 'rule_2',
          categoryId: 'cat_shopping',
          matchType: 'regex',
          pattern: r'amazon|flipkart',
          priority: 5,
        ),
        CategoryRule(
          id: 'rule_3',
          categoryId: 'cat_misc',
          matchType: 'contains',
          pattern: 'ORDER',
          priority: 1, // lowest priority
        ),
      ];

      final catSwiggy = CategorizationRulesEngine.matchCategory(
        merchant: 'Swiggy',
        description: 'Online Order Swiggy',
        rules: rules,
      );
      expect(catSwiggy, 'cat_food');

      final catAmazon = CategorizationRulesEngine.matchCategory(
        merchant: 'Amazon Seller',
        description: 'Order from amazon.in',
        rules: rules,
      );
      expect(catAmazon, 'cat_shopping');

      // Rule 1 has higher priority than Rule 3 even if description has 'ORDER'
      final catPriority = CategorizationRulesEngine.matchCategory(
        merchant: 'SWIGGY ORDER',
        description: 'ORDER 123',
        rules: rules,
      );
      expect(catPriority, 'cat_food');
    });
  });

  group('Phase 10: SMS Transaction Parser', () {
    test('Parses HDFC debit alert', () {
      const sms = 'Alert: Rs. 450.00 debited from HDFC Bank A/C **1234 on 04-OCT-26 to SWIGGY. Avl Bal: Rs 12,345.00';
      final draft = SmsTransactionParser.parse(sms, defaultAccountId: 'acc_hdfc');
      expect(draft, isNotNull);
      expect(draft!.amount, 450.0);
      expect(draft.kind, 'expense');
      expect(draft.merchant, 'SWIGGY');
      expect(draft.source, TransactionSource.sms);
    });

    test('Parses ICICI credit alert', () {
      const sms = 'Your A/C XX5678 is credited with INR 25,000.00 on 01-OCT-26 by Salary. Avail Bal: INR 75,000.00';
      final draft = SmsTransactionParser.parse(sms, defaultAccountId: 'acc_icici');
      expect(draft, isNotNull);
      expect(draft!.amount, 25000.0);
      expect(draft.kind, 'income');
      expect(draft.source, TransactionSource.sms);
    });

    test('Parses generic UPI debit alert', () {
      const sms = 'Rs 120.00 spent on your Card ending 4321 at CHAI POINT on 04-10-2026.';
      final draft = SmsTransactionParser.parse(sms);
      expect(draft, isNotNull);
      expect(draft!.amount, 120.0);
      expect(draft.kind, 'expense');
      expect(draft.merchant, 'CHAI POINT');
    });

    test('Returns null on non-financial SMS', () {
      const sms = 'Your OTP for login is 123456. Valid for 10 minutes.';
      final draft = SmsTransactionParser.parse(sms);
      expect(draft, isNull);
    });
  });
}
