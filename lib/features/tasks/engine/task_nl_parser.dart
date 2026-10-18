import 'package:habit_tracker/features/tasks/models/task_os_models.dart';

enum ChipType {
  date,
  time,
  duration,
  priority,
  course,
  tag,
  recurrence,
  reminder,
}

class ParsedChip {
  final String id;
  final ChipType type;
  final String label;
  final String rawToken;
  final dynamic value;

  const ParsedChip({
    required this.id,
    required this.type,
    required this.label,
    required this.rawToken,
    required this.value,
  });

  @override
  String toString() => 'ParsedChip($type, label: $label, token: $rawToken)';
}

class ParsedTaskInput {
  final String rawInput;
  final String cleanTitle;
  final DateTime? dueAt;
  final bool hasDueTime;
  final int priority;
  final String? courseCode;
  final List<String> tags;
  final int estimateMin;
  final String? recurrenceRule;
  final String recurrenceMode;
  final List<int> reminderOffsetsMin;
  final List<ParsedChip> chips;

  const ParsedTaskInput({
    required this.rawInput,
    required this.cleanTitle,
    this.dueAt,
    this.hasDueTime = false,
    this.priority = TaskPriority.low,
    this.courseCode,
    this.tags = const [],
    this.estimateMin = 30,
    this.recurrenceRule,
    this.recurrenceMode = 'fixed',
    this.reminderOffsetsMin = const [],
    this.chips = const [],
  });

  TaskItem toTaskItem({
    required String id,
    String? notes,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    return TaskItem(
      id: id,
      title: cleanTitle.isEmpty ? rawInput : cleanTitle,
      notes: notes,
      status: TaskStatus.todo,
      priority: priority,
      dueAt: dueAt,
      hasDueTime: hasDueTime,
      courseId: courseCode,
      tags: tags,
      estimateMin: estimateMin,
      recurrenceRule: recurrenceRule,
      recurrenceMode: recurrenceMode,
      reminderOffsetsMin: reminderOffsetsMin,
      createdAt: current,
      updatedAt: current,
    );
  }
}

/// Natural Language Parser for live task capture (CAP-2)
ParsedTaskInput parseNaturalLanguageTask(String rawInput, DateTime now) {
  if (rawInput.trim().isEmpty) {
    return ParsedTaskInput(
      rawInput: rawInput,
      cleanTitle: '',
      priority: TaskPriority.low,
    );
  }

  String workingText = rawInput;
  final List<ParsedChip> chips = [];

  DateTime? parsedDate;
  int? parsedHour;
  int? parsedMinute;
  bool hasExplicitTime = false;
  int priority = TaskPriority.low;
  String? courseCode;
  final List<String> tags = [];
  int estimateMin = 30;
  String? recurrenceRule;
  String recurrenceMode = 'fixed';
  final List<int> reminderOffsets = [];

  // Helper to remove matched token from workingText
  void stripToken(String token) {
    // Replace only whole word or token boundary
    final escaped = RegExp.escape(token);
    workingText = workingText
        .replaceAll(RegExp('(?:^|\\s+)$escaped(?:\\s+|\$)', caseSensitive: false), ' ')
        .trim();
  }

  // 1. Parse Duration: ~2h, ~45m, for 45m, est 90min, 1.5h
  final durationRegex = RegExp(
    r'(?:~|for\s+|est\s+)?(\d+(?:\.\d+)?)\s*(h|hr|hrs|hours|m|min|mins|minutes)\b',
    caseSensitive: false,
  );
  final durMatch = durationRegex.firstMatch(workingText);
  if (durMatch != null) {
    final val = double.tryParse(durMatch.group(1)!) ?? 0.5;
    final unit = durMatch.group(2)!.toLowerCase();
    if (unit.startsWith('h')) {
      estimateMin = (val * 60).round();
    } else {
      estimateMin = val.round();
    }
    final rawToken = durMatch.group(0)!;
    chips.add(ParsedChip(
      id: 'duration',
      type: ChipType.duration,
      label: '${estimateMin}m est',
      rawToken: rawToken,
      value: estimateMin,
    ));
    stripToken(rawToken);
  }

  // 2. Parse Priority: !1..!4, !urgent, !high, !med, !low
  final priorityRegex = RegExp(
    r'!(urgent|high|med|medium|low|[1-4])\b',
    caseSensitive: false,
  );
  final priMatch = priorityRegex.firstMatch(workingText);
  if (priMatch != null) {
    final rawToken = priMatch.group(0)!;
    final pVal = priMatch.group(1)!.toLowerCase();
    if (pVal == '1' || pVal == 'urgent') {
      priority = TaskPriority.urgent;
    } else if (pVal == '2' || pVal == 'high') {
      priority = TaskPriority.high;
    } else if (pVal == '3' || pVal == 'med' || pVal == 'medium') {
      priority = TaskPriority.medium;
    } else {
      priority = TaskPriority.low;
    }
    chips.add(ParsedChip(
      id: 'priority',
      type: ChipType.priority,
      label: '!${TaskPriority.label(priority)}',
      rawToken: rawToken,
      value: priority,
    ));
    stripToken(rawToken);
  }

  // 3. Parse Course / Project: #([A-Za-z0-9_-]+)
  final courseRegex = RegExp(r'#([A-Za-z0-9_-]+)');
  final courseMatch = courseRegex.firstMatch(workingText);
  if (courseMatch != null) {
    final rawToken = courseMatch.group(0)!;
    courseCode = courseMatch.group(1)!;
    chips.add(ParsedChip(
      id: 'course',
      type: ChipType.course,
      label: '#$courseCode',
      rawToken: rawToken,
      value: courseCode,
    ));
    stripToken(rawToken);
  }

  // 4. Parse Tags: @([A-Za-z0-9_-]+)
  final tagRegex = RegExp(r'@([A-Za-z0-9_-]+)');
  final allTagMatches = tagRegex.allMatches(workingText).toList();
  for (var m in allTagMatches) {
    final rawToken = m.group(0)!;
    final tag = m.group(1)!;
    tags.add(tag);
    chips.add(ParsedChip(
      id: 'tag_$tag',
      type: ChipType.tag,
      label: '@$tag',
      rawToken: rawToken,
      value: tag,
    ));
    stripToken(rawToken);
  }

  // 5. Parse Reminders: remind 1d before, remind 30m before, remind 2h before
  final reminderRegex = RegExp(
    r'\bremind\s+(\d+)\s*(d|day|days|h|hr|hours|m|min|mins)\s+before\b',
    caseSensitive: false,
  );
  final remMatch = reminderRegex.firstMatch(workingText);
  if (remMatch != null) {
    final rawToken = remMatch.group(0)!;
    final val = int.tryParse(remMatch.group(1)!) ?? 10;
    final unit = remMatch.group(2)!.toLowerCase();
    int offsetMin = val;
    if (unit.startsWith('d')) {
      offsetMin = val * 1440;
    } else if (unit.startsWith('h')) {
      offsetMin = val * 60;
    }
    reminderOffsets.add(offsetMin);
    chips.add(ParsedChip(
      id: 'reminder',
      type: ChipType.reminder,
      label: 'Remind ${remMatch.group(1)}${unit[0]} before',
      rawToken: rawToken,
      value: offsetMin,
    ));
    stripToken(rawToken);
  }

  // 6. Parse Recurrence: daily, every weekday, every mon..sun, every X weeks, after completion
  final recurrenceRegex = RegExp(
    r'\b(daily|every\s+weekday|every\s+(?:mon|tue|wed|thu|fri|sat|sun)(?:day)?|every\s+\d+\s+weeks?|after\s+completion)\b',
    caseSensitive: false,
  );
  final recMatch = recurrenceRegex.firstMatch(workingText);
  if (recMatch != null) {
    final rawToken = recMatch.group(0)!;
    final lower = rawToken.toLowerCase();
    if (lower == 'after completion') {
      recurrenceMode = 'afterCompletion';
      recurrenceRule = 'FREQ=DAILY';
    } else if (lower == 'daily') {
      recurrenceRule = 'FREQ=DAILY';
    } else if (lower.contains('weekday')) {
      recurrenceRule = 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR';
    } else if (lower.startsWith('every ')) {
      final dayPart = lower.replaceFirst('every ', '').trim();
      final dayMap = {
        'mon': 'MO', 'monday': 'MO',
        'tue': 'TU', 'tuesday': 'TU',
        'wed': 'WE', 'wednesday': 'WE',
        'thu': 'TH', 'thursday': 'TH',
        'fri': 'FR', 'friday': 'FR',
        'sat': 'SA', 'saturday': 'SA',
        'sun': 'SU', 'sunday': 'SU',
      };
      if (dayMap.containsKey(dayPart)) {
        recurrenceRule = 'FREQ=WEEKLY;BYDAY=${dayMap[dayPart]}';
      } else {
        recurrenceRule = 'FREQ=WEEKLY';
      }
    }
    chips.add(ParsedChip(
      id: 'recurrence',
      type: ChipType.recurrence,
      label: rawToken,
      rawToken: rawToken,
      value: recurrenceRule,
    ));
    stripToken(rawToken);
  }

  // 7. Parse Explicit Times: 5pm, 5:30pm, 17:30, noon, midnight
  final timeRegex = RegExp(
    r'\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b|\b([01]?\d|2[0-3]):([0-5]\d)\b|\b(noon|midnight)\b',
    caseSensitive: false,
  );
  final timeMatch = timeRegex.firstMatch(workingText);
  if (timeMatch != null) {
    hasExplicitTime = true;
    final rawToken = timeMatch.group(0)!;
    if (timeMatch.group(6) != null) {
      // noon or midnight
      final word = timeMatch.group(6)!.toLowerCase();
      parsedHour = word == 'noon' ? 12 : 0;
      parsedMinute = 0;
    } else if (timeMatch.group(3) != null) {
      // 12-hour format e.g. 5pm, 5:30pm
      int h = int.parse(timeMatch.group(1)!);
      int m = timeMatch.group(2) != null ? int.parse(timeMatch.group(2)!) : 0;
      final ampm = timeMatch.group(3)!.toLowerCase();
      if (ampm == 'pm' && h < 12) h += 12;
      if (ampm == 'am' && h == 12) h = 0;
      parsedHour = h;
      parsedMinute = m;
    } else if (timeMatch.group(4) != null) {
      // 24-hour format e.g. 17:30
      parsedHour = int.parse(timeMatch.group(4)!);
      parsedMinute = int.parse(timeMatch.group(5)!);
    }

    final formattedMin = (parsedMinute ?? 0).toString().padLeft(2, '0');
    final formattedTime = '${(parsedHour ?? 0).toString().padLeft(2, '0')}:$formattedMin';
    chips.add(ParsedChip(
      id: 'time',
      type: ChipType.time,
      label: formattedTime,
      rawToken: rawToken,
      value: formattedTime,
    ));
    stripToken(rawToken);
  }

  // 8. Parse Dates: today, tmr, tomorrow, mon..sun, next mon..next sun, in X days, end of month, 25 oct
  final dateRegex = RegExp(
    r'\b(today|tomorrow|tmr|in\s+\d+\s+days?|end\s+of\s+month|next\s+(?:mon|tue|wed|thu|fri|sat|sun)(?:day)?|(?:mon|tue|wed|thu|fri|sat|sun)(?:day)?|(?:\d{1,2})(?:st|nd|rd|th)?\s+(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*)\b',
    caseSensitive: false,
  );
  final dateMatch = dateRegex.firstMatch(workingText);
  if (dateMatch != null) {
    final rawToken = dateMatch.group(0)!;
    final lower = rawToken.toLowerCase();

    if (lower == 'today') {
      parsedDate = DateTime(now.year, now.month, now.day);
    } else if (lower == 'tomorrow' || lower == 'tmr') {
      parsedDate = DateTime(now.year, now.month, now.day + 1);
    } else if (lower.startsWith('in ') && lower.contains('day')) {
      final days = int.tryParse(RegExp(r'\d+').firstMatch(lower)?.group(0) ?? '1') ?? 1;
      parsedDate = DateTime(now.year, now.month, now.day + days);
    } else if (lower == 'end of month') {
      parsedDate = DateTime(now.year, now.month + 1, 0); // Last day of month
    } else if (lower.startsWith('next ')) {
      final dayName = lower.replaceFirst('next ', '').trim();
      parsedDate = _resolveNextWeekday(dayName, now, forceNextWeek: true);
    } else if (_isWeekday(lower)) {
      parsedDate = _resolveNextWeekday(lower, now, forceNextWeek: false);
    } else {
      // e.g. 25 oct, 3rd nov
      parsedDate = _parseMonthDay(lower, now);
    }

    if (parsedDate != null) {
      chips.add(ParsedChip(
        id: 'date',
        type: ChipType.date,
        label: _formatDateLabel(parsedDate, now),
        rawToken: rawToken,
        value: parsedDate,
      ));
      stripToken(rawToken);
    }
  }

  // Combine Date & Time if parsed
  DateTime? finalDueAt;
  if (parsedDate != null) {
    finalDueAt = DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
      parsedHour ?? (hasExplicitTime ? 12 : 23),
      parsedMinute ?? (hasExplicitTime ? 0 : 59),
    );
  } else if (hasExplicitTime) {
    // If time was given without date, default to today if time > now, else tomorrow
    final testDate = DateTime(
      now.year,
      now.month,
      now.day,
      parsedHour ?? 12,
      parsedMinute ?? 0,
    );
    finalDueAt = testDate.isAfter(now)
        ? testDate
        : testDate.add(const Duration(days: 1));
  }

  final cleanTitle = workingText.replaceAll(RegExp(r'\s+'), ' ').trim();

  return ParsedTaskInput(
    rawInput: rawInput,
    cleanTitle: cleanTitle,
    dueAt: finalDueAt,
    hasDueTime: hasExplicitTime,
    priority: priority,
    courseCode: courseCode,
    tags: tags,
    estimateMin: estimateMin,
    recurrenceRule: recurrenceRule,
    recurrenceMode: recurrenceMode,
    reminderOffsetsMin: reminderOffsets,
    chips: chips,
  );
}

bool _isWeekday(String text) {
  const days = [
    'mon', 'monday',
    'tue', 'tuesday',
    'wed', 'wednesday',
    'thu', 'thursday',
    'fri', 'friday',
    'sat', 'saturday',
    'sun', 'sunday',
  ];
  return days.contains(text.toLowerCase());
}

DateTime _resolveNextWeekday(String dayName, DateTime now,
    {required bool forceNextWeek}) {
  const dayIndexMap = {
    'mon': DateTime.monday, 'monday': DateTime.monday,
    'tue': DateTime.tuesday, 'tuesday': DateTime.tuesday,
    'wed': DateTime.wednesday, 'wednesday': DateTime.wednesday,
    'thu': DateTime.thursday, 'thursday': DateTime.thursday,
    'fri': DateTime.friday, 'friday': DateTime.friday,
    'sat': DateTime.saturday, 'saturday': DateTime.saturday,
    'sun': DateTime.sunday, 'sunday': DateTime.sunday,
  };

  final targetDay = dayIndexMap[dayName.toLowerCase()] ?? DateTime.friday;
  int diff = targetDay - now.weekday;
  if (diff <= 0) {
    diff += 7;
  }
  if (forceNextWeek && diff < 7) {
    diff += 7;
  }
  return DateTime(now.year, now.month, now.day + diff);
}

DateTime? _parseMonthDay(String text, DateTime now) {
  try {
    final dayNum =
        int.tryParse(RegExp(r'^\d+').firstMatch(text)?.group(0) ?? '');
    if (dayNum == null) return null;

    const months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };

    int? monthNum;
    for (var m in months.entries) {
      if (text.contains(m.key)) {
        monthNum = m.value;
        break;
      }
    }
    if (monthNum == null) return null;

    var targetYear = now.year;
    final candidate = DateTime(targetYear, monthNum, dayNum);
    if (candidate.isBefore(DateTime(now.year, now.month, now.day))) {
      targetYear++;
    }
    return DateTime(targetYear, monthNum, dayNum);
  } catch (_) {
    return null;
  }
}

String _formatDateLabel(DateTime date, DateTime now) {
  final d = DateTime(date.year, date.month, date.day);
  final n = DateTime(now.year, now.month, now.day);
  final diff = d.difference(n).inDays;

  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff > 1 && diff < 7) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[date.weekday - 1];
  }
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${date.day} ${m[date.month - 1]}';
}
