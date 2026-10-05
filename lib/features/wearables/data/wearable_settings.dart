import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class WearableSettings {
  static Box get _box => Hive.box('settings');

  static bool get isEnabled => _box.get('wear_enabled', defaultValue: false);
  static set isEnabled(bool value) => _box.put('wear_enabled', value);

  static String get source => _box.get('wear_source', defaultValue: 'samsung_sdk');
  static set source(String value) => _box.put('wear_source', value);

  static String? get lastSyncIso => _box.get('wear_last_sync');
  static set lastSyncIso(String? value) => _box.put('wear_last_sync', value);

  static int? get lastSyncMs => _box.get('wear_last_sync_ms');
  static set lastSyncMs(int? value) => _box.put('wear_last_sync_ms', value);

  static bool get useMockProvider => _box.get('wear_use_mock_provider', defaultValue: false);
  static set useMockProvider(bool value) => _box.put('wear_use_mock_provider', value);

  static bool get autoSyncOnResume => _box.get('wear_auto_sync_on_resume', defaultValue: true);
  static set autoSyncOnResume(bool value) => _box.put('wear_auto_sync_on_resume', value);

  static Map<String, dynamic> get changeTokens {
    final raw = _box.get('wear_change_tokens');
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return {};
  }
  static set changeTokens(Map<String, dynamic> value) => _box.put('wear_change_tokens', value);

  static int get backfillDays => _box.get('wear_backfill_days', defaultValue: 30);
  static set backfillDays(int value) => _box.put('wear_backfill_days', value);

  static String get burnCreditMode => _box.get('wear_burn_credit_mode', defaultValue: 'workouts_only');
  static set burnCreditMode(String value) => _box.put('wear_burn_credit_mode', value);

  static bool get aiShare => _box.get('wear_ai_share', defaultValue: false);
  static set aiShare(bool value) => _box.put('wear_ai_share', value);

  static bool get debugDump => _box.get('wear_debug_dump', defaultValue: false);
  static set debugDump(bool value) => _box.put('wear_debug_dump', value);

  static int get stepGoalDefault => _box.get('step_goal_default', defaultValue: 8000);
  static set stepGoalDefault(int value) => _box.put('step_goal_default', value);

  static int get sleepGoalMinutesDefault => _box.get('sleep_goal_minutes_default', defaultValue: 420);
  static set sleepGoalMinutesDefault(int value) => _box.put('sleep_goal_minutes_default', value);

  static int get activeMinutesGoalDefault => _box.get('active_minutes_goal_default', defaultValue: 30);
  static set activeMinutesGoalDefault(int value) => _box.put('active_minutes_goal_default', value);

  static int? get wakeTargetMinutesDefault => _box.get('wake_target_minutes_default');
  static set wakeTargetMinutesDefault(int? value) => _box.put('wake_target_minutes_default', value);

  static int get wakeGraceMinutes => _box.get('wake_grace_minutes', defaultValue: 0);
  static set wakeGraceMinutes(int value) => _box.put('wake_grace_minutes', value);

  static String get wakeUnloggedPolicy => _box.get('wake_unlogged_policy', defaultValue: 'missed');
  static set wakeUnloggedPolicy(String value) => _box.put('wake_unlogged_policy', value);

  static int get wakeMissPenaltyXp => _box.get('wake_miss_penalty_xp', defaultValue: 0);
  static set wakeMissPenaltyXp(int value) => _box.put('wake_miss_penalty_xp', value);

  static bool get wakeInferFromSleep => _box.get('wake_infer_from_sleep', defaultValue: true);
  static set wakeInferFromSleep(bool value) => _box.put('wake_infer_from_sleep', value);

  static bool get journalAutologEnabled => _box.get('journal_autolog_enabled', defaultValue: true);
  static set journalAutologEnabled(bool value) => _box.put('journal_autolog_enabled', value);

  static List<String> get journalAutologKinds {
    final raw = _box.get('journal_autolog_kinds');
    if (raw is List) {
      return List<String>.from(raw);
    }
    return ['wake', 'sleep', 'workout', 'steps', 'energy'];
  }
  static set journalAutologKinds(List<String> value) => _box.put('journal_autolog_kinds', value);

  static String? get profileSex => _box.get('profile_sex');
  static set profileSex(String? value) => _box.put('profile_sex', value);

  static String? get profileDob => _box.get('profile_dob');
  static set profileDob(String? value) => _box.put('profile_dob', value);

  static double? get profileHeightCm => _box.get('profile_height_cm');
  static set profileHeightCm(double? value) => _box.put('profile_height_cm', value);

  static bool get ageIndexEnabled => _box.get('age_index_enabled', defaultValue: true);
  static set ageIndexEnabled(bool value) => _box.put('age_index_enabled', value);
}
