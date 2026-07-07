import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:habit_tracker/data/models/goal.dart';

class AiContext {
  static String buildSystemPrompt() {
    return '''Habit AI. JSON ONLY:{"intent":"","message":"","actions":[{"type":"","payload":{}}]}
Types: food_entry(name,calories,protein,carbs,fat,meal_type), burn_entry(activity,calories_burned,duration_minutes), task_create(title,type,target_value,unit,category), finance_transaction(title,amount,mode,category), finance_goal(name,target), play_vault_video(query).
No MD. 5k=5000, 1L=100000. Goal=expensive buy.''';
  }

  static String buildDietContext(double t) {
    try {
      final log = Hive.box<DietDayLog>('diet_logs').get(DateFormat('yyyy-MM-dd').format(DateTime.now()));
      if (log == null) return '[DIET] Tgt:\$t None';
      return '[DIET] In:\${log.totalCalories} Net:\${log.netCalories} Tgt:\$t';
    } catch (_) { return ''; }
  }

  static double _asD(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

  static String buildFinanceContext() {
    try {
      final now = DateTime.now();
      double inc = 0, exp = 0;
      for (var tx in Hive.box<Transaction>('finance_transactions').values) {
        if (tx.date.month == now.month && tx.date.year == now.year) {
          if (tx.mode.toLowerCase() == 'expense' || tx.amount < 0) exp += tx.amount.abs();
          else inc += tx.amount.abs();
        }
      }
      return '[FIN] Inc:\${inc.toStringAsFixed(0)} Exp:\${exp.toStringAsFixed(0)}';
    } catch (_) { return ''; }
  }

  static String buildTaskContext() {
    try {
      final goals = Hive.box<Goal>('mission_box_v4').values.toList();
      int c = goals.where((g) => g?.isCompleted == true).length, a = goals.where((g) => g?.isCompleted != true && g?.isArchived != true).length;
      return '[TASK] Act:\$a Dn:\$c';
    } catch (_) { return ''; }
  }
}
