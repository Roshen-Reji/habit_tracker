import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:habit_tracker/features/finance/data/finance_storage.dart';
import 'package:habit_tracker/features/finance/models/models.dart';

/// Service responsible for automatic and manual JSON backups of all finance data.
class FinanceBackupService {
  /// Exports all finance data to a JSON string or file.
  static Future<String> exportJson({String? targetFilePath}) async {
    final storage = FinanceStorage();

    final txList = storage.transactionBox.values
        .map((tx) => {
              'title': tx.title,
              'amount': tx.amount,
              'category': tx.category,
              'date': tx.date.toIso8601String(),
              'mode': tx.mode,
              'icon': tx.icon,
              'id': tx.id,
              'kind': tx.kind,
              'accountId': tx.accountId,
              'toAccountId': tx.toAccountId,
              'categoryId': tx.categoryId,
              'merchant': tx.merchant,
              'paymentMethod': tx.paymentMethod,
              'notes': tx.notes,
              'tags': tx.tags,
              'splits': tx.splits,
              'receiptPaths': tx.receiptPaths,
              'recurringRuleId': tx.recurringRuleId,
              'sourceRef': tx.sourceRef,
              'createdAt': tx.createdAt?.toIso8601String(),
              'goalId': tx.goalId,
              'interestAmount': tx.interestAmount,
              'refundOfId': tx.refundOfId,
            })
        .toList();

    final vaultList = storage.vaultBox.values
        .map((v) => {
              'name': v.name,
              'balance': v.balance,
              'bank': v.bank,
              'type': v.type,
              'colorValue': v.colorValue,
            })
        .toList();

    final accountList = storage.accountBox.values
        .map((a) => {
              'id': a.id,
              'name': a.name,
              'kind': a.kind,
              'institution': a.institution,
              'openingBalance': a.openingBalance,
              'openingDate': a.openingDate.toIso8601String(),
              'colorValue': a.colorValue,
              'archived': a.archived,
              'includeInNetWorth': a.includeInNetWorth,
              'spendable': a.spendable,
              'creditLimit': a.creditLimit,
              'statementDay': a.statementDay,
              'dueDay': a.dueDay,
              'principal': a.principal,
              'annualRate': a.annualRate,
              'emi': a.emi,
              'tenureMonths': a.tenureMonths,
              'startDate': a.startDate?.toIso8601String(),
            })
        .toList();

    final categoryList = storage.categoryBox.values
        .map((c) => {
              'id': c.id,
              'name': c.name,
              'kind': c.kind,
              'group': c.group,
              'iconKey': c.iconKey,
              'colorValue': c.colorValue,
              'parentId': c.parentId,
              'essential': c.essential,
              'archived': c.archived,
              'sortOrder': c.sortOrder,
            })
        .toList();

    final ruleList = storage.ruleBox.values
        .map((r) => {
              'id': r.id,
              'pattern': r.pattern,
              'matchType': r.matchType,
              'categoryId': r.categoryId,
              'priority': r.priority,
              'createdFromCorrection': r.createdFromCorrection,
            })
        .toList();

    final recurringList = storage.recurringBox.values
        .map((r) => {
              'id': r.id,
              'name': r.name,
              'kind': r.kind,
              'amount': r.amount,
              'amountIsVariable': r.amountIsVariable,
              'categoryId': r.categoryId,
              'accountId': r.accountId,
              'toAccountId': r.toAccountId,
              'frequency': r.frequency,
              'interval': r.interval,
              'anchorDate': r.anchorDate?.toIso8601String(),
              'dayOfMonth': r.dayOfMonth,
              'startDate': r.startDate.toIso8601String(),
              'endDate': r.endDate?.toIso8601String(),
              'autoPost': r.autoPost,
              'reminderDaysBefore': r.reminderDaysBefore,
              'status': r.status,
              'folio': r.folio,
              'notes': r.notes,
              'createdAt': r.createdAt.toIso8601String(),
            })
        .toList();

    final budgetLines = storage.budgetLineBox.values
        .map((b) => {
              'id': b.id,
              'categoryId': b.categoryId,
              'bucketRef': b.bucketRef,
              'amount': b.amount,
              'rollover': b.rollover,
              'essential': b.essential,
              'startMonth': b.startMonth,
            })
        .toList();

    final budgetOverrides = storage.budgetOverrideBox.values
        .map((o) => {
              'lineId': o.lineId,
              'monthKey': o.monthKey,
              'amount': o.amount,
            })
        .toList();

    final goals = storage.goalBox.values
        .map((g) => {
              'id': g.id,
              'name': g.name,
              'kind': g.kind,
              'targetAmount': g.targetAmount,
              'deadline': g.deadline?.toIso8601String(),
              'dueDate': g.dueDate?.toIso8601String(),
              'accountId': g.accountId,
              'colorValue': g.colorValue,
              'priority': g.priority,
              'autoContribute': g.autoContribute,
              'plannedMonthly': g.plannedMonthly,
              'linkedCategoryId': g.linkedCategoryId,
              'archived': g.archived,
            })
        .toList();

    final goalEntries = storage.goalEntryBox.values
        .map((e) => {
              'id': e.id,
              'goalId': e.goalId,
              'date': e.date.toIso8601String(),
              'amount': e.amount,
              'note': e.note,
              'sourceRef': e.sourceRef,
            })
        .toList();

    final valuations = storage.valuationBox.values
        .map((v) => {
              'id': v.id,
              'accountId': v.accountId,
              'date': v.date.toIso8601String(),
              'value': v.value,
              'units': v.units,
              'unitPrice': v.unitPrice,
            })
        .toList();

    final splitGroups = storage.splitGroupBox.values
        .map((g) => {
              'id': g.id,
              'name': g.name,
              'kind': g.kind,
              'members': g.members,
              'createdAt': g.createdAt.toIso8601String(),
            })
        .toList();

    final splitEntries = storage.splitEntryBox.values
        .map((e) => {
              'id': e.id,
              'groupId': e.groupId,
              'date': e.date.toIso8601String(),
              'title': e.title,
              'amount': e.amount,
              'paidBy': e.paidBy,
              'shares': e.shares,
              'txId': e.txId,
              'settled': e.settled,
            })
        .toList();

    // Settings box snapshot
    final settingsMap = <String, dynamic>{};
    for (final key in storage.settingsBox.keys) {
      settingsMap[key.toString()] = storage.settingsBox.get(key);
    }

    // Global settings snapshot (global_xp, rem_*, etc.)
    final globalSettingsMap = <String, dynamic>{};
    if (Hive.isBoxOpen('settings')) {
      final globalBox = Hive.box('settings');
      for (final key in globalBox.keys) {
        final keyStr = key.toString();
        if (keyStr == 'global_xp' || keyStr.startsWith('rem_')) {
          globalSettingsMap[keyStr] = globalBox.get(key);
        }
      }
    }

    // XP History snapshot
    final xpHistoryMap = <String, dynamic>{};
    if (Hive.isBoxOpen('xp_history')) {
      final xpBox = Hive.box('xp_history');
      for (final key in xpBox.keys) {
        xpHistoryMap[key.toString()] = xpBox.get(key);
      }
    }

    final backupPayload = {
      'version': 3,
      'exportedAt': DateTime.now().toIso8601String(),
      'transactions': txList,
      'vaults': vaultList,
      'accounts': accountList,
      'categories': categoryList,
      'rules': ruleList,
      'recurring': recurringList,
      'budgetLines': budgetLines,
      'budgetOverrides': budgetOverrides,
      'goals': goals,
      'goalEntries': goalEntries,
      'valuations': valuations,
      'splitGroups': splitGroups,
      'splitEntries': splitEntries,
      'settings': settingsMap,
      'globalSettings': globalSettingsMap,
      'xpHistory': xpHistoryMap,
    };

    final jsonString =
        const JsonEncoder.withIndent('  ').convert(backupPayload);

    if (targetFilePath != null) {
      final file = File(targetFilePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonString);
      return targetFilePath;
    }

    // Default backup directory in documents
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docsDir.path}/backups');
      await backupDir.create(recursive: true);

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupPath = '${backupDir.path}/finance_$timestamp.json';
      await File(backupPath).writeAsString(jsonString);

      // Keep only last 5 backups
      await _pruneBackups(backupDir);
      return backupPath;
    } catch (_) {
      return jsonString;
    }
  }

  /// Imports and restores finance data from JSON string.
  static Future<Map<String, int>> importJson(
    String jsonString, {
    bool dryRun = false,
  }) async {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    final storage = FinanceStorage();

    final txList = (data['transactions'] as List? ?? []);
    final vaultList = (data['vaults'] as List? ?? []);
    final accountList = (data['accounts'] as List? ?? []);
    final categoryList = (data['categories'] as List? ?? []);
    final ruleList = (data['rules'] as List? ?? []);
    final recurringList = (data['recurring'] as List? ?? []);
    final budgetLines = (data['budgetLines'] as List? ?? []);
    final budgetOverrides = (data['budgetOverrides'] as List? ?? []);
    final goals = (data['goals'] as List? ?? []);
    final goalEntries = (data['goalEntries'] as List? ?? []);
    final valuations = (data['valuations'] as List? ?? []);
    final splitGroups = (data['splitGroups'] as List? ?? []);
    final splitEntries = (data['splitEntries'] as List? ?? []);

    final summary = {
      'transactions': txList.length,
      'vaults': vaultList.length,
      'accounts': accountList.length,
      'categories': categoryList.length,
      'rules': ruleList.length,
      'recurring': recurringList.length,
      'budgetLines': budgetLines.length,
      'budgetOverrides': budgetOverrides.length,
      'goals': goals.length,
      'goalEntries': goalEntries.length,
      'valuations': valuations.length,
      'splitGroups': splitGroups.length,
      'splitEntries': splitEntries.length,
    };

    if (dryRun) return summary;

    // Clear current boxes
    await storage.clearAll();

    // Restore transactions
    for (final item in txList) {
      final tx = Transaction(
        title: item['title'] ?? '',
        amount: (item['amount'] as num?)?.toDouble() ?? 0.0,
        category: item['category'] ?? 'Other',
        date: DateTime.tryParse(item['date'] ?? '') ?? DateTime.now(),
        mode: item['mode'] ?? 'expense',
        icon: item['icon'] ?? 'expense',
        id: item['id'],
        kind: item['kind'],
        accountId: item['accountId'],
        toAccountId: item['toAccountId'],
        categoryId: item['categoryId'],
        merchant: item['merchant'],
        paymentMethod: item['paymentMethod'],
        notes: item['notes'],
        tags: (item['tags'] as List?)?.map((e) => e.toString()).toList(),
        splits: item['splits'],
        receiptPaths:
            (item['receiptPaths'] as List?)?.map((e) => e.toString()).toList(),
        recurringRuleId: item['recurringRuleId'],
        sourceRef: item['sourceRef'],
        createdAt: DateTime.tryParse(item['createdAt'] ?? ''),
        goalId: item['goalId'],
        interestAmount: (item['interestAmount'] as num?)?.toDouble(),
        refundOfId: item['refundOfId'],
      );
      await storage.transactionBox.add(tx);
    }

    // Restore vaults
    for (final item in vaultList) {
      final v = AssetVault(
        name: item['name'] ?? '',
        balance: (item['balance'] as num?)?.toDouble() ?? 0.0,
        bank: item['bank'] ?? '',
        type: item['type'] ?? 'Savings',
        colorValue: (item['colorValue'] as num?)?.toInt() ?? 0xFF000000,
      );
      await storage.vaultBox.add(v);
    }

    // Restore accounts
    for (final item in accountList) {
      final acc = Account(
        id: item['id'] ?? '',
        name: item['name'] ?? '',
        kind: item['kind'] ?? 'bank',
        institution: item['institution'],
        openingBalance: (item['openingBalance'] as num?)?.toDouble() ?? 0.0,
        openingDate:
            DateTime.tryParse(item['openingDate'] ?? '') ?? DateTime.now(),
        colorValue: (item['colorValue'] as num?)?.toInt() ?? 0xFF000000,
        archived: item['archived'] ?? false,
        includeInNetWorth: item['includeInNetWorth'] ?? true,
        spendable: item['spendable'] ?? true,
        creditLimit: (item['creditLimit'] as num?)?.toDouble(),
        statementDay: (item['statementDay'] as num?)?.toInt(),
        dueDay: (item['dueDay'] as num?)?.toInt(),
        principal: (item['principal'] as num?)?.toDouble(),
        annualRate: (item['annualRate'] as num?)?.toDouble(),
        emi: (item['emi'] as num?)?.toDouble(),
        tenureMonths: (item['tenureMonths'] as num?)?.toInt(),
        startDate: DateTime.tryParse(item['startDate'] ?? ''),
      );
      await storage.accountBox.put(acc.id, acc);
    }

    // Restore categories
    for (final item in categoryList) {
      final cat = Category(
        id: item['id'] ?? '',
        name: item['name'] ?? '',
        kind: item['kind'] ?? 'expense',
        group: item['group'] ?? 'needs',
        iconKey: item['iconKey'] ?? 'category',
        colorValue: (item['colorValue'] as num?)?.toInt() ?? 0xFF000000,
        parentId: item['parentId'],
        essential: item['essential'] ?? false,
        archived: item['archived'] ?? false,
        sortOrder: (item['sortOrder'] as num?)?.toInt() ?? 0,
      );
      await storage.categoryBox.put(cat.id, cat);
    }

    // Restore rules
    for (final item in ruleList) {
      final rule = CategoryRule(
        id: item['id'] ?? '',
        pattern: item['pattern'] ?? '',
        matchType: item['matchType'] ?? 'contains',
        categoryId: item['categoryId'] ?? '',
        priority: (item['priority'] as num?)?.toInt() ?? 0,
        createdFromCorrection: item['createdFromCorrection'] ?? false,
      );
      await storage.ruleBox.put(rule.id, rule);
    }

    // Restore recurring rules
    for (final item in recurringList) {
      final r = RecurringRule(
        id: item['id'] ?? '',
        name: item['name'] ?? '',
        kind: item['kind'] ?? 'bill',
        amount: (item['amount'] as num?)?.toDouble() ?? 0.0,
        amountIsVariable: item['amountIsVariable'] ?? false,
        categoryId: item['categoryId'],
        accountId: item['accountId'],
        toAccountId: item['toAccountId'],
        frequency: item['frequency'] ?? 'monthly',
        interval: (item['interval'] as num?)?.toInt() ?? 1,
        anchorDate: DateTime.tryParse(item['anchorDate'] ?? ''),
        dayOfMonth: (item['dayOfMonth'] as num?)?.toInt(),
        startDate: DateTime.tryParse(item['startDate'] ?? '') ?? DateTime.now(),
        endDate: DateTime.tryParse(item['endDate'] ?? ''),
        autoPost: item['autoPost'] ?? false,
        reminderDaysBefore: (item['reminderDaysBefore'] as num?)?.toInt() ?? 2,
        status: item['status'] ?? 'active',
        folio: item['folio'],
        notes: item['notes'],
        createdAt: DateTime.tryParse(item['createdAt'] ?? '') ?? DateTime.now(),
      );
      await storage.recurringBox.put(r.id, r);
    }

    // Restore budget lines
    for (final item in budgetLines) {
      final b = BudgetLine(
        id: item['id'] ?? '',
        categoryId: item['categoryId'],
        bucketRef: item['bucketRef'],
        amount: (item['amount'] as num?)?.toDouble() ?? 0.0,
        rollover: item['rollover'] ?? false,
        essential: item['essential'] ?? false,
        startMonth: item['startMonth'] ?? '2026-01',
      );
      await storage.budgetLineBox.put(b.id, b);
    }

    // Restore budget overrides
    for (final item in budgetOverrides) {
      final o = BudgetOverride(
        lineId: item['lineId'] ?? '',
        monthKey: item['monthKey'] ?? '',
        amount: (item['amount'] as num?)?.toDouble() ?? 0.0,
      );
      await storage.budgetOverrideBox.put('${o.lineId}_${o.monthKey}', o);
    }

    // Restore goals
    for (final item in goals) {
      final g = SavingsGoal(
        id: item['id'] ?? '',
        name: item['name'] ?? '',
        kind: item['kind'] ?? 'goal',
        targetAmount: (item['targetAmount'] as num?)?.toDouble() ?? 0.0,
        deadline: DateTime.tryParse(item['deadline'] ?? ''),
        dueDate: DateTime.tryParse(item['dueDate'] ?? ''),
        accountId: item['accountId'],
        colorValue: (item['colorValue'] as num?)?.toInt() ?? 0xFF000000,
        priority: (item['priority'] as num?)?.toInt() ?? 1,
        autoContribute: item['autoContribute'] ?? false,
        plannedMonthly: (item['plannedMonthly'] as num?)?.toDouble(),
        linkedCategoryId: item['linkedCategoryId'],
        archived: item['archived'] ?? false,
      );
      await storage.goalBox.put(g.id, g);
    }

    // Restore goal entries
    for (final item in goalEntries) {
      final e = GoalEntry(
        id: item['id'] ?? '',
        goalId: item['goalId'] ?? '',
        date: DateTime.tryParse(item['date'] ?? '') ?? DateTime.now(),
        amount: (item['amount'] as num?)?.toDouble() ?? 0.0,
        note: item['note'],
        sourceRef: item['sourceRef'],
      );
      await storage.goalEntryBox.put(e.id, e);
    }

    // Restore valuations
    for (final item in valuations) {
      final v = Valuation(
        id: item['id'] ?? '',
        accountId: item['accountId'] ?? '',
        date: DateTime.tryParse(item['date'] ?? '') ?? DateTime.now(),
        value: (item['value'] as num?)?.toDouble() ?? 0.0,
        units: (item['units'] as num?)?.toDouble(),
        unitPrice: (item['unitPrice'] as num?)?.toDouble(),
      );
      await storage.valuationBox.put(v.id, v);
    }

    // Restore split groups
    for (final item in splitGroups) {
      final g = SplitGroup(
        id: item['id'] ?? '',
        name: item['name'] ?? '',
        kind: item['kind'] ?? 'trip',
        members:
            (item['members'] as List?)?.map((e) => e.toString()).toList() ?? [],
        createdAt: DateTime.tryParse(item['createdAt'] ?? '') ?? DateTime.now(),
      );
      await storage.splitGroupBox.put(g.id, g);
    }

    // Restore split entries
    for (final item in splitEntries) {
      final e = SplitEntry(
        id: item['id'] ?? '',
        groupId: item['groupId'] ?? '',
        date: DateTime.tryParse(item['date'] ?? '') ?? DateTime.now(),
        title: item['title'] ?? '',
        amount: (item['amount'] as num?)?.toDouble() ?? 0.0,
        paidBy: item['paidBy'] ?? '',
        shares: (item['shares'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
            ) ??
            {},
        txId: item['txId'],
        settled: item['settled'] ?? false,
      );
      await storage.splitEntryBox.put(e.id, e);
    }

    // Restore settings
    final settingsMap = (data['settings'] as Map? ?? {});
    for (final entry in settingsMap.entries) {
      await storage.settingsBox.put(entry.key, entry.value);
    }

    // Restore global settings (global_xp, rem_*)
    final globalSettingsMap = (data['globalSettings'] as Map? ?? {});
    if (globalSettingsMap.isNotEmpty && Hive.isBoxOpen('settings')) {
      final globalBox = Hive.box('settings');
      for (final entry in globalSettingsMap.entries) {
        await globalBox.put(entry.key, entry.value);
      }
    }

    // Restore xp_history
    final xpHistoryMap = (data['xpHistory'] as Map? ?? {});
    if (xpHistoryMap.isNotEmpty && Hive.isBoxOpen('xp_history')) {
      final xpBox = Hive.box('xp_history');
      for (final entry in xpHistoryMap.entries) {
        await xpBox.put(entry.key, entry.value);
      }
    }

    return summary;
  }

  static Future<void> _pruneBackups(Directory backupDir) async {
    try {
      final files = await backupDir
          .list()
          .where((f) => f is File && f.path.endsWith('.json'))
          .cast<File>()
          .toList();

      if (files.length > 5) {
        files.sort(
            (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
        final toDelete = files.take(files.length - 5);
        for (final file in toDelete) {
          await file.delete();
        }
      }
    } catch (_) {}
  }
}
