import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:habit_tracker/core/theme/app_colors.dart';
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';
import 'package:habit_tracker/features/tasks/data/task_os_repository.dart';
import 'package:habit_tracker/features/diet/data/diet_repository.dart';
import 'package:habit_tracker/features/wearables/data/wearable_repository.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

/// The 12 Geometric Mood States matching the Master Spec (AGENTS.md Phase 5.1).
enum UserMoodState {
  excited,   // 1. Soft Pink Circle (◡ ◡ + wide smile)
  joyful,    // 2. Hot Pink 4-Lobed Clover (crinkle eyes + open-top smile)
  grateful,  // 3. Purple Vertical Peanut (serene eyes + gentle smile)
  energized, // 4. Lavender 3-Crown Scalloped Square (winged eyes + compact smile)
  sensitive, // 5. Sky Blue Dome (sad eyes + animated teardrop)
  confused,  // 6. Royal Blue Hexagon (dot pupil + rotating orange spiral)
  bored,     // 7. Forest Green Circle (joined rolling eyes + flat mouth)
  stressed,  // 8. Emerald Rounded Triangle (> < eyes + flat tense mouth)
  angry,     // 9. Red-Orange Rounded Square (glaring flat eyes + straight mouth)
  insecure,  // 10. Orange Circle (horizontal pill band with shifting pupil)
  hurt,      // 11. Amber 3-Wave Scalloped Rect (closed downward eyes + flat mouth)
  guilty,    // 12. Golden Yellow Quarter Wedge (eyes in lower-left glancing sideways)
}

/// Metadata & Palette tokens for the 12 Mood States
extension UserMoodStateExt on UserMoodState {
  String get displayName {
    switch (this) {
      case UserMoodState.excited:
        return 'Excited';
      case UserMoodState.joyful:
        return 'Joyful';
      case UserMoodState.grateful:
        return 'Grateful';
      case UserMoodState.energized:
        return 'Energized';
      case UserMoodState.sensitive:
        return 'Sensitive';
      case UserMoodState.confused:
        return 'Confused';
      case UserMoodState.bored:
        return 'Bored';
      case UserMoodState.stressed:
        return 'Stressed';
      case UserMoodState.angry:
        return 'Angry';
      case UserMoodState.insecure:
        return 'Insecure';
      case UserMoodState.hurt:
        return 'Hurt';
      case UserMoodState.guilty:
        return 'Guilty';
    }
  }

  Color get color {
    switch (this) {
      case UserMoodState.excited:
        return const Color(0xFFF9A8D4); // Soft Pink
      case UserMoodState.joyful:
        return const Color(0xFFF472B6); // Hot Pink
      case UserMoodState.grateful:
        return const Color(0xFF9353D3); // Purple
      case UserMoodState.energized:
        return const Color(0xFFA882DD); // Lavender
      case UserMoodState.sensitive:
        return const Color(0xFF0EA5E9); // Sky Blue
      case UserMoodState.confused:
        return const Color(0xFF1D4ED8); // Royal Blue
      case UserMoodState.bored:
        return const Color(0xFF15803D); // Forest Green
      case UserMoodState.stressed:
        return const Color(0xFF059669); // Emerald Green
      case UserMoodState.angry:
        return const Color(0xFFEA580C); // Red-Orange
      case UserMoodState.insecure:
        return const Color(0xFFF97316); // Orange
      case UserMoodState.hurt:
        return const Color(0xFFF59E0B); // Amber
      case UserMoodState.guilty:
        return const Color(0xFFEAB308); // Golden Yellow
    }
  }
}

/// 5.3 Multi-Sector Mood Detection Engine
/// Evaluates Tasks, Finance, Diet, and Health repositories to determine active user mood.
class MoodDetectionEngine {
  static final ValueNotifier<UserMoodState> currentMoodNotifier =
      ValueNotifier<UserMoodState>(detectMood());

  static UserMoodState detectMood() {
    if (Hive.isBoxOpen('settings')) {
      final box = Hive.box('settings');
      final overrideName = box.get('manual_mood_override') as String?;
      final overrideDate = box.get('manual_mood_date') as String?;
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      if (overrideName != null && overrideDate == todayStr) {
        for (final m in UserMoodState.values) {
          if (m.name == overrideName) return m;
        }
      }
    }

    // Live Cross-Sector Evaluation
    int stressedScore = 0;
    int excitedScore = 0;
    int joyfulScore = 0;
    int sensitiveScore = 0;
    int boredScore = 0;

    // 1. Tasks & Habits
    try {
      final tasks = TaskOsRepository.instance.tasksNotifier.value;
      if (tasks.isNotEmpty) {
        final now = DateTime.now();
        final overdue = tasks.where((t) => t.status != TaskStatus.done && t.dueAt != null && t.dueAt!.isBefore(now)).length;
        final completed = tasks.where((t) => t.status == TaskStatus.done).length;
        final total = tasks.length;

        if (overdue > 3) stressedScore += 3;
        if (total > 0 && (completed / total) >= 0.85) excitedScore += 3;
      }
    } catch (_) {}

    // 2. Health & Sleep
    try {
      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final view = WearableRepository.instance.dayView(todayKey);
      final sleepMin = view.sleepDurationMin ?? 420;
      final steps = view.totalSteps;

      if (sleepMin < 330) sensitiveScore += 3; // < 5.5 hours
      if (steps >= 8000) excitedScore += 2;
    } catch (_) {}

    // 3. Diet
    try {
      final now = DateTime.now();
      final todayKey = DateFormat('yyyy-MM-dd').format(now);
      final logs = DietRepository.instance.getLogsForDate(todayKey);

      if (logs.isEmpty && now.hour >= 14) {
        boredScore += 2;
      } else if (logs.isNotEmpty) {
        final consumedKcal = logs.fold(0.0, (s, l) => s + l.kcal);
        final targetKcal = DietRepository.instance.dailyTargets.targetKcal;
        if (targetKcal > 0 && (consumedKcal / targetKcal) >= 0.75) {
          joyfulScore += 2;
        }
      }
    } catch (_) {}

    // Tally winner
    if (stressedScore >= 3) return UserMoodState.stressed;
    if (sensitiveScore >= 3) return UserMoodState.sensitive;
    if (excitedScore >= 3) return UserMoodState.excited;
    if (joyfulScore >= 2) return UserMoodState.joyful;
    if (boredScore >= 2) return UserMoodState.bored;

    return UserMoodState.energized;
  }

  static String getDetectionRationale(UserMoodState mood) {
    switch (mood) {
      case UserMoodState.excited:
        return 'Daily goals are thriving and step activity is high! High momentum today.';
      case UserMoodState.joyful:
        return 'Habits, meals, and tasks are in harmonious alignment.';
      case UserMoodState.grateful:
        return 'Consistent routine maintained with healthy pacing.';
      case UserMoodState.energized:
        return 'Ready for deep focus sessions and physical activity.';
      case UserMoodState.sensitive:
        return 'Restorative sleep was under 5.5 hours. Pacing is recommended today.';
      case UserMoodState.confused:
        return 'Multiple open tasks without scheduled priority. AI can help prioritize.';
      case UserMoodState.bored:
        return 'No activity or meal logged yet this afternoon. Time for a quick break!';
      case UserMoodState.stressed:
        return 'More than 3 overdue tasks detected. Let’s tackle the easiest one first.';
      case UserMoodState.angry:
        return 'Intense workload detected. Take a 2-minute breath reset.';
      case UserMoodState.insecure:
        return 'Uncertain about target progression. Your habits build resilience.';
      case UserMoodState.hurt:
        return 'High mental strain detected. Prioritize recovery and water.';
      case UserMoodState.guilty:
        return 'Missed a schedule? Every moment is a clean slate to begin again.';
    }
  }

  static void setManualOverride(UserMoodState mood) {
    if (Hive.isBoxOpen('settings')) {
      final box = Hive.box('settings');
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      box.put('manual_mood_override', mood.name);
      box.put('manual_mood_date', todayStr);
    }
    currentMoodNotifier.value = mood;
  }
}

/// Continuous 60fps Mood Sticker Avatar Widget.
/// Renders vector geometric character with blinking, glancing, and speaking physics.
class MoodStickerAvatar extends StatefulWidget {
  final double size;
  final UserMoodState? mood;
  final bool isSpeaking;
  final bool enableTapCheckin;
  final VoidCallback? onTap;

  const MoodStickerAvatar({
    super.key,
    this.size = 40.0,
    this.mood,
    this.isSpeaking = false,
    this.enableTapCheckin = true,
    this.onTap,
  });

  @override
  State<MoodStickerAvatar> createState() => _MoodStickerAvatarState();
}

class _MoodStickerAvatarState extends State<MoodStickerAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _idleController;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _idleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    if (widget.enableTapCheckin) {
      showMoodCheckinSheet(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserMoodState>(
      valueListenable: MoodDetectionEngine.currentMoodNotifier,
      builder: (context, activeMood, _) {
        final moodToUse = widget.mood ?? activeMood;

        return GestureDetector(
          onTap: _handleTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _idleController,
            builder: (context, _) {
              final t = _idleController.value;

              // 1. Eye Blinking factor: compresses vertical eye scale to 0.08 over 160ms
              double blinkScaleY = 1.0;
              if (t >= 0.85 && t <= 0.90) {
                final blinkProgress = (t - 0.85) / 0.05;
                blinkScaleY = (blinkProgress < 0.5)
                    ? (1.0 - (blinkProgress * 2.0 * 0.92))
                    : (0.08 + ((blinkProgress - 0.5) * 2.0 * 0.92));
              }

              // 2. Eye Glancing Pupil Shift (-2.5 to +2.5)
              final glanceOffset = Offset(
                math.sin(t * 2 * math.pi) * 2.2,
                math.cos(t * 2 * math.pi) * 1.2,
              );

              // 3. Speaking / Smiling squash-stretch
              double squashX = 1.0;
              double squashY = 1.0;
              if (widget.isSpeaking) {
                final speakingT = (t * 8) % 1.0;
                squashX = 1.0 + math.sin(speakingT * 2 * math.pi) * 0.05;
                squashY = 1.0 - math.sin(speakingT * 2 * math.pi) * 0.05;
              }

              // 4. Mood specific loop effects
              double spiralRotation = (moodToUse == UserMoodState.confused) ? (t * 2 * math.pi) : 0.0;
              double teardropBob = (moodToUse == UserMoodState.sensitive) ? math.sin(t * 4 * math.pi) * 2.0 : 0.0;
              double shiverX = (moodToUse == UserMoodState.stressed) ? math.sin(t * 24 * math.pi) * 1.2 : 0.0;

              return Transform.translate(
                offset: Offset(shiverX, 0),
                child: Transform.scale(
                  scaleX: squashX,
                  scaleY: squashY,
                  child: CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _MoodStickerPainter(
                      mood: moodToUse,
                      blinkScaleY: blinkScaleY,
                      glanceOffset: glanceOffset,
                      isSpeaking: widget.isSpeaking,
                      speakingProgress: (t * 6) % 1.0,
                      spiralRotation: spiralRotation,
                      teardropBob: teardropBob,
                      resolveGrayscale: AppColors.resolveAccent(context, moodToUse.color) != moodToUse.color,
                      resolvedColor: AppColors.resolveAccent(context, moodToUse.color),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Master Vector CustomPainter for all 12 Geometric Characters
class _MoodStickerPainter extends CustomPainter {
  final UserMoodState mood;
  final double blinkScaleY;
  final Offset glanceOffset;
  final bool isSpeaking;
  final double speakingProgress;
  final double spiralRotation;
  final double teardropBob;
  final bool resolveGrayscale;
  final Color resolvedColor;

  _MoodStickerPainter({
    required this.mood,
    required this.blinkScaleY,
    required this.glanceOffset,
    required this.isSpeaking,
    required this.speakingProgress,
    required this.spiralRotation,
    required this.teardropBob,
    required this.resolveGrayscale,
    required this.resolvedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    final bodyPaint = Paint()
      ..color = resolveGrayscale ? resolvedColor : mood.color
      ..style = PaintingStyle.fill;

    // ------------------------------------------------------------------------
    // 1. DRAW GEOMETRIC BODY SHAPE
    // ------------------------------------------------------------------------
    switch (mood) {
      case UserMoodState.excited:
      case UserMoodState.bored:
      case UserMoodState.insecure:
        // Circle
        canvas.drawCircle(center, w * 0.48, bodyPaint);
        break;

      case UserMoodState.joyful:
        // 4-Lobed Clover
        final cloverPath = Path();
        final r = w * 0.28;
        cloverPath.addOval(Rect.fromCircle(center: Offset(center.dx - r * 0.55, center.dy), radius: r));
        cloverPath.addOval(Rect.fromCircle(center: Offset(center.dx + r * 0.55, center.dy), radius: r));
        cloverPath.addOval(Rect.fromCircle(center: Offset(center.dx, center.dy - r * 0.55), radius: r));
        cloverPath.addOval(Rect.fromCircle(center: Offset(center.dx, center.dy + r * 0.55), radius: r));
        canvas.drawPath(cloverPath, bodyPaint);
        break;

      case UserMoodState.grateful:
        // Vertical Peanut / Figure-8
        final peanutPath = Path();
        final pr = w * 0.32;
        peanutPath.addOval(Rect.fromCircle(center: Offset(center.dx, h * 0.32), radius: pr));
        peanutPath.addOval(Rect.fromCircle(center: Offset(center.dx, h * 0.68), radius: pr));
        canvas.drawPath(peanutPath, bodyPaint);
        break;

      case UserMoodState.energized:
        // 3-Crown Scalloped Top Rounded Square
        final crownPath = Path();
        final left = w * 0.08;
        final right = w * 0.92;
        final bottom = h * 0.92;
        crownPath.moveTo(left, h * 0.4);
        // 3 scallops
        crownPath.quadraticBezierTo(w * 0.22, h * 0.1, w * 0.36, h * 0.35);
        crownPath.quadraticBezierTo(w * 0.50, h * 0.05, w * 0.64, h * 0.35);
        crownPath.quadraticBezierTo(w * 0.78, h * 0.1, right, h * 0.4);
        crownPath.lineTo(right, bottom - 12);
        crownPath.quadraticBezierTo(right, bottom, right - 12, bottom);
        crownPath.lineTo(left + 12, bottom);
        crownPath.quadraticBezierTo(left, bottom, left, bottom - 12);
        crownPath.close();
        canvas.drawPath(crownPath, bodyPaint);
        break;

      case UserMoodState.sensitive:
        // Dome / Rounded Arch (Flat bottom, semicircular top)
        final domePath = Path();
        domePath.moveTo(w * 0.08, h * 0.90);
        domePath.lineTo(w * 0.08, h * 0.50);
        domePath.arcToPoint(Offset(w * 0.92, h * 0.50), radius: Radius.circular(w * 0.42));
        domePath.lineTo(w * 0.92, h * 0.90);
        domePath.close();
        canvas.drawPath(domePath, bodyPaint);
        break;

      case UserMoodState.confused:
        // Regular Hexagon
        final hexPath = Path();
        final hr = w * 0.48;
        for (int i = 0; i < 6; i++) {
          final a = (i * 60 - 30) * (math.pi / 180);
          final p = Offset(center.dx + hr * math.cos(a), center.dy + hr * math.sin(a));
          if (i == 0) hexPath.moveTo(p.dx, p.dy);
          else hexPath.lineTo(p.dx, p.dy);
        }
        hexPath.close();
        canvas.drawPath(hexPath, bodyPaint);
        break;

      case UserMoodState.stressed:
        // Rounded Equilateral Triangle
        final triPath = Path();
        triPath.moveTo(center.dx, h * 0.08);
        triPath.lineTo(w * 0.92, h * 0.88);
        triPath.lineTo(w * 0.08, h * 0.88);
        triPath.close();
        canvas.drawPath(triPath, bodyPaint);
        break;

      case UserMoodState.angry:
        // Rounded Square
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: w * 0.88, height: h * 0.88),
            Radius.circular(w * 0.22),
          ),
          bodyPaint,
        );
        break;

      case UserMoodState.hurt:
        // 3-Wave Scalloped Vertical Rectangle
        final wavePath = Path();
        wavePath.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: w * 0.78, height: h * 0.92),
            Radius.circular(w * 0.20),
          ),
        );
        canvas.drawPath(wavePath, bodyPaint);
        break;

      case UserMoodState.guilty:
        // Quarter-Circle Wedge
        final wedgePath = Path();
        wedgePath.moveTo(w * 0.88, h * 0.88);
        wedgePath.lineTo(w * 0.12, h * 0.88);
        wedgePath.lineTo(w * 0.12, h * 0.12);
        wedgePath.arcToPoint(Offset(w * 0.88, h * 0.88), radius: Radius.circular(w * 0.76));
        wedgePath.close();
        canvas.drawPath(wedgePath, bodyPaint);
        break;
    }

    // ------------------------------------------------------------------------
    // 2. DRAW EYES & MOUTH FOR SPECIFIC MOOD
    // ------------------------------------------------------------------------
    final strokePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.05).clamp(1.5, 3.5)
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    switch (mood) {
      case UserMoodState.excited:
        // Closed upward happy arc eyes (◡ ◡) + wide smile
        canvas.save();
        canvas.translate(0, center.dy * (1.0 - blinkScaleY));
        canvas.scale(1.0, blinkScaleY);

        final leftEye = Path()..addArc(Rect.fromCenter(center: Offset(center.dx - w * 0.18, h * 0.40), width: w * 0.18, height: h * 0.14), math.pi, math.pi);
        final rightEye = Path()..addArc(Rect.fromCenter(center: Offset(center.dx + w * 0.18, h * 0.40), width: w * 0.18, height: h * 0.14), math.pi, math.pi);
        canvas.drawPath(leftEye, strokePaint);
        canvas.drawPath(rightEye, strokePaint);
        canvas.restore();

        // Wide curved smile
        final smilePath = Path()
          ..addArc(Rect.fromCenter(center: Offset(center.dx, h * 0.58), width: w * 0.36, height: h * 0.22), 0, math.pi);
        canvas.drawPath(smilePath, strokePaint);
        break;

      case UserMoodState.joyful:
        // Double-arc crinkle eyes + wide open-top smile
        canvas.save();
        canvas.translate(0, center.dy * (1.0 - blinkScaleY));
        canvas.scale(1.0, blinkScaleY);

        final leftJoy = Path()..addArc(Rect.fromCenter(center: Offset(center.dx - w * 0.18, h * 0.40), width: w * 0.18, height: h * 0.14), 0, -math.pi);
        final rightJoy = Path()..addArc(Rect.fromCenter(center: Offset(center.dx + w * 0.18, h * 0.40), width: w * 0.18, height: h * 0.14), 0, -math.pi);
        canvas.drawPath(leftJoy, strokePaint);
        canvas.drawPath(rightJoy, strokePaint);
        canvas.restore();

        // Open top smile arc
        final joySmile = Path()
          ..moveTo(center.dx - w * 0.20, h * 0.60)
          ..quadraticBezierTo(center.dx, h * 0.78, center.dx + w * 0.20, h * 0.60);
        canvas.drawPath(joySmile, strokePaint);
        break;

      case UserMoodState.grateful:
        // Serene closed downward-arc eyes (◡ ◡) + gentle smile
        final leftG = Path()..addArc(Rect.fromCenter(center: Offset(center.dx - w * 0.16, h * 0.38), width: w * 0.16, height: h * 0.12), 0, math.pi);
        final rightG = Path()..addArc(Rect.fromCenter(center: Offset(center.dx + w * 0.16, h * 0.38), width: w * 0.16, height: h * 0.12), 0, math.pi);
        canvas.drawPath(leftG, strokePaint);
        canvas.drawPath(rightG, strokePaint);

        final gSmile = Path()
          ..moveTo(center.dx - w * 0.14, h * 0.58)
          ..quadraticBezierTo(center.dx, h * 0.68, center.dx + w * 0.14, h * 0.58);
        canvas.drawPath(gSmile, strokePaint);
        break;

      case UserMoodState.energized:
        // Winged happy slanted eyes + compact smile
        final leftE = Path()
          ..moveTo(center.dx - w * 0.26, h * 0.45)
          ..lineTo(center.dx - w * 0.10, h * 0.38);
        final rightE = Path()
          ..moveTo(center.dx + w * 0.10, h * 0.38)
          ..lineTo(center.dx + w * 0.26, h * 0.45);
        canvas.drawPath(leftE, strokePaint);
        canvas.drawPath(rightE, strokePaint);

        canvas.drawCircle(Offset(center.dx, h * 0.62), w * 0.06, fillPaint);
        break;

      case UserMoodState.sensitive:
        // Sad downward eyes + white animated teardrop hanging from left eye
        final leftS = Path()..addArc(Rect.fromCenter(center: Offset(center.dx - w * 0.18, h * 0.42), width: w * 0.16, height: h * 0.12), 0, -math.pi);
        final rightS = Path()..addArc(Rect.fromCenter(center: Offset(center.dx + w * 0.18, h * 0.42), width: w * 0.16, height: h * 0.12), 0, -math.pi);
        canvas.drawPath(leftS, strokePaint);
        canvas.drawPath(rightS, strokePaint);

        // Teardrop
        final tearDropCenter = Offset(center.dx - w * 0.22, h * 0.56 + teardropBob);
        canvas.drawCircle(tearDropCenter, w * 0.06, whitePaint);

        // Downward quiver mouth
        final sadMouth = Path()
          ..moveTo(center.dx - w * 0.12, h * 0.70)
          ..quadraticBezierTo(center.dx, h * 0.64, center.dx + w * 0.12, h * 0.70);
        canvas.drawPath(sadMouth, strokePaint);
        break;

      case UserMoodState.confused:
        // Left pupil is black dot, right eye contains rotating orange spiral
        canvas.drawCircle(Offset(center.dx - w * 0.18, h * 0.42), w * 0.14, whitePaint);
        canvas.drawCircle(Offset(center.dx - w * 0.18, h * 0.42), w * 0.06, fillPaint);

        // Right eye with rotating orange spiral
        canvas.drawCircle(Offset(center.dx + w * 0.18, h * 0.42), w * 0.14, whitePaint);
        canvas.save();
        canvas.translate(center.dx + w * 0.18, h * 0.42);
        canvas.rotate(spiralRotation);
        final spiralPaint = Paint()
          ..color = const Color(0xFFF97316)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        final spiralPath = Path();
        for (double a = 0; a < 3 * math.pi; a += 0.2) {
          final r = a * (w * 0.012);
          final p = Offset(r * math.cos(a), r * math.sin(a));
          if (a == 0) spiralPath.moveTo(p.dx, p.dy);
          else spiralPath.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(spiralPath, spiralPaint);
        canvas.restore();

        // Squiggly mouth
        final squiggly = Path()
          ..moveTo(center.dx - w * 0.14, h * 0.68)
          ..lineTo(center.dx - w * 0.04, h * 0.64)
          ..lineTo(center.dx + w * 0.04, h * 0.70)
          ..lineTo(center.dx + w * 0.14, h * 0.65);
        canvas.drawPath(squiggly, strokePaint);
        break;

      case UserMoodState.bored:
        // Two joined white eyes with pupils rolling upward-right
        final leftB = Offset(center.dx - w * 0.10, h * 0.40);
        final rightB = Offset(center.dx + w * 0.10, h * 0.40);
        canvas.drawCircle(leftB, w * 0.12, whitePaint);
        canvas.drawCircle(rightB, w * 0.12, whitePaint);
        canvas.drawCircle(Offset(leftB.dx + 3, leftB.dy - 3), w * 0.05, fillPaint);
        canvas.drawCircle(Offset(rightB.dx + 3, rightB.dy - 3), w * 0.05, fillPaint);

        // Flat horizontal line mouth
        canvas.drawLine(Offset(center.dx - w * 0.15, h * 0.65), Offset(center.dx + w * 0.15, h * 0.65), strokePaint);
        break;

      case UserMoodState.stressed:
        // Tight angled > < eyes and short flat tense mouth
        final leftAngled = Path()
          ..moveTo(center.dx - w * 0.26, h * 0.46)
          ..lineTo(center.dx - w * 0.14, h * 0.52)
          ..lineTo(center.dx - w * 0.26, h * 0.58);
        final rightAngled = Path()
          ..moveTo(center.dx + w * 0.26, h * 0.46)
          ..lineTo(center.dx + w * 0.14, h * 0.52)
          ..lineTo(center.dx + w * 0.26, h * 0.58);
        canvas.drawPath(leftAngled, strokePaint);
        canvas.drawPath(rightAngled, strokePaint);

        canvas.drawLine(Offset(center.dx - w * 0.12, h * 0.74), Offset(center.dx + w * 0.12, h * 0.74), strokePaint);
        break;

      case UserMoodState.angry:
        // Flat-topped glaring white eyes with centered pupils + straight horizontal mouth
        final browPath = Path()
          ..moveTo(center.dx - w * 0.28, h * 0.36)
          ..lineTo(center.dx, h * 0.44)
          ..lineTo(center.dx + w * 0.28, h * 0.36);
        canvas.drawPath(browPath, strokePaint);

        canvas.drawCircle(Offset(center.dx - w * 0.14, h * 0.48), w * 0.08, whitePaint);
        canvas.drawCircle(Offset(center.dx + w * 0.14, h * 0.48), w * 0.08, whitePaint);
        canvas.drawCircle(Offset(center.dx - w * 0.14, h * 0.48), w * 0.04, fillPaint);
        canvas.drawCircle(Offset(center.dx + w * 0.14, h * 0.48), w * 0.04, fillPaint);

        canvas.drawLine(Offset(center.dx - w * 0.16, h * 0.68), Offset(center.dx + w * 0.16, h * 0.68), strokePaint);
        break;

      case UserMoodState.insecure:
        // Horizontal cyclops/pill white eye band with black pupil shifting nervously side-to-side
        final bandRect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(center.dx, h * 0.44), width: w * 0.48, height: h * 0.20),
          Radius.circular(h * 0.10),
        );
        canvas.drawRRect(bandRect, whitePaint);

        final pupilX = center.dx + glanceOffset.dx * 1.5;
        canvas.drawCircle(Offset(pupilX, h * 0.44), w * 0.06, fillPaint);

        final insecMouth = Path()
          ..moveTo(center.dx - w * 0.12, h * 0.66)
          ..lineTo(center.dx - w * 0.04, h * 0.69)
          ..lineTo(center.dx + w * 0.04, h * 0.65)
          ..lineTo(center.dx + w * 0.12, h * 0.67);
        canvas.drawPath(insecMouth, strokePaint);
        break;

      case UserMoodState.hurt:
        // Closed downward eyes (◡ ◡) and short flat line mouth
        final leftHurt = Path()..addArc(Rect.fromCenter(center: Offset(center.dx - w * 0.15, h * 0.42), width: w * 0.14, height: h * 0.10), 0, math.pi);
        final rightHurt = Path()..addArc(Rect.fromCenter(center: Offset(center.dx + w * 0.15, h * 0.42), width: w * 0.14, height: h * 0.10), 0, math.pi);
        canvas.drawPath(leftHurt, strokePaint);
        canvas.drawPath(rightHurt, strokePaint);

        canvas.drawLine(Offset(center.dx - w * 0.10, h * 0.66), Offset(center.dx + w * 0.10, h * 0.66), strokePaint);
        break;

      case UserMoodState.guilty:
        // Two white eyes tucked in lower-left corner glancing sideways
        final eye1 = Offset(w * 0.28, h * 0.58);
        final eye2 = Offset(w * 0.46, h * 0.64);
        canvas.drawCircle(eye1, w * 0.10, whitePaint);
        canvas.drawCircle(eye2, w * 0.10, whitePaint);
        canvas.drawCircle(Offset(eye1.dx - 2, eye1.dy), w * 0.045, fillPaint);
        canvas.drawCircle(Offset(eye2.dx - 2, eye2.dy), w * 0.045, fillPaint);

        // Small nervous mouth dot
        canvas.drawCircle(Offset(w * 0.62, h * 0.72), w * 0.035, fillPaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _MoodStickerPainter oldDelegate) {
    return oldDelegate.mood != mood ||
        oldDelegate.blinkScaleY != blinkScaleY ||
        oldDelegate.glanceOffset != glanceOffset ||
        oldDelegate.isSpeaking != isSpeaking ||
        oldDelegate.spiralRotation != spiralRotation ||
        oldDelegate.teardropBob != teardropBob ||
        oldDelegate.resolveGrayscale != resolveGrayscale;
  }
}

/// 5.2 Interactive "Check-in time: How are you today?" Sheet
void showMoodCheckinSheet(BuildContext context) {
  HapticFeedback.mediumImpact();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final sheetBg = isDark ? const Color(0xFF161B22) : Colors.white;
      final currentMood = MoodDetectionEngine.detectMood();
      final rationale = MoodDetectionEngine.getDetectionRationale(currentMood);

      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Check-in time: How are you today?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Detected: ${currentMood.displayName} — $rationale',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF8B949E) : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 20),

                // 4x3 Grid of 12 Mood Stickers
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: UserMoodState.values.length,
                  itemBuilder: (context, index) {
                    final mood = UserMoodState.values[index];
                    final isSelected = mood == MoodDetectionEngine.currentMoodNotifier.value;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        MoodDetectionEngine.setManualOverride(mood);
                        setSheetState(() {});
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (ctx.mounted) Navigator.pop(ctx);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? mood.color.withValues(alpha: 0.22)
                              : (isDark ? const Color(0xFF1F2630) : const Color(0xFFF3F5F7)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? mood.color : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            MoodStickerAvatar(
                              size: 42,
                              mood: mood,
                              enableTapCheckin: false,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              mood.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
