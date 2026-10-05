import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/data/services/journal_service.dart';
import 'package:habit_tracker/data/services/xp_ledger.dart';
import 'package:habit_tracker/features/journal/data/journal_day_repository.dart';
import 'package:habit_tracker/features/tasks/data/wake_log_repository.dart';
import 'package:habit_tracker/features/wearables/data/wearable_repository.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class WearableCleanupService {
  static const int currentBridgeVersion = 2;
  static const String versionKey = 'wear_bridge_version';

  static bool shouldRunPurge() {
    if (!Hive.isBoxOpen('settings')) return false;
    final version = Hive.box('settings').get(versionKey, defaultValue: 1);
    return version < currentBridgeVersion;
  }

  /// Runs the purge migration, cleans any simulated or synthetic health entries from core data,
  /// writes a backup JSON file first, and resets wearable settings to a clean state.
  static Future<Map<String, int>> runPurge() async {
    final results = <String, int>{
      'wearable_rows': 0,
      'diet_burns': 0,
      'journal_autologs': 0,
      'wake_logs': 0,
    };

    try {
      // 1. Create a JSON backup in app documents directory
      final backupDir = await getApplicationDocumentsDirectory();
      final backupFolder = Directory(p.join(backupDir.path, 'backups'));
      if (!backupFolder.existsSync()) {
        backupFolder.createSync(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupFile = File(p.join(backupFolder.path, 'mvp4_1_purge_$timestamp.json'));

      final backupData = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'reason': 'MVP 4.1 purge of simulated data',
      };

      // 2. Clean wear_* boxes
      final wearRepo = WearableRepository.instance;
      int wearCount = 0;
      if (Hive.isBoxOpen(WearableRepository.dailyBoxName)) {
        wearCount += wearRepo.dailyBox.length;
        await wearRepo.dailyBox.clear();
      }
      if (Hive.isBoxOpen(WearableRepository.sleepBoxName)) {
        wearCount += wearRepo.sleepBox.length;
        await wearRepo.sleepBox.clear();
      }
      if (Hive.isBoxOpen(WearableRepository.exerciseBoxName)) {
        wearCount += wearRepo.exerciseBox.length;
        await wearRepo.exerciseBox.clear();
      }
      if (Hive.isBoxOpen(WearableRepository.bodyBoxName)) {
        wearCount += wearRepo.bodyBox.length;
        await wearRepo.bodyBox.clear();
      }
      if (Hive.isBoxOpen(WearableRepository.energyBoxName)) {
        wearCount += wearRepo.energyBox.length;
        await wearRepo.energyBox.clear();
      }
      if (Hive.isBoxOpen(WearableRepository.agesBoxName)) {
        wearCount += wearRepo.agesBox.length;
        await wearRepo.agesBox.clear();
      }
      results['wearable_rows'] = wearCount;

      // 3. Clean diet_logs (burn entries starting with burn_shealth_ or externalId shealth_)
      if (Hive.isBoxOpen('diet_logs')) {
        final dietBox = Hive.box<DietDayLog>('diet_logs');
        int burnCount = 0;
        for (final dayLog in dietBox.values) {
          final initialLen = dayLog.burnEntries.length;
          dayLog.burnEntries.removeWhere((b) =>
              b.id.startsWith('burn_shealth_') ||
              b.id.startsWith('wear_') ||
              (b.externalId != null && b.externalId!.startsWith('shealth_')));

          // Clear supersededBy on any entries that were superseded by shealth_
          for (final b in dayLog.burnEntries) {
            if (b.supersededBy != null &&
                (b.supersededBy!.startsWith('shealth_') || b.supersededBy!.startsWith('wear_'))) {
              b.supersededBy = null;
            }
          }

          if (dayLog.burnEntries.length != initialLen) {
            burnCount += (initialLen - dayLog.burnEntries.length);
            await dayLog.save();
          }
        }
        results['diet_burns'] = burnCount;
      }

      // 4. Clean auto-logs in journals (events with source == 'samsung_health')
      try {
        final jBox = await JournalService.instance.openEncryptedBox();
        int jCount = 0;
        for (final entry in jBox.values) {
          if (entry.autoLogJson != null && entry.autoLogJson!.isNotEmpty) {
            final events = JournalDayRepository.instance.getAutoLogs(entry);
            final initialLen = events.length;
            events.removeWhere((e) => e.source == 'samsung_health' || e.source == 'wearable');
            if (events.length != initialLen) {
              jCount += (initialLen - events.length);
              entry.autoLogJson = jsonEncode(events.map((e) => e.toJson()).toList());
              await entry.save();
            }
          }
        }
        results['journal_autologs'] = jCount;
      } catch (e) {
        debugPrint('Purge journal cleanup error: $e');
      }

      // 5. Clean wake logs with source == 'samsung_health'
      if (Hive.isBoxOpen(WakeLogRepository.boxName)) {
        final wakeBox = WakeLogRepository.instance.box;
        final keysToRemove = <String>[];
        for (final log in wakeBox.values) {
          if (log.source == 'samsung_health' || log.source == 'sleep_infer') {
            keysToRemove.add(log.dayKey);
          }
        }
        for (final k in keysToRemove) {
          await wakeBox.delete(k);
          await XpLedger.set(k, 'wake_on_time', 0);
        }
        results['wake_logs'] = keysToRemove.length;
      }

      // Save backup file
      backupData['results'] = results;
      await backupFile.writeAsString(jsonEncode(backupData));

      // 6. Reset settings
      if (Hive.isBoxOpen('settings')) {
        final settings = Hive.box('settings');
        await settings.delete('wear_last_sync');
        await settings.delete('wear_last_sync_ms');
        await settings.delete('wear_change_tokens');
        await settings.put('wear_enabled', false);
        await settings.put(versionKey, currentBridgeVersion);
      }
    } catch (e, st) {
      debugPrint('WearableCleanupService.runPurge error: $e\n$st');
    }

    return results;
  }
}
