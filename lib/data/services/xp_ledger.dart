import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/models/xp_ledger_entry.dart';
import 'package:habit_tracker/data/services/global_xp_service.dart';

class XpLedger {
  static const String boxName = 'xp_ledger';

  static Box<XpLedgerEntry> get box => Hive.box<XpLedgerEntry>(boxName);

  static void registerAdapter() {
    if (!Hive.isAdapterRegistered(68)) {
      Hive.registerAdapter(XpLedgerEntryAdapter());
    }
  }

  /// Opens the xp_ledger box.
  static Future<Box<XpLedgerEntry>> openBox() async {
    registerAdapter();
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<XpLedgerEntry>(boxName);
    }
    return await Hive.openBox<XpLedgerEntry>(boxName);
  }

  /// Sets an XP amount for a specific rule and day. Applies only the delta `amount - previous`
  /// to the historical date via [GlobalXPService.addXPForDate].
  static Future<int> set(String dayKey, String ruleId, int amount) async {
    final b = await openBox();
    final id = XpLedgerEntry.generateId(dayKey, ruleId);
    final existing = b.get(id);

    final previousAmount = existing?.amount ?? 0;
    final delta = amount - previousAmount;

    if (delta != 0) {
      DateTime date;
      try {
        final parts = dayKey.split('-');
        date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      } catch (_) {
        date = DateTime.now();
      }

      GlobalXPService.addXPForDate(date, delta);
    }

    final entry = XpLedgerEntry(
      id: id,
      dayKey: dayKey,
      ruleId: ruleId,
      amount: amount,
      updatedAt: DateTime.now(),
    );
    await b.put(id, entry);

    return delta;
  }

  /// Gets the currently recorded XP amount for a rule on a day.
  static int get(String dayKey, String ruleId) {
    if (!Hive.isBoxOpen(boxName)) return 0;
    final id = XpLedgerEntry.generateId(dayKey, ruleId);
    return box.get(id)?.amount ?? 0;
  }

  /// Gets all ledger entries for a given dayKey.
  static List<XpLedgerEntry> entriesForDay(String dayKey) {
    if (!Hive.isBoxOpen(boxName)) return [];
    return box.values.where((e) => e.dayKey == dayKey).toList();
  }

  /// Sum of all ledger XP for a day.
  static int totalForDay(String dayKey) {
    if (!Hive.isBoxOpen(boxName)) return 0;
    return entriesForDay(dayKey).fold(0, (sum, e) => sum + e.amount);
  }
}
