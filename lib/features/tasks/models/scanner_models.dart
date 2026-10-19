/// Models for the Context-Aware Digital Scanner & Smart Auto-Router.
enum ScanDocCategory {
  timetable,
  examSchedule,
  syllabus,
  tasks,
  expenses,
}

class ScannedExtractItem {
  final String id;
  String title;
  String subtitle;
  String targetModule; // 'timetable' | 'course' | 'task' | 'habit' | 'finance'
  final String? matchedContextTag;
  final bool isRelevant;
  bool isSelected;
  String? dateStr; // YYYY-MM-DD
  String? timeStr; // e.g. "09:00 AM"
  String? venue;
  String? code; // course code e.g. "CS301"
  String? slot; // e.g. "Slot A"
  int? credits;
  double? amount;
  String? category;
  int? dayOfWeek; // 1 = Mon .. 7 = Sun
  int? startMinutes; // minutes from midnight e.g. 540 = 9:00 AM
  int? durationMinutes; // e.g. 50 or 60
  final Map<String, dynamic> structuredPayload;

  ScannedExtractItem({
    required this.id,
    required this.title,
    this.subtitle = '',
    required this.targetModule,
    this.matchedContextTag,
    required this.isRelevant,
    required this.isSelected,
    this.dateStr,
    this.timeStr,
    this.venue,
    this.code,
    this.slot,
    this.credits,
    this.amount,
    this.category,
    this.dayOfWeek,
    this.startMinutes,
    this.durationMinutes,
    this.structuredPayload = const {},
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'targetModule': targetModule,
        'matchedContextTag': matchedContextTag,
        'isRelevant': isRelevant,
        'isSelected': isSelected,
        'dateStr': dateStr,
        'timeStr': timeStr,
        'venue': venue,
        'code': code,
        'slot': slot,
        'credits': credits,
        'amount': amount,
        'category': category,
        'dayOfWeek': dayOfWeek,
        'startMinutes': startMinutes,
        'durationMinutes': durationMinutes,
        'structuredPayload': structuredPayload,
      };

  factory ScannedExtractItem.fromMap(Map<String, dynamic> map) {
    return ScannedExtractItem(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      subtitle: map['subtitle']?.toString() ?? '',
      targetModule: map['targetModule']?.toString() ?? 'task',
      matchedContextTag: map['matchedContextTag']?.toString(),
      isRelevant: map['isRelevant'] == true,
      isSelected: map['isSelected'] == true,
      dateStr: map['dateStr']?.toString(),
      timeStr: map['timeStr']?.toString(),
      venue: map['venue']?.toString(),
      code: map['code']?.toString(),
      slot: map['slot']?.toString(),
      credits: map['credits'] is num ? (map['credits'] as num).toInt() : null,
      amount: map['amount'] is num ? (map['amount'] as num).toDouble() : null,
      category: map['category']?.toString(),
      dayOfWeek:
          map['dayOfWeek'] is num ? (map['dayOfWeek'] as num).toInt() : null,
      startMinutes: map['startMinutes'] is num
          ? (map['startMinutes'] as num).toInt()
          : null,
      durationMinutes: map['durationMinutes'] is num
          ? (map['durationMinutes'] as num).toInt()
          : null,
      structuredPayload: map['structuredPayload'] is Map
          ? Map<String, dynamic>.from(map['structuredPayload'])
          : {},
    );
  }
}

class ScannedDocumentResult {
  final ScanDocCategory detectedCategory;
  final String detectedDestination;
  final List<ScannedExtractItem> items;
  final String rawExtractedText;

  const ScannedDocumentResult({
    required this.detectedCategory,
    required this.detectedDestination,
    required this.items,
    this.rawExtractedText = '',
  });

  int get selectedCount => items.where((i) => i.isSelected).length;
  int get relevantCount => items.where((i) => i.isRelevant).length;
}
