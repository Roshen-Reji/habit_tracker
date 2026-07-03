import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker/data/models/diet_models.dart';
import 'package:habit_tracker/data/models/goal.dart';
import 'package:habit_tracker/models/finance_model.dart';
import 'package:habit_tracker/models/song_model.dart';
import 'package:habit_tracker/services/music_manager.dart';

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

// --- Main AI Service ---
class AiService {
  static AiService? _instance;
  List<Map<String, dynamic>> _messagesHistory = [];

  AiService._();

  static AiService get instance {
    _instance ??= AiService._();
    return _instance!;
  }

  bool get isConfigured {
    String apiKey = Hive.box('settings').get('freetheai_key', defaultValue: '');
    if (apiKey.isEmpty) apiKey = const String.fromEnvironment('FREETHEAI_API_KEY', defaultValue: '');
    return apiKey.isNotEmpty;
  }

  void _initModel() {
    String apiKey = Hive.box('settings').get('freetheai_key', defaultValue: '');
    if (apiKey.isEmpty) apiKey = const String.fromEnvironment('FREETHEAI_API_KEY', defaultValue: '');
    if (apiKey.isEmpty) return;

    _messagesHistory = [
      {'role': 'system', 'content': _buildSystemPrompt()},
      {'role': 'assistant', 'content': 'Understood. I\'m your AI assistant. I can help with diet tracking, task management, finance analysis, music playback, and general advice. What can I do for you?'},
    ];
  }

  String _buildSystemPrompt() {
    return '''You are a powerful personal AI assistant integrated into a habit tracking app. You handle MULTIPLE domains:

## CAPABILITIES:
1. **DIET TRACKING**: Log food, estimate calories/macros, track burns, generate reports
2. **TASK MANAGEMENT**: Parse natural language into structured goals/tasks
3. **FINANCE ANALYSIS**: Query expenses, provide spending diagnostics and honest opinions
4. **MUSIC CONTROL**: Search and play songs from user's local library
5. **GOAL ANALYSIS**: Analyze completion rates, streaks, provide motivational feedback

## RESPONSE FORMAT:
You MUST respond with valid JSON in this exact format:
{
  "intent": "<one of: diet_log, diet_burn, diet_report, diet_advice, task_create, finance_query, finance_advice, music_play, goal_opinion, general_chat>",
  "message": "<your conversational response to the user>",
  "actions": [
    {
      "type": "<food_entry | burn_entry | task_create | music_play>",
      "payload": { ... }
    }
  ]
}

## ACTION PAYLOADS:

### food_entry:
{"name": "2 Eggs", "calories": 140, "protein": 12.0, "carbs": 1.0, "fat": 10.0, "meal_type": "breakfast"}

### burn_entry:
{"activity": "Running", "calories_burned": 150, "duration_minutes": 20}

### task_create:
{"title": "Physics Lectures", "type": "today|daily|weekly|monthly", "target_value": 2, "unit": "lectures", "category": "learning|health|productivity|fitness|hobby"}

### music_play:
{"search_query": "blinding lights", "artist_hint": "the weeknd"}

## RULES:
- For diet: Estimate macros based on common nutritional data. Be accurate. Don't use ~ symbols.
- For diet reports: Calculate totals precisely. Double-check math.
- For tasks: Infer the correct type from context ("today" = today, "everyday" / "daily" = daily, "this week" = weekly, "this month" = monthly)
- For finance: Provide honest, unbiased analysis. Highlight concerning patterns.
- For music: Extract the song name and artist if mentioned.
- Always respond in JSON format. No markdown outside the JSON.
- If the user's message is ambiguous, classify as general_chat and ask for clarification.
- You can include multiple actions in one response (e.g., logging multiple food items).
''';
  }

  /// Process a user message and return an AI response
  Future<AiResponse> processMessage(String userMessage, {String? contextHint, Uint8List? imageBytes}) async {
    if (!isConfigured) {
      return AiResponse(
        message: 'Please set your Gemini API key in Settings to use AI features.',
        intent: 'error',
      );
    }

    if (_messagesHistory.isEmpty) {
      _initModel();
    }

    try {
      // Build context
      String contextData = '';
      if (contextHint == 'diet' || contextHint == null) {
        contextData += _buildDietContext();
      }
      if (contextHint == 'finance' || contextHint == null) {
        contextData += _buildFinanceContext();
      }
      if (contextHint == 'tasks' || contextHint == null) {
        contextData += _buildTaskContext();
      }
      if (contextHint == 'music' || contextHint == null) {
        contextData += _buildMusicContext();
      }

      final fullMessage = contextData.isNotEmpty
          ? '[CONTEXT]\n$contextData\n[USER MESSAGE]\n$userMessage'
          : userMessage;

      Map<String, dynamic> userMessageContent;
      if (imageBytes != null) {
        final base64Image = base64Encode(imageBytes);
        userMessageContent = {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': fullMessage},
            {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}}
          ]
        };
      } else {
        userMessageContent = {
          'role': 'user',
          'content': fullMessage
        };
      }

      _messagesHistory.add(userMessageContent);

      String apiKey = Hive.box('settings').get('freetheai_key', defaultValue: '');
      if (apiKey.isEmpty) apiKey = const String.fromEnvironment('FREETHEAI_API_KEY', defaultValue: '');

      final requestBody = {
        'model': 'opc/deepseek-v4-flash-free',
        'messages': _messagesHistory,
        'temperature': 0.7,
      };

      final response = await http.post(
        Uri.parse('https://api.freetheai.xyz/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://github.com/habit-tracker', // Optional OpenRouter header
          'X-Title': 'Commander Habit Tracker',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final responseText = json['choices'][0]['message']['content'];
        
        // Append assistant response to history
        _messagesHistory.add({'role': 'assistant', 'content': responseText});
        
        return _parseResponse(responseText);
      } else {
        debugPrint('FreeTheAI Error: ${response.statusCode} - ${response.body}');
        return AiResponse(
          message: 'Error communicating with AI service. Please try again.',
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

  // --- Context Builders ---

  String _buildDietContext() {
    try {
      final box = Hive.box<DietDayLog>('diet_logs');
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayLog = box.get(today);

      if (todayLog == null) return '\n[DIET TODAY: No meals logged yet. Target: ${_getCalorieTarget()} kcal]\n';

      final buffer = StringBuffer();
      buffer.writeln('\n[DIET TODAY - $today]');
      buffer.writeln('Target: ${todayLog.targetCalories} kcal');
      buffer.writeln('Foods logged:');
      for (var e in todayLog.entries) {
        buffer.writeln('  - ${e.name}: ${e.calories} kcal, P:${e.protein}g, C:${e.carbs}g, F:${e.fat}g (${e.mealType.name})');
      }
      buffer.writeln('Total intake: ${todayLog.totalCalories} kcal');
      buffer.writeln('Burns logged:');
      for (var b in todayLog.burnEntries) {
        buffer.writeln('  - ${b.activity}: ${b.caloriesBurned} kcal (${b.durationMinutes} min)');
      }
      buffer.writeln('Total burned: ${todayLog.totalBurned} kcal');
      buffer.writeln('Net: ${todayLog.netCalories} kcal');
      buffer.writeln('Deficit/Surplus: ${todayLog.isDeficit ? "DEFICIT" : "SURPLUS"} ${todayLog.deficit.abs().toStringAsFixed(0)} kcal');

      // Last 7 days summary
      buffer.writeln('\n[DIET LAST 7 DAYS]');
      for (int i = 6; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        final key = DateFormat('yyyy-MM-dd').format(date);
        final log = box.get(key);
        if (log != null) {
          buffer.writeln('  $key: ${log.totalCalories.toStringAsFixed(0)} kcal in, ${log.totalBurned.toStringAsFixed(0)} burned');
        }
      }

      return buffer.toString();
    } catch (e) {
      return '\n[DIET: Data unavailable]\n';
    }
  }

  String _buildFinanceContext() {
    try {
      final txBox = Hive.box<Transaction>('finance_transactions');
      final transactions = txBox.values.toList();

      if (transactions.isEmpty) return '\n[FINANCE: No transactions recorded]\n';

      final now = DateTime.now();
      final buffer = StringBuffer();

      // This month
      double monthIncome = 0, monthExpense = 0;
      Map<String, double> categorySpend = {};

      for (var tx in transactions) {
        if (tx.date.month == now.month && tx.date.year == now.year) {
          if (tx.amount > 0) {
            monthIncome += tx.amount;
          } else {
            monthExpense += tx.amount.abs();
            categorySpend[tx.category] = (categorySpend[tx.category] ?? 0) + tx.amount.abs();
          }
        }
      }

      buffer.writeln('\n[FINANCE - ${DateFormat('MMMM yyyy').format(now)}]');
      buffer.writeln('Income: ${monthIncome.toStringAsFixed(0)}');
      buffer.writeln('Expenses: ${monthExpense.toStringAsFixed(0)}');
      buffer.writeln('Savings: ${(monthIncome - monthExpense).toStringAsFixed(0)}');
      buffer.writeln('Savings Rate: ${monthIncome > 0 ? ((monthIncome - monthExpense) / monthIncome * 100).toStringAsFixed(1) : 0}%');
      buffer.writeln('Spending by category:');
      final sorted = categorySpend.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      for (var e in sorted) {
        buffer.writeln('  - ${e.key}: ${e.value.toStringAsFixed(0)}');
      }

      // Last week transactions
      final weekAgo = now.subtract(const Duration(days: 7));
      double weekExpense = 0;
      Map<String, double> weekCategories = {};
      for (var tx in transactions) {
        if (tx.date.isAfter(weekAgo) && tx.amount < 0) {
          weekExpense += tx.amount.abs();
          weekCategories[tx.category] = (weekCategories[tx.category] ?? 0) + tx.amount.abs();
        }
      }
      buffer.writeln('\n[LAST 7 DAYS]');
      buffer.writeln('Total spent: ${weekExpense.toStringAsFixed(0)}');
      final weekSorted = weekCategories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      for (var e in weekSorted) {
        buffer.writeln('  - ${e.key}: ${e.value.toStringAsFixed(0)}');
      }

      return buffer.toString();
    } catch (e) {
      return '\n[FINANCE: Data unavailable]\n';
    }
  }

  String _buildTaskContext() {
    try {
      final box = Hive.box<Goal>('mission_box_v4');
      final goals = box.values.toList();

      if (goals.isEmpty) return '\n[TASKS: No missions created]\n';

      final buffer = StringBuffer();
      buffer.writeln('\n[TASKS/MISSIONS]');

      int completed = goals.where((g) => g.isCompleted).length;
      int active = goals.where((g) => !g.isCompleted && !g.isArchived).length;
      buffer.writeln('Active: $active, Completed: $completed, Total: ${goals.length}');

      // Group by type
      for (var type in GoalType.values) {
        final typeGoals = goals.where((g) => g.type == type && !g.isArchived).toList();
        if (typeGoals.isNotEmpty) {
          buffer.writeln('${type.name.toUpperCase()} (${typeGoals.length}):');
          for (var g in typeGoals.take(5)) {
            buffer.writeln('  - ${g.title}: ${g.isCompleted ? "✓" : "${g.currentValue.toInt()}/${g.targetValue.toInt()} ${g.unit}"} (streak: ${g.streakCount})');
          }
        }
      }

      return buffer.toString();
    } catch (e) {
      return '\n[TASKS: Data unavailable]\n';
    }
  }

  String _buildMusicContext() {
    try {
      final manager = MusicManager();
      final songs = manager.currentPlaylist;
      if (songs == null || songs.isEmpty) return '\n[MUSIC: No songs loaded. User needs to open Music tab first to load library.]\n';

      final buffer = StringBuffer();
      buffer.writeln('\n[MUSIC LIBRARY - ${songs.length} songs available]');
      buffer.writeln('Song list (title | artist):');
      for (var s in songs.take(50)) {
        buffer.writeln('  - ${s.title} | ${s.artist}');
      }
      if (songs.length > 50) {
        buffer.writeln('  ... and ${songs.length - 50} more');
      }

      return buffer.toString();
    } catch (e) {
      return '\n[MUSIC: Library unavailable]\n';
    }
  }

  // --- Action Executors ---

  /// Execute a confirmed food entry action
  void executeFoodAction(AiAction action) {
    final payload = action.payload;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final box = Hive.box<DietDayLog>('diet_logs');

    DietDayLog log = box.get(today) ?? DietDayLog(
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

    // If the log is already in the box, save it; otherwise put it
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

    DietDayLog log = box.get(today) ?? DietDayLog(
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

    final goal = Goal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: payload['title'] ?? 'Untitled Task',
      type: type,
      category: category,
      targetValue: (payload['target_value'] ?? 1).toDouble(),
      unit: payload['unit'] ?? 'units',
      createdDate: DateTime.now(),
    );

    box.put(goal.id, goal);
  }

  /// Execute music play action — fuzzy search and play
  SongModel? executeMusicAction(AiAction action, List<SongModel> availableSongs) {
    final query = (action.payload['search_query'] ?? '').toString().toLowerCase();
    final artistHint = (action.payload['artist_hint'] ?? '').toString().toLowerCase();

    if (query.isEmpty || availableSongs.isEmpty) return null;

    // Fuzzy search: score each song
    SongModel? bestMatch;
    double bestScore = -1;

    for (var song in availableSongs) {
      double score = 0;
      final title = song.title.toLowerCase();
      final artist = song.artist.toLowerCase();

      // Exact title match
      if (title == query) {
        score += 100;
      }
      // Title contains query
      else if (title.contains(query)) {
        score += 60 + (query.length / title.length) * 30;
      }
      // Query contains title
      else if (query.contains(title)) {
        score += 40;
      }
      // Fuzzy: Levenshtein-like word matching
      else {
        final queryWords = query.split(RegExp(r'\s+'));
        int matchedWords = 0;
        for (var word in queryWords) {
          if (title.contains(word) || artist.contains(word)) {
            matchedWords++;
          }
        }
        score += (matchedWords / queryWords.length) * 50;
      }

      // Artist bonus
      if (artistHint.isNotEmpty) {
        if (artist == artistHint) {
          score += 30;
        } else if (artist.contains(artistHint) || artistHint.contains(artist)) {
          score += 15;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = song;
      }
    }

    if (bestMatch != null && bestScore > 10) {
      // Play the song
      final index = availableSongs.indexOf(bestMatch);
      MusicManager().setPlaylist(availableSongs, index);
      return bestMatch;
    }

    return null;
  }

  /// Confirm and execute an action
  void executeAction(AiAction action, {List<SongModel>? availableSongs}) {
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
      case 'music_play':
        if (availableSongs != null) {
          executeMusicAction(action, availableSongs);
        }
        break;
    }
    action.isConfirmed = true;
  }

  double _getCalorieTarget() {
    return Hive.box('settings').get('daily_calorie_target', defaultValue: 2000.0).toDouble();
  }

  /// Reset chat session
  void resetChat() {
    _messagesHistory.clear();
  }

  /// Get today's diet log
  DietDayLog getTodayLog() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final box = Hive.box<DietDayLog>('diet_logs');
    return box.get(today) ?? DietDayLog(
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

    DietDayLog log = box.get(today) ?? DietDayLog(
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
