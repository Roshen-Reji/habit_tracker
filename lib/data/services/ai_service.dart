import 'package:habit_tracker/core/utils/format_utils.dart';
import 'dart:convert';
import 'package:habit_tracker/data/services/ai_context.dart';
import 'package:habit_tracker/data/services/gemini_client.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:habit_tracker/services/now_playing_service.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';
import 'package:habit_tracker/features/finance/data/finance_controller.dart';
import 'package:habit_tracker/features/finance/engine/query.dart';
import 'package:habit_tracker/features/finance/engine/what_if_engine.dart';
import 'package:habit_tracker/features/finance/models/category.dart';
import 'package:habit_tracker/features/finance/models/recurring_rule.dart';
import 'package:habit_tracker/features/finance/models/savings_goal.dart';
import 'package:habit_tracker/features/finance/models/budget_line.dart';
import 'package:habit_tracker/features/wearables/engine/wake_parser.dart';
import 'package:habit_tracker/features/wearables/data/wake_service.dart';
import 'package:habit_tracker/features/tasks/data/wake_log_repository.dart';
import 'package:habit_tracker/features/journal/data/journal_day_repository.dart';
import 'package:habit_tracker/features/wearables/data/sync_service.dart';
import 'package:habit_tracker/features/wearables/data/wearable_repository.dart';
import 'package:habit_tracker/features/wearables/data/wearable_settings.dart';
import 'package:habit_tracker/features/tasks/engine/native_task_ai_engine.dart';
import 'package:habit_tracker/features/diet/models/diet_planner_models.dart';
import 'package:habit_tracker/features/diet/engine/native_diet_ai_engine.dart';
import 'package:habit_tracker/features/diet/data/diet_repository.dart';
import 'package:habit_tracker/features/tasks/models/scanner_models.dart';
import 'package:habit_tracker/features/tasks/models/task_os_models.dart';
import 'package:habit_tracker/features/tasks/data/task_os_repository.dart';
import 'package:habit_tracker/features/tasks/engine/task_nl_parser.dart';
import 'package:habit_tracker/features/finance/engine/capture_engine.dart';

// --- AI Response Model ---
class AiResponse {
  final String message;
  final String intent;
  final List<AiAction> actions;
  final Map<String, dynamic>? data;

  AiResponse({
    required this.message,
    required this.intent,
    this.actions = const [],
    this.data,
  });
}

class AiAction {
  final String type; // 'food_entry', 'burn_entry', 'task_create', 'music_play'
  final Map<String, dynamic> payload;
  final String? sector;
  final String? op;
  bool isConfirmed;

  AiAction({
    required this.type,
    required this.payload,
    this.sector,
    this.op,
    this.isConfirmed = false,
  });
}

class _TaskDraft {
  final String title;
  final GoalType type;
  final GoalCategory category;
  final double targetValue;
  final String unit;
  final DateTime? endDate;

  _TaskDraft({
    required this.title,
    required this.type,
    required this.category,
    required this.targetValue,
    required this.unit,
    this.endDate,
  });
}

// --- Main AI Service ---
class AiService {
  static AiService? _instance;
  List<Map<String, dynamic>> _messagesHistory = [];

  AiService._();

  static AiService get instance {
    _instance ??= AiService._();
    return _instance!;
  }

  String get settingsApiKey {
    if (!Hive.isBoxOpen('settings')) return '';
    return Hive.box('settings')
        .get('gemini_api_key', defaultValue: '')
        .toString()
        .trim();
  }

  String get envApiKey {
    return const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '')
        .trim();
  }

  String get activeApiKey {
    final settingsKey = settingsApiKey;
    if (settingsKey.isNotEmpty) return settingsKey;
    return envApiKey;
  }

  String get activeApiKeySource {
    if (settingsApiKey.isNotEmpty) return 'Settings';
    if (envApiKey.isNotEmpty) return 'Environment';
    return 'None';
  }

  bool get isConfigured => activeApiKey.isNotEmpty;

  String get configurationSummary {
    if (settingsApiKey.isNotEmpty) return 'Settings key active';
    if (envApiKey.isNotEmpty) return 'Environment key active';
    return 'Local AI only';
  }

  // --- Smart Local Intent Detection ---
  // Detects intent from user message BEFORE sending to AI to minimize token usage
  String detectIntent(String message,
      {bool hasImage = false, String? contextHint}) {
    final lower = message.toLowerCase().trim();

    final forced = contextHint?.toLowerCase().trim();
    if (forced == 'tasks' || forced == 'task' || forced == 'missions')
      return 'tasks';
    if (forced == 'finance') return 'finance';
    if (forced == 'diet' || forced == 'food') return 'diet';
    if (forced == 'vault' || forced == 'speech') return 'vault';
    if (forced == 'wake' || forced == 'wakeup') return 'wake';
    if (forced == 'wear' || forced == 'wearable' || forced == 'watch')
      return 'wear';
    if (forced == 'journal') return 'journal';

    // Image -> most likely food logging
    if (hasImage) return 'diet';

    // Wake, Wear, and Journal intent routing takes precedence over general task/diet/music
    if (_looksLikeWakeIntent(lower)) return 'wake';
    if (_looksLikeWearIntent(lower)) return 'wear';
    if (_looksLikeJournalNote(lower)) return 'journal';
    if (_looksLikeVaultCommand(lower)) return 'vault';
    if (_looksLikeFinanceIntent(lower)) return 'finance';
    if (_looksLikeTaskCreate(lower) || _isTaskStatusQuery(lower))
      return 'tasks';

    // Diet keywords
    final dietWords = [
      'eat',
      'ate',
      'diet',
      'food',
      'meal',
      'calorie',
      'kcal',
      'protein',
      'carbs',
      'fat',
      'water',
      'drink',
      'drank',
      'nutrition',
      'breakfast',
      'lunch',
      'dinner',
      'snack',
      'hungry',
      'recipe',
      'cook',
      'burn',
      'burned',
      'burnt',
      'consume',
      'consumed'
    ];
    for (final w in dietWords) {
      if (lower.contains(w)) return 'diet';
    }

    // Finance keywords
    final financeWords = [
      'spend',
      'spent',
      'money',
      'expense',
      'income',
      'budget',
      'save',
      'savings',
      'finance',
      'cost',
      'buy',
      'bought',
      'paid',
      'pay',
      'rupee',
      'rs',
      'salary',
      'emi',
      'sip',
      'invest',
      'loan',
      'debt',
      'rent',
      'bill',
      'recharge',
      'shopping',
      'paisa',
      'kharcha',
      'transaction'
    ];
    for (final w in financeWords) {
      if (lower.contains(w)) return 'finance';
    }

    // Task keywords
    final taskWords = [
      'task',
      'goal',
      'mission',
      'todo',
      'complete',
      'finish',
      'study',
      'work',
      'exercise',
      'gym',
      'read',
      'habit',
      'streak',
      'progress',
      'daily',
      'weekly',
      'monthly',
      'schedule',
      'routine',
      'padhai',
      'kaam',
      'target'
    ];
    for (final w in taskWords) {
      if (lower.contains(w)) return 'tasks';
    }

    // Music keywords after vault/diet/finance/tasks so "play motivation video"
    // does not get swallowed by song search.
    final musicWords = [
      'song',
      'track',
      'music',
      'listen',
      'queue',
      'album',
      'artist',
      'sing',
      'bajao',
      'gana',
      'gaana',
      'sunao',
      'suno',
      'laga do',
      'chalao',
      'baja',
      'put on',
      'shuffle',
      'next song',
      'skip',
      'pause',
      'resume',
      'playing'
    ];
    for (final w in musicWords) {
      if (lower.contains(w)) return 'music';
    }
    if (lower.startsWith('play ') &&
        !_containsAny(lower, ['video', 'speech', 'vault'])) {
      return 'music';
    }

    return 'general';
  }

  // --- Local NLP Engine ---
  Future<AiResponse?> _handleLocally(String message, String intent) async {
    final lower = message.toLowerCase().trim();

    if (intent == 'wake') return await _handleWakeLocally(message);
    if (intent == 'wear') return await _handleWearLocally(message);
    if (intent == 'journal') return await _handleJournalLocally(message);
    if (intent == 'vault') return _handleVaultLocally(message);
    if (intent == 'tasks') return _handleTasksLocally(message);
    if (intent == 'finance') return _handleFinanceLocally(message);
    if (intent == 'diet') return _handleDietLocally(message);

    if (_looksLikeWakeIntent(lower)) return await _handleWakeLocally(message);
    if (_looksLikeWearIntent(lower)) return await _handleWearLocally(message);
    if (_looksLikeJournalNote(lower))
      return await _handleJournalLocally(message);
    if (_isTaskStatusQuery(lower)) return _buildTaskStatusResponse(lower);
    if (_looksLikeVaultCommand(lower)) return _handleVaultLocally(message);

    return null;
  }

  // Kept as a fallback reference while the newer local command router handles
  // the live app path above.
  // ignore: unused_element
  AiResponse? _handleLocallyLegacy(String message, String intent) {
    final lower = message.toLowerCase().trim();

    if (intent == 'tasks') {
      if (lower.contains('10,000 steps') ||
          lower.contains('10000 steps') ||
          lower == 'steps goal') {
        return AiResponse(
          message:
              'Created daily metric goal: 10,000 steps (tracks automatically from Galaxy Watch).',
          intent: 'task_create',
          actions: [
            AiAction(
              type: 'task_create',
              payload: {
                'title': '10,000 steps',
                'type': 'daily',
                'category': 'fitness',
                'target_value': 10000.0,
                'unit': 'steps',
                'kind': 'metric',
                'metric_key': 'steps',
                'metric_op': '>=',
              },
              isConfirmed: true,
            ),
          ],
        );
      }
      if (lower.contains('30 active min') ||
          lower.contains('30 active minutes')) {
        return AiResponse(
          message:
              'Created daily metric goal: 30 active minutes (tracks automatically from Galaxy Watch).',
          intent: 'task_create',
          actions: [
            AiAction(
              type: 'task_create',
              payload: {
                'title': '30 active minutes',
                'type': 'daily',
                'category': 'fitness',
                'target_value': 30.0,
                'unit': 'mins',
                'kind': 'metric',
                'metric_key': 'active_minutes',
                'metric_op': '>=',
              },
              isConfirmed: true,
            ),
          ],
        );
      }
      if (lower.contains('sleep 7 h') || lower.contains('sleep 7 hours')) {
        return AiResponse(
          message:
              'Created daily metric goal: Sleep 7 hours (tracks automatically from Galaxy Watch).',
          intent: 'task_create',
          actions: [
            AiAction(
              type: 'task_create',
              payload: {
                'title': 'Sleep 7 h',
                'type': 'daily',
                'category': 'health',
                'target_value': 420.0,
                'unit': 'mins',
                'kind': 'metric',
                'metric_key': 'sleep_minutes',
                'metric_op': '>=',
              },
              isConfirmed: true,
            ),
          ],
        );
      }
      if (lower.contains('workout today') || lower == 'daily workout') {
        return AiResponse(
          message:
              'Created daily metric goal: Workout today (tracks automatically from Galaxy Watch).',
          intent: 'task_create',
          actions: [
            AiAction(
              type: 'task_create',
              payload: {
                'title': 'Workout today',
                'type': 'daily',
                'category': 'fitness',
                'target_value': 30.0,
                'unit': 'mins',
                'kind': 'metric',
                'metric_key': 'workout_minutes',
                'metric_op': '>=',
              },
              isConfirmed: true,
            ),
          ],
        );
      }

      // Create daily task with duration: "i am going to do 10 push ups everyday for 10 days" or "this week i am going to do 10 push ups everyday"
      final dailyRegex = RegExp(
          r'(?:i am going to do|do|i will do|add a daily task to|remind me to)?\s*(\d+)?\s*(.*?)\s*(everyday|daily)(?:\s+(for\s+(\d+)\s+(days?|weeks?|months?)))?',
          caseSensitive: false);
      final thisWeekRegex = RegExp(
          r'(?:this week|this month)\s+(?:i am going to do|do|i will do|add a task to)?\s*(\d+)?\s*(.*?)\s*(everyday|daily)',
          caseSensitive: false);

      Match? matchToUse;
      DateTime? endDate;
      String? targetStr;
      String title = '';

      final thisWeekMatch = thisWeekRegex.firstMatch(lower);
      final dailyMatch = dailyRegex.firstMatch(lower);

      if (thisWeekMatch != null && thisWeekMatch.group(2) != null) {
        matchToUse = thisWeekMatch;
        targetStr = thisWeekMatch.group(1);
        title = thisWeekMatch.group(2)!.trim();
        if (lower.contains('this week'))
          endDate = DateTime.now().add(const Duration(days: 7));
        else if (lower.contains('this month'))
          endDate = DateTime.now().add(const Duration(days: 30));
      } else if (dailyMatch != null && dailyMatch.group(2) != null) {
        matchToUse = dailyMatch;
        targetStr = dailyMatch.group(1);
        title = dailyMatch.group(2)!.trim();
        if (dailyMatch.group(4) != null) {
          int count = int.tryParse(dailyMatch.group(5) ?? '1') ?? 1;
          String unit = dailyMatch.group(6) ?? 'days';
          if (unit.startsWith('week'))
            endDate = DateTime.now().add(Duration(days: count * 7));
          else if (unit.startsWith('month'))
            endDate = DateTime.now().add(Duration(days: count * 30));
          else
            endDate = DateTime.now().add(Duration(days: count));
        }
      }

      if (matchToUse != null && title.isNotEmpty && title != 'a') {
        // clean up stray words at the start
        title = title
            .replaceAll(
                RegExp(
                    r'^(?:add a task to|remind me to|i will do|do|i will|to)\s+'),
                '')
            .trim();
        return AiResponse(
            message:
                'Created a daily mission to do $title${endDate != null ? " until ${DateFormat('MMM dd').format(endDate)}" : ""}.',
            intent: 'task_create',
            actions: [
              AiAction(type: 'task_create', payload: {
                'title': title,
                'type': 'daily',
                'target_value':
                    targetStr != null ? double.tryParse(targetStr) : 1.0,
                'unit': 'times',
                'category': 'productivity',
                'end_date': endDate?.toIso8601String()
              })
            ]);
      }

      // Create today task: "i will do hw today"
      final todayRegex = RegExp(
          r'(?:add a task to|remind me to|i will do|do|i will|to)?\s*(.*?)\s+(today|tonight)',
          caseSensitive: false);
      final todayMatch = todayRegex.firstMatch(lower);
      if (todayMatch != null && todayMatch.group(1) != null) {
        String title = todayMatch.group(1)!.trim();
        title = title
            .replaceAll(
                RegExp(
                    r'^(?:add a task to|remind me to|i will do|do|i will|to)\s+'),
                '')
            .trim();
        if (title.isNotEmpty) {
          return AiResponse(
              message: 'Created a mission for today: $title.',
              intent: 'task_create',
              actions: [
                AiAction(type: 'task_create', payload: {
                  'title': title,
                  'type': 'today',
                  'target_value': 1.0,
                  'unit': 'times',
                  'category': 'productivity'
                })
              ]);
        }
      }

      // Status query: "how much task i finished" or "remaining for today"
      if (lower.contains('how much') ||
          lower.contains('remaining') ||
          lower.contains('finished') ||
          lower.contains('status')) {
        final box = Hive.box<Goal>('mission_box_v4');
        final todayGoals = box.values
            .where((g) => g.type == GoalType.today || g.type == GoalType.daily)
            .toList();
        final completed = todayGoals.where((g) => g.isCompleted).length;
        final total = todayGoals.length;
        final remaining = total - completed;

        final completedTasks = todayGoals
            .where((g) => g.isCompleted)
            .map((g) => g.title)
            .join(", ");
        final remainingTasks = todayGoals
            .where((g) => !g.isCompleted)
            .map((g) => g.title)
            .join(", ");

        String msg =
            'You have completed $completed out of $total missions today ($remaining remaining).';
        if ((lower.contains('what') ||
                lower.contains('finished') ||
                lower.contains('completed')) &&
            completedTasks.isNotEmpty) {
          msg += ' You finished: $completedTasks.';
        } else if (lower.contains('remaining') && remainingTasks.isNotEmpty) {
          msg += ' Remaining tasks: $remainingTasks.';
        }

        return AiResponse(
          message: msg,
          intent: 'general_chat',
        );
      }
    } else if (intent == 'finance') {
      // Add income: "add 100rs to my income"
      final incomeRegex = RegExp(
          r'(?:add|got|received|earned|made)\s+(\d+(?:\.\d+)?)(?:rs|₹|\$| bucks)?\s*(?:to\s+(?:my\s+)?income)?',
          caseSensitive: false);
      final incomeMatch = incomeRegex.firstMatch(lower);
      if (incomeMatch != null &&
          (lower.contains('income') ||
              lower.contains('earned') ||
              lower.contains('received'))) {
        final amount = double.tryParse(incomeMatch.group(1) ?? '0') ?? 0;
        FinanceRepository().addTransaction(TxDraft(
          title: 'Income',
          amount: amount,
          date: DateTime.now(),
          mode: 'income',
          category: 'Salary',
          icon: 'wallet',
          kind: 'income',
        ));
        return AiResponse(
            message: 'Added $amount to your income.', intent: 'general_chat');
      }

      // Add expense: "i bought a pepsi for 40rs" or "reduce 40rs for pepsi"
      final expenseRegex = RegExp(
          r'(?:i\s+)?(?:bought\s+(?:a\s+)?(.*?)\s+for\s+(\d+(?:\.\d+)?)|reduce\s+(\d+(?:\.\d+)?)(?:rs|₹|\$)?\s+(?:for|on)\s+(.*?)|spent\s+(\d+(?:\.\d+)?)(?:rs|₹|\$)?\s+(?:on|for)\s+(.*?)|paid\s+(\d+(?:\.\d+)?)(?:rs|₹|\$)?\s+(?:for|on)\s+(.*?))',
          caseSensitive: false);
      final expenseMatch = expenseRegex.firstMatch(lower);
      if (expenseMatch != null) {
        String title = '';
        double amount = 0;
        if (expenseMatch.group(1) != null) {
          title = expenseMatch.group(1)!.trim();
          amount = double.tryParse(expenseMatch.group(2) ?? '0') ?? 0;
        } else if (expenseMatch.group(3) != null) {
          amount = double.tryParse(expenseMatch.group(3) ?? '0') ?? 0;
          title = expenseMatch.group(4)!.trim();
        } else if (expenseMatch.group(5) != null) {
          amount = double.tryParse(expenseMatch.group(5) ?? '0') ?? 0;
          title = expenseMatch.group(6)!.trim();
        } else if (expenseMatch.group(7) != null) {
          amount = double.tryParse(expenseMatch.group(7) ?? '0') ?? 0;
          title = expenseMatch.group(8)!.trim();
        }

        FinanceRepository().addTransaction(TxDraft(
          title: title,
          amount: amount,
          date: DateTime.now(),
          mode: 'expense',
          category: 'Shopping',
          icon: 'shopping-cart',
          kind: 'expense',
        ));
        return AiResponse(
            message: 'Logged an expense of $amount for $title. Wallet updated.',
            intent: 'general_chat');
      }

      // SIP query: "whats my current sip"
      if (lower.contains('sip')) {
        final vaultBox = Hive.box<AssetVault>('finance_vaults');
        double sipTotal = 0;
        for (var vault in vaultBox.values) {
          if (vault.type == 'SIP') sipTotal += vault.balance;
        }
        return AiResponse(
            message:
                'Your total active SIP balance across vaults is $sipTotal.',
            intent: 'general_chat');
      }

      double _parseAmount(String digits, String? suffix) {
        double val = double.tryParse(digits) ?? 0;
        if (suffix != null) {
          final s = suffix.toLowerCase();
          if (s.startsWith('k')) val *= 1000;
          if (s.startsWith('lakh')) val *= 100000;
          if (s.startsWith('m')) val *= 1000000;
        }
        return val;
      }

      // Budget query
      final budgetRegex = RegExp(
          r'(?:set|add|create)\s+(?:a\s+)?budget\s+(?:for|on)\s+(.*?)\s+(\d+(?:\.\d+)?)\s*(k|lakh|lakhs|m)?\s*(?:rs|₹|\$)?',
          caseSensitive: false);
      final budgetMatch = budgetRegex.firstMatch(lower);
      if (budgetMatch != null) {
        final category = _titleCase(budgetMatch.group(1) ?? 'Other');
        final amount =
            _parseAmount(budgetMatch.group(2) ?? '0', budgetMatch.group(3));
        return AiResponse(
            message: 'Set a budget of $amount for $category.',
            intent: 'general_chat',
            actions: [
              AiAction(
                  type: 'finance_budget',
                  payload: {'category': category, 'total': amount})
            ]);
      }

      // SIP adding query
      final sipAddRegex = RegExp(
          r'(?:add|set)\s+(?:a\s+)?(?:monthly\s+)?sip\s+(?:for\s+)?(.*?)\s+(?:for\s+|of\s+)?(\d+(?:\.\d+)?)\s*(k|lakh|lakhs|m)?\s*(?:rs|₹|\$)?',
          caseSensitive: false);
      final sipAddMatch = sipAddRegex.firstMatch(lower);
      if (sipAddMatch != null) {
        final name = _titleCase(sipAddMatch.group(1) ?? 'Mutual Fund');
        final amount =
            _parseAmount(sipAddMatch.group(2) ?? '0', sipAddMatch.group(3));
        return AiResponse(
            message: 'Added monthly SIP $name for $amount.',
            intent: 'general_chat',
            actions: [
              AiAction(
                  type: 'finance_sip',
                  payload: {'name': name, 'amount': amount, 'due': 5})
            ]);
      }

      // Commitment query
      final commitRegex = RegExp(
          r'(?:add|set)\s+(?:a\s+)?(?:monthly\s+)?commitment\s+(?:for\s+)?(.*?)\s+(?:for\s+|of\s+)?(\d+(?:\.\d+)?)\s*(k|lakh|lakhs|m)?\s*(?:rs|₹|\$)?',
          caseSensitive: false);
      final commitMatch = commitRegex.firstMatch(lower);
      if (commitMatch != null) {
        final name = _titleCase(commitMatch.group(1) ?? 'Subscription');
        final amount =
            _parseAmount(commitMatch.group(2) ?? '0', commitMatch.group(3));
        return AiResponse(
            message: 'Added monthly commitment $name for $amount.',
            intent: 'general_chat',
            actions: [
              AiAction(
                  type: 'finance_commitment',
                  payload: {'name': name, 'amount': amount, 'date': 1})
            ]);
      }

      // Goal query
      final goalRegex = RegExp(
          r'(?:add|set)\s+(?:a\s+)?(?:finance\s+)?goal\s+(?:to\s+buy\s+|for\s+)?(.*?)\s+(?:worth\s+|for\s+|of\s+)?(\d+(?:\.\d+)?)\s*(k|lakh|lakhs|m)?\s*(?:rs|₹|\$)?',
          caseSensitive: false);
      final goalMatch = goalRegex.firstMatch(lower);
      if (goalMatch != null) {
        final name = _titleCase(goalMatch.group(1) ?? 'Goal');
        final amount =
            _parseAmount(goalMatch.group(2) ?? '0', goalMatch.group(3));
        return AiResponse(
            message: 'Added finance goal $name for $amount.',
            intent: 'general_chat',
            actions: [
              AiAction(
                  type: 'finance_goal',
                  payload: {'name': name, 'target': amount})
            ]);
      }
    } else if (intent == 'diet') {
      // Quick calorie intake: "i ate 200kcal today" or "ate 200 kcal"
      final intakeRegex = RegExp(
          r'(?:ate|consumed|had|eat)\s+(\d+(?:\.\d+)?)\s*(?:kcal|calories|cal)(?:\s+(?:of|from)\s+(.*?))?',
          caseSensitive: false);
      final intakeMatch = intakeRegex.firstMatch(lower);
      if (intakeMatch != null) {
        final kcals = double.tryParse(intakeMatch.group(1) ?? '0') ?? 0;
        final foodName = intakeMatch.group(2)?.trim() ?? 'Quick Entry';
        return AiResponse(
            message: 'Logged $kcals calories directly to your diet log.',
            intent: 'diet_log',
            actions: [
              AiAction(type: 'food_entry', payload: {
                'name': foodName,
                'calories': kcals,
                'protein': 0.0,
                'carbs': 0.0,
                'fat': 0.0,
                'meal_type': 'snack'
              })
            ]);
      }

      // Quick calorie burn: "i burned 200 kcal while cycling"
      final burnRegex = RegExp(
          r'(?:burned|burnt|burn)\s+(\d+(?:\.\d+)?)\s*(?:kcal|calories|cal)(?:\s+(?:while|by|doing|from)\s+(.*))?',
          caseSensitive: false);
      final burnMatch = burnRegex.firstMatch(lower);
      if (burnMatch != null) {
        final kcals = double.tryParse(burnMatch.group(1) ?? '0') ?? 0;
        // The activity could contain trailing words like "today", let's strip them
        String activity = burnMatch.group(2)?.trim() ?? 'Activity';
        activity = activity.replaceAll(RegExp(r'\s+today$'), '');
        return AiResponse(
            message: 'Logged $kcals calories burned from $activity.',
            intent: 'diet_burn',
            actions: [
              AiAction(type: 'burn_entry', payload: {
                'activity': activity,
                'calories_burned': kcals,
                'duration_minutes': 0,
              })
            ]);
      }

      // Hydration: "drank 2 glass of water"
      final drinkRegex = RegExp(
          r'(?:drank|drink)\s+(\d+(?:\.\d+)?)\s*(glass|glasses|liter|liters|ml)?\s*(?:of\s+)?(water|milk|juice)',
          caseSensitive: false);
      final drinkMatch = drinkRegex.firstMatch(lower);
      if (drinkMatch != null) {
        return AiResponse(
            message: 'Logged your drink locally.',
            intent: 'diet_log',
            actions: [
              AiAction(type: 'food_entry', payload: {
                'name':
                    '${drinkMatch.group(1)} ${drinkMatch.group(2) ?? 'units'} of ${drinkMatch.group(3)}',
                'calories': drinkMatch.group(3) == 'water' ? 0 : 50,
                'protein': 0.0,
                'carbs': 0.0,
                'fat': 0.0,
                'meal_type': 'snack'
              })
            ]);
      }
    } else if (intent == 'general' ||
        lower.contains('play') ||
        lower.contains('video')) {
      // Speech vault: "play a motivation video"
      final playVideoRegex = RegExp(r'play\s+(?:a\s+)?(.*)\s*(?:video|speech)',
          caseSensitive: false);
      final playMatch = playVideoRegex.firstMatch(lower);
      if (playMatch != null) {
        final query = playMatch.group(1)!.trim().toLowerCase();
        return AiResponse(
            message: 'Opening video related to "$query" from the Speech Vault.',
            intent: 'general_chat',
            actions: [
              AiAction(type: 'play_vault_video', payload: {'query': query})
            ]);
      }
    }

    // Return null to fallback to Gemini if no regex matches confidently
    return null;
  }

  AiResponse? _handleTasksLocally(String message) {
    final lower = message.toLowerCase().trim();

    if (_isTaskStatusQuery(lower)) {
      return _buildTaskStatusResponse(lower);
    }

    final doneMatch = RegExp(
      r'^(?:mark|complete|completed|finish|finished|done)\s+(?:my\s+|the\s+)?(.+?)(?:\s+(?:task|mission))?$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (doneMatch != null &&
        !_containsAny(
            lower, ['today', 'tomorrow', 'this week', 'this month'])) {
      final completed = _completeMatchingTask(doneMatch.group(1) ?? '');
      if (completed != null) {
        return AiResponse(
          message: 'Marked "${completed.title}" as complete.',
          intent: 'general_chat',
        );
      }
    }

    if (!_looksLikeTaskCreate(lower)) return null;

    final draft = _parseTaskDraft(message);
    if (draft == null) return null;

    final endText = draft.endDate != null
        ? ' until ${DateFormat('MMM d').format(draft.endDate!)}'
        : '';
    final targetText = draft.targetValue == 1 && draft.unit == 'times'
        ? ''
        : ' (${_numText(draft.targetValue)} ${draft.unit})';

    return AiResponse(
      message:
          'Ready to create ${draft.type.name} mission: ${draft.title}$targetText$endText.',
      intent: 'task_create',
      actions: [
        AiAction(type: 'task_create', payload: {
          'title': draft.title,
          'type': draft.type.name,
          'target_value': draft.targetValue,
          'unit': draft.unit,
          'category': draft.category.name,
          if (draft.endDate != null)
            'end_date': draft.endDate!.toIso8601String(),
        })
      ],
    );
  }

  AiResponse _buildTaskStatusResponse(String lower) {
    final box = Hive.box<Goal>('mission_box_v4');
    final today = _dateOnly(DateTime.now());
    final todayGoals = box.values.where((goal) {
      if (goal.isArchived) return false;
      if (goal.type != GoalType.today && goal.type != GoalType.daily)
        return false;
      if (goal.endDate != null && _dateOnly(goal.endDate!).isBefore(today))
        return false;
      return true;
    }).toList();

    final completedGoals = todayGoals.where((g) => g.isCompleted).toList();
    final remainingGoals = todayGoals.where((g) => !g.isCompleted).toList();

    final buffer = StringBuffer(
      'Today you finished ${completedGoals.length}/${todayGoals.length} missions.',
    );

    if (completedGoals.isNotEmpty &&
        _containsAny(
            lower, ['what', 'finished', 'completed', 'done', 'status'])) {
      buffer.write(
          ' Finished: ${completedGoals.map((g) => g.title).join(', ')}.');
    }
    if (remainingGoals.isNotEmpty &&
        _containsAny(
            lower, ['remaining', 'left', 'pending', 'status', 'today'])) {
      buffer.write(
          ' Remaining: ${remainingGoals.map((g) => g.title).join(', ')}.');
    }
    if (todayGoals.isEmpty) {
      buffer.write(' No active today/daily missions are scheduled.');
    } else if (remainingGoals.isEmpty) {
      buffer.write(' Everything for today is done.');
    }

    return AiResponse(message: buffer.toString(), intent: 'general_chat');
  }

  Goal? _completeMatchingTask(String query) {
    final cleanQuery = _cleanWords(query);
    if (cleanQuery.isEmpty) return null;

    final box = Hive.box<Goal>('mission_box_v4');
    Goal? bestGoal;
    var bestScore = 0;

    for (final goal in box.values) {
      if (goal.isArchived || goal.isCompleted) continue;
      final title = _cleanWords(goal.title);
      var score = 0;
      if (title == cleanQuery) {
        score = 100;
      } else if (title.contains(cleanQuery) || cleanQuery.contains(title)) {
        score = 70;
      } else {
        final queryWords = cleanQuery.split(' ');
        for (final word in queryWords) {
          if (word.length > 2 && title.contains(word)) score += 12;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestGoal = goal;
      }
    }

    if (bestGoal != null && bestScore >= 24) {
      bestGoal.complete();
      box.put(bestGoal.id, bestGoal);
      return bestGoal;
    }
    return null;
  }

  _TaskDraft? _parseTaskDraft(String message) {
    final lower = message.toLowerCase();
    final isDaily = _containsAny(
        lower, ['everyday', 'every day', 'daily', 'each day', 'per day']);
    final GoalType type;
    if (isDaily) {
      type = GoalType.daily;
    } else if (lower.contains('this week') || lower.contains('weekly')) {
      type = GoalType.weekly;
    } else if (lower.contains('this month') || lower.contains('monthly')) {
      type = GoalType.monthly;
    } else {
      type = GoalType.today;
    }

    final phrase = _stripTaskNoise(message);
    final parsed = _extractTaskTarget(phrase);
    final title = _titleCase(parsed['title'] as String);
    if (title.length < 2) return null;

    return _TaskDraft(
      title: title,
      type: type,
      category: _inferTaskCategory(title),
      targetValue: parsed['targetValue'] as double,
      unit: parsed['unit'] as String,
      endDate: _inferTaskEndDate(lower, type),
    );
  }

  Map<String, dynamic> _extractTaskTarget(String phrase) {
    var clean = _cleanWords(phrase);
    if (clean.isEmpty) {
      return {'title': '', 'targetValue': 1.0, 'unit': 'times'};
    }

    final unitMatch = RegExp(
      r'\b(\d+(?:\.\d+)?)\s*(hours?|hrs?|hr|minutes?|mins?|min|pages?|chapters?|lectures?|lessons?|sets?|reps?|push\s*ups?|pull\s*ups?|squats?|steps?|km|kilometers?|kilometres?)\b',
      caseSensitive: false,
    ).firstMatch(clean);

    if (unitMatch != null) {
      final target = double.tryParse(unitMatch.group(1) ?? '') ?? 1.0;
      final rawUnit = unitMatch.group(2) ?? 'times';
      final unit = _normalizeTaskUnit(rawUnit);
      final before = clean.substring(0, unitMatch.start).trim();
      final after = clean
          .substring(unitMatch.end)
          .replaceFirst(RegExp(r'^(of|for)\s+', caseSensitive: false), '')
          .trim();

      String title;
      if (_isExerciseUnit(rawUnit) && before.isEmpty) {
        title = rawUnit.replaceAll(RegExp(r'\s+'), ' ');
      } else {
        title =
            [before, after].where((part) => part.isNotEmpty).join(' ').trim();
        if (title.isEmpty) title = rawUnit.replaceAll(RegExp(r'\s+'), ' ');
      }

      return {
        'title': _removeGenericTaskVerbs(title),
        'targetValue': target,
        'unit': unit
      };
    }

    final numberMatch = RegExp(r'\b(\d+(?:\.\d+)?)\b').firstMatch(clean);
    if (numberMatch != null) {
      final target = double.tryParse(numberMatch.group(1) ?? '') ?? 1.0;
      clean = clean.replaceRange(numberMatch.start, numberMatch.end, '').trim();
      return {
        'title': _removeGenericTaskVerbs(clean),
        'targetValue': target,
        'unit': 'times'
      };
    }

    return {
      'title': _removeGenericTaskVerbs(clean),
      'targetValue': 1.0,
      'unit': 'times'
    };
  }

  String _stripTaskNoise(String message) {
    var clean = message.toLowerCase();
    clean = clean.replaceAll(RegExp(r'[.!?]'), ' ');
    clean = clean.replaceAll(RegExp(r"\bi[' ]?ll\b"), 'i will');
    clean = clean.replaceAll(RegExp(r'\b(this|next)\s+(week|month)\b'), ' ');
    clean = clean.replaceAll(RegExp(r'\b(today|tonight|tomorrow)\b'), ' ');
    clean = clean.replaceAll(
        RegExp(r'\b(everyday|every day|daily|each day|per day)\b'), ' ');
    clean = clean.replaceAll(
        RegExp(r'\b(?:for|next)\s+\d+(?:\.\d+)?\s+(?:days?|weeks?|months?)\b'),
        ' ');
    clean = clean.replaceAll(RegExp(r'\buntil\s+[a-z0-9 ,/-]+$'), ' ');

    final prefix = RegExp(
      r'^(?:please\s+)?(?:add(?:\s+a)?(?:\s+daily)?(?:\s+task)?(?:\s+to)?|create(?:\s+a)?(?:\s+task)?|make(?:\s+a)?(?:\s+task)?|set(?:\s+up)?|remind\s+me\s+to|i\s+will|i\s+am\s+going\s+to|i\s+need\s+to|i\s+want\s+to|going\s+to|task|mission|to|do)\s+',
      caseSensitive: false,
    );

    var previous = '';
    while (previous != clean) {
      previous = clean;
      clean = clean.replaceFirst(prefix, '').trim();
    }

    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    clean = clean.replaceFirst(RegExp(r'^(a|an|the)\s+'), '');
    return clean;
  }

  DateTime? _inferTaskEndDate(String lower, GoalType type) {
    final now = DateTime.now();
    final untilDate = _parseUntilDate(lower);
    if (untilDate != null) return _endOfDay(untilDate);

    final durationMatch = RegExp(
      r'\b(?:for|next)\s+(\d+)\s+(days?|weeks?|months?)\b',
      caseSensitive: false,
    ).firstMatch(lower);
    if (durationMatch != null) {
      final count = int.tryParse(durationMatch.group(1) ?? '') ?? 1;
      final unit = durationMatch.group(2) ?? 'days';
      if (unit.startsWith('week'))
        return _endOfDay(now.add(Duration(days: (count * 7) - 1)));
      if (unit.startsWith('month'))
        return _endOfDay(DateTime(now.year, now.month + count, now.day)
            .subtract(const Duration(days: 1)));
      return _endOfDay(now.add(Duration(days: count - 1)));
    }

    if (lower.contains('this week'))
      return _endOfDay(now.add(Duration(days: DateTime.sunday - now.weekday)));
    if (lower.contains('this month'))
      return _endOfDay(DateTime(now.year, now.month + 1, 0));
    if (lower.contains('tomorrow'))
      return _endOfDay(now.add(const Duration(days: 1)));
    if (lower.contains('today') ||
        lower.contains('tonight') ||
        type == GoalType.today) return _endOfDay(now);

    return null;
  }

  DateTime? _parseUntilDate(String lower) {
    final match =
        RegExp(r'\buntil\s+(.+)$', caseSensitive: false).firstMatch(lower);
    if (match == null) return null;

    var raw = (match.group(1) ?? '').trim();
    raw = raw.replaceAll(RegExp(r'[.!?]'), '');
    raw = raw
        .replaceAll(RegExp(r'\b(everyday|every day|daily|task|mission)\b'), '')
        .trim();

    final numeric =
        RegExp(r'(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?').firstMatch(raw);
    if (numeric != null) {
      final day = int.tryParse(numeric.group(1) ?? '');
      final month = int.tryParse(numeric.group(2) ?? '');
      var year = int.tryParse(numeric.group(3) ?? '') ?? DateTime.now().year;
      if (year < 100) year += 2000;
      if (day != null && month != null) return DateTime(year, month, day);
    }

    final weekdays = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };
    final isNext = raw.startsWith('next ');
    raw = raw.replaceFirst(RegExp(r'^next\s+'), '').trim();

    int? weekday;
    for (final entry in weekdays.entries) {
      if (raw.startsWith(entry.key)) {
        weekday = entry.value;
        break;
      }
    }

    if (weekday != null) {
      final now = DateTime.now();
      var days = weekday - now.weekday;
      if (days < 0 || (isNext && days == 0)) days += 7;
      return now.add(Duration(days: days));
    }

    return null;
  }

  AiResponse? _handleFinanceLocally(String message) {
    final lower = message.toLowerCase().trim();

    // Invariant §6.9 & P11-4: Check privacy switch
    if (Hive.isBoxOpen('finance_settings')) {
      final allowed = Hive.box('finance_settings')
          .get('ai_finance_privacy', defaultValue: true);
      if (allowed == false) {
        return AiResponse(
          message:
              'Finance AI features are disabled in Settings > AI & Privacy.',
          intent: 'finance',
        );
      }
    }

    // 1. What-If simulator fast path ("Can I afford a ₹50,000 phone?")
    final whatIfResponse = _handleWhatIfLocally(lower);
    if (whatIfResponse != null) return whatIfResponse;

    // 2. Deterministic natural-language query ("spent on Swiggy last month", "top 5 merchants", "net worth")
    final queryResponse = _handleFinanceQueryLocally(lower);
    if (queryResponse != null) return queryResponse;

    if (_isSipQuery(lower)) return _buildSipResponse();
    if (_isFinanceSummaryQuery(lower)) return _buildFinanceSummaryResponse();

    final amount = _extractMoneyAmount(lower);
    if (amount == null || amount <= 0) return null;

    // 3. Transfer fast path ("Transfer 5000 from HDFC to ICICI")
    final transferResponse = _handleTransferLocally(lower, amount);
    if (transferResponse != null) return transferResponse;

    // 4. Recurring bill fast path ("Add recurring bill Netflix 649 monthly")
    final recurringResponse = _handleRecurringLocally(lower, amount);
    if (recurringResponse != null) return recurringResponse;

    final budgetDraft = _parseFinanceBudgetDraft(lower, amount);
    if (budgetDraft != null) {
      return AiResponse(
        message:
            'Ready to set ${budgetDraft['category']} budget to ${_formatMoney(amount)}.',
        intent: 'finance_advice',
        actions: [
          AiAction(type: 'finance_budget', payload: budgetDraft),
        ],
      );
    }

    final sipDraft = _parseFinanceSipDraft(lower, amount);
    if (sipDraft != null) {
      return AiResponse(
        message:
            'Ready to add SIP ${sipDraft['name']} for ${_formatMoney(amount)} per month.',
        intent: 'finance_advice',
        actions: [
          AiAction(type: 'finance_sip', payload: sipDraft),
        ],
      );
    }

    final commitmentDraft = _parseFinanceCommitmentDraft(lower, amount);
    if (commitmentDraft != null) {
      return AiResponse(
        message:
            'Ready to add monthly commitment ${commitmentDraft['name']} for ${_formatMoney(amount)}.',
        intent: 'finance_advice',
        actions: [
          AiAction(type: 'finance_commitment', payload: commitmentDraft),
        ],
      );
    }

    final goalDraft = _parseFinanceGoalDraft(lower, amount);
    if (goalDraft != null) {
      return AiResponse(
        message:
            'Ready to add finance goal ${goalDraft['name']} for ${_formatMoney(amount)}.',
        intent: 'finance_advice',
        actions: [
          AiAction(type: 'finance_goal', payload: goalDraft),
        ],
      );
    }

    final isExpense = _looksLikeExpense(lower);
    final isIncome = _looksLikeIncome(lower);

    if (isIncome && !isExpense) {
      final title = _extractIncomeTitle(lower);
      return AiResponse(
        message: 'Ready to add ${_formatMoney(amount)} income as "$title".',
        intent: 'finance_advice',
        actions: [
          AiAction(type: 'finance_transaction', payload: {
            'title': title,
            'amount': amount,
            'mode': 'income',
            'category': 'Income',
          }),
        ],
      );
    }

    if (isExpense) {
      final title = _extractExpenseTitle(lower);
      final category = _inferExpenseCategory(title);
      return AiResponse(
        message:
            'Ready to log ${_formatMoney(amount)} expense for "$title" under $category.',
        intent: 'finance_advice',
        actions: [
          AiAction(type: 'finance_transaction', payload: {
            'title': title,
            'amount': amount,
            'mode': 'expense',
            'category': category,
          }),
        ],
      );
    }

    return null;
  }

  AiResponse? _handleWhatIfLocally(String lower) {
    if (!_containsAny(
        lower, ['can i afford', 'afford a', 'afford to buy', 'can i buy'])) {
      return null;
    }
    final amount = _extractMoneyAmount(lower);
    if (amount == null || amount <= 0) return null;

    String itemName = lower
        .replaceAll(
            RegExp(r'can i afford\s*(?:a|an|the)?', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'afford\s*(?:to\s+buy)?\s*(?:a|an|the)?',
                caseSensitive: false),
            '')
        .replaceAll(
            RegExp(r'can i buy\s*(?:a|an|the)?', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'(?:for|\?|\b)(?:₹|rs\.?|inr)?\s*[\d,]+(?:\.\d+)?\b',
                caseSensitive: false),
            '')
        .trim();
    if (itemName.isEmpty) itemName = 'Purchase';

    final controller = FinanceController();
    final txs = controller.allTransactions;
    final now = DateTime.now();

    final liquid = controller.getLiquidBalance(asOf: now);

    final past3mExpenses = txs.where((t) {
      final diffDays = now.difference(t.date).inDays;
      return diffDays >= 0 && diffDays <= 90 && t.effectiveKind == 'expense';
    }).fold<double>(0.0, (sum, t) => sum + t.amount.abs());
    final avgMonthlyExpense =
        past3mExpenses > 0 ? (past3mExpenses / 3.0) : 10000.0;
    final emergencyBuffer = avgMonthlyExpense;

    final past3mIncome = txs.where((t) {
      final diffDays = now.difference(t.date).inDays;
      return diffDays >= 0 &&
          diffDays <= 90 &&
          (t.effectiveKind == 'income' || t.effectiveKind == 'refund');
    }).fold<double>(0.0, (sum, t) => sum + t.amount.abs());
    final avgSurplus =
        ((past3mIncome - past3mExpenses) / 3.0).clamp(0.0, double.infinity);

    final result = WhatIfEngine.canAfford(
      amount: amount,
      forecastMonthEnd: liquid,
      emergencyBuffer: emergencyBuffer,
      avgMonthlySurplus3m: avgSurplus,
    );

    final buffer = StringBuffer();
    buffer.writeln('Verdict: ${result.title}');
    buffer.writeln(result.explanation);
    buffer.writeln(result.recommendation);
    if (result.monthsToSave != null && result.monthsToSave! > 0) {
      buffer.writeln(
          'Estimated saving time: ~${result.monthsToSave} months (saving ${FormatUtils.formatMoney(avgSurplus, decimals: 0)}/mo).');
    }

    return AiResponse(
      message: buffer.toString().trim(),
      intent: 'finance_whatif',
      actions: [
        AiAction(
          type: 'finance_whatif',
          payload: {
            'item_name': itemName,
            'amount': amount,
            'status': result.status.name,
            'projected_after': result.projectedAfter,
          },
        ),
      ],
    );
  }

  AiResponse? _handleFinanceQueryLocally(String lower) {
    final controller = FinanceController();
    final now = DateTime.now();

    // 1. Net worth query
    if (lower.contains('net worth') || lower.contains('networth')) {
      final query = const FinanceQuery(subject: QuerySubject.networth);
      final res = FinanceQueryExecutor.execute(
        query: query,
        transactions: controller.allTransactions,
        accounts: controller.activeAccounts,
        today: now,
      );
      return AiResponse(message: res.formattedAnswer, intent: 'finance_query');
    }

    // 2. Account balance query
    if (lower.contains('balance')) {
      String? accountFilter;
      for (final a in controller.activeAccounts) {
        if (lower.contains(a.name.toLowerCase())) {
          accountFilter = a.name;
          break;
        }
      }
      final query = FinanceQuery(
        subject: QuerySubject.balance,
        filters: QueryFilters(account: accountFilter),
      );
      final res = FinanceQueryExecutor.execute(
        query: query,
        transactions: controller.allTransactions,
        accounts: controller.activeAccounts,
        today: now,
      );
      return AiResponse(message: res.formattedAnswer, intent: 'finance_query');
    }

    // 3. Top merchants query
    if (lower.contains('top') &&
        (lower.contains('merchant') ||
            lower.contains('payee') ||
            lower.contains('store') ||
            lower.contains('place'))) {
      int topN = 5;
      final match = RegExp(r'top\s+(\d+)').firstMatch(lower);
      if (match != null) {
        topN = int.tryParse(match.group(1)!) ?? 5;
      }
      final query = FinanceQuery(
        metric: QueryMetric.top,
        subject: QuerySubject.spending,
        groupBy: QueryGroupBy.merchant,
        topN: topN,
      );
      final res = FinanceQueryExecutor.execute(
        query: query,
        transactions: controller.allTransactions,
        accounts: controller.activeAccounts,
        today: now,
      );
      return AiResponse(message: res.formattedAnswer, intent: 'finance_query');
    }

    // 4. "How much did I spend" / "Spent on ..." / "Expenses this month"
    final isSpendQuery = lower.contains('how much') ||
        lower.contains('what did i spend') ||
        lower.contains('spent on') ||
        lower.contains('expenses on') ||
        lower.contains('spending on') ||
        lower.contains('spending this') ||
        lower.contains('spent this') ||
        lower.contains('spent last');

    if (isSpendQuery) {
      QueryPeriod period = QueryPeriod.thisMonth;
      if (lower.contains('last month') || lower.contains('pichle mahine')) {
        period = QueryPeriod.lastMonth;
      } else if (lower.contains('this week') || lower.contains('is hafte')) {
        period = QueryPeriod.thisWeek;
      } else if (lower.contains('last week') ||
          lower.contains('pichle hafte')) {
        period = QueryPeriod.lastWeek;
      } else if (lower.contains('today') || lower.contains('aaj')) {
        period = QueryPeriod.today;
      } else if (lower.contains('yesterday') || lower.contains('kal')) {
        period = QueryPeriod.yesterday;
      } else if (lower.contains('this year') || lower.contains('is saal')) {
        period = QueryPeriod.thisYear;
      } else if (lower.contains('last year') || lower.contains('pichle saal')) {
        period = QueryPeriod.lastYear;
      }

      String? merchant;
      for (final m in controller.allMerchants) {
        if (m.isNotEmpty && lower.contains(m.toLowerCase())) {
          merchant = m;
          break;
        }
      }

      String? category;
      for (final c in controller.activeCategories) {
        if (c.name.isNotEmpty && lower.contains(c.name.toLowerCase())) {
          category = c.name;
          break;
        }
      }

      final query = FinanceQuery(
        metric: QueryMetric.sum,
        subject: QuerySubject.spending,
        filters: QueryFilters(
          merchant: merchant,
          category: category,
          period: period,
        ),
      );

      final res = FinanceQueryExecutor.execute(
        query: query,
        transactions: controller.allTransactions,
        accounts: controller.activeAccounts,
        today: now,
        categories: controller.activeCategories,
      );
      return AiResponse(message: res.formattedAnswer, intent: 'finance_query');
    }

    return null;
  }

  AiResponse? _handleTransferLocally(String lower, double amount) {
    if (!lower.contains('transfer') && !lower.contains('bhejo')) return null;

    final controller = FinanceController();
    final accounts = controller.activeAccounts;

    String? fromAccount;
    String? toAccount;

    for (final a in accounts) {
      if (lower.contains('from ${a.name.toLowerCase()}') ||
          lower.contains('${a.name.toLowerCase()} se')) {
        fromAccount = a.name;
      }
      if (lower.contains('to ${a.name.toLowerCase()}') ||
          lower.contains('${a.name.toLowerCase()} me') ||
          lower.contains('${a.name.toLowerCase()} mein')) {
        toAccount = a.name;
      }
    }

    if (fromAccount == null && accounts.isNotEmpty) {
      fromAccount = accounts.first.name;
    }
    if (toAccount == null && accounts.length > 1) {
      toAccount = accounts
          .firstWhere((a) => a.name != fromAccount, orElse: () => accounts.last)
          .name;
    }

    return AiResponse(
      message:
          'Ready to transfer ${_formatMoney(amount)} from $fromAccount to $toAccount.',
      intent: 'finance_advice',
      actions: [
        AiAction(
          type: 'finance_transfer',
          payload: {
            'amount': amount,
            'from_account': fromAccount,
            'to_account': toAccount,
          },
        ),
      ],
    );
  }

  AiResponse? _handleRecurringLocally(String lower, double amount) {
    final isRec = lower.contains('recurring') ||
        lower.contains('subscription') ||
        lower.contains('bill') ||
        lower.contains('every month') ||
        lower.contains('har mahine');
    if (!isRec) return null;

    String frequency = 'monthly';
    if (lower.contains('weekly') || lower.contains('har hafte'))
      frequency = 'weekly';
    if (lower.contains('quarterly')) frequency = 'quarterly';
    if (lower.contains('yearly') || lower.contains('annual'))
      frequency = 'yearly';

    String kind = 'bill';
    if (lower.contains('subscription')) kind = 'subscription';
    if (lower.contains('sip')) kind = 'sip';
    if (lower.contains('emi')) kind = 'emi';

    String name = 'Recurring Item';
    final prefixes = ['recurring', 'subscription', 'bill for', 'bill', 'add'];
    String cleaned = lower;
    for (final p in prefixes) {
      cleaned = cleaned.replaceAll(p, '');
    }
    cleaned = cleaned
        .replaceAll(
            RegExp(
                r'(?:every\s+\w+|monthly|weekly|quarterly|yearly|₹|rs\.?|inr|[\d,]+(?:\.\d+)?)'),
            '')
        .trim();
    if (cleaned.isNotEmpty) name = _titleCase(cleaned);

    return AiResponse(
      message:
          'Ready to add $frequency $kind "$name" for ${_formatMoney(amount)}.',
      intent: 'finance_advice',
      actions: [
        AiAction(
          type: 'finance_recurring',
          payload: {
            'name': name,
            'amount': amount,
            'frequency': frequency,
            'kind': kind,
          },
        ),
      ],
    );
  }

  AiResponse _buildSipResponse() {
    final controller = FinanceController();
    final sips =
        controller.allRecurringRules.where((r) => r.kind == 'sip').toList();
    final monthlySip = sips.fold<double>(0, (sum, rule) => sum + rule.amount);

    final details = sips.map((rule) {
      return '${rule.name}: ${FormatUtils.formatMoney(rule.amount)}/mo';
    }).join(', ');

    final msg = StringBuffer(
        'Your current SIP commitment is ${FormatUtils.formatMoney(monthlySip)}/month.');
    if (details.isNotEmpty) msg.write(' ($details).');

    return AiResponse(message: msg.toString(), intent: 'general_chat');
  }

  AiResponse _buildFinanceSummaryResponse() {
    final txBox = Hive.box<Transaction>('finance_transactions');
    final vaultBox = Hive.box<AssetVault>('finance_vaults');
    final settingsBox = Hive.box('finance_settings');
    final now = DateTime.now();

    double monthIncome = 0;
    double monthExpense = 0;
    double allTimeNet = 0;

    for (final tx in txBox.values) {
      final mode = tx.mode.toLowerCase();
      final isExpense = mode == 'expense' || tx.amount < 0;
      final signedAmount = isExpense ? -tx.amount.abs() : tx.amount.abs();
      allTimeNet += signedAmount;

      if (tx.date.month == now.month && tx.date.year == now.year) {
        if (isExpense) {
          monthExpense += tx.amount.abs();
        } else {
          monthIncome += tx.amount.abs();
        }
      }
    }

    final goals = List.from(settingsBox.get('goals', defaultValue: []));
    final goalsSaved = goals.fold<double>(
        0, (sum, item) => sum + _asDouble((item as Map)['saved']));
    final vaultTotal =
        vaultBox.values.fold<double>(0, (sum, vault) => sum + vault.balance);
    final totalBalance = vaultTotal + allTimeNet + goalsSaved;

    return AiResponse(
      message:
          'This month: income ${_formatMoney(monthIncome)}, expenses ${_formatMoney(monthExpense)}, net ${_formatMoney(monthIncome - monthExpense)}. Current tracked balance is ${_formatMoney(totalBalance)}.',
      intent: 'general_chat',
    );
  }

  AiResponse? _handleDietLocally(String message) {
    final lower = message.toLowerCase().trim();

    if (_isDietStatusQuery(lower)) return _buildDietStatusResponse();

    final burnMatch = RegExp(
      r'\b(?:burned|burnt|burn)\s+(\d+(?:\.\d+)?)\s*(?:kcal|calories|cal)(?:\s+(?:while|by|doing|from)\s+(.*))?',
      caseSensitive: false,
    ).firstMatch(lower);
    if (burnMatch != null) {
      final kcals = double.tryParse(burnMatch.group(1) ?? '0') ?? 0;
      var activity = burnMatch.group(2)?.trim() ?? 'Activity';
      activity = activity.replaceAll(RegExp(r'\s+(today|tonight)$'), '');
      return AiResponse(
        message:
            'Ready to log ${_numText(kcals)} calories burned from $activity.',
        intent: 'diet_burn',
        actions: [
          AiAction(type: 'burn_entry', payload: {
            'activity': _titleCase(activity),
            'calories_burned': kcals,
            'duration_minutes': 0,
          })
        ],
      );
    }

    final drinkMatch = RegExp(
      r'\b(?:drank|drink|had)\s+(\d+(?:\.\d+)?)?\s*(glass|glasses|liter|liters|litre|litres|ml)?\s*(?:of\s+)?(water|milk|juice)\b',
      caseSensitive: false,
    ).firstMatch(lower);
    if (drinkMatch != null) {
      final qty = drinkMatch.group(1) ?? '1';
      final unit = drinkMatch.group(2) ?? 'glass';
      final drink = drinkMatch.group(3) ?? 'water';
      return AiResponse(
        message: 'Ready to log $qty $unit of $drink.',
        intent: 'diet_log',
        actions: [
          AiAction(type: 'food_entry', payload: {
            'name': '${_numText(double.tryParse(qty) ?? 1)} $unit of $drink',
            'calories': drink == 'water' ? 0.0 : 50.0,
            'protein': 0.0,
            'carbs': drink == 'water' ? 0.0 : 12.0,
            'fat': 0.0,
            'meal_type': _inferMealType(lower),
          })
        ],
      );
    }

    final amountFirst = RegExp(
      r'\b(?:ate|consumed|had|eat|log)\s+(\d+(?:\.\d+)?)\s*(?:kcal|calories|cal)(?:\s+(?:of|from)\s+(.*?))?(?:\s+today)?$',
      caseSensitive: false,
    ).firstMatch(lower);
    final nameFirst = RegExp(
      r'\b(?:ate|consumed|had|eat|log)\s+(.+?)\s+(?:for|with)?\s*(\d+(?:\.\d+)?)\s*(?:kcal|calories|cal)\b',
      caseSensitive: false,
    ).firstMatch(lower);

    if (amountFirst != null || nameFirst != null) {
      final calories = amountFirst != null
          ? double.tryParse(amountFirst.group(1) ?? '0') ?? 0
          : double.tryParse(nameFirst!.group(2) ?? '0') ?? 0;
      var foodName = amountFirst != null
          ? (amountFirst.group(2)?.trim().isNotEmpty == true
              ? amountFirst.group(2)!.trim()
              : 'Quick Entry')
          : (nameFirst!.group(1)?.trim() ?? 'Quick Entry');
      foodName = foodName.replaceAll(RegExp(r'\s+(today|tonight)$'), '').trim();

      return AiResponse(
        message:
            'Ready to log ${_numText(calories)} calories for ${_titleCase(foodName)}.',
        intent: 'diet_log',
        actions: [
          AiAction(type: 'food_entry', payload: {
            'name': _titleCase(foodName),
            'calories': calories,
            'protein': _extractMacro(lower, 'protein'),
            'carbs': _extractMacro(lower, 'carbs'),
            'fat': _extractMacro(lower, 'fat'),
            'meal_type': _inferMealType(lower),
          })
        ],
      );
    }

    return null;
  }

  AiResponse _buildDietStatusResponse() {
    final log = getTodayLog();
    final remaining = log.targetCalories - log.netCalories;
    final foodList = log.entries.isEmpty
        ? 'No food logged yet.'
        : 'Food: ${log.entries.map((e) => e.name).join(', ')}.';
    final burnList = log.burnEntries.isEmpty
        ? ''
        : ' Burned: ${log.burnEntries.map((e) => '${e.activity} ${_numText(e.caloriesBurned)} kcal').join(', ')}.';

    return AiResponse(
      message:
          'Diet today: ${_numText(log.totalCalories)} kcal in, ${_numText(log.totalBurned)} burned, net ${_numText(log.netCalories)}. ${remaining >= 0 ? _numText(remaining) : _numText(remaining.abs())} kcal ${remaining >= 0 ? 'remaining' : 'over target'}. $foodList$burnList',
      intent: 'general_chat',
    );
  }

  AiResponse? _handleVaultLocally(String message) {
    final lower = message.toLowerCase().trim();
    if (!_looksLikeVaultCommand(lower)) return null;

    var query = lower;
    query = query.replaceAll(RegExp(r'\b(play|open|watch|show|start)\b'), ' ');
    query = query.replaceAll(
        RegExp(r'\b(a|an|the|from|in|my|vault|video|speech|youtube)\b'), ' ');
    query = query.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (query.isEmpty && lower.contains('motivation')) query = 'motivation';
    if (query.isEmpty) query = 'motivation';

    return AiResponse(
      message:
          'I found this as a vault request. Tap Accept to open a "$query" video from the Vault.',
      intent: 'general_chat',
      actions: [
        AiAction(type: 'play_vault_video', payload: {'query': query})
      ],
    );
  }

  bool _looksLikeWakeIntent(String lower) {
    if (_containsAny(lower, [
      'woke up',
      'wake up',
      'wakeup',
      'woke at',
      'woke by',
      'woken up',
      'uth gaya',
      'baje utha',
      'pe utha',
      'ko utha',
      'wake streak',
      'wake target',
      'wake time',
      'wake status',
    ])) {
      return true;
    }
    if (WakeParser.parseLog(lower) != null) return true;
    if (WakeParser.parseTask(lower) != null) return true;
    return false;
  }

  bool _looksLikeWearIntent(String lower) {
    if (_containsAny(lower, [
      'galaxy watch',
      'samsung health',
      'sync watch',
      'sync my watch',
      'refresh watch',
      'update watch',
      'wearable',
      'ages index',
      'energy score',
      'body composition',
      'skeletal muscle',
      'body fat',
    ])) {
      return true;
    }
    if (lower.contains('watch') &&
        _containsAny(lower,
            ['sync', 'status', 'battery', 'connect', 'steps', 'sleep'])) {
      return true;
    }
    if ((lower.contains('step') || lower.contains('steps')) &&
        _containsAny(lower, ['today', 'how many', 'count', 'walked', 'goal'])) {
      return true;
    }
    if (lower.contains('sleep') &&
        _containsAny(
            lower, ['score', 'last night', 'how long', 'how much', 'hours'])) {
      return true;
    }
    if (lower.contains('energy') &&
        _containsAny(lower, ['score', 'today', 'how is', 'my energy'])) {
      return true;
    }
    return false;
  }

  bool _looksLikeJournalNote(String lower) {
    return lower.startsWith('journal:') ||
        lower.startsWith('journal note:') ||
        lower.startsWith('log note:') ||
        lower.startsWith('note to journal:') ||
        lower.startsWith('note:') ||
        lower.startsWith("today's note:");
  }

  Future<AiResponse?> _handleWakeLocally(String message) async {
    final lower = message.toLowerCase().trim();

    // Check for conversational undo
    if (lower == 'undo' ||
        lower == 'undo wake' ||
        lower == 'undo wake up' ||
        lower == 'undo wakeup') {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await WakeService.instance.undo(today);
      return AiResponse(
        message: 'Reverted today\'s wake-up log and reversed awarded XP.',
        intent: 'general_chat',
      );
    }

    // 1. Check if it is a wake log (e.g. "woke up at 6:15", "aaj 6 baje utha", "uth gaya 5:30 am")
    final logDraft = WakeParser.parseLog(message);
    if (logDraft != null) {
      final result =
          await WakeService.instance.logWake(logDraft.wakeAt, source: 'chat');
      final formattedTime = DateFormat('hh:mm a').format(logDraft.wakeAt);
      final dayKey = DateFormat('yyyy-MM-dd').format(logDraft.wakeAt);
      final streak = result.goal?.streakCount ?? (result.onTime ? 1 : 0);
      final statusText = result.evaluation?.statusText ??
          (result.onTime ? 'On time (+5 XP)' : 'Missed target');

      final responseMsg = '${result.message} (Streak: 🔥 $streak)';

      return AiResponse(
        message: responseMsg,
        intent: 'wakeup_log',
        actions: [
          AiAction(
            type: 'wakeup_log',
            payload: {
              'wake_at': logDraft.wakeAt.toIso8601String(),
              'day_key': dayKey,
              'formatted_time': formattedTime,
              'on_time': result.onTime,
              'streak': streak,
              'status_text': statusText,
              'auto_executed': true,
            },
            isConfirmed: true,
          ),
        ],
      );
    }

    // 2. Check if it is a task creation (e.g. "create wake-up task at 5:00 AM", "set wake up goal 5:30 am")
    final taskDraft = WakeParser.parseTask(message);
    if (taskDraft != null) {
      final goal = await WakeService.instance.createOrUpdateWakeupTask(
        targetMinutes: taskDraft.targetMinutes,
        title: taskDraft.title,
      );
      final h = taskDraft.targetMinutes ~/ 60;
      final m = taskDraft.targetMinutes % 60;
      final timeStr =
          '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

      return AiResponse(
        message:
            'Created daily wake-up mission: target $timeStr (+5 XP on time).',
        intent: 'wakeup_task_create',
        actions: [
          AiAction(
            type: 'wakeup_task_create',
            payload: {
              'target_minutes': taskDraft.targetMinutes,
              'time_str': timeStr,
              'goal_id': goal.id,
            },
            isConfirmed: true,
          ),
        ],
      );
    }

    // 3. Status query: "wake status", "what is my wake streak", etc.
    if (_containsAny(lower,
        ['status', 'streak', 'target', 'today', 'how', 'when', 'what'])) {
      final goal = WakeService.instance.getWakeupGoal();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayLog = WakeLogRepository.instance.getLog(today);

      if (goal == null && todayLog == null) {
        return AiResponse(
          message:
              'No wake-up task is configured yet. Say "Create wake-up task at 5:00 AM" to set one up.',
          intent: 'general_chat',
        );
      }

      final targetH =
          ((goal?.targetMinutes ?? 300) ~/ 60).toString().padLeft(2, '0');
      final targetM =
          ((goal?.targetMinutes ?? 300) % 60).toString().padLeft(2, '0');
      final streak = goal?.streakCount ?? 0;

      final buf = StringBuffer(
          'Wake-up Target: $targetH:$targetM. Streak: 🔥 $streak days.');
      if (todayLog != null) {
        buf.write(
            ' Today: Logged at ${DateFormat('hh:mm a').format(todayLog.wakeAt)} (${todayLog.onTime ? 'On time ✓' : 'Missed ✕'}).');
      } else {
        buf.write(' Not yet logged for today.');
      }

      return AiResponse(message: buf.toString(), intent: 'general_chat');
    }

    return null;
  }

  Future<AiResponse?> _handleWearLocally(String message) async {
    final lower = message.toLowerCase().trim();

    // 1. Sync Watch Action
    if (lower.contains('sync') ||
        lower.contains('refresh watch') ||
        lower.contains('update watch')) {
      SyncService.instance.sync();
      return AiResponse(
        message: 'Syncing your Galaxy Watch with Samsung Health...',
        intent: 'wear',
        actions: [
          AiAction(
            type: 'wear_sync',
            payload: {'action': 'sync'},
            isConfirmed: true,
          ),
        ],
      );
    }

    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final view = WearableRepository.instance.dayView(todayKey);

    // 2. Steps Query
    if (lower.contains('step')) {
      final steps = view.totalSteps;
      final goal = view.activity?.stepGoal ?? WearableSettings.stepGoalDefault;
      if (steps > 0) {
        final pct = ((steps / goal) * 100).round();
        return AiResponse(
          message:
              'You have walked ${NumberFormat('#,###').format(steps)} steps today ($pct% of your $goal step goal).',
          intent: 'wear',
        );
      } else {
        return AiResponse(
          message:
              'No steps recorded for today yet. Make sure your Galaxy Watch is connected and synced.',
          intent: 'wear',
        );
      }
    }

    // 3. Sleep Query
    if (lower.contains('sleep')) {
      final sleep = view.mainSleep;
      if (sleep != null && sleep.durationMin > 0) {
        final h = sleep.durationMin ~/ 60;
        final m = sleep.durationMin % 60;
        final scoreStr =
            sleep.score != null ? ' (Sleep Score: ${sleep.score})' : '';
        return AiResponse(
          message: 'You slept for ${h}h ${m}m last night$scoreStr.',
          intent: 'wear',
        );
      } else {
        return AiResponse(
          message: 'No sleep data recorded for last night yet.',
          intent: 'wear',
        );
      }
    }

    // 4. Weight Query
    if (lower.contains('weight')) {
      final weight = view.latestWeight;
      if (weight != null) {
        return AiResponse(
          message: 'Your recorded weight for today is  kg.',
          intent: 'wear',
        );
      } else {
        return AiResponse(
          message: 'No weight recorded for today yet.',
          intent: 'wear',
        );
      }
    }

    // 5. Heart Rate Query
    if (lower.contains('heart rate') ||
        lower.contains('hr') ||
        lower.contains('bpm')) {
      final hr = view.restingHeartRate;
      if (hr != null) {
        return AiResponse(
          message: 'Your resting heart rate today is  bpm.',
          intent: 'wear',
        );
      } else {
        return AiResponse(
          message: 'No resting heart rate recorded for today yet.',
          intent: 'wear',
        );
      }
    }

    // 6. Workout / Exercise Query
    if (lower.contains('workout') || lower.contains('exercise')) {
      final exercises = view.exercises;
      if (exercises.isNotEmpty) {
        final lines = exercises.map((e) {
          final title = e.title ?? e.type;
          final cal = e.totalKcal ?? e.activeKcal;
          final calStr = cal != null ? ', ${cal.round()} kcal' : '';
          return '• $title (${e.durationMin}m$calStr)';
        }).join('\n');
        return AiResponse(
          message: 'Today\'s Workouts (${exercises.length}):\n$lines',
          intent: 'wear',
        );
      } else {
        return AiResponse(
          message: 'No workouts recorded for today yet.',
          intent: 'wear',
        );
      }
    }

    // 7. Body Composition Query
    if (lower.contains('body') ||
        lower.contains('fat') ||
        lower.contains('muscle') ||
        lower.contains('weight')) {
      final body = view.bodyComp;
      if (body != null) {
        final parts = <String>[];
        if (body.weightKg != null)
          parts.add('Weight: ${body.weightKg!.toStringAsFixed(1)} kg');
        if (body.bodyFatPct != null)
          parts.add('Body Fat: ${body.bodyFatPct!.toStringAsFixed(1)}%');
        if (body.skeletalMuscleMassKg != null)
          parts.add(
              'Muscle: ${body.skeletalMuscleMassKg!.toStringAsFixed(1)} kg');
        if (body.bmi != null) parts.add('BMI: ${body.bmi!.toStringAsFixed(1)}');
        return AiResponse(
          message: 'Latest Body Composition:\n${parts.join(' · ')}',
          intent: 'wear',
        );
      } else {
        return AiResponse(
          message: 'No body composition data recorded yet.',
          intent: 'wear',
        );
      }
    }

    // 8. General Watch Overview
    final steps = view.totalSteps;
    final sleep = view.mainSleep;
    final energy = view.energy?.score;
    final overview = <String>[];
    if (steps > 0)
      overview.add('Steps: ${NumberFormat('#,###').format(steps)}');
    if (sleep != null && sleep.durationMin > 0) {
      overview
          .add('Sleep: ${sleep.durationMin ~/ 60}h ${sleep.durationMin % 60}m');
    }
    if (energy != null) overview.add('Energy: $energy/100');

    if (overview.isNotEmpty) {
      return AiResponse(
        message: 'Galaxy Watch 7 Status Today:\n${overview.join(' · ')}',
        intent: 'wear',
      );
    } else {
      return AiResponse(
        message:
            'Galaxy Watch connected, but no health records have been synced for today yet. Say "sync watch" to refresh.',
        intent: 'wear',
      );
    }
  }

  Future<AiResponse?> _handleJournalLocally(String message) async {
    final note = message
        .replaceFirst(
          RegExp(
              r"^(?:journal:\s*|journal\s+note:\s*|log\s+note:\s*|note\s+to\s+journal:\s*|note:\s*|today's\s+note:\s*)",
              caseSensitive: false),
          '',
        )
        .trim();

    if (note.isEmpty) {
      return AiResponse(
        message: 'Please provide some text to save to your journal.',
        intent: 'general_chat',
      );
    }

    final now = DateTime.now();
    final dayKey = DateFormat('yyyy-MM-dd').format(now);
    final repo = JournalDayRepository.instance;
    await repo.appendNote(dayKey, note, time: now);

    return AiResponse(
      message: 'Saved to today\'s journal: "$note"',
      intent: 'journal_note',
      actions: [
        AiAction(
          type: 'journal_note',
          payload: {
            'day_key': dayKey,
            'text': note,
            'timestamp': now.toIso8601String(),
          },
          isConfirmed: true,
        ),
      ],
    );
  }

  bool _containsAny(String text, List<String> needles) {
    for (final needle in needles) {
      if (text.contains(needle)) return true;
    }
    return false;
  }

  bool _looksLikeFinanceIntent(String lower) {
    if (_containsAny(lower, [
      'sip',
      'emi',
      'budget',
      'finance',
      'income',
      'salary',
      'expense',
      'spent',
      'bought',
      'paid',
      'rupee',
      'rupees',
      'rs',
      'inr',
      'money',
      'savings',
      'invest',
      'investment',
      'mutual fund',
      'loan',
      'debt',
      'rent',
      'bill',
      'recharge',
      'shopping',
      'paisa',
      'kharcha',
      'transaction'
    ])) {
      return true;
    }

    final hasMoney = _extractMoneyAmount(lower) != null;
    if (hasMoney &&
        _containsAny(lower, ['save', 'buy', 'worth', 'goal', 'fund'])) {
      return true;
    }
    return false;
  }

  bool _looksLikeVaultCommand(String lower) {
    if (_containsAny(lower, ['song', 'music', 'track', 'album'])) return false;
    final wantsMedia =
        _containsAny(lower, ['play', 'open', 'watch', 'show', 'start']);
    final vaultWords =
        _containsAny(lower, ['video', 'speech', 'vault', 'youtube']);
    final motivationVideo =
        _containsAny(lower, ['motivation', 'motivational']) && wantsMedia;
    return wantsMedia && (vaultWords || motivationVideo);
  }

  bool _isTaskStatusQuery(String lower) {
    final asksStatus = _containsAny(lower, [
      'how much',
      'how many',
      'remaining',
      'left',
      'pending',
      'finished',
      'completed',
      'done',
      'status'
    ]);
    final taskContext =
        _containsAny(lower, ['task', 'tasks', 'mission', 'missions', 'today']);
    return asksStatus && taskContext;
  }

  bool _looksLikeTaskCreate(String lower) {
    if (_containsAny(lower, [
      'i will',
      "i'll",
      'ill ',
      'i am going',
      'i need to',
      'i want to',
      'remind me',
      'add task',
      'add a task',
      'create task',
      'todo'
    ])) {
      return true;
    }
    if (_containsAny(lower, [
      'daily',
      'everyday',
      'every day',
      'this week',
      'this month',
      'today',
      'tonight',
      'tomorrow'
    ])) {
      return RegExp(
              r'\b(study|read|workout|exercise|gym|homework|hw|practice|finish|complete|do|write|call|clean|learn)\b')
          .hasMatch(lower);
    }
    return false;
  }

  bool _looksLikeIncome(String lower) {
    return _containsAny(lower, [
      'income',
      'earned',
      'received',
      'salary',
      'got paid',
      'credited',
      'credit',
      'deposit'
    ]);
  }

  bool _looksLikeExpense(String lower) {
    return _containsAny(lower, [
      'spent',
      'bought',
      'paid',
      'buy',
      'expense',
      'reduce',
      'deduct',
      'debited',
      'cost',
      'ordered'
    ]);
  }

  bool _isSipQuery(String lower) {
    return lower.contains('sip') &&
        _containsAny(
            lower, ['current', 'what', 'how much', 'total', 'show', 'my']);
  }

  bool _isFinanceSummaryQuery(String lower) {
    return _containsAny(lower, [
      'balance',
      'summary',
      'expenses',
      'expense report',
      'income report',
      'spent this month',
      'current money',
      'finance status'
    ]);
  }

  Map<String, dynamic>? _parseFinanceBudgetDraft(String lower, double amount) {
    if (!lower.contains('budget')) return null;
    return {
      'category': _inferBudgetCategory(lower),
      'total': amount,
    };
  }

  Map<String, dynamic>? _parseFinanceSipDraft(String lower, double amount) {
    final looksLikeSip = lower.contains('sip') ||
        lower.contains('mutual fund') ||
        (_containsAny(lower, ['invest', 'investment']) &&
            _containsAny(lower, ['monthly', 'every month', 'per month']));
    if (!looksLikeSip) return null;

    final name = _extractFinanceName(
      lower,
      fallback: 'Mutual Fund',
      noiseWords: const [
        'add',
        'set',
        'start',
        'create',
        'new',
        'my',
        'monthly',
        'month',
        'sip',
        'invest',
        'investment',
        'amount',
        'worth',
        'of',
        'for',
        'in',
        'into',
        'to',
      ],
    );

    return {
      'name': name,
      'amount': amount,
      'due': _extractDueDay(lower) ?? 5,
    };
  }

  Map<String, dynamic>? _parseFinanceCommitmentDraft(
      String lower, double amount) {
    if (lower.contains('sip') || lower.contains('budget')) return null;
    final recurring = _containsAny(lower, [
      'monthly',
      'every month',
      'per month',
      'each month',
      'recurring',
      'commitment',
      'fixed expense',
      'fixed cost',
      'subscription',
      'emi',
      'rent',
      'insurance',
      'saving',
      'savings'
    ]);
    if (!recurring) return null;

    final category = _inferCommitmentCategory(lower);
    final name = _extractFinanceName(
      lower,
      fallback: category,
      noiseWords: const [
        'add',
        'set',
        'create',
        'new',
        'my',
        'monthly',
        'month',
        'every',
        'per',
        'each',
        'recurring',
        'commitment',
        'fixed',
        'expense',
        'cost',
        'payment',
        'emi',
        'loan',
        'rent',
        'insurance',
        'subscription',
        'amount',
        'of',
        'for',
        'on',
        'to',
      ],
    );

    return {
      'name': name,
      'amount': amount,
      'date': _extractDueDay(lower) ?? 1,
      'category': category,
    };
  }

  Map<String, dynamic>? _parseFinanceGoalDraft(String lower, double amount) {
    if (lower.contains('budget') || lower.contains('sip')) return null;
    if (lower.contains('emi') &&
        _containsAny(lower, ['monthly', 'every month', 'per month'])) {
      return null;
    }

    final explicitGoal = _containsAny(lower, [
      'finance goal',
      'financial goal',
      'saving goal',
      'savings goal',
      'goal'
    ]);
    final saveFor = RegExp(r'\bsav(?:e|ing)\b.*\bfor\b').hasMatch(lower);
    final buyWorth = lower.contains('buy') &&
        (_containsAny(lower, ['worth', 'for']) || amount >= 5000);
    if (!explicitGoal && !saveFor && !buyWorth) return null;
    if (_looksLikeExpense(lower) && !saveFor && !explicitGoal && !buyWorth) {
      return null;
    }

    final name = _extractFinanceName(
      lower,
      fallback: 'Goal',
      noiseWords: const [
        'add',
        'set',
        'create',
        'new',
        'my',
        'finance',
        'financial',
        'saving',
        'savings',
        'save',
        'goal',
        'target',
        'want',
        'need',
        'buy',
        'purchase',
        'worth',
        'amount',
        'of',
        'for',
        'to',
      ],
    );

    return {
      'name': name,
      'target': amount,
    };
  }

  String _inferBudgetCategory(String lower) {
    const categories = [
      'Food',
      'Shopping',
      'Transport',
      'Utilities',
      'Health',
      'Entertainment',
      'OTT',
      'Groceries',
      'EMI',
      'Other',
    ];

    for (final category in categories) {
      if (lower.contains(category.toLowerCase())) return category;
    }
    if (_containsAny(lower, ['grocery', 'vegetable', 'milk'])) {
      return 'Groceries';
    }
    if (_containsAny(lower, ['movie', 'netflix', 'prime', 'spotify'])) {
      return lower.contains('netflix') ||
              lower.contains('prime') ||
              lower.contains('spotify')
          ? 'OTT'
          : 'Entertainment';
    }
    if (_containsAny(lower, ['loan', 'emi'])) return 'EMI';
    return 'Other';
  }

  String _inferCommitmentCategory(String lower) {
    if (lower.contains('emi') || lower.contains('loan')) return 'EMI';
    if (lower.contains('rent')) return 'Rent';
    if (lower.contains('insurance')) return 'Insurance';
    if (_containsAny(lower, ['saving', 'savings'])) return 'Savings';
    if (_containsAny(lower, ['netflix', 'prime', 'spotify', 'subscription'])) {
      return 'Subscription';
    }
    return 'Fixed';
  }

  int? _extractDueDay(String lower) {
    final explicit = RegExp(
      r'\b(?:due|date|day|on)\s*(?:day\s*)?(\d{1,2})(?:st|nd|rd|th)?\b',
      caseSensitive: false,
    ).firstMatch(lower);
    final parsed = int.tryParse(explicit?.group(1) ?? '');
    if (parsed != null && parsed >= 1 && parsed <= 31) return parsed;
    return null;
  }

  String _extractFinanceName(String lower,
      {required String fallback, required List<String> noiseWords}) {
    var clean = lower;
    clean = clean.replaceAll(
      RegExp(
        r'(?:rs\.?|inr|rupees?|\$)?\s*\d+(?:,\d{3})*(?:\.\d+)?\s*(?:k|thousand|lakh|lakhs|lac|lacs|m|million|cr|crore|crores)?\s*(?:rs\.?|inr|rupees?|\$)?',
        caseSensitive: false,
      ),
      ' ',
    );
    clean = clean.replaceAll(RegExp(r'\b\d{1,2}(?:st|nd|rd|th)\b'), ' ');
    clean = clean.replaceAll(RegExp(r'[^\w\s]'), ' ');

    final words = [
      ...noiseWords,
      'i',
      'am',
      'a',
      'an',
      'the',
      'please',
      'rs',
      'inr',
      'rupee',
      'rupees',
      'k',
      'lakh',
      'lakhs',
      'lac',
      'lacs',
      'crore',
      'crores',
      'due',
      'date',
      'day',
      'on',
      'at',
      'by',
      'from',
      'with',
      'and',
      'of',
      'for',
      'to',
      'in',
      'into',
      'worth',
      'amount',
      'buy',
      'purchase',
      'invest',
      'investment',
      'save',
      'saving',
      'savings',
    ];
    for (final word in words) {
      clean = clean.replaceAll(RegExp('\\b${RegExp.escape(word)}\\b'), ' ');
    }

    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return fallback;
    return _titleCase(clean);
  }

  bool _isDietStatusQuery(String lower) {
    final asksDiet = _containsAny(lower, [
      'diet',
      'calorie',
      'calories',
      'food',
      'eat',
      'eaten',
      'protein',
      'macros'
    ]);
    final asksStatus = _containsAny(lower,
        ['status', 'remaining', 'left', 'today', 'how much', 'what did']);
    return asksDiet && asksStatus;
  }

  String _cleanWords(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _titleCase(String input) {
    final clean = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return clean;
    return clean
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part.length == 1
            ? part.toUpperCase()
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _removeGenericTaskVerbs(String input) {
    var clean = input.trim();
    clean = clean.replaceFirst(
        RegExp(r'^(do|complete|finish|make|task|mission)\s+'), '');
    return clean.trim();
  }

  GoalCategory _inferTaskCategory(String title) {
    final lower = title.toLowerCase();
    if (_containsAny(lower, [
      'push',
      'pull',
      'squat',
      'gym',
      'workout',
      'run',
      'walk',
      'steps',
      'exercise'
    ])) return GoalCategory.fitness;
    if (_containsAny(lower, [
      'study',
      'read',
      'homework',
      'hw',
      'lecture',
      'chapter',
      'book',
      'learn'
    ])) return GoalCategory.learning;
    if (_containsAny(lower, ['sleep', 'water', 'meditate', 'medicine', 'diet']))
      return GoalCategory.health;
    if (_containsAny(lower, ['guitar', 'draw', 'paint', 'music', 'game']))
      return GoalCategory.hobby;
    return GoalCategory.productivity;
  }

  String _normalizeTaskUnit(String rawUnit) {
    final raw = rawUnit.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (raw.startsWith('hour') || raw == 'hr' || raw.startsWith('hrs'))
      return 'hours';
    if (raw.startsWith('min')) return 'minutes';
    if (raw.startsWith('page')) return 'pages';
    if (raw.startsWith('chapter')) return 'chapters';
    if (raw.startsWith('lecture')) return 'lectures';
    if (raw.startsWith('lesson')) return 'lessons';
    if (raw.startsWith('step')) return 'steps';
    if (raw == 'km' || raw.startsWith('kilo')) return 'km';
    if (_isExerciseUnit(raw)) return 'reps';
    return raw;
  }

  bool _isExerciseUnit(String rawUnit) {
    final raw = rawUnit.toLowerCase();
    return raw.contains('push') ||
        raw.contains('pull') ||
        raw.contains('squat') ||
        raw.contains('rep');
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _endOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59);

  double? _extractMoneyAmount(String lower) {
    final currencyMatch = RegExp(
      r'(?:rs\.?|inr|rupees?|\$)\s*(\d+(?:,\d{3})*(?:\.\d+)?)\s*(k|thousand|lakh|lakhs|lac|lacs|m|million|cr|crore|crores)?|(\d+(?:,\d{3})*(?:\.\d+)?)\s*(k|thousand|lakh|lakhs|lac|lacs|m|million|cr|crore|crores)?\s*(?:rs\.?|inr|rupees?|\$)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (currencyMatch != null) {
      final value = currencyMatch.group(1) ?? currencyMatch.group(3) ?? '';
      final suffix = currencyMatch.group(2) ?? currencyMatch.group(4);
      return _parseMoneyValue(value, suffix);
    }

    final contextualMatch = RegExp(
      r'\b(?:for|on|paid|spent|reduce|deduct(?:ed)?|add|set|create|start|earned|received|income|salary|credited|deposit(?:ed)?|worth|amount|target|save|invest)\s+(?:rs\.?|inr|rupees?|\$)?\s*(\d+(?:,\d{3})*(?:\.\d+)?)\s*(k|thousand|lakh|lakhs|lac|lacs|m|million|cr|crore|crores)?\s*(?:rs\.?|inr|rupees?|\$)?',
      caseSensitive: false,
    ).firstMatch(lower);
    if (contextualMatch != null) {
      return _parseMoneyValue(
          contextualMatch.group(1) ?? '', contextualMatch.group(2));
    }

    final suffixMatch = RegExp(
      r'\b(\d+(?:,\d{3})*(?:\.\d+)?)\s*(k|thousand|lakh|lakhs|lac|lacs|m|million|cr|crore|crores)\b',
      caseSensitive: false,
    ).firstMatch(lower);
    if (suffixMatch != null) {
      return _parseMoneyValue(suffixMatch.group(1) ?? '', suffixMatch.group(2));
    }

    final matches = RegExp(r'\b(\d+(?:,\d{3})*(?:\.\d+)?)\b')
        .allMatches(lower)
        .map((match) => _parseMoneyValue(match.group(1) ?? '', null))
        .whereType<double>()
        .toList();
    if (matches.isEmpty) return null;
    return matches.reduce((a, b) => a > b ? a : b);
  }

  double? _parseMoneyValue(String raw, String? suffix) {
    final value = double.tryParse(raw.replaceAll(',', ''));
    if (value == null) return null;
    final unit = suffix?.toLowerCase();
    if (unit == null || unit.isEmpty) return value;
    if (unit == 'k' || unit == 'thousand') return value * 1000;
    if (unit == 'lakh' || unit == 'lakhs' || unit == 'lac' || unit == 'lacs') {
      return value * 100000;
    }
    if (unit == 'm' || unit == 'million') return value * 1000000;
    if (unit == 'cr' || unit == 'crore' || unit == 'crores') {
      return value * 10000000;
    }
    return value;
  }

  String _extractIncomeTitle(String lower) {
    if (lower.contains('salary')) return 'Salary';
    final fromMatch =
        RegExp(r'\bfrom\s+(.+)$', caseSensitive: false).firstMatch(lower);
    if (fromMatch != null) return 'Income from ${fromMatch.group(1)!.trim()}';
    return 'Income';
  }

  String _extractExpenseTitle(String lower) {
    final bought = RegExp(
      r'\bbought\s+(?:a|an|the)?\s*(.+?)\s+(?:for|at)\s+(?:rs\.?|inr|rupees?)?\s*\d',
      caseSensitive: false,
    ).firstMatch(lower);
    if (bought != null) return _cleanFinanceTitle(bought.group(1) ?? '');

    final spent = RegExp(
      r'\b(?:spent|paid|reduce|deduct(?:ed)?)\s+(?:rs\.?|inr|rupees?)?\s*\d[\d,.]*\s*(?:rs\.?|inr|rupees?)?\s*(?:on|for|towards)?\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (spent != null) return _cleanFinanceTitle(spent.group(1) ?? '');

    final cost = RegExp(
      r'\b(.+?)\s+cost(?:ed)?\s+(?:rs\.?|inr|rupees?)?\s*\d',
      caseSensitive: false,
    ).firstMatch(lower);
    if (cost != null) return _cleanFinanceTitle(cost.group(1) ?? '');

    return 'Expense';
  }

  String _cleanFinanceTitle(String value) {
    var clean = value
        .replaceAll(
            RegExp(r'\b(today|tonight|yesterday|please|bro|dude)\b'), '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    clean = clean.replaceFirst(RegExp(r'^(a|an|the)\s+'), '');
    return clean.isEmpty ? 'Expense' : clean;
  }

  String _inferExpenseCategory(String title) {
    final lower = title.toLowerCase();
    if (_containsAny(lower, [
      'pepsi',
      'coke',
      'coffee',
      'tea',
      'chai',
      'snack',
      'lunch',
      'dinner',
      'breakfast',
      'food',
      'swiggy',
      'zomato'
    ])) return 'Food';
    if (_containsAny(lower, [
      'bus',
      'train',
      'metro',
      'cab',
      'uber',
      'ola',
      'petrol',
      'diesel',
      'fuel',
      'auto'
    ])) return 'Transport';
    if (_containsAny(lower, [
      'bill',
      'electricity',
      'water',
      'wifi',
      'internet',
      'recharge',
      'phone'
    ])) return 'Utilities';
    if (_containsAny(lower, ['medicine', 'doctor', 'hospital', 'health']))
      return 'Health';
    if (_containsAny(
        lower, ['movie', 'game', 'netflix', 'prime', 'spotify', 'ott']))
      return 'Entertainment';
    if (_containsAny(lower, ['grocery', 'groceries', 'vegetable', 'milk']))
      return 'Groceries';
    if (_containsAny(lower, ['emi', 'loan'])) return 'EMI';
    if (_containsAny(
        lower, ['shirt', 'jeans', 'amazon', 'flipkart', 'shopping']))
      return 'Shopping';
    return 'Other';
  }

  String _formatMoney(double value) {
    final fixed = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return 'Rs $fixed';
  }

  String _numText(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _inferMealType(String lower) {
    if (lower.contains('breakfast')) return 'breakfast';
    if (lower.contains('lunch')) return 'lunch';
    if (lower.contains('dinner')) return 'dinner';
    final hour = DateTime.now().hour;
    if (hour < 11) return 'breakfast';
    if (hour < 16) return 'lunch';
    if (hour > 19) return 'dinner';
    return 'snack';
  }

  double _extractMacro(String lower, String macro) {
    final match =
        RegExp('(\\d+(?:\\.\\d+)?)\\s*g?\\s*$macro', caseSensitive: false)
            .firstMatch(lower);
    if (match != null) return double.tryParse(match.group(1) ?? '') ?? 0.0;
    final reverse =
        RegExp('$macro\\s*(\\d+(?:\\.\\d+)?)\\s*g?', caseSensitive: false)
            .firstMatch(lower);
    return double.tryParse(reverse?.group(1) ?? '') ?? 0.0;
  }

  void _initModel() {
    _messagesHistory = [];
  }

  // System prompt moved to AiContext

  /// Tier 1 — On-Device Deterministic Fast-Path (0 API Tokens)
  Future<AiResponse?> tryHandleOnDevice(String userMessage) async {
    final trimmed = userMessage.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();

    // 1. Diet Pattern: Hydration (e.g., "drank 500ml water", "drink 250 ml water", "drank 2 glasses of water")
    final waterMatch = RegExp(
      r'(?:drank|drink|had|logged)\s+(\d+(?:\.\d+)?)\s*(ml|liters?|l|glasses?|glass)?(?:\s+(?:of\s+)?water)?',
      caseSensitive: false,
    ).firstMatch(lower);
    if (waterMatch != null && (lower.contains('water') || lower.contains('ml') || lower.contains('glass'))) {
      final amount = double.tryParse(waterMatch.group(1) ?? '250') ?? 250.0;
      final unit = (waterMatch.group(2) ?? 'ml').toLowerCase();
      double ml = amount;
      if (unit.startsWith('glass')) {
        ml = amount * 250.0;
      } else if (unit.startsWith('l')) {
        ml = amount * 1000.0;
      }
      await DietRepository.instance.addWater(ml);
      final action = AiAction(
        type: 'diet_water',
        payload: {'ml': ml},
        isConfirmed: true,
        sector: 'diet',
        op: 'log_water',
      );
      return AiResponse(
        message: 'Logged ${ml.round()} ml of water intake.',
        intent: 'diet_log',
        actions: [action],
      );
    }

    // 2. Diet Pattern: Food Log (e.g. "log 400 cal oats 15g protein for breakfast")
    final isDietKeyword = lower.startsWith('log ') || lower.startsWith('ate ') || lower.startsWith('eat ') || lower.startsWith('had ');
    if (isDietKeyword && (lower.contains('cal') || lower.contains('kcal') || lower.contains('protein') || lower.contains('for breakfast') || lower.contains('for lunch') || lower.contains('for dinner') || lower.contains('for snack'))) {
      final calMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:cal|kcal|calories)').firstMatch(lower);
      final cal = calMatch != null ? double.tryParse(calMatch.group(1)!) ?? 0.0 : 0.0;

      final pMatch = RegExp(r'(\d+(?:\.\d+)?)\s*g?\s*protein').firstMatch(lower);
      final protein = pMatch != null ? double.tryParse(pMatch.group(1)!) ?? 0.0 : 0.0;

      final cMatch = RegExp(r'(\d+(?:\.\d+)?)\s*g?\s*carbs?').firstMatch(lower);
      final carbs = cMatch != null ? double.tryParse(cMatch.group(1)!) ?? 0.0 : 0.0;

      final fMatch = RegExp(r'(\d+(?:\.\d+)?)\s*g?\s*fats?').firstMatch(lower);
      final fat = fMatch != null ? double.tryParse(fMatch.group(1)!) ?? 0.0 : 0.0;

      MealSlot slot = MealSlot.snack;
      if (lower.contains('breakfast')) {
        slot = MealSlot.breakfast;
      } else if (lower.contains('lunch')) {
        slot = MealSlot.lunch;
      } else if (lower.contains('dinner')) {
        slot = MealSlot.dinner;
      }

      String name = trimmed
          .replaceAll(RegExp(r'^(?:log|ate|eat|had)\s+', caseSensitive: false), '')
          .replaceAll(RegExp(r'\b\d+(?:\.\d+)?\s*(?:cal|kcal|calories)\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\b\d+(?:\.\d+)?\s*g?\s*protein\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\b\d+(?:\.\d+)?\s*g?\s*carbs?\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\b\d+(?:\.\d+)?\s*g?\s*fats?\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\bfor\s+(?:breakfast|lunch|dinner|snack|snacks)\b', caseSensitive: false), '')
          .trim();
      if (name.isEmpty) name = 'Quick Food Entry';

      final entryId = 'log_${DateTime.now().millisecondsSinceEpoch}';
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final entry = DietLogEntry(
        id: entryId,
        dateIso: today,
        mealSlot: slot,
        title: name,
        quantity: 1.0,
        gramsTotal: 100,
        kcal: cal,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
      );

      await DietRepository.instance.logFood(entry);
      final action = AiAction(
        type: 'food_entry',
        payload: {
          'id': entry.id,
          'log_id': entry.id,
          'name': entry.title,
          'calories': entry.kcal,
          'protein': entry.proteinG,
          'carbs': entry.carbsG,
          'fat': entry.fatG,
          'meal_type': entry.mealSlot,
        },
        isConfirmed: true,
        sector: 'diet',
        op: 'log_meal',
      );
      return AiResponse(
        message: 'Logged "${entry.title}" (${entry.kcal.round()} kcal, ${entry.proteinG.round()}g P) for ${entry.mealSlot}.',
        intent: 'diet_log',
        actions: [action],
      );
    }

    // 3. Finance Pattern (e.g. "spent 120 onshawarma", "spent 120 on shawarma", "paid 50 auto")
    final expenseMatch = RegExp(
      r'^(?:spent|paid|bought|reduce)\s+(?:rs|₹)?\s*(\d+(?:\.\d+)?)(?:rs|₹)?\s+(?:on|for)?\s*(.*)',
      caseSensitive: false,
    ).firstMatch(lower);

    final incomeMatch = RegExp(
      r'^(?:add|got|received|earned|made)\s+(?:rs|₹)?\s*(\d+(?:\.\d+)?)(?:rs|₹)?\s*(?:to\s+(?:my\s+)?income|\s+income|\s+from\s+(.*))?',
      caseSensitive: false,
    ).firstMatch(lower);

    if (expenseMatch != null) {
      final amount = double.tryParse(expenseMatch.group(1) ?? '0') ?? 0.0;
      String rawTitle = (expenseMatch.group(2) ?? '').trim();
      if (rawTitle.isEmpty) rawTitle = 'Expense';
      final cleanMerchant = MerchantNormalizer.normalize(rawTitle);
      final title = cleanMerchant.isNotEmpty ? cleanMerchant : rawTitle;

      String cat = 'Other';
      final rules = FinanceRepository().storage.ruleBox.values.toList();
      final matchedCatId = CategorizationRulesEngine.matchCategory(
        description: title,
        rules: rules,
      );
      if (matchedCatId != null && matchedCatId.isNotEmpty) {
        cat = matchedCatId;
      } else {
        final tLow = title.toLowerCase();
        if (tLow.contains('shawarma') || tLow.contains('food') || tLow.contains('lunch') || tLow.contains('dinner') || tLow.contains('coffee') || tLow.contains('tea') || tLow.contains('pepsi') || tLow.contains('snack')) {
          cat = 'Food';
        } else if (tLow.contains('auto') || tLow.contains('uber') || tLow.contains('ola') || tLow.contains('cab') || tLow.contains('metro') || tLow.contains('bus') || tLow.contains('petrol') || tLow.contains('fuel')) {
          cat = 'Transport';
        } else if (tLow.contains('recharge') || tLow.contains('wifi') || tLow.contains('electricity') || tLow.contains('bill')) {
          cat = 'Bills';
        }
      }

      final draft = TxDraft(
        title: title[0].toUpperCase() + title.substring(1),
        amount: -amount,
        date: DateTime.now(),
        mode: 'expense',
        category: cat,
        icon: cat == 'Food' ? 'utensils' : (cat == 'Transport' ? 'car' : 'shopping-cart'),
        kind: 'expense',
      );
      final tx = await FinanceRepository().addTransaction(draft);
      final action = AiAction(
        type: 'finance_transaction',
        payload: {
          'tx_id': tx.id,
          'title': draft.title,
          'amount': amount,
          'mode': 'expense',
          'category': cat,
        },
        isConfirmed: true,
        sector: 'finance',
        op: 'add_tx',
      );
      return AiResponse(
        message: 'Recorded ₹${amount.toStringAsFixed(0)} expense for ${draft.title} under $cat.',
        intent: 'finance_transaction',
        actions: [action],
      );
    }

    if (incomeMatch != null && (lower.contains('income') || lower.contains('received') || lower.contains('earned') || lower.contains('salary'))) {
      final amount = double.tryParse(incomeMatch.group(1) ?? '0') ?? 0.0;
      String source = (incomeMatch.group(2) ?? 'Income').trim();
      if (source.isEmpty) source = 'Income';

      final draft = TxDraft(
        title: source[0].toUpperCase() + source.substring(1),
        amount: amount,
        date: DateTime.now(),
        mode: 'income',
        category: 'Income',
        icon: 'wallet',
        kind: 'income',
      );
      final tx = await FinanceRepository().addTransaction(draft);
      final action = AiAction(
        type: 'finance_transaction',
        payload: {
          'tx_id': tx.id,
          'title': draft.title,
          'amount': amount,
          'mode': 'income',
          'category': 'Income',
        },
        isConfirmed: true,
        sector: 'finance',
        op: 'add_tx',
      );
      return AiResponse(
        message: 'Added ₹${amount.toStringAsFixed(0)} income to your wallet.',
        intent: 'finance_transaction',
        actions: [action],
      );
    }

    // 4. Habit Pattern: Strictly Recurring Routines (e.g. "add habit code 1 hour every day")
    final isHabitCommand = lower.startsWith('add habit ') || lower.startsWith('create habit ');
    if (isHabitCommand || ((lower.startsWith('add ') || lower.startsWith('create ')) && (lower.contains('every day') || lower.contains('everyday') || lower.contains('daily')))) {
      String habitTitle = trimmed
          .replaceAll(RegExp(r'^(?:add|create)\s+habit\s+', caseSensitive: false), '')
          .replaceAll(RegExp(r'^(?:add|create)\s+', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+(?:everyday|every\s+day|daily)$', caseSensitive: false), '')
          .trim();
      if (habitTitle.isEmpty) habitTitle = 'New Routine';

      final habitId = 'habit_${DateTime.now().millisecondsSinceEpoch}';
      final habit = ForgivingHabitItem(
        id: habitId,
        name: habitTitle,
        category: 'Routines',
        frequency: 'daily',
        targetPerWeek: 7,
      );
      final pairedTask = TaskItem(
        id: 'task_${habit.id}',
        title: habitTitle,
        status: TaskStatus.todo,
        priority: TaskPriority.medium,
        isHabit: true,
        recurrenceFrequency: 'daily',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await TaskOsRepository.instance.saveHabit(habit);
      await TaskOsRepository.instance.saveTask(pairedTask);

      final action = AiAction(
        type: 'habit_create',
        payload: {
          'id': habit.id,
          'habit_id': habit.id,
          'title': habit.title,
          'frequency': 'daily',
        },
        isConfirmed: true,
        sector: 'habits',
        op: 'add_habit',
      );
      return AiResponse(
        message: 'Created daily recurring habit "$habitTitle".',
        intent: 'habit_create',
        actions: [action],
      );
    }

    // 5. Task Pattern: Strictly One-Time Task (e.g. "add task finish OS record today")
    if (lower.startsWith('add task ') || lower.startsWith('create task ') || lower.startsWith('todo ') || lower.startsWith('remind me to ')) {
      final rawTask = trimmed
          .replaceAll(RegExp(r'^(?:add\s+task|create\s+task|todo|remind\s+me\s+to)\s+', caseSensitive: false), '');
      final parsed = parseNaturalLanguageTask(rawTask, DateTime.now());
      final taskId = 'task_${DateTime.now().millisecondsSinceEpoch}';
      final taskDate = DateFormat('yyyy-MM-dd').format(parsed.dueAt ?? DateTime.now());

      final task = TaskItem(
        id: taskId,
        title: parsed.cleanTitle.isNotEmpty ? parsed.cleanTitle : rawTask,
        status: TaskStatus.todo,
        priority: parsed.priority,
        dueAt: parsed.dueAt ?? DateTime.now(),
        hasDueTime: parsed.hasDueTime,
        isHabit: false, // STRICTLY ONE-TIME
        recurrenceFrequency: 'none',
        recurrenceRule: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await TaskOsRepository.instance.saveTask(task);
      final action = AiAction(
        type: 'task_create',
        payload: {
          'id': task.id,
          'task_id': task.id,
          'title': task.title,
          'date': task.scheduledDate,
          'isHabit': false,
        },
        isConfirmed: true,
        sector: 'tasks',
        op: 'add_task',
      );
      return AiResponse(
        message: 'Created one-time task "${task.title}" for $taskDate.',
        intent: 'task_create',
        actions: [action],
      );
    }

    return null;
  }

  /// Process a user message and return an AI response
  Future<AiResponse> processMessage(String userMessage,
      {String? contextHint, Uint8List? imageBytes}) async {
    if (_messagesHistory.isEmpty) {
      _initModel();
    }

    try {
      // Tier 1: On-Device Deterministic Fast-Path (0 Tokens)
      if (imageBytes == null) {
        final fastPath = await tryHandleOnDevice(userMessage);
        if (fastPath != null) {
          _messagesHistory.add({
            'role': 'user',
            'parts': [
              {'text': userMessage}
            ]
          });
          _messagesHistory.add({
            'role': 'model',
            'parts': [
              {'text': fastPath.message}
            ]
          });
          return fastPath;
        }

        final detectedIntent = detectIntent(
          userMessage,
          hasImage: false,
          contextHint: contextHint,
        );

        if (detectedIntent == 'music') {
          final mediaResponse = await handleMediaIntent(userMessage);
          if (mediaResponse != null) {
            _messagesHistory.add({
              'role': 'user',
              'parts': [
                {'text': userMessage}
              ]
            });
            _messagesHistory.add({
              'role': 'model',
              'parts': [
                {'text': mediaResponse.message}
              ]
            });
            return mediaResponse;
          }
        }

        final localResponse = await _handleLocally(userMessage, detectedIntent);
        if (localResponse != null) {
          _messagesHistory.add({
            'role': 'user',
            'parts': [
              {'text': userMessage}
            ]
          });
          _messagesHistory.add({
            'role': 'model',
            'parts': [
              {'text': localResponse.message}
            ]
          });
          return localResponse;
        }
      }

      final apiKey = activeApiKey;
      if (apiKey.isEmpty) {
        return AiResponse(
          message:
              'I can handle common task, habit, finance, diet, music, and vault commands locally, but this request needs Gemini. Add the Gemini API key in Settings for fallback reasoning.',
          intent: 'error',
        );
      }

      // Tier 2: Intent-Scoped Delta Context (<150 tokens)
      final sectors = AiContext.classifyPromptSectors(userMessage);
      final deltaContext = AiContext.buildDeltaContext(sectors);

      final fullMessage = deltaContext.isNotEmpty
          ? '[DELTA_CONTEXT]\n$deltaContext\n[USER MESSAGE]\n$userMessage'
          : userMessage;

      // Build Gemini API request parts
      List<Map<String, dynamic>> parts = [];
      parts.add({'text': fullMessage});

      if (imageBytes != null) {
        final base64Image = base64Encode(imageBytes);
        parts.add({
          'inline_data': {
            'mime_type': 'image/jpeg',
            'data': base64Image,
          }
        });
      }

      // Add user message to history
      _messagesHistory.add({
        'role': 'user',
        'parts': [
          {'text': fullMessage}
        ],
      });

      // Cap history to last 2 messages (1 turn) to prevent token bloat
      if (_messagesHistory.length > 2) {
        _messagesHistory =
            _messagesHistory.sublist(_messagesHistory.length - 2);
      }

      final requestBody = {
        'system_instruction': {
          'parts': [
            {'text': AiContext.buildSystemPrompt()}
          ]
        },
        'contents': [
          ..._messagesHistory.sublist(
              0, _messagesHistory.length > 0 ? _messagesHistory.length - 1 : 0),
          {
            'role': 'user',
            'parts': parts,
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'responseMimeType': 'application/json',
        },
      };

      final client = GeminiClient();
      final result = await client.generateContent(
        requestBody: requestBody,
        apiKey: apiKey,
        activeApiKeySource: activeApiKeySource,
      );

      if (result.isSuccess && result.text != null) {
        final responseText = result.text!;

        _messagesHistory.add({
          'role': 'model',
          'parts': [
            {'text': responseText}
          ],
        });

        final parsed = _parseResponse(responseText);

        // Execute all returned actions automatically across repositories
        for (final act in parsed.actions) {
          await executeAction(act);
        }

        return parsed;
      } else {
        return AiResponse(
          message: result.errorMessage ?? 'Gemini request failed.',
          intent: 'error',
        );
      }
    } catch (e) {
      debugPrint('AI Service Error: $e');
      _messagesHistory.clear();
      return AiResponse(
        message: 'Sorry, I encountered an error. Please try again. ($e)',
        intent: 'error',
      );
    }
  }

  AiResponse _parseResponse(String responseText) {
    try {
      String cleaned = responseText.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      final actions = <AiAction>[];
      if (json['actions'] != null) {
        for (var action in (json['actions'] as List)) {
          if (action is Map) {
            final sector = action['sector']?.toString();
            final op = action['op']?.toString();
            final data = Map<String, dynamic>.from(action['data'] ?? action['payload'] ?? {});

            String type = action['type']?.toString() ?? 'unknown';
            if (type == 'unknown' && sector != null) {
              if (sector == 'diet') {
                type = op == 'log_water' ? 'diet_water' : 'food_entry';
              } else if (sector == 'finance') {
                type = 'finance_transaction';
              } else if (sector == 'tasks') {
                type = 'task_create';
              } else if (sector == 'habits') {
                type = 'habit_create';
              } else if (sector == 'journal') {
                type = 'journal_note';
              }
            }

            actions.add(AiAction(
              type: type,
              payload: data,
              sector: sector,
              op: op,
              isConfirmed: false,
            ));
          }
        }
      }

      final reply = json['reply'] ?? json['message'] ?? 'No response generated.';
      return AiResponse(
        message: reply.toString(),
        intent: json['intent'] ?? 'general_chat',
        actions: actions,
        data: json['data'] as Map<String, dynamic>?,
      );
    } catch (e) {
      return AiResponse(
        message: responseText,
        intent: 'general_chat',
      );
    }
  }

  // --- Action Executors ---

  /// Execute a confirmed food entry action
  void executeFoodAction(AiAction action) {
    final payload = action.payload;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final box = Hive.box<DietDayLog>('diet_logs');

    DietDayLog log = box.get(today) ??
        DietDayLog(
          dateKey: today,
          targetCalories: _getCalorieTarget(),
        );

    final mealStr = (payload['meal_type'] ?? 'snack').toString().toLowerCase();
    MealType mealType;
    switch (mealStr) {
      case 'breakfast':
        mealType = MealType.breakfast;
        break;
      case 'lunch':
        mealType = MealType.lunch;
        break;
      case 'dinner':
        mealType = MealType.dinner;
        break;
      default:
        mealType = MealType.snack;
    }

    final entry = FoodEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: payload['name'] ?? 'Unknown Food',
      calories: (payload['calories'] ?? 0).toDouble(),
      protein: (payload['protein'] ?? 0).toDouble(),
      carbs: (payload['carbs'] ?? 0).toDouble(),
      fat: (payload['fat'] ?? 0).toDouble(),
      timestamp: DateTime.now(),
      mealType: mealType,
    );

    log.entries.add(entry);

    if (box.containsKey(today)) {
      log.save();
    } else {
      box.put(today, log);
    }

    MealSlot slot;
    switch (mealType) {
      case MealType.breakfast:
        slot = MealSlot.breakfast;
        break;
      case MealType.lunch:
        slot = MealSlot.lunch;
        break;
      case MealType.dinner:
        slot = MealSlot.dinner;
        break;
      case MealType.snack:
        slot = MealSlot.snack;
        break;
    }

    DietRepository.instance.logFood(
      DietLogEntry(
        id: entry.id,
        dateIso: today,
        mealSlot: slot,
        title: entry.name,
        quantity: 1.0,
        gramsTotal: 100.0,
        kcal: entry.calories,
        proteinG: entry.protein,
        carbsG: entry.carbs,
        fatG: entry.fat,
      ),
    );
  }

  /// Execute a confirmed burn entry action
  void executeBurnAction(AiAction action) {
    final payload = action.payload;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final box = Hive.box<DietDayLog>('diet_logs');

    DietDayLog log = box.get(today) ??
        DietDayLog(
          dateKey: today,
          targetCalories: _getCalorieTarget(),
        );

    final burn = CalorieBurnEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      activity: payload['activity'] ?? 'Exercise',
      caloriesBurned: (payload['calories_burned'] ?? 0).toDouble(),
      durationMinutes: (payload['duration_minutes'] ?? 0).toInt(),
      timestamp: DateTime.now(),
    );

    log.burnEntries.add(burn);

    if (box.containsKey(today)) {
      log.save();
    } else {
      box.put(today, log);
    }
  }

  /// Execute a confirmed task creation action
  void executeTaskAction(AiAction action) {
    final payload = action.payload;
    final box = Hive.box<Goal>('mission_box_v4');

    GoalType type;
    switch ((payload['type'] ?? 'today').toString().toLowerCase()) {
      case 'daily':
        type = GoalType.daily;
        break;
      case 'weekly':
        type = GoalType.weekly;
        break;
      case 'monthly':
        type = GoalType.monthly;
        break;
      default:
        type = GoalType.today;
    }

    GoalCategory category;
    switch ((payload['category'] ?? 'productivity').toString().toLowerCase()) {
      case 'health':
        category = GoalCategory.health;
        break;
      case 'learning':
        category = GoalCategory.learning;
        break;
      case 'fitness':
        category = GoalCategory.fitness;
        break;
      case 'hobby':
        category = GoalCategory.hobby;
        break;
      default:
        category = GoalCategory.productivity;
    }

    DateTime? endDate;
    if (payload['end_date'] != null) {
      try {
        endDate = DateTime.parse(payload['end_date']);
      } catch (e) {
        debugPrint('Error parsing end_date: $e');
      }
    }

    final goal = Goal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: payload['title'] ?? 'Untitled Task',
      type: type,
      category: category,
      targetValue: _asDouble(payload['target_value'] ?? 1),
      unit: (payload['unit'] ?? 'units').toString(),
      createdDate: DateTime.now(),
      endDate: endDate,
      kind: payload['kind']?.toString(),
      metricKey: payload['metric_key']?.toString(),
      metricOp: payload['metric_op']?.toString() ?? '>=',
    );

    box.put(goal.id, goal);
  }

  /// Execute a confirmed finance transaction action
  void executeFinanceAction(AiAction action) {
    final payload = action.payload;
    final mode = (payload['mode'] ?? payload['kind'] ?? 'expense')
        .toString()
        .toLowerCase();
    final isExpense = mode != 'income';
    final title =
        (payload['title'] ?? (isExpense ? 'Expense' : 'Income')).toString();
    final amount = _asDouble(payload['amount']);
    if (amount <= 0) return;

    final repo = FinanceRepository();
    final categoryName =
        (payload['category'] ?? (isExpense ? 'Other' : 'Income')).toString();
    final merchant = payload['merchant']?.toString();
    final accountName = payload['account_name']?.toString().toLowerCase();

    String? accountId;
    if (accountName != null) {
      for (final a in repo.storage.accountBox.values) {
        if (a.name.toLowerCase().contains(accountName)) {
          accountId = a.id;
          break;
        }
      }
    }
    accountId ??= repo.storage.accountBox.values
        .where((a) => a.spendable && !a.archived)
        .firstOrNull
        ?.id;

    String? categoryId;
    for (final c in repo.storage.categoryBox.values) {
      if (c.name.toLowerCase() == categoryName.toLowerCase()) {
        categoryId = c.id;
        break;
      }
    }

    final date = payload['date'] != null
        ? (DateTime.tryParse(payload['date'].toString()) ?? DateTime.now())
        : DateTime.now();

    repo.addTransaction(TxDraft(
      title: title,
      amount: isExpense ? -amount.abs() : amount.abs(),
      kind: isExpense ? 'expense' : 'income',
      mode: isExpense ? 'expense' : 'income',
      category: categoryName,
      categoryId: categoryId,
      merchant: merchant,
      accountId: accountId,
      date: date,
    ));
  }

  void _executeFinanceTransferAction(AiAction action) {
    final payload = action.payload;
    final amount = _asDouble(payload['amount']);
    if (amount <= 0) return;

    final repo = FinanceRepository();
    final fromName = payload['from_account']?.toString().toLowerCase();
    final toName = payload['to_account']?.toString().toLowerCase();

    String? fromId;
    String? toId;

    for (final a in repo.storage.accountBox.values) {
      if (fromName != null && a.name.toLowerCase().contains(fromName))
        fromId = a.id;
      if (toName != null && a.name.toLowerCase().contains(toName)) toId = a.id;
    }

    final spendable = repo.storage.accountBox.values
        .where((a) => a.spendable && !a.archived)
        .toList();
    if (fromId == null && spendable.isNotEmpty) fromId = spendable.first.id;
    if (toId == null && spendable.length > 1) {
      toId = spendable
          .firstWhere((a) => a.id != fromId, orElse: () => spendable.last)
          .id;
    }

    if (fromId != null && toId != null && fromId != toId) {
      repo.addTransaction(TxDraft(
        title: 'Transfer',
        amount: amount.abs(),
        kind: 'transfer',
        mode: 'transfer',
        category: 'Transfer',
        accountId: fromId,
        toAccountId: toId,
        date: DateTime.now(),
        notes: payload['notes']?.toString(),
      ));
    }
  }

  void _executeFinanceBudgetAction(AiAction action) {
    final payload = action.payload;
    final categoryName = (payload['category'] ?? 'Other').toString();
    final total = _asDouble(payload['total'] ?? payload['amount'] ?? 0);
    if (total <= 0) return;

    final repo = FinanceRepository();
    Category? matchedCat;
    for (final c in repo.storage.categoryBox.values) {
      if (c.name.toLowerCase() == categoryName.toLowerCase()) {
        matchedCat = c;
        break;
      }
    }

    final categoryId =
        matchedCat?.id ?? 'cat_${DateTime.now().millisecondsSinceEpoch}';
    if (matchedCat == null) {
      repo.addCategory(Category(
        id: categoryId,
        name: categoryName,
        kind: 'expense',
        group: 'wants',
        iconKey: 'expense',
        colorValue: 0xFF9E9E9E,
      ));
    }

    BudgetLine? existingLine;
    for (final l in repo.storage.budgetLineBox.values) {
      if (l.categoryId == categoryId) {
        existingLine = l;
        break;
      }
    }

    final line = existingLine != null
        ? BudgetLine(
            id: existingLine.id,
            categoryId: categoryId,
            amount: total,
            rollover: existingLine.rollover,
            essential: existingLine.essential,
            startMonth: existingLine.startMonth,
          )
        : BudgetLine(
            id: 'bl_${DateTime.now().millisecondsSinceEpoch}',
            categoryId: categoryId,
            amount: total,
            startMonth: DateFormat('yyyy-MM').format(DateTime.now()),
          );

    repo.setBudgetLine(line);
  }

  void _executeFinanceCommitmentAction(AiAction action) {
    _executeFinanceRecurringAction(action);
  }

  void _executeFinanceSipAction(AiAction action) {
    final payload = Map<String, dynamic>.from(action.payload);
    payload['kind'] = 'sip';
    _executeFinanceRecurringAction(
        AiAction(type: 'finance_recurring', payload: payload));
  }

  void _executeFinanceRecurringAction(AiAction action) {
    final payload = action.payload;
    final name = (payload['name'] ?? 'Recurring Bill').toString();
    final amount = _asDouble(payload['amount']);
    if (amount <= 0) return;

    final kind = (payload['kind'] ?? 'bill').toString().toLowerCase();
    final freq = (payload['frequency'] ?? 'monthly').toString().toLowerCase();
    final dueDay =
        int.tryParse((payload['due'] ?? payload['date'] ?? 1).toString()) ?? 1;

    final now = DateTime.now();
    final anchor = DateTime(now.year, now.month, dueDay.clamp(1, 28));

    final rule = RecurringRule(
      id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      kind: kind,
      amount: amount,
      frequency: freq,
      anchorDate: anchor,
      startDate: anchor,
      notes: payload['notes']?.toString(),
      createdAt: DateTime.now(),
    );

    FinanceRepository().addRecurringRule(rule);
  }

  void _executeFinanceGoalAction(AiAction action) {
    final payload = action.payload;
    final name = (payload['name'] ?? 'Goal').toString();
    final target = _asDouble(payload['target']);
    if (target <= 0) return;

    DateTime? deadline;
    if (payload['deadline'] != null &&
        payload['deadline'].toString().isNotEmpty) {
      deadline = DateTime.tryParse(payload['deadline'].toString());
    }

    final goal = SavingsGoal(
      id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      targetAmount: target,
      deadline: deadline,
      colorValue: 0xFF2DD4BF,
    );

    FinanceRepository().addGoal(goal);
  }

  /// Handles media playback and transport commands on active media sessions
  Future<AiResponse?> handleMediaIntent(String message) async {
    final lower = message.toLowerCase().trim();

    // 1. Pause
    if (_containsAny(
        lower, ['pause', 'stop', 'rok do', 'roko', 'ruk jao', 'thahar'])) {
      await NowPlayingService.instance.send(MediaCommand.pause);
      return AiResponse(
        message: '⏸️ Paused media playback.',
        intent: 'music',
      );
    }

    // 2. Next / Skip
    if (_containsAny(lower,
        ['next', 'skip', 'agla', 'aage badho', 'change song', 'next track'])) {
      await NowPlayingService.instance.send(MediaCommand.next);
      return AiResponse(
        message: '⏭️ Skipped to next track.',
        intent: 'music',
      );
    }

    // 3. Previous / Back
    if (_containsAny(lower,
        ['previous', 'prev', 'pichla', 'peeche', 'last song', 'back song'])) {
      await NowPlayingService.instance.send(MediaCommand.previous);
      return AiResponse(
        message: '⏮️ Returning to previous track.',
        intent: 'music',
      );
    }

    // 4. Resume / Play
    if (lower == 'play' ||
        lower == 'resume' ||
        lower == 'chalao' ||
        lower == 'chalu karo' ||
        lower == 'play music' ||
        lower == 'shuru karo') {
      await NowPlayingService.instance.send(MediaCommand.play);
      return AiResponse(
        message: '▶️ Resumed media playback.',
        intent: 'music',
      );
    }

    // 5. Seek / Forward / Rewind
    final seekMatch = RegExp(
            r'(?:seek|forward|rewind|aage|peeche)\s+(?:to\s+)?(\d+)\s*(?:sec|seconds|s|min|minutes|m)?')
        .firstMatch(lower);
    if (seekMatch != null) {
      final numStr = seekMatch.group(1);
      if (numStr != null) {
        int seconds = int.tryParse(numStr) ?? 0;
        if (lower.contains('min')) seconds *= 60;
        await NowPlayingService.instance
            .send(MediaCommand.seekTo, argument: seconds * 1000);
        return AiResponse(
          message: '⏩ Seeked playback to $seconds seconds.',
          intent: 'music',
        );
      }
    }

    // 6. Play specific query
    final prefixes = [
      'play ',
      'play me ',
      'put on ',
      'can you play ',
      'please play ',
      'play the song ',
      'play song ',
      'i want to listen to ',
      'listen to ',
      'bajao ',
      'chalao ',
      'laga do ',
      'sunao ',
      'suno ',
      'play the track ',
    ];

    String query = '';
    for (final p in prefixes) {
      if (lower.startsWith(p)) {
        query = lower.substring(p.length).trim();
        break;
      }
    }

    if (query.isNotEmpty) {
      final active = NowPlayingService.instance.nowPlaying.value;
      if (active == null) {
        return AiResponse(
          message:
              "No active music session detected. Start playing in your preferred music app (Spotify, YouTube Music, etc.) and I'll control it.",
          intent: 'music',
        );
      }
      await NowPlayingService.instance
          .send(MediaCommand.playFromSearch, argument: query);
      return AiResponse(
        message:
            '🎵 Searching and playing "$query" via ${active.packageName.split('.').last}...',
        intent: 'music',
      );
    }

    return null;
  }

  /// Confirm and execute an action
  Future<void> executeAction(AiAction action) async {
    final payload = action.payload;
    final type = action.type;

    if (type == 'food_entry' || (action.sector == 'diet' && action.op == 'log_meal')) {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final slotStr = (payload['meal_type'] ?? payload['slot'] ?? 'snack').toString().toLowerCase();
      final id = payload['log_id']?.toString() ?? payload['id']?.toString() ?? 'log_${DateTime.now().millisecondsSinceEpoch}';
      payload['log_id'] = id;
      payload['id'] = id;

      MealSlot slot = MealSlot.snack;
      if (slotStr == 'breakfast') slot = MealSlot.breakfast;
      else if (slotStr == 'lunch') slot = MealSlot.lunch;
      else if (slotStr == 'dinner') slot = MealSlot.dinner;

      final entry = DietLogEntry(
        id: id,
        dateIso: today,
        mealSlot: slot,
        title: (payload['name'] ?? payload['title'] ?? 'Food Entry').toString(),
        quantity: 1.0,
        gramsTotal: 100.0,
        kcal: (payload['calories'] ?? payload['cal'] ?? 0).toDouble(),
        proteinG: (payload['protein'] ?? payload['p'] ?? 0).toDouble(),
        carbsG: (payload['carbs'] ?? payload['c'] ?? 0).toDouble(),
        fatG: (payload['fat'] ?? payload['f'] ?? 0).toDouble(),
      );
      await DietRepository.instance.logFood(entry);
    } else if (type == 'diet_water' || (action.sector == 'diet' && action.op == 'log_water')) {
      final ml = (payload['ml'] ?? 250).toDouble();
      await DietRepository.instance.addWater(ml);
    } else if (type == 'finance_transaction' || (action.sector == 'finance' && action.op == 'add_tx')) {
      final amount = (payload['amount'] ?? 0).toDouble();
      final isExp = payload['is_expense'] == true || (payload['mode'] ?? 'expense').toString().toLowerCase() == 'expense';
      final title = (payload['title'] ?? payload['name'] ?? 'Transaction').toString();
      final cat = (payload['category'] ?? (isExp ? 'Other' : 'Income')).toString();

      final draft = TxDraft(
        title: title,
        amount: isExp ? -amount.abs() : amount.abs(),
        date: DateTime.now(),
        mode: isExp ? 'expense' : 'income',
        category: cat,
        icon: isExp ? 'shopping-cart' : 'wallet',
        kind: isExp ? 'expense' : 'income',
      );
      final tx = await FinanceRepository().addTransaction(draft);
      payload['tx_id'] = tx.id;
    } else if (type == 'task_create' || (action.sector == 'tasks' && action.op == 'add_task')) {
      final id = payload['task_id']?.toString() ?? payload['id']?.toString() ?? 'task_${DateTime.now().millisecondsSinceEpoch}';
      payload['task_id'] = id;
      payload['id'] = id;
      final title = (payload['title'] ?? 'Task').toString();
      final date = (payload['date'] ?? payload['scheduledDate'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now())).toString();

      final task = TaskItem(
        id: id,
        title: title,
        status: TaskStatus.todo,
        priority: TaskPriority.medium,
        isHabit: false,
        dueAt: DateTime.tryParse(date) ?? DateTime.now(),
        recurrenceFrequency: 'none',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await TaskOsRepository.instance.saveTask(task);
    } else if (type == 'habit_create' || (action.sector == 'habits' && action.op == 'add_habit')) {
      final id = payload['habit_id']?.toString() ?? payload['id']?.toString() ?? 'habit_${DateTime.now().millisecondsSinceEpoch}';
      payload['habit_id'] = id;
      payload['id'] = id;
      final title = (payload['title'] ?? 'Habit').toString();
      final freq = (payload['frequency'] ?? 'daily').toString();

      final habit = ForgivingHabitItem(
        id: id,
        name: title,
        frequency: freq,
        category: 'Routines',
        targetPerWeek: freq == 'daily' ? 7 : 3,
      );
      final pairedTask = TaskItem(
        id: 'task_$id',
        title: title,
        status: TaskStatus.todo,
        priority: TaskPriority.medium,
        isHabit: true,
        recurrenceFrequency: freq,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await TaskOsRepository.instance.saveHabit(habit);
      await TaskOsRepository.instance.saveTask(pairedTask);
    } else if (type == 'journal_note' || (action.sector == 'journal' && action.op == 'add_note')) {
      final text = (payload['text'] ?? '').toString();
      if (text.isNotEmpty) {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await JournalDayRepository.instance.appendNote(today, text);
      }
    } else {
      switch (action.type) {
        case 'burn_entry':
          executeBurnAction(action);
          break;
        case 'finance_budget':
          _executeFinanceBudgetAction(action);
          break;
        case 'finance_commitment':
          _executeFinanceCommitmentAction(action);
          break;
        case 'finance_sip':
          _executeFinanceSipAction(action);
          break;
        case 'finance_goal':
          _executeFinanceGoalAction(action);
          break;
        case 'finance_transfer':
          _executeFinanceTransferAction(action);
          break;
        case 'finance_recurring':
          _executeFinanceRecurringAction(action);
          break;
        case 'wear_sync':
          SyncService.instance.sync();
          break;
        case 'wakeup_log':
        case 'wakeup_task_create':
        case 'finance_whatif':
        case 'finance_query':
          break;
      }
    }
    action.isConfirmed = true;
  }

  /// Revert an executed action (1-tap Undo)
  Future<void> undoAction(AiAction action) async {
    final type = action.type;
    final payload = action.payload;

    try {
      if (type == 'food_entry' || (action.sector == 'diet' && action.op == 'log_meal')) {
        final id = payload['log_id']?.toString() ?? payload['id']?.toString();
        if (id != null) {
          await DietRepository.instance.deleteFoodLog(id);
        }
      } else if (type == 'diet_water' || (action.sector == 'diet' && action.op == 'log_water')) {
        final ml = (payload['ml'] ?? 250).toDouble();
        await DietRepository.instance.addWater(-ml);
      } else if (type == 'finance_transaction' || (action.sector == 'finance' && action.op == 'add_tx')) {
        final txId = payload['tx_id'] ?? payload['id'];
        if (txId != null) {
          await FinanceRepository().deleteTransaction(txId);
        }
      } else if (type == 'task_create' || (action.sector == 'tasks' && action.op == 'add_task')) {
        final taskId = payload['task_id']?.toString() ?? payload['id']?.toString();
        if (taskId != null) {
          await TaskOsRepository.instance.deleteTask(taskId, permanent: true);
        }
      } else if (type == 'habit_create' || (action.sector == 'habits' && action.op == 'add_habit')) {
        final habitId = payload['habit_id']?.toString() ?? payload['id']?.toString();
        if (habitId != null) {
          await TaskOsRepository.instance.deleteHabit(habitId, permanent: true);
          await TaskOsRepository.instance.deleteTask('task_$habitId', permanent: true);
        }
      } else if (type == 'wakeup_log') {
        final dayKey = payload['day_key'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
        await WakeService.instance.undo(dayKey);
      }
    } catch (e) {
      debugPrint('Undo error: $e');
    }
    payload['undone'] = true;
  }

  double _getCalorieTarget() {
    return Hive.box('settings')
        .get('daily_calorie_target', defaultValue: 2000.0)
        .toDouble();
  }

  /// Reset chat session
  void resetChat() {
    _messagesHistory.clear();
  }

  /// Get today's diet log
  DietDayLog getTodayLog() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final box = Hive.box<DietDayLog>('diet_logs');
    return box.get(today) ??
        DietDayLog(
          dateKey: today,
          targetCalories: _getCalorieTarget(),
        );
  }

  /// Get diet log for specific date
  DietDayLog? getLogForDate(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    final box = Hive.box<DietDayLog>('diet_logs');
    return box.get(key);
  }

  /// Get logs for the last N days
  List<DietDayLog> getLogsForRange(int days) {
    final box = Hive.box<DietDayLog>('diet_logs');
    final logs = <DietDayLog>[];
    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      final log = box.get(key);
      if (log != null) {
        logs.add(log);
      } else {
        // Create empty placeholder for charting
        logs.add(DietDayLog(dateKey: key, targetCalories: _getCalorieTarget()));
      }
    }
    return logs;
  }

  /// Add a manual calorie burn
  void addManualBurn(String activity, double calories, int durationMinutes) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final box = Hive.box<DietDayLog>('diet_logs');

    DietDayLog log = box.get(today) ??
        DietDayLog(
          dateKey: today,
          targetCalories: _getCalorieTarget(),
        );

    final burn = CalorieBurnEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      activity: activity,
      caloriesBurned: calories,
      durationMinutes: durationMinutes,
      timestamp: DateTime.now(),
    );

    log.burnEntries.add(burn);

    if (box.containsKey(today)) {
      log.save();
    } else {
      box.put(today, log);
    }
  }

  /// Extracts structured task candidates from natural language text, voice transcripts,
  /// or document/photo OCR with Gemini cloud enrichment and NativeTaskAiEngine fallback.
  Future<List<Map<String, dynamic>>> extractTasksWithAi(
    String input, {
    Uint8List? imageBytes,
    String? mimeType,
  }) async {
    final now = DateTime.now();

    if (isConfigured) {
      try {
        final client = GeminiClient();
        final promptText = '''
Extract all academic, project, homework, exam, or personal tasks from the following text or image.
Current DateTime is: ${now.toIso8601String()}.
Return a JSON array ONLY with NO markdown fences, matching this exact schema:
[
  {
    "title": "Task title",
    "dueAt": "ISO-8601 string or null",
    "courseCode": "Course code e.g. CS301 or null",
    "priority": 1 for Urgent, 2 for High, 3 for Medium, 4 for Low,
    "estimateMin": 45,
    "tags": ["academic"],
    "confidence": 0.95
  }
]
Input text:
$input
''';

        final parts = <Map<String, dynamic>>[];
        if (imageBytes != null && imageBytes.isNotEmpty) {
          parts.add({
            'inline_data': {
              'mime_type': mimeType ?? 'image/jpeg',
              'data': base64Encode(imageBytes),
            }
          });
        }
        parts.add({'text': promptText});

        final requestBody = {
          'contents': [
            {'parts': parts}
          ],
          'generationConfig': {
            'temperature': 0.1,
            'responseMimeType': 'application/json',
          }
        };

        final result = await client.generateContent(
          requestBody: requestBody,
          apiKey: activeApiKey,
        );

        if (result.isSuccess && result.text != null && result.text!.trim().isNotEmpty) {
          final cleanJson = result.text!.replaceAll(RegExp(r'^```json\s*|```$'), '').trim();
          final decoded = jsonDecode(cleanJson);
          if (decoded is List) {
            final tasks = <Map<String, dynamic>>[];
            for (final item in decoded) {
              if (item is Map) {
                tasks.add(Map<String, dynamic>.from(item));
              }
            }
            if (tasks.isNotEmpty) {
              return tasks;
            }
          }
        }
      } catch (e) {
        debugPrint('extractTasksWithAi cloud call failed, using native engine: $e');
      }
    }

    // Instant offline fallback using NativeTaskAiEngine
    final candidates = input.contains('\n') ||
            input.toLowerCase().contains('assignment') ||
            input.toLowerCase().contains('exam') ||
            input.toLowerCase().contains('quiz') ||
            input.toLowerCase().contains('syllabus')
        ? NativeTaskAiEngine.extractTasksFromDocumentText(input, now)
        : NativeTaskAiEngine.extractTasksFromBrainDump(input, now);

    return candidates.map((c) => c.toMap()).toList();
  }

  /// Context-Aware Digital Scanner & Classifier Pipeline (Phase 4).
  /// Parses document text (PDF/OCR) or image with user context filter (e.g. "CS S3")
  /// and automatically routes items to their respective modules.
  Future<ScannedDocumentResult> parseDocumentWithFilter({
    required String rawText,
    required String contextFilter,
    Uint8List? imageBytes,
    String? mimeType,
  }) async {
    final cleanFilter = contextFilter.trim().toLowerCase();
    final filterTokens = cleanFilter
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();

    // 1. Detect Category Heuristically
    final lowerText = rawText.toLowerCase();
    ScanDocCategory detectedCat = ScanDocCategory.tasks;
    String detectedDest = 'Tasks';

    if (lowerText.contains('timetable') ||
        (lowerText.contains('slot') && lowerText.contains('period')) ||
        (lowerText.contains('monday') &&
            lowerText.contains('tuesday') &&
            lowerText.contains('room'))) {
      detectedCat = ScanDocCategory.timetable;
      detectedDest = 'Academics → Timetable';
    } else if (lowerText.contains('syllabus') ||
        lowerText.contains('course outcome') ||
        lowerText.contains('module 1') ||
        lowerText.contains('prerequisites') ||
        (lowerText.contains('course code') && lowerText.contains('credits'))) {
      detectedCat = ScanDocCategory.syllabus;
      detectedDest = 'Academics → Courses';
    } else if (lowerText.contains('exam schedule') ||
        lowerText.contains('midterm') ||
        lowerText.contains('end semester exam') ||
        lowerText.contains('date sheet') ||
        lowerText.contains('examination')) {
      detectedCat = ScanDocCategory.examSchedule;
      detectedDest = 'Tasks (Dated Exams)';
    } else if (lowerText.contains('invoice') ||
        lowerText.contains('receipt') ||
        lowerText.contains('total amount') ||
        lowerText.contains('gst') ||
        lowerText.contains('subtotal') ||
        lowerText.contains('bill to')) {
      detectedCat = ScanDocCategory.expenses;
      detectedDest = 'Finance → Transactions';
    }

    // 2. Try Gemini Cloud AI if configured
    if (isConfigured) {
      try {
        final client = GeminiClient();
        final promptText = '''
You are a precision digital document parser and smart auto-router.
Given the following document text and/or image:
1. Detect document type: "timetable", "examSchedule", "syllabus", "tasks", or "expenses".
2. User's Context Filter is: "$contextFilter".
   - If the user specifies "$contextFilter" (e.g. "CS S3" or "Computer Science Semester 3"):
     Evaluate each extracted row. If it belongs to the user's branch/semester (e.g. CS, CSE, S3, or relevant slot/course), set "isRelevant": true.
     If it belongs to another branch/semester (e.g. ME, EC, CE, S5, S7), set "isRelevant": false.
   - If context filter is empty, set "isRelevant": true for all items.
3. For each item specify targetModule: "timetable" | "course" | "task" | "habit" | "finance".
4. Extract structured fields where applicable:
   - title, subtitle, targetModule, isRelevant, matchedContextTag (e.g. "$contextFilter"),
   - code (course code e.g. CS301), venue (room/hall), slot (e.g. Slot A),
   - dayOfWeek (1 for Mon .. 7 for Sun), startMinutes (minutes from midnight, e.g. 540 for 9:00 AM), durationMinutes (e.g. 50),
   - dateStr (YYYY-MM-DD), timeStr (e.g. 10:00 AM), amount (number for expenses), category, credits (integer).

Return a JSON object ONLY with NO markdown fences, following this exact schema:
{
  "detectedCategory": "timetable" | "examSchedule" | "syllabus" | "tasks" | "expenses",
  "detectedDestination": "Academics → Timetable" | "Academics → Courses" | "Tasks" | "Finance",
  "items": [
    {
      "id": "1",
      "title": "Data Structures",
      "subtitle": "Slot A · Mon 9:00 AM · Hall 101",
      "targetModule": "timetable",
      "isRelevant": true,
      "matchedContextTag": "$contextFilter",
      "code": "CS301",
      "venue": "Hall 101",
      "slot": "Slot A",
      "dayOfWeek": 1,
      "startMinutes": 540,
      "durationMinutes": 50,
      "credits": 4
    }
  ]
}

Document Text:
$rawText
''';

        final parts = <Map<String, dynamic>>[];
        if (imageBytes != null && imageBytes.isNotEmpty) {
          parts.add({
            'inline_data': {
              'mime_type': mimeType ?? 'image/jpeg',
              'data': base64Encode(imageBytes),
            }
          });
        }
        parts.add({'text': promptText});

        final requestBody = {
          'contents': [
            {'parts': parts}
          ],
          'generationConfig': {
            'temperature': 0.1,
            'responseMimeType': 'application/json',
          }
        };

        final result = await client.generateContent(
          requestBody: requestBody,
          apiKey: activeApiKey,
        );

        if (result.isSuccess &&
            result.text != null &&
            result.text!.trim().isNotEmpty) {
          final cleanJson =
              result.text!.replaceAll(RegExp(r'^```json\s*|```$'), '').trim();
          final decoded = jsonDecode(cleanJson);
          if (decoded is Map) {
            final catStr = decoded['detectedCategory']?.toString() ?? '';
            ScanDocCategory cat = detectedCat;
            if (catStr == 'timetable') cat = ScanDocCategory.timetable;
            if (catStr == 'syllabus') cat = ScanDocCategory.syllabus;
            if (catStr == 'examSchedule') cat = ScanDocCategory.examSchedule;
            if (catStr == 'expenses') cat = ScanDocCategory.expenses;
            if (catStr == 'tasks') cat = ScanDocCategory.tasks;

            final destStr =
                decoded['detectedDestination']?.toString() ?? detectedDest;
            final rawItems = decoded['items'];
            final List<ScannedExtractItem> items = [];

            if (rawItems is List) {
              for (int i = 0; i < rawItems.length; i++) {
                final itemMap = rawItems[i];
                if (itemMap is Map) {
                  final map = Map<String, dynamic>.from(itemMap);
                  if (!map.containsKey('id') || map['id'] == null) {
                    map['id'] =
                        'scan_${DateTime.now().millisecondsSinceEpoch}_$i';
                  }
                  final isRel = map['isRelevant'] == true;
                  map['isSelected'] = isRel;
                  items.add(ScannedExtractItem.fromMap(map));
                }
              }
            }

            if (items.isNotEmpty) {
              return ScannedDocumentResult(
                detectedCategory: cat,
                detectedDestination: destStr,
                items: items,
                rawExtractedText: rawText,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('parseDocumentWithFilter cloud call error: $e');
      }
    }

    // 3. Deterministic Local On-Device Fallback (0 tokens)
    return _parseDocumentLocally(
        rawText, cleanFilter, filterTokens, detectedCat, detectedDest);
  }

  ScannedDocumentResult _parseDocumentLocally(
    String rawText,
    String cleanFilter,
    List<String> filterTokens,
    ScanDocCategory detectedCat,
    String detectedDest,
  ) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.length > 3)
        .toList();

    final List<ScannedExtractItem> items = [];
    int idx = 0;

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.startsWith('page ') ||
          lower.startsWith('printed on') ||
          lower.startsWith('table of contents')) {
        continue;
      }

      bool isRel = true;
      if (filterTokens.isNotEmpty) {
        final containsAny = filterTokens.any((tok) => lower.contains(tok));
        final isCsFilter = filterTokens.any((t) => t == 'cs' || t == 'cse');
        final hasConflictingBranch = isCsFilter &&
            (lower.contains(' ec ') ||
                lower.contains(' me ') ||
                lower.contains(' ce ') ||
                lower.contains(' ee ') ||
                lower.startsWith('ec') ||
                lower.startsWith('me') ||
                lower.startsWith('ce'));

        isRel = containsAny && !hasConflictingBranch;
      }

      String targetMod = 'task';
      String title = line;
      String subtitle = '';
      String? code;
      String? slot;
      String? venue;
      int? dayOfWeek;
      int? startMinutes;
      int? durationMinutes;
      int? credits;
      double? amount;

      if (detectedCat == ScanDocCategory.timetable) {
        targetMod = 'timetable';
        if (lower.contains('mon')) dayOfWeek = 1;
        if (lower.contains('tue')) dayOfWeek = 2;
        if (lower.contains('wed')) dayOfWeek = 3;
        if (lower.contains('thu')) dayOfWeek = 4;
        if (lower.contains('fri')) dayOfWeek = 5;
        if (lower.contains('sat')) dayOfWeek = 6;

        final slotMatch = RegExp(
                r'\b(slot\s*[a-z0-9]|batch\s*[a-z0-9]|\b[a-f]\s*slot)\b',
                caseSensitive: false)
            .firstMatch(line);
        if (slotMatch != null) slot = slotMatch.group(0);

        final codeMatch =
            RegExp(r'\b([A-Z]{2,4}\s*\d{3,4})\b').firstMatch(line);
        if (codeMatch != null) code = codeMatch.group(0)?.replaceAll(' ', '');

        final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(line);
        if (timeMatch != null) {
          final h = int.tryParse(timeMatch.group(1)!) ?? 9;
          final m = int.tryParse(timeMatch.group(2)!) ?? 0;
          startMinutes = h * 60 + m;
          durationMinutes = 50;
        }

        final roomMatch = RegExp(r'\b(hall|room|lab|lh)\s*[a-z0-9\-]+\b',
                caseSensitive: false)
            .firstMatch(line);
        if (roomMatch != null) venue = roomMatch.group(0);

        subtitle = [
          if (slot != null) slot,
          if (code != null) code,
          if (venue != null) venue,
        ].join(' · ');
      } else if (detectedCat == ScanDocCategory.syllabus) {
        targetMod = 'course';
        final codeMatch =
            RegExp(r'\b([A-Z]{2,4}\s*\d{3,4})\b').firstMatch(line);
        if (codeMatch != null) code = codeMatch.group(0)?.replaceAll(' ', '');

        final credMatch = RegExp(r'(\d)\s*(credits?|cr)\b', caseSensitive: false)
            .firstMatch(line);
        if (credMatch != null) credits = int.tryParse(credMatch.group(1)!);

        subtitle = [
          if (code != null) 'Code: $code',
          if (credits != null) '$credits Credits',
        ].join(' · ');
      } else if (detectedCat == ScanDocCategory.expenses) {
        targetMod = 'finance';
        final amtMatch = RegExp(
                r'(?:₹|\$|rs\.?|inr)?\s*(\d+(?:[.,]\d{2})?)',
                caseSensitive: false)
            .firstMatch(line);
        if (amtMatch != null) {
          amount = double.tryParse(amtMatch.group(1)!.replaceAll(',', ''));
        }
        subtitle = amount != null
            ? '₹${amount.toStringAsFixed(0)} · Scanned Expense'
            : 'Expense item';
      } else {
        targetMod = 'task';
        subtitle = 'One-time task candidate';
      }

      items.add(ScannedExtractItem(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}_$idx',
        title: title,
        subtitle: subtitle,
        targetModule: targetMod,
        matchedContextTag: isRel ? cleanFilter : null,
        isRelevant: isRel,
        isSelected: isRel,
        code: code,
        slot: slot,
        venue: venue,
        dayOfWeek: dayOfWeek,
        startMinutes: startMinutes,
        durationMinutes: durationMinutes,
        credits: credits,
        amount: amount,
      ));
      idx++;
    }

    return ScannedDocumentResult(
      detectedCategory: detectedCat,
      detectedDestination: detectedDest,
      items: items,
      rawExtractedText: rawText,
    );
  }

  /// Parses natural meal descriptions, photos, or packaged nutrition labels into
  /// draft [DietLogEntry] items with Gemini cloud AI and NativeDietAiEngine fallback.
  Future<List<DietLogEntry>> parseMealDescriptionWithAi(
    String input, {
    Uint8List? imageBytes,
    String? mimeType,
    MealSlot defaultSlot = MealSlot.lunch,
    String? dateIso,
  }) async {
    final effectiveDate = dateIso ??
        DateTime.now().toIso8601String().split('T').first;
    final repo = DietRepository.instance;

    if (isConfigured) {
      try {
        final client = GeminiClient();
        final promptText = '''
You are a precision clinical and sports dietitian. Parse the following meal description, photo, or nutrition label into individual food items.
Consider Indian regional foods (Kerala, South/North Indian) and household units (katori, cup, roti, appam, dosa, idli, glass, piece, tbsp, g).
Return a JSON array ONLY with NO markdown fences, following this exact schema:
[
  {
    "title": "Kerala Appam",
    "quantity": 2.0,
    "unit": "appam",
    "gramsTotal": 110.0,
    "kcal": 192.0,
    "proteinG": 2.8,
    "carbsG": 39.6,
    "fatG": 2.0,
    "fibreG": 1.3,
    "confidence": "approximate",
    "allergenWarnings": []
  }
]
Input text:
$input
''';

        final parts = <Map<String, dynamic>>[];
        if (imageBytes != null && imageBytes.isNotEmpty) {
          parts.add({
            'inline_data': {
              'mime_type': mimeType ?? 'image/jpeg',
              'data': base64Encode(imageBytes),
            }
          });
        }
        parts.add({'text': promptText});

        final requestBody = {
          'contents': [
            {'parts': parts}
          ],
          'generationConfig': {
            'temperature': 0.1,
            'responseMimeType': 'application/json',
          }
        };

        final result = await client.generateContent(
          requestBody: requestBody,
          apiKey: activeApiKey,
        );

        if (result.isSuccess && result.text != null && result.text!.trim().isNotEmpty) {
          final cleanJson = result.text!.replaceAll(RegExp(r'^```json\s*|```$'), '').trim();
          final decoded = jsonDecode(cleanJson);
          if (decoded is List) {
            final draftList = <DietLogEntry>[];
            int counter = 0;
            for (final item in decoded) {
              if (item is Map) {
                final m = Map<String, dynamic>.from(item);
                draftList.add(
                  DietLogEntry(
                    id: 'draft_ai_${DateTime.now().millisecondsSinceEpoch}_${counter++}',
                    dateIso: effectiveDate,
                    mealSlot: defaultSlot,
                    title: m['title']?.toString() ?? 'Logged Item',
                    quantity: (m['quantity'] as num?)?.toDouble() ?? 1.0,
                    unit: HouseholdUnit.fromString(m['unit']?.toString() ?? 'serving'),
                    gramsTotal: (m['gramsTotal'] as num?)?.toDouble() ?? 100.0,
                    kcal: (m['kcal'] as num?)?.toDouble() ?? 150.0,
                    proteinG: (m['proteinG'] as num?)?.toDouble() ?? 5.0,
                    carbsG: (m['carbsG'] as num?)?.toDouble() ?? 20.0,
                    fatG: (m['fatG'] as num?)?.toDouble() ?? 5.0,
                    fibreG: (m['fibreG'] as num?)?.toDouble() ?? 2.0,
                    confidence: FoodConfidence.approximate,
                    allergenWarnings: List<String>.from(m['allergenWarnings'] ?? const []),
                    notes: 'Parsed via Gemini Cloud AI',
                  ),
                );
              }
            }
            if (draftList.isNotEmpty) {
              return draftList;
            }
          }
        }
      } catch (e) {
        debugPrint('parseMealDescriptionWithAi cloud call failed, using native engine: $e');
      }
    }

    // Offline native AI fallback
    return NativeDietAiEngine.parseMealTextToDraftLogs(
      text: input,
      db: repo.foods,
      dateIso: effectiveDate,
      defaultSlot: defaultSlot,
      userAllergies: repo.profile.allergies,
    );
  }

  /// Generates a complete daily or weekly meal plan with Gemini cloud AI
  /// and NativeDietAiEngine fallback.
  Future<List<PlannedMealItem>> generateSmartMealPlanWithAi({
    required NutritionProfile profile,
    required List<String> pantryItems,
    String? dateIso,
  }) async {
    final effectiveDate = dateIso ??
        DateTime.now().toIso8601String().split('T').first;
    final repo = DietRepository.instance;

    if (isConfigured) {
      try {
        final client = GeminiClient();
        final promptText = '''
You are a sports nutritionist. Generate a balanced 1-day meal plan (breakfast, lunch, snack, dinner) for this user:
Goal: ${profile.goal.label}
Pantry ingredients available: ${pantryItems.join(', ')}
Dietary pattern: ${profile.dietaryPattern.label}
Allergies/Avoid: ${profile.allergies.join(', ')}
Max cook time: ${profile.maxCookTimeMin} minutes
Return a JSON array ONLY with NO markdown fences, following this exact schema:
[
  {
    "mealSlot": "breakfast",
    "title": "Steamed Idli with Sambar",
    "servings": 1.0,
    "kcal": 320.0,
    "proteinG": 12.0,
    "carbsG": 55.0,
    "fatG": 4.5,
    "fibreG": 6.0,
    "prepTimeMin": 15,
    "estimatedCostInr": 35.0,
    "whySuggested": "High fibre and gentle on morning digestion"
  }
]
''';

        final requestBody = {
          'contents': [
            {
              'parts': [
                {'text': promptText}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.2,
            'responseMimeType': 'application/json',
          }
        };

        final result = await client.generateContent(
          requestBody: requestBody,
          apiKey: activeApiKey,
        );

        if (result.isSuccess && result.text != null && result.text!.trim().isNotEmpty) {
          final cleanJson = result.text!.replaceAll(RegExp(r'^```json\s*|```$'), '').trim();
          final decoded = jsonDecode(cleanJson);
          if (decoded is List) {
            final plan = <PlannedMealItem>[];
            int counter = 0;
            for (final item in decoded) {
              if (item is Map) {
                final m = Map<String, dynamic>.from(item);
                plan.add(
                  PlannedMealItem(
                    id: 'plan_cloud_${DateTime.now().millisecondsSinceEpoch}_${counter++}',
                    dateIso: effectiveDate,
                    mealSlot: MealSlot.fromString(m['mealSlot']?.toString() ?? 'lunch'),
                    title: m['title']?.toString() ?? 'Balanced Meal',
                    servings: (m['servings'] as num?)?.toDouble() ?? 1.0,
                    kcal: (m['kcal'] as num?)?.toDouble() ?? 400.0,
                    proteinG: (m['proteinG'] as num?)?.toDouble() ?? 20.0,
                    carbsG: (m['carbsG'] as num?)?.toDouble() ?? 50.0,
                    fatG: (m['fatG'] as num?)?.toDouble() ?? 12.0,
                    fibreG: (m['fibreG'] as num?)?.toDouble() ?? 6.0,
                    prepTimeMin: (m['prepTimeMin'] as num?)?.toInt() ?? 20,
                    estimatedCostInr: (m['estimatedCostInr'] as num?)?.toDouble() ?? 50.0,
                    whySuggested: m['whySuggested']?.toString() ?? 'Optimized for your targets',
                  ),
                );
              }
            }
            if (plan.isNotEmpty) {
              return plan;
            }
          }
        }
      } catch (e) {
        debugPrint('generateSmartMealPlanWithAi cloud call failed, using native engine: $e');
      }
    }

    // Offline native AI fallback
    return NativeDietAiEngine.generatePlanFromPantry(
      availableIngredients: pantryItems,
      profile: profile,
      foods: repo.foods,
      dateIso: effectiveDate,
    );
  }
}
