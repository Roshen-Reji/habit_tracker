import 'package:intl/intl.dart';

class WakeParseResult {
  final DateTime? wakeAt;
  final double confidence;
  final bool needsClarification;
  final String? question;
  final String? error;

  WakeParseResult({
    this.wakeAt,
    this.confidence = 0.0,
    this.needsClarification = false,
    this.question,
    this.error,
  });

  bool get isSuccess => wakeAt != null && !needsClarification && error == null;
}

class WakeLogDraft {
  final DateTime wakeAt;
  WakeLogDraft({required this.wakeAt});
}

class WakeTaskDraft {
  final int targetMinutes;
  final String title;
  WakeTaskDraft({required this.targetMinutes, required this.title});
}

class WakeParser {
  /// Parses a natural language wake-up message.
  static WakeParseResult parse(String text, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final lower = text.trim().toLowerCase();

    // Rejection of "tomorrow"
    if (lower.contains('tomorrow') ||
        lower.contains('kal subah') && lower.contains('uthoonga')) {
      return WakeParseResult(
        error: "You cannot log a wake-up time for tomorrow.",
      );
    }

    // Relative: "just woke up", "i'm up", "just got up", "abhi utha"
    if (lower == 'just woke up' ||
        lower == "i'm up" ||
        lower == 'im up' ||
        lower == 'just got up' ||
        lower == 'i am up' ||
        lower == 'abhi utha' ||
        lower == 'abhi utha hu') {
      return WakeParseResult(wakeAt: clock, confidence: 1.0);
    }

    // Relative offset: "woke up 10 minutes ago", "got up 15 mins ago"
    final offsetMatch =
        RegExp(r'(\d+)\s*(?:minutes?|mins?)\s*ago').firstMatch(lower);
    if (offsetMatch != null) {
      final mins = int.tryParse(offsetMatch.group(1)!) ?? 0;
      return WakeParseResult(
        wakeAt: clock.subtract(Duration(minutes: mins)),
        confidence: 0.95,
      );
    }

    // Check if "yesterday" or "kal" (past) is mentioned
    bool isYesterday = lower.contains('yesterday') || lower.contains('kal');

    // Ambiguity check: "at 12" without am/pm
    final at12Match =
        RegExp(r'(?:at|around|@)\s*12(?!\s*(?:am|pm|:|\d))').firstMatch(lower);
    if (at12Match != null &&
        !lower.contains('12 am') &&
        !lower.contains('12 pm') &&
        !lower.contains('12:')) {
      return WakeParseResult(
        needsClarification: true,
        question: "Did you wake up at 12:00 AM (midnight) or 12:00 PM (noon)?",
      );
    }

    // Explicit 24h format: "16:00", "04:30"
    final time24Match =
        RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)\b').firstMatch(lower);
    if (time24Match != null && !lower.contains('am') && !lower.contains('pm')) {
      final h = int.parse(time24Match.group(1)!);
      final m = int.parse(time24Match.group(2)!);
      var targetDate =
          isYesterday ? clock.subtract(const Duration(days: 1)) : clock;
      var candidate =
          DateTime(targetDate.year, targetDate.month, targetDate.day, h, m);

      if (candidate.isAfter(clock) && !isYesterday) {
        return WakeParseResult(
          needsClarification: true,
          question:
              "That time is in the future. Did you mean yesterday at ${DateFormat('h:mm a').format(candidate)}?",
        );
      }
      return WakeParseResult(wakeAt: candidate, confidence: 0.95);
    }

    // Standard format with optional am/pm:
    // e.g. "4:30 am", "5 am", "7 pm", "4:30", "at 4", "woke up at 5"
    // Hinglish: "subah 4 baje utha", "4 baje utha", "shaam 5 baje"
    bool hasPm = lower.contains('pm') ||
        lower.contains('evening') ||
        lower.contains('afternoon') ||
        lower.contains('night') ||
        lower.contains('shaam') ||
        lower.contains('raat');

    bool hasAm = lower.contains('am') ||
        lower.contains('morning') ||
        lower.contains('subah');

    final timeMatch = RegExp(
            r'\b(?:at|around|@|baje\s*)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|baje)?\b')
        .firstMatch(lower);
    if (timeMatch != null) {
      int? rawH = int.tryParse(timeMatch.group(1)!);
      int rawM = timeMatch.group(2) != null
          ? (int.tryParse(timeMatch.group(2)!) ?? 0)
          : 0;
      final matchedMeridiem = timeMatch.group(3);

      if (matchedMeridiem == 'pm') hasPm = true;
      if (matchedMeridiem == 'am') hasAm = true;

      if (rawH != null && rawH >= 0 && rawH <= 24) {
        int hour = rawH;
        if (hasPm && hour < 12) hour += 12;
        if (hasAm && hour == 12) hour = 0;
        // Default rule: hours 1-11 mean AM unless explicit PM indicated
        if (!hasPm && !hasAm && hour >= 1 && hour <= 11) {
          hour = rawH; // default AM
        }

        var targetDate =
            isYesterday ? clock.subtract(const Duration(days: 1)) : clock;
        var candidate = DateTime(
            targetDate.year, targetDate.month, targetDate.day, hour, rawM);

        if (candidate.isAfter(clock) && !isYesterday) {
          return WakeParseResult(
            needsClarification: true,
            question: "That time is in the future. Did you mean yesterday?",
          );
        }

        return WakeParseResult(wakeAt: candidate, confidence: 0.9);
      }
    }

    return WakeParseResult(
      error:
          "Could not understand wake-up time. Try saying 'I woke up at 5:00 AM' or 'woke up at 4'.",
    );
  }

  static WakeLogDraft? parseLog(String text) {
    final lower = text.toLowerCase().trim();
    final isLogIntent = lower.contains('woke') ||
        lower.contains('wake up') ||
        lower.contains('wakeup') ||
        lower.contains('uth gaya') ||
        lower.contains('utha') ||
        lower.contains('just up') ||
        lower.contains("i'm up") ||
        lower.contains('abhi utha');
    if (!isLogIntent) return null;

    final res = parse(text);
    if (res.wakeAt != null) {
      return WakeLogDraft(wakeAt: res.wakeAt!);
    }
    return null;
  }

  static WakeTaskDraft? parseTask(String text) {
    final lower = text.toLowerCase().trim();
    final isTaskIntent = lower.contains('create') ||
        lower.contains('set') ||
        lower.contains('make') ||
        lower.contains('add') ||
        lower.contains('new') ||
        lower.contains('goal') ||
        lower.contains('target');
    final isWake = lower.contains('wake') || lower.contains('uthna');
    if (!isTaskIntent || !isWake) return null;

    final match =
        RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b').firstMatch(lower);
    if (match != null) {
      int h = int.parse(match.group(1)!);
      int m = match.group(2) != null ? int.parse(match.group(2)!) : 0;
      final meridiem = match.group(3);
      if (meridiem == 'pm' && h < 12) h += 12;
      if (meridiem == 'am' && h == 12) h = 0;
      final targetMin = h * 60 + m;
      final hStr = h.toString().padLeft(2, '0');
      final mStr = m.toString().padLeft(2, '0');
      return WakeTaskDraft(
        targetMinutes: targetMin,
        title: 'Wake up at $hStr:$mStr',
      );
    }
    return null;
  }
}
