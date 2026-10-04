import 'dart:convert';
import 'package:habit_tracker/data/services/ai_context.dart';
import 'package:habit_tracker/data/services/gemini_client.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:habit_tracker/services/now_playing_service.dart';
import 'package:habit_tracker/features/finance/data/finance_repository.dart';

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
  bool isConfirmed;

  AiAction({
    required this.type,
    required this.payload,
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

    // Image -> most likely food logging
    if (hasImage) return 'diet';

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
  AiResponse? _handleLocally(String message, String intent) {
    final lower = message.toLowerCase().trim();

    if (intent == 'vault') return _handleVaultLocally(message);
    if (intent == 'tasks') return _handleTasksLocally(message);
    if (intent == 'finance') return _handleFinanceLocally(message);
    if (intent == 'diet') return _handleDietLocally(message);

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

    if (_isSipQuery(lower)) return _buildSipResponse();
    if (_isFinanceSummaryQuery(lower)) return _buildFinanceSummaryResponse();

    final amount = _extractMoneyAmount(lower);
    if (amount == null || amount <= 0) return null;

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

  AiResponse _buildSipResponse() {
    final settingsBox = Hive.box('finance_settings');
    final planner = Map.from(settingsBox
        .get('planner', defaultValue: {'fixedExpenses': [], 'sips': []}));
    final sips = List.from(planner['sips'] ?? []);
    final monthlySip = sips.fold<double>(
        0, (sum, item) => sum + _asDouble((item as Map)['amount']));

    final vaultBox = Hive.box<AssetVault>('finance_vaults');
    final sipVaults = vaultBox.values.where((vault) {
      final name = vault.name.toLowerCase();
      final type = vault.type.toLowerCase();
      return name.contains('sip') || type.contains('sip');
    }).toList();
    final vaultTotal =
        sipVaults.fold<double>(0, (sum, vault) => sum + vault.balance);

    final details = sips.map((item) {
      final sip = Map.from(item as Map);
      return '${sip['name'] ?? 'SIP'}: ${_formatMoney(_asDouble(sip['amount']))}/mo';
    }).join(', ');

    final msg = StringBuffer(
        'Your current SIP commitment is ${_formatMoney(monthlySip)}/month.');
    if (details.isNotEmpty) msg.write(' $details.');
    if (vaultTotal > 0)
      msg.write(' SIP-tagged vault balance: ${_formatMoney(vaultTotal)}.');

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

  void _recordFinanceTransaction({
    required String title,
    required double amount,
    required bool isExpense,
    required String category,
  }) {
    FinanceRepository().addTransaction(TxDraft(
      title: _titleCase(
          title.isEmpty ? (isExpense ? 'Expense' : 'Income') : title),
      amount: isExpense ? -amount.abs() : amount.abs(),
      date: DateTime.now(),
      mode: isExpense ? 'expense' : 'income',
      category: category,
      icon: isExpense ? 'expense' : 'income',
      kind: isExpense ? 'expense' : 'income',
    ));
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

  /// Process a user message and return an AI response
  Future<AiResponse> processMessage(String userMessage,
      {String? contextHint, Uint8List? imageBytes}) async {
    if (_messagesHistory.isEmpty) {
      _initModel();
    }

    try {
      // Smart intent detection - only attach relevant context
      final detectedIntent = detectIntent(
        userMessage,
        hasImage: imageBytes != null,
        contextHint: contextHint,
      );

      // Attempt to handle locally using Regex NLP engine first (saves time and tokens)
      if (imageBytes == null) {
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

        final localResponse = _handleLocally(userMessage, detectedIntent);
        if (localResponse != null) {
          // Add to history so future Gemini calls know what happened
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
              'I can handle common task, finance, diet, music, and vault commands locally, but this request needs Gemini. Add the Gemini API key in Settings for fallback reasoning. Settings keys are used before environment keys.',
          intent: 'error',
        );
      }

      // Build minimal context based on detected intent
      String contextData = '';
      if (detectedIntent == 'diet') {
        contextData = AiContext.buildDietContext(_getCalorieTarget());
      } else if (detectedIntent == 'finance') {
        contextData = AiContext.buildFinanceContext();
      } else if (detectedIntent == 'tasks') {
        contextData = AiContext.buildTaskContext();
      }
      // 'music' intent is handled on-device - never reaches AI
      // 'general' intent gets no context - saves tokens

      final fullMessage = contextData.isNotEmpty
          ? '[CONTEXT]\n$contextData\n[USER MESSAGE]\n$userMessage'
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

      // Add user message to history (text only for history)
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

      // Do NOT prepend system prompt to user message text.
      // Instead, pass it properly in the generationConfig or systemInstruction

      // Build Gemini API request
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
            'parts': parts, // Use parts with image if present
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

        // Append assistant response to history
        _messagesHistory.add({
          'role': 'model',
          'parts': [
            {'text': responseText}
          ],
        });

        return _parseResponse(responseText);
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
      // Clean up response - remove markdown code fences if present
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
          actions.add(AiAction(
            type: action['type'] ?? 'unknown',
            payload: Map<String, dynamic>.from(action['payload'] ?? {}),
          ));
        }
      }

      return AiResponse(
        message: json['message'] ?? 'No response generated.',
        intent: json['intent'] ?? 'general_chat',
        actions: actions,
        data: json['data'] as Map<String, dynamic>?,
      );
    } catch (e) {
      // If JSON parsing fails, treat as general chat text
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
    );

    box.put(goal.id, goal);
  }

  /// Execute a confirmed finance transaction action
  void executeFinanceAction(AiAction action) {
    final payload = action.payload;
    final mode = (payload['mode'] ?? 'expense').toString().toLowerCase();
    final isExpense = mode != 'income';
    final title =
        (payload['title'] ?? (isExpense ? 'Expense' : 'Income')).toString();
    final amount = _asDouble(payload['amount']);
    if (amount <= 0) return;

    _recordFinanceTransaction(
      title: title,
      amount: amount,
      isExpense: isExpense,
      category:
          (payload['category'] ?? (isExpense ? 'Other' : 'Income')).toString(),
    );
  }

  void _executeFinanceBudgetAction(AiAction action) {
    final payload = action.payload;
    final category = payload['category']?.toString() ?? 'Other';
    final total = _asDouble(payload['total'] ?? 0);
    if (total <= 0) return;

    final settingsBox = Hive.box('finance_settings');
    List budgets = List.from(settingsBox.get('budgets', defaultValue: []));

    int existingIdx = budgets.indexWhere((b) {
      final item = Map.from(b as Map);
      return item['category']?.toString().toLowerCase() ==
          category.toLowerCase();
    });
    if (existingIdx != -1) {
      final existing = Map.from(budgets[existingIdx] as Map);
      existing['total'] = total;
      budgets[existingIdx] = existing;
    } else {
      budgets.add({
        'category': category,
        'total': total,
        'color': 0xFF22C55E,
      });
    }
    settingsBox.put('budgets', budgets);
  }

  void _executeFinanceCommitmentAction(AiAction action) {
    final payload = action.payload;
    final name = payload['name']?.toString() ?? 'Subscription';
    final amount = _asDouble(payload['amount'] ?? 0);
    final date = payload['date'] ?? 1;
    if (amount <= 0) return;

    final settingsBox = Hive.box('finance_settings');
    Map p = Map.from(settingsBox
        .get('planner', defaultValue: {"fixedExpenses": [], "sips": []}));
    List fixed = List.from(p['fixedExpenses'] ?? []);

    fixed.add({
      'name': name,
      'amount': amount,
      'due': int.tryParse(date.toString()) ?? 1,
      'category': payload['category']?.toString() ?? 'Fixed',
    });

    p['fixedExpenses'] = fixed;
    settingsBox.put('planner', p);
  }

  void _executeFinanceGoalAction(AiAction action) {
    final payload = action.payload;
    final name = payload['name']?.toString() ?? 'Goal';
    final target = _asDouble(payload['target'] ?? 0);
    if (target <= 0) return;

    final settingsBox = Hive.box('finance_settings');
    List goals = List.from(settingsBox.get('goals', defaultValue: []));

    goals.add({
      'name': name,
      'saved': _asDouble(payload['saved'] ?? 0),
      'target': target,
      'deadline': payload['deadline']?.toString() ?? '',
      'color': 0xFF2DD4BF,
    });
    settingsBox.put('goals', goals);
  }

  void _executeFinanceSipAction(AiAction action) {
    final payload = action.payload;
    final name = payload['name']?.toString() ?? 'SIP';
    final amount = _asDouble(payload['amount'] ?? 0);
    final due = payload['due'] ?? 1;
    if (amount <= 0) return;

    final settingsBox = Hive.box('finance_settings');
    Map p = Map.from(settingsBox
        .get('planner', defaultValue: {"fixedExpenses": [], "sips": []}));
    List sipsList = List.from(p['sips'] ?? []);

    sipsList.add({
      'name': name,
      'amount': amount,
      'due': int.tryParse(due.toString()) ?? 1,
      'folio': payload['folio']?.toString() ?? 'Auto-added',
    });

    p['sips'] = sipsList;
    settingsBox.put('planner', p);
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
  void executeAction(AiAction action) {
    switch (action.type) {
      case 'food_entry':
        executeFoodAction(action);
        break;
      case 'burn_entry':
        executeBurnAction(action);
        break;
      case 'task_create':
        executeTaskAction(action);
        break;
      case 'finance_transaction':
        executeFinanceAction(action);
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
    }
    action.isConfirmed = true;
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
}
