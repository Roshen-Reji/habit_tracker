import 'package:habit_tracker/features/tasks/engine/task_nl_parser.dart';
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';

/// Represents a candidate task extracted from voice brain-dump, OCR, or syllabus text.
class ExtractedTaskCandidate {
  final String title;
  final DateTime? dueAt;
  final bool hasDueTime;
  final String? courseCode;
  final int priority;
  final int? estimateMin;
  final List<String> tags;
  final String? recurrenceRule;
  final double confidence; // 0.65 to 0.98
  final String? sourceSnippet;

  const ExtractedTaskCandidate({
    required this.title,
    this.dueAt,
    this.hasDueTime = false,
    this.courseCode,
    this.priority = TaskPriority.low,
    this.estimateMin,
    this.tags = const [],
    this.recurrenceRule,
    this.confidence = 0.80,
    this.sourceSnippet,
  });

  TaskItem toTaskItem({required String id, DateTime? now}) {
    final current = now ?? DateTime.now();
    return TaskItem(
      id: id,
      title: title,
      status: TaskStatus.todo,
      priority: priority,
      dueAt: dueAt,
      hasDueTime: hasDueTime,
      courseId: courseCode,
      estimateMin: estimateMin ?? 30,
      tags: tags,
      recurrenceRule: recurrenceRule,
      createdAt: current,
      updatedAt: current,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'dueAt': dueAt?.toIso8601String(),
        'hasDueTime': hasDueTime,
        'courseCode': courseCode,
        'priority': priority,
        'estimateMin': estimateMin,
        'tags': tags,
        'recurrenceRule': recurrenceRule,
        'confidence': confidence,
        'sourceSnippet': sourceSnippet,
      };

  factory ExtractedTaskCandidate.fromMap(Map<String, dynamic> map) {
    return ExtractedTaskCandidate(
      title: map['title']?.toString() ?? '',
      dueAt: map['dueAt'] != null
          ? DateTime.tryParse(map['dueAt'].toString())
          : null,
      hasDueTime: map['hasDueTime'] == true,
      courseCode: map['courseCode']?.toString(),
      priority: (map['priority'] as num?)?.toInt() ?? TaskPriority.low,
      estimateMin: (map['estimateMin'] as num?)?.toInt(),
      tags: (map['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      recurrenceRule: map['recurrenceRule']?.toString(),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.80,
      sourceSnippet: map['sourceSnippet']?.toString(),
    );
  }
}

/// Pure Dart on-device AI engine for instantaneous (<50ms) task extraction
/// from spoken voice transcripts, brain-dumps, and syllabus documents.
class NativeTaskAiEngine {
  /// Splits a voice transcript or pasted brain-dump paragraph into individual tasks
  /// and runs deterministic NLP on each segment.
  static List<ExtractedTaskCandidate> extractTasksFromBrainDump(
    String transcript,
    DateTime now,
  ) {
    if (transcript.trim().isEmpty) return [];

    // Step 1: Split by explicit line breaks and bullet numbers first
    final rawLines = transcript.split(RegExp(r'\r?\n+'));
    final segments = <String>[];

    for (final line in rawLines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // Split numbered lists e.g. "1. Do X 2. Do Y"
      final numberedChunks = trimmedLine.split(RegExp(r'(?<=\s|^)\d+[\.\)]\s+'));
      for (final chunk in numberedChunks) {
        final cleanedChunk = chunk.trim();
        if (cleanedChunk.isEmpty) continue;

        // Split on spoken conjunction delimiters ("and then", "after that", "also", ";")
        final subParts = cleanedChunk.split(
          RegExp(
            r'\s*(?:;\s*|\band\s+then\b|\bafter\s+that\b|\balso\b|\bnext\b)\s*',
            caseSensitive: false,
          ),
        );

        for (final sp in subParts) {
          final t = sp.trim();
          if (t.isNotEmpty) {
            // Further split on commas if the clause has action verb / task indicators
            if (t.contains(',') && _hasMultipleActionClauses(t)) {
              final commaParts = t.split(RegExp(r',\s*'));
              segments.addAll(commaParts.where((s) => s.trim().isNotEmpty));
            } else {
              segments.add(t);
            }
          }
        }
      }
    }

    final candidates = <ExtractedTaskCandidate>[];

    for (final seg in segments) {
      final cleaned = seg.trim().replaceAll(RegExp(r'^[-*•]\s*'), '');
      if (cleaned.length < 3) continue;

      final parsed = parseNaturalLanguageTask(cleaned, now);
      final finalTitle = parsed.cleanTitle.isNotEmpty ? parsed.cleanTitle : cleaned;
      if (finalTitle.trim().isEmpty) continue;

      // Compute deterministic confidence score (0.65 to 0.98)
      double score = 0.70;
      if (parsed.dueAt != null) score += 0.12;
      if (parsed.hasDueTime) score += 0.05;
      if (parsed.courseCode != null && parsed.courseCode!.isNotEmpty) score += 0.08;
      if (parsed.priority == TaskPriority.urgent ||
          parsed.priority == TaskPriority.high) {
        score += 0.05;
      }
      if (parsed.tags.isNotEmpty) score += 0.04;
      if (parsed.estimateMin != 30) score += 0.04;
      if (score > 0.98) score = 0.98;
      if (score < 0.65) score = 0.65;

      candidates.add(
        ExtractedTaskCandidate(
          title: finalTitle,
          dueAt: parsed.dueAt,
          hasDueTime: parsed.hasDueTime,
          courseCode: parsed.courseCode,
          priority: parsed.priority,
          estimateMin: parsed.estimateMin,
          tags: parsed.tags,
          recurrenceRule: parsed.recurrenceRule,
          confidence: double.parse(score.toStringAsFixed(2)),
          sourceSnippet: seg,
        ),
      );
    }

    return candidates;
  }

  /// Parses academic syllabus text, OCR output, or markdown tables for assignments,
  /// exams, lab records, project milestones, dates, and course codes.
  static List<ExtractedTaskCandidate> extractTasksFromDocumentText(
    String rawText,
    DateTime now,
  ) {
    if (rawText.trim().isEmpty) return [];

    final lines = rawText.split(RegExp(r'\r?\n+'));
    final candidates = <ExtractedTaskCandidate>[];

    // Global course detection in document header (e.g., CS301, #DBMS, CS 302)
    String? documentCourseCode;
    final docCourseMatch = RegExp(r'\b([A-Z]{2,5}\s?\d{3,4})\b').firstMatch(rawText);
    if (docCourseMatch != null) {
      documentCourseCode = docCourseMatch.group(1)?.replaceAll(' ', '').toUpperCase();
    }

    final academicPattern = RegExp(
      r'\b(assignment|lab|record|quiz|midterm|final|exam|test|project|module|milestone|presentation|homework|viva|submission)\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final isAcademic = academicPattern.hasMatch(trimmed);
      final hasDate = _containsDateToken(trimmed);

      // If line contains academic indicator or clear date assignment
      if (isAcademic || hasDate) {
        // Strip table pipe characters and bullet markers
        final sanitized = trimmed
            .replaceAll(RegExp(r'\|'), ' ')
            .replaceAll(RegExp(r'^[-*•\d\.]+\s*'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        if (sanitized.length < 4) continue;

        final parsed = parseNaturalLanguageTask(sanitized, now);

        // Course code override
        String? lineCourseCode = parsed.courseCode;
        if (lineCourseCode == null || lineCourseCode.isEmpty) {
          final lineCourseMatch =
              RegExp(r'\b([A-Z]{2,5}\s?\d{3,4})\b').firstMatch(sanitized);
          if (lineCourseMatch != null) {
            lineCourseCode =
                lineCourseMatch.group(1)?.replaceAll(' ', '').toUpperCase();
          } else {
            lineCourseCode = documentCourseCode;
          }
        }

        // Determine priority based on academic weight
        int priority = parsed.priority;
        final lower = sanitized.toLowerCase();
        if (lower.contains('final') ||
            lower.contains('midterm') ||
            lower.contains('exam') ||
            lower.contains('project')) {
          priority = TaskPriority.urgent;
        } else if (lower.contains('assignment') ||
            lower.contains('quiz') ||
            lower.contains('submission')) {
          priority = TaskPriority.high;
        }

        // Confidence calculation
        double score = 0.75;
        if (isAcademic) score += 0.10;
        if (hasDate) score += 0.08;
        if (lineCourseCode != null) score += 0.05;
        if (score > 0.98) score = 0.98;

        final title = parsed.cleanTitle.isNotEmpty ? parsed.cleanTitle : sanitized;

        candidates.add(
          ExtractedTaskCandidate(
            title: title,
            dueAt: parsed.dueAt,
            hasDueTime: parsed.hasDueTime,
            courseCode: lineCourseCode,
            priority: priority,
            estimateMin: parsed.estimateMin,
            tags: [
              ...parsed.tags,
              if (isAcademic) 'academic',
            ],
            confidence: double.parse(score.toStringAsFixed(2)),
            sourceSnippet: trimmed,
          ),
        );
      }
    }

    // Fallback: If no structured academic lines found, try splitting as brain dump
    if (candidates.isEmpty) {
      return extractTasksFromBrainDump(rawText, now);
    }

    return candidates;
  }

  static bool _hasMultipleActionClauses(String text) {
    final lower = text.toLowerCase();
    final actionVerbs = [
      'submit',
      'finish',
      'complete',
      'do',
      'read',
      'review',
      'call',
      'buy',
      'prepare',
      'write',
      'revise',
      'watch',
      'study',
    ];
    int count = 0;
    for (final v in actionVerbs) {
      if (lower.contains(v)) count++;
      if (count >= 2) return true;
    }
    return false;
  }

  static bool _containsDateToken(String text) {
    // Matches DD/MM, Oct 24, Nov 12, tomorrow, monday, week 4, etc.
    final dateReg = RegExp(
      r'(\d{1,2}[\/\-\.]\d{1,2}|\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{1,2}\b|\btomorrow\b|\btonight\b|\bfriday\b|\bmonday\b|\btuesday\b|\bwednesday\b|\bthursday\b|\bsaturday\b|\bsunday\b|\bweek\s+\d+\b)',
      caseSensitive: false,
    );
    return dateReg.hasMatch(text);
  }
}
