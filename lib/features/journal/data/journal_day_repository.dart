import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker/data/models/productivity_models.dart';
import 'package:habit_tracker/data/services/journal_service.dart';

class AutoLogEvent {
  final String key;
  final String kind; // 'wake', 'sleep', 'workout', 'steps', 'energy', 'note'
  final String text;
  final DateTime timestamp;
  final String source;
  final Map<String, dynamic> params;

  AutoLogEvent({
    required this.key,
    required this.kind,
    required this.text,
    DateTime? timestamp,
    this.source = 'manual',
    this.params = const {},
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'key': key,
        'kind': kind,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'source': source,
        'params': params,
      };

  factory AutoLogEvent.fromJson(Map<String, dynamic> json) => AutoLogEvent(
        key: json['key'] as String? ?? 'event',
        kind: json['kind'] as String? ?? 'note',
        text: json['text'] as String? ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'])
            : null,
        source: json['source'] as String? ?? 'manual',
        params: (json['params'] as Map?)?.cast<String, dynamic>() ?? {},
      );
}

class JournalDayRepository {
  static final JournalDayRepository instance = JournalDayRepository._();
  JournalDayRepository._();
  factory JournalDayRepository() => instance;

  final JournalService _service = JournalService.instance;

  /// Retrieves or creates the single Day Journal document for [dayKey] (yyyy-MM-dd).
  Future<JournalEntry> getOrCreateDay(String dayKey) async {
    final box = await _service.openEncryptedBox();
    final dayDocId = 'day_$dayKey';
    var entry = box.get(dayDocId);

    if (entry == null) {
      DateTime date;
      try {
        final parts = dayKey.split('-');
        date = DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      } catch (_) {
        date = DateTime.now();
      }

      final formattedTitle = DateFormat('EEEE, d MMM yyyy').format(date);
      final emptyQuillDelta = jsonEncode([
        {'insert': '\n'}
      ]);

      entry = JournalEntry(
        id: dayDocId,
        title: formattedTitle,
        bodyDelta: emptyQuillDelta,
        createdAt: date,
        updatedAt: DateTime.now(),
        dayKey: dayKey,
        autoLogJson: '[]',
      );
      await box.put(dayDocId, entry);
    }
    return entry;
  }

  /// Appends or updates an auto-log line for the day.
  /// If the encrypted box cannot be opened immediately, falls back to `journal_inbox` in settings.
  Future<void> appendAutoLog(String dayKey, AutoLogEvent event) async {
    try {
      final entry = await getOrCreateDay(dayKey);
      final events = getAutoLogs(entry);

      // Upsert by key
      final index = events.indexWhere((e) => e.key == event.key);
      if (index >= 0) {
        events[index] = event;
      } else {
        events.add(event);
      }

      entry.autoLogJson = jsonEncode(events.map((e) => e.toJson()).toList());
      entry.updatedAt = DateTime.now();
      await entry.save();

      // Flush any pending inbox items
      await flushInbox();
    } catch (e) {
      debugPrint('Failed to write auto-log to journal: $e, queuing in inbox');
      _queueInInbox(dayKey, event);
    }
  }

  /// Removes an auto-log item by its key.
  Future<void> removeAutoLog(String dayKey, String eventKey) async {
    try {
      final entry = await getOrCreateDay(dayKey);
      final events = getAutoLogs(entry);
      events.removeWhere((e) => e.key == eventKey);
      entry.autoLogJson = jsonEncode(events.map((e) => e.toJson()).toList());
      entry.updatedAt = DateTime.now();
      await entry.save();
    } catch (e) {
      debugPrint('Error removing auto-log: $e');
    }
  }

  /// Decodes auto-log events from a journal entry.
  List<AutoLogEvent> getAutoLogs(JournalEntry entry) {
    if (entry.autoLogJson == null || entry.autoLogJson!.isEmpty) return [];
    try {
      final raw = jsonDecode(entry.autoLogJson!);
      if (raw is List) {
        return raw
            .map((item) =>
                AutoLogEvent.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (e) {
      debugPrint('Error decoding autoLogJson: $e');
    }
    return [];
  }

  /// Returns legacy entries for a day (entries not starting with 'day_' and not merged).
  List<JournalEntry> legacyEntriesFor(String dayKey) {
    final entries = _service.getEntries();
    return entries.where((e) {
      final k = e.dayKey ?? DateFormat('yyyy-MM-dd').format(e.createdAt);
      return k == dayKey && !e.id.startsWith('day_') && e.mergedInto == null;
    }).toList();
  }

  /// Merges all legacy entries for a day into the primary day document.
  Future<void> mergeLegacyEntries(String dayKey) async {
    final dayDoc = await getOrCreateDay(dayKey);
    final leg = legacyEntriesFor(dayKey);
    if (leg.isEmpty) return;

    List<dynamic> mainDelta = [];
    try {
      mainDelta = List<dynamic>.from(jsonDecode(dayDoc.bodyDelta));
    } catch (_) {
      mainDelta = [
        {'insert': '\n'}
      ];
    }

    for (final l in leg) {
      final timeStr = DateFormat('h:mm a').format(l.createdAt);
      mainDelta.add({
        'insert': '\n\n--- ${l.title} ($timeStr) ---\n',
        'attributes': {'bold': true}
      });
      try {
        final lDelta = jsonDecode(l.bodyDelta);
        if (lDelta is List) {
          mainDelta.addAll(lDelta);
        } else {
          mainDelta.add({'insert': '${l.bodyDelta}\n'});
        }
      } catch (_) {
        mainDelta.add({'insert': '${l.bodyDelta}\n'});
      }
      l.mergedInto = dayDoc.id;
      await l.save();
    }

    dayDoc.bodyDelta = jsonEncode(mainDelta);
    dayDoc.updatedAt = DateTime.now();
    await dayDoc.save();
  }

  /// Undoes a previous merge for that day.
  Future<void> undoMergeLegacyEntries(String dayKey) async {
    final entries = _service.getEntries();
    final dayDocId = 'day_$dayKey';
    for (final e in entries) {
      if (e.mergedInto == dayDocId) {
        e.mergedInto = null;
        await e.save();
      }
    }
  }

  /// Ensures all existing legacy entries have a valid dayKey set based on their createdAt.
  Future<void> migrateDayKeysIfNeeded() async {
    final entries = _service.getEntries();
    for (final e in entries) {
      if (e.dayKey == null || e.dayKey!.isEmpty) {
        e.dayKey = DateFormat('yyyy-MM-dd').format(e.createdAt);
        await e.save();
      }
    }
  }

  /// Appends a plaintext note snippet into the Day's Quill delta and registers an auto-log entry.
  Future<void> appendNote(String dayKey, String note, {DateTime? time}) async {
    final entry = await getOrCreateDay(dayKey);
    final now = time ?? DateTime.now();
    final timeStr = DateFormat('h:mm a').format(now);

    List<dynamic> ops = [];
    try {
      ops = List<dynamic>.from(jsonDecode(entry.bodyDelta));
    } catch (_) {
      ops = [
        {'insert': '\n'}
      ];
    }

    ops.add({'insert': '\n• [$timeStr] $note\n'});
    entry.bodyDelta = jsonEncode(ops);
    entry.updatedAt = DateTime.now();
    await entry.save();

    await appendAutoLog(
      dayKey,
      AutoLogEvent(
        key: 'note_${now.millisecondsSinceEpoch}',
        kind: 'note',
        text: note,
        timestamp: now,
        source: 'chat',
      ),
    );
  }

  void _queueInInbox(String dayKey, AutoLogEvent event) {
    if (!Hive.isBoxOpen('settings')) return;
    final settings = Hive.box('settings');
    final inbox = List<Map<String, dynamic>>.from(
        settings.get('journal_inbox', defaultValue: []));
    inbox.add({
      'dayKey': dayKey,
      'event': event.toJson(),
    });
    settings.put('journal_inbox', inbox);
  }

  Future<void> flushInbox() async {
    if (!Hive.isBoxOpen('settings')) return;
    final settings = Hive.box('settings');
    final rawInbox = settings.get('journal_inbox');
    if (rawInbox == null || (rawInbox is List && rawInbox.isEmpty)) return;

    final inbox = List<Map<String, dynamic>>.from(rawInbox);
    settings.put('journal_inbox', []);

    for (final item in inbox) {
      final dayKey = item['dayKey'] as String;
      final eventMap = Map<String, dynamic>.from(item['event'] as Map);
      final event = AutoLogEvent.fromJson(eventMap);
      await appendAutoLog(dayKey, event);
    }
  }
}
