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
    String apiKey = Hive.box('settings').get('gemini_api_key', defaultValue: '');
    if (apiKey.isEmpty) apiKey = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    return apiKey.isNotEmpty;
  }

  // --- Smart Local Intent Detection ---
  // Detects intent from user message BEFORE sending to AI to minimize token usage
  String detectIntent(String message, {bool hasImage = false}) {
    final lower = message.toLowerCase().trim();

    // Image -> most likely food logging
    if (hasImage) return 'diet';

    // Music keywords (broad coverage for informal phrasing)
    final musicWords = ['play', 'song', 'track', 'music', 'listen', 'queue', 'album', 'artist',
      'sing', 'bajao', 'gana', 'gaana', 'sunao', 'suno', 'laga do', 'chalao', 'baja',
      'put on', 'shuffle', 'next song', 'skip', 'pause', 'resume', 'playing'];
    for (final w in musicWords) {
      if (lower.contains(w)) return 'music';
    }

    // Diet keywords
    final dietWords = ['eat', 'ate', 'food', 'calorie', 'protein', 'carb', 'fat', 'burn',
      'meal', 'breakfast', 'lunch', 'dinner', 'snack', 'diet', 'drink', 'drank', 'khaya',
      'khana', 'piya', 'kcal', 'macro', 'nutrition', 'fiber', 'consumed', 'intake',
      'biryani', 'rice', 'roti', 'dal', 'chicken', 'egg', 'milk', 'juice', 'water',
      'coffee', 'tea', 'oats', 'bread', 'pizza', 'burger', 'salad', 'fruit', 'weight'];
    for (final w in dietWords) {
      if (lower.contains(w)) return 'diet';
    }

    // Finance keywords
    final financeWords = ['spend', 'spent', 'money', 'expense', 'income', 'budget', 'save',
      'savings', 'finance', 'cost', 'buy', 'bought', 'paid', 'pay', 'rupee', 'rs',
      'salary', 'emi', 'sip', 'invest', 'loan', 'debt', 'rent', 'bill', 'recharge',
      'shopping', 'paisa', 'kharcha', 'transaction'];
    for (final w in financeWords) {
      if (lower.contains(w)) return 'finance';
    }

    // Task keywords
    final taskWords = ['task', 'goal', 'mission', 'todo', 'complete', 'finish', 'study',
      'work', 'exercise', 'gym', 'read', 'habit', 'streak', 'progress', 'daily',
      'weekly', 'monthly', 'schedule', 'routine', 'padhai', 'kaam', 'target'];
    for (final w in taskWords) {
      if (lower.contains(w)) return 'tasks';
    }

    return 'general';
  }

  void _initModel() {
    _messagesHistory = [];
  }

  String _buildSystemPrompt() {
    return '''You are a concise personal AI assistant in a habit tracking app.

CAPABILITIES: Diet tracking, task management, finance analysis, goal feedback.

RESPOND IN JSON:
{"intent":"<diet_log|diet_burn|diet_report|diet_advice|task_create|finance_query|finance_advice|goal_opinion|general_chat>","message":"<your response>","actions":[{"type":"<food_entry|burn_entry|task_create>","payload":{}}]}

ACTION PAYLOADS:
food_entry: {"name":"2 Eggs","calories":140,"protein":12.0,"carbs":1.0,"fat":10.0,"meal_type":"breakfast"}
burn_entry: {"activity":"Running","calories_burned":150,"duration_minutes":20}
task_create: {"title":"Study","type":"today|daily|weekly|monthly","target_value":2,"unit":"hours","category":"learning|health|productivity|fitness|hobby"}

RULES:
- Estimate macros accurately. No ~ symbols.
- Infer task type from context.
- For finance: honest analysis.
- Always respond in JSON. No markdown outside JSON.
- Keep responses short and direct.
- Multiple actions allowed in one response.''';
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
      // Smart intent detection - only attach relevant context
      final detectedIntent = detectIntent(userMessage, hasImage: imageBytes != null);

      // Build minimal context based on detected intent
      String contextData = '';
      if (detectedIntent == 'diet') {
        contextData = _buildDietContext();
      } else if (detectedIntent == 'finance') {
        contextData = _buildFinanceContext();
      } else if (detectedIntent == 'tasks') {
        contextData = _buildTaskContext();
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
        'parts': [{'text': fullMessage}],
      });

      // Cap history to last 6 messages to prevent token bloat
      if (_messagesHistory.length > 6) {
        _messagesHistory = _messagesHistory.sublist(_messagesHistory.length - 6);
      }

      String apiKey = Hive.box('settings').get('gemini_api_key', defaultValue: '');
      if (apiKey.isEmpty) apiKey = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

      // Prepend system prompt to the first user message instead of using system_instruction
      if (parts.isNotEmpty) {
        final originalText = parts[0]['text'] ?? '';
        parts[0]['text'] = _buildSystemPrompt() + '\n\n' + originalText;
      } else {
        parts.insert(0, {'text': _buildSystemPrompt()});
      }

      // Build Gemini API request
      final requestBody = {
        'contents': [
          ..._messagesHistory.sublist(0, _messagesHistory.length > 0 ? _messagesHistory.length - 1 : 0),
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

      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final responseText = json['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        
        // Append assistant response to history
        _messagesHistory.add({
          'role': 'model',
          'parts': [{'text': responseText}],
        });
        
        return _parseResponse(responseText);
      } else {
        debugPrint('Gemini API Error: ${response.statusCode} - ${response.body}');
        return AiResponse(
          message: 'Error communicating with Gemini. Please check your API key.',
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

  // --- Context Builders (Trimmed for minimal tokens) ---

  String _buildDietContext() {
    try {
      final box = Hive.box<DietDayLog>('diet_logs');
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayLog = box.get(today);

      if (todayLog == null) return '\n[DIET: No meals today. Target: ${_getCalorieTarget()} kcal]\n';

      final buffer = StringBuffer();
      buffer.writeln('\n[DIET TODAY]');
      buffer.writeln('Target: ${todayLog.targetCalories} kcal');
      for (var e in todayLog.entries) {
        buffer.writeln('  ${e.name}: ${e.calories}cal P:${e.protein}g C:${e.carbs}g F:${e.fat}g (${e.mealType.name})');
      }
      buffer.writeln('Total: ${todayLog.totalCalories}cal in, ${todayLog.totalBurned}cal burned');
      buffer.writeln('Net: ${todayLog.netCalories}cal | ${todayLog.isDeficit ? "DEFICIT" : "SURPLUS"} ${todayLog.deficit.abs().toStringAsFixed(0)}');

      return buffer.toString();
    } catch (e) {
      return '\n[DIET: Data unavailable]\n';
    }
  }

  String _buildFinanceContext() {
    try {
      final txBox = Hive.box<Transaction>('finance_transactions');
      final transactions = txBox.values.toList();

      if (transactions.isEmpty) return '\n[FINANCE: No transactions]\n';

      final now = DateTime.now();
      double monthIncome = 0, monthExpense = 0;

      for (var tx in transactions) {
        if (tx.date.month == now.month && tx.date.year == now.year) {
          if (tx.amount > 0) monthIncome += tx.amount;
          else monthExpense += tx.amount.abs();
        }
      }

      return '\n[FINANCE ${DateFormat('MMM yyyy').format(now)}] Income: ${monthIncome.toStringAsFixed(0)} | Spent: ${monthExpense.toStringAsFixed(0)} | Saved: ${(monthIncome - monthExpense).toStringAsFixed(0)}\n';
    } catch (e) {
      return '\n[FINANCE: Data unavailable]\n';
    }
  }

  String _buildTaskContext() {
    try {
      final box = Hive.box<Goal>('mission_box_v4');
      final goals = box.values.toList();

      if (goals.isEmpty) return '\n[TASKS: None]\n';

      int completed = goals.where((g) => g.isCompleted).length;
      int active = goals.where((g) => !g.isCompleted && !g.isArchived).length;
      return '\n[TASKS] Active: $active, Completed: $completed, Total: ${goals.length}\n';
    } catch (e) {
      return '\n[TASKS: Data unavailable]\n';
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

  /// On-device fuzzy search for music - no AI needed
  SongModel? searchAndPlayMusic(String query, List<SongModel> availableSongs) {
    if (query.isEmpty || availableSongs.isEmpty) return null;

    final queryLower = query.toLowerCase().trim();
    
    // Phase 1: Search by title (exact, contains, word match)
    SongModel? bestMatch;
    double bestScore = 0; // Initialize at 0 instead of -1

    for (var song in availableSongs) {
      final title = song.title.toLowerCase();
      final artist = song.artist.toLowerCase();
      double score = 0;

      // Exact title match
      if (title == queryLower) {
        score = 100;
      }
      // Title contains query
      else if (title.contains(queryLower)) {
        score = 60 + (queryLower.length / title.length) * 30;
      }
      // Query contains title
      else if (queryLower.contains(title) && title.length > 2) {
        score = 40;
      }
      // Word-by-word matching
      else {
        final queryWords = queryLower.split(RegExp(r'\s+'));
        int matchedWords = 0;
        for (var word in queryWords) {
          if (word.length > 2 && (title.contains(word) || artist.contains(word))) {
            matchedWords++;
          }
        }
        if (queryWords.isNotEmpty && matchedWords > 0) {
          score = (matchedWords / queryWords.length) * 50;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = song;
      }
    }

    // Phase 1 success - title match found
    if (bestMatch != null && bestScore > 15) {
      final index = availableSongs.indexOf(bestMatch);
      MusicManager().setPlaylist(availableSongs, index);
      return bestMatch;
    }

    // Phase 2: Search by artist name
    bestScore = 0;
    bestMatch = null;
    for (var song in availableSongs) {
      final artist = song.artist.toLowerCase();
      double score = 0;
      
      if (artist == queryLower) {
        score = 80;
      } else if (artist.contains(queryLower)) {
        score = 30 + (queryLower.length / artist.length) * 20;
      } else {
        final queryWords = queryLower.split(RegExp(r'\s+'));
        for (var word in queryWords) {
          if (word.length > 3 && artist.contains(word)) { // Increased to > 3 to avoid matching "the", "and", etc.
            score += 10;
          }
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = song;
      }
    }

    if (bestMatch != null && bestScore >= 10) { // Increased threshold to 10
      final index = availableSongs.indexOf(bestMatch);
      MusicManager().setPlaylist(availableSongs, index);
      return bestMatch;
    }

    return null; // No match found
  }

  /// Extract song query from natural language message
  String extractSongQuery(String message) {
    final lower = message.toLowerCase().trim();
    
    // Remove common prefixes
    final prefixes = [
      'play ', 'play me ', 'put on ', 'can you play ', 'please play ',
      'play the song ', 'play song ', 'i want to listen to ', 'listen to ',
      'bajao ', 'chalao ', 'laga do ', 'sunao ', 'suno ',
      'play the track ', 'queue ', 'add to queue ',
    ];
    
    String cleaned = lower;
    for (final prefix in prefixes) {
      if (cleaned.startsWith(prefix)) {
        cleaned = cleaned.substring(prefix.length).trim();
        break;
      }
    }
    
    // Remove trailing common words
    final suffixes = [' please', ' now', ' for me', ' bro', ' dude', ' yaar'];
    for (final suffix in suffixes) {
      if (cleaned.endsWith(suffix)) {
        cleaned = cleaned.substring(0, cleaned.length - suffix.length).trim();
      }
    }
    
    // Remove "by [artist]" to get just the song name for primary search
    final byMatch = RegExp(r'\s+by\s+.+$').firstMatch(cleaned);
    if (byMatch != null) {
      cleaned = cleaned.substring(0, byMatch.start).trim();
    }
    
    return cleaned;
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
