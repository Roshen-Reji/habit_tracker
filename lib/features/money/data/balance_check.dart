import 'package:flutter/foundation.dart';
import 'package:habit_tracker/features/finance/data/backup/finance_backup_service.dart';
import 'package:habit_tracker/features/finance/data/finance_storage.dart';
import 'package:habit_tracker/features/finance/engine/ledger.dart';
import 'package:habit_tracker/features/finance/models/account.dart';
import 'package:habit_tracker/models/finance_model.dart';
import '../core/account_group.dart';
import '../core/ledger.dart';
import '../core/minor.dart';
import '../state/money_state.dart';
import 'money_store.dart';

/// Information about an account's balance discrepancy caused by removing the openingDate cutoff.
class AccountDiscrepancy {
  final Account account;
  final double oldBalance;
  final double newBalance;
  final List<Transaction> ignoredTransactions;

  AccountDiscrepancy({
    required this.account,
    required this.oldBalance,
    required this.newBalance,
    required this.ignoredTransactions,
  });

  bool get hasDiscrepancy => (oldBalance - newBalance).abs() >= 0.01;
  double get difference => newBalance - oldBalance;
}

/// Potential duplicate SIP entry detected during migration audit.
class DuplicateSipItem {
  final String accountId;
  final String title;
  final DateTime date;
  final double amount;
  final String? sourceRef;
  final String reason;

  DuplicateSipItem({
    required this.accountId,
    required this.title,
    required this.date,
    required this.amount,
    this.sourceRef,
    required this.reason,
  });
}

/// Service managing data safety and the one-time balance migration check (Section 6).
class BalanceCheckService {
  final FinanceStorage storage;
  final MoneyStore store;

  BalanceCheckService({
    FinanceStorage? storage,
    MoneyStore? store,
  })  : storage = storage ?? FinanceStorage(),
        store = store ?? MoneyStore();

  /// Whether the initial balance check migration has already run.
  bool get isMigrationDone =>
      storage.settingsBox
          .get('money2_balance_migration_done', defaultValue: false) ==
      true;

  /// Takes an automated pre-flight JSON backup.
  /// Aborts and throws an exception if backup fails.
  Future<String> takeSafetyBackup() async {
    try {
      final jsonBackup = await FinanceBackupService.exportJson();
      if (jsonBackup.isEmpty) {
        throw StateError(
            'FinanceBackupService returned an empty JSON backup string.');
      }
      return jsonBackup;
    } catch (e) {
      debugPrint('BalanceCheckService: Safety backup failed: $e');
      throw StateError('Pre-flight JSON backup failed. Aborting migration: $e');
    }
  }

  /// Calculates discrepancies between old rule (with openingDate cutoff)
  /// and new rule (Law L2: all entries up to cutoff count).
  List<AccountDiscrepancy> computeDiscrepancies({DateTime? asOf}) {
    final cutoff = asOf ?? DateTime.now();
    final allTx = storage.transactionBox.values.toList();
    final allValuations = storage.valuationBox.values.toList();
    final allAccounts = storage.accountBox.values.toList();
    final entries = store.loadEntries();

    final results = <AccountDiscrepancy>[];

    for (final acc in allAccounts) {
      // 1. Compute old balance using legacy LedgerEngine
      final oldBal = LedgerEngine.balance(
        acc,
        allTx,
        allValuations,
        asOf: cutoff,
      );

      // 2. Compute new balance using Law L2
      final coreAcc = CoreAccount.fromRaw(
        id: acc.id,
        name: acc.name,
        rawKind: acc.kind,
        openingBalance: acc.openingBalance,
        openingDate: acc.openingDate,
        mainAccountId: store.getSetting<String>(
          'money2_main_account_id',
          defaultValue: 'acc_main',
        ),
      );

      final newBalMinor = CoreLedger.balance(
        account: coreAcc,
        entries: entries,
        valuations: store.loadValuations(),
        asOf: cutoff,
      );
      final newBal = Minor.fromMinor(newBalMinor);

      // 3. Find ignored transactions
      final ignored = allTx.where((tx) {
        final touchesAcc = tx.accountId == acc.id || tx.toAccountId == acc.id;
        final isBeforeOpening = tx.date.isBefore(acc.openingDate);
        final isBeforeCutoff = !tx.date.isAfter(cutoff);
        return touchesAcc && isBeforeOpening && isBeforeCutoff;
      }).toList();

      results.add(AccountDiscrepancy(
        account: acc,
        oldBalance: oldBal,
        newBalance: newBal,
        ignoredTransactions: ignored,
      ));
    }

    return results;
  }

  /// Option 1: User chooses to "Use new balances" (Law L2 directly).
  Future<void> applyUseNewBalances() async {
    await takeSafetyBackup();
    await storage.settingsBox.put('money2_balance_migration_done', true);
    MoneyState().refreshFromStore(store);
  }

  /// Option 2: User chooses to "Keep today's balances".
  ///
  /// Adjusts openingBalance = oldBalance - Σ effects of all entries,
  /// so today's number stays identical and future entries behave correctly according to Law L2.
  Future<void> applyKeepTodayBalances({DateTime? asOf}) async {
    await takeSafetyBackup();
    final cutoff = asOf ?? DateTime.now();
    final discrepancies = computeDiscrepancies(asOf: cutoff);

    for (final d in discrepancies) {
      if (d.hasDiscrepancy) {
        final acc = d.account;

        // Calculate sum of effects of all entries on this account (with zero opening balance)
        final tempCoreAcc = CoreAccount(
          id: acc.id,
          name: acc.name,
          group: AccountClassifier.classify(
            accountId: acc.id,
            mainAccountId: '',
            rawKind: acc.kind,
          ),
          rawKind: acc.kind,
          openingBalanceMinor: 0,
          openingDate: DateTime(2000, 1, 1),
        );

        final sumOfEffectsMinor = CoreLedger.balance(
          account: tempCoreAcc,
          entries: store.loadEntries(),
          valuations: store.loadValuations(),
          asOf: cutoff,
        );
        final sumOfEffects = Minor.fromMinor(sumOfEffectsMinor);

        // Adjust opening balance so openingBalance + sumOfEffects == oldBalance
        final adjustedOpening = d.oldBalance - sumOfEffects;
        acc.openingBalance = (adjustedOpening * 100.0).round() / 100.0;
        await acc.save();
      }
    }

    await storage.settingsBox.put('money2_balance_migration_done', true);
    MoneyState().refreshFromStore(store);
  }

  /// Checks for legacy duplicate SIP entries and plain "SIP · name" expenses with no destination.
  List<DuplicateSipItem> checkLegacyDuplicates() {
    final allTx = storage.transactionBox.values.toList();
    final duplicates = <DuplicateSipItem>[];

    // Map month -> Set of sourceRefs
    final sipByMonth = <String, List<Transaction>>{};

    for (final tx in allTx) {
      final yyyyMm =
          '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}';
      final ref = tx.sourceRef ?? '';

      // Check if both sip_... and rec:.... exist for the same month
      if (ref.startsWith('sip_') || ref.startsWith('rec:')) {
        sipByMonth.putIfAbsent(yyyyMm, () => []).add(tx);
      }

      // Check for plain "SIP · name" expenses with no destination account
      if (tx.title.toLowerCase().startsWith('sip') &&
          tx.effectiveKind == 'expense' &&
          (tx.toAccountId == null || tx.toAccountId!.isEmpty)) {
        duplicates.add(DuplicateSipItem(
          accountId: tx.accountId ?? 'unknown',
          title: tx.title,
          date: tx.date,
          amount: tx.amount.abs(),
          sourceRef: tx.sourceRef,
          reason: 'SIP recorded as plain expense without a destination fund.',
        ));
      }
    }

    for (final entry in sipByMonth.entries) {
      final txs = entry.value;
      if (txs.length > 1) {
        final hasSipRef =
            txs.any((t) => (t.sourceRef ?? '').startsWith('sip_'));
        final hasRecRef =
            txs.any((t) => (t.sourceRef ?? '').startsWith('rec:'));
        if (hasSipRef && hasRecRef) {
          for (final t in txs) {
            duplicates.add(DuplicateSipItem(
              accountId: t.accountId ?? 'unknown',
              title: t.title,
              date: t.date,
              amount: t.amount.abs(),
              sourceRef: t.sourceRef,
              reason: 'Duplicate SIP references in month ${entry.key}.',
            ));
          }
        }
      }
    }

    return duplicates;
  }
}
