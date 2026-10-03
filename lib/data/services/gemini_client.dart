import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

class GeminiResult {
  final bool isSuccess;
  final String? text;
  final String? modelUsed;
  final int statusCode;
  final String? errorMessage;

  GeminiResult.success({
    required this.text,
    required this.modelUsed,
    this.statusCode = 200,
  })  : isSuccess = true,
        errorMessage = null;

  GeminiResult.failure({
    required this.errorMessage,
    required this.statusCode,
    this.modelUsed,
  })  : isSuccess = false,
        text = null;
}

class GeminiClient {
  final http.Client _client;

  /// Default verified flash model fallback list (Oct 2026)
  static const List<String> fallbackModels = [
    'gemini-3.8-flash',
    'gemini-3.7-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-2.5-flash',
  ];

  GeminiClient({http.Client? client}) : _client = client ?? http.Client();

  /// Resolves the model candidate list in order:
  /// 1. settings['gemini_model'] (owner override)
  /// 2. ListModels endpoint filtered to generateContent + flash, cached for 24 hours
  /// 3. Built-in fallback list
  Future<List<String>> resolveModels({
    required String apiKey,
    Box? settingsBox,
  }) async {
    Box? box;
    try {
      box = settingsBox ??
          (Hive.isBoxOpen('settings') ? Hive.box('settings') : null);
    } catch (_) {}

    final override = box?.get('gemini_model')?.toString().trim();
    if (override != null && override.isNotEmpty) {
      return [override];
    }

    // Check 24-hour cache
    if (box != null) {
      final cached = box.get('gemini_cached_models');
      final cacheTime = box.get('gemini_models_cache_time');
      if (cached is List && cacheTime is int) {
        final age = DateTime.now().millisecondsSinceEpoch - cacheTime;
        if (age < const Duration(hours: 24).inMilliseconds &&
            cached.isNotEmpty) {
          return cached.map((e) => e.toString()).toList();
        }
      }
    }

    // Attempt ListModels API
    try {
      final url =
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models');
      final res = await _client.get(
        url,
        headers: {
          'x-goog-api-key': apiKey,
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rawList = (data['models'] as List?) ?? [];
        final flashModels = <String>[];
        for (final m in rawList) {
          final name = (m['name'] as String? ?? '').replaceFirst('models/', '');
          final methods = (m['supportedGenerationMethods'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          if (methods.contains('generateContent') && name.contains('flash')) {
            flashModels.add(name);
          }
        }
        flashModels.sort((a, b) => b.compareTo(a)); // Newest first
        if (flashModels.isNotEmpty) {
          if (box != null) {
            await box.put('gemini_cached_models', flashModels);
            await box.put('gemini_models_cache_time',
                DateTime.now().millisecondsSinceEpoch);
          }
          return flashModels;
        }
      }
    } catch (e) {
      debugPrint('GeminiClient ListModels failed: $e');
    }

    return fallbackModels;
  }

  /// Sends a generateContent request with the given [requestBody].
  /// Iterates through candidates:
  /// - 404: Proceeds to next model
  /// - 429: Backs off once (honors Retry-After) then proceeds
  /// - 400: Stops immediately and surfaces error
  /// - 401/403: Stops immediately with key guidance
  /// - Surfaces the first non-404 error encountered
  Future<GeminiResult> generateContent({
    required Map<String, dynamic> requestBody,
    required String apiKey,
    String activeApiKeySource = 'custom',
    Box? settingsBox,
  }) async {
    final models =
        await resolveModels(apiKey: apiKey, settingsBox: settingsBox);

    GeminiResult? firstNon404Error;

    for (final model in models) {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
      );
      final headers = {
        'x-goog-api-key': apiKey,
        'Content-Type': 'application/json',
      };
      final bodyStr = jsonEncode(requestBody);

      http.Response response;
      try {
        response = await _client.post(url, headers: headers, body: bodyStr);
      } catch (e) {
        debugPrint('Gemini attempt failed ($model): $e');
        firstNon404Error ??= GeminiResult.failure(
          errorMessage: 'Network error calling Gemini ($model): $e',
          statusCode: 0,
          modelUsed: model,
        );
        continue;
      }

      final truncated = response.body.length > 180
          ? '${response.body.substring(0, 180)}...'
          : response.body;
      debugPrint(
          'Gemini API: status=${response.statusCode} model=$model truncated-body=$truncated');

      if (response.statusCode == 200) {
        try {
          final json = jsonDecode(response.body);
          final text = json['candidates']?[0]?['content']?['parts']?[0]?['text']
              as String?;
          if (text != null) {
            return GeminiResult.success(
              text: text,
              modelUsed: model,
              statusCode: 200,
            );
          }
        } catch (e) {
          return GeminiResult.failure(
            errorMessage: 'Failed to parse Gemini response: $e',
            statusCode: 200,
            modelUsed: model,
          );
        }
      }

      // 401 or 403: Stop immediately with key guidance
      if (response.statusCode == 401 || response.statusCode == 403) {
        return GeminiResult.failure(
          errorMessage:
              'Gemini fallback failed using the $activeApiKeySource key (${response.statusCode}). Recheck the key in Settings. Details: $truncated',
          statusCode: response.statusCode,
          modelUsed: model,
        );
      }

      // 400: Stop and surface body
      if (response.statusCode == 400) {
        return GeminiResult.failure(
          errorMessage: 'Gemini Bad Request (400, model $model): $truncated',
          statusCode: 400,
          modelUsed: model,
        );
      }

      // 429: Back off once, retry same model, then next model
      if (response.statusCode == 429) {
        int backoffSeconds = 1;
        final retryAfter = response.headers['retry-after'];
        if (retryAfter != null) {
          final parsed = int.tryParse(retryAfter);
          if (parsed != null && parsed > 0) {
            backoffSeconds = parsed.clamp(1, 3);
          }
        }
        await Future.delayed(Duration(seconds: backoffSeconds));

        try {
          final retryRes =
              await _client.post(url, headers: headers, body: bodyStr);
          final retryTruncated = retryRes.body.length > 180
              ? '${retryRes.body.substring(0, 180)}...'
              : retryRes.body;
          debugPrint(
              'Gemini API Retry: status=${retryRes.statusCode} model=$model truncated-body=$retryTruncated');

          if (retryRes.statusCode == 200) {
            final json = jsonDecode(retryRes.body);
            final text = json['candidates']?[0]?['content']?['parts']?[0]
                ?['text'] as String?;
            if (text != null) {
              return GeminiResult.success(
                text: text,
                modelUsed: model,
                statusCode: 200,
              );
            }
          }
        } catch (_) {}

        firstNon404Error ??= GeminiResult.failure(
          errorMessage: 'Gemini Rate Limited (429, model $model): $truncated',
          statusCode: 429,
          modelUsed: model,
        );
        continue;
      }

      // 404: Next model
      if (response.statusCode == 404) {
        continue;
      }

      // Other status (e.g. 500, 503)
      firstNon404Error ??= GeminiResult.failure(
        errorMessage:
            'Gemini fallback failed using the $activeApiKeySource key (${response.statusCode}, $model). Recheck the key in Settings. Details: $truncated',
        statusCode: response.statusCode,
        modelUsed: model,
      );
    }

    return firstNon404Error ??
        GeminiResult.failure(
          errorMessage:
              'All Gemini models in fallback chain were unavailable (404 Not Found).',
          statusCode: 404,
        );
  }

  /// Sends a minimal ping request to test the API key and model resolution
  Future<GeminiResult> testConnection({
    required String apiKey,
    Box? settingsBox,
  }) async {
    final minimalBody = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': 'Ping'}
          ]
        }
      ],
      'generationConfig': {
        'maxOutputTokens': 10,
      }
    };

    return generateContent(
      requestBody: minimalBody,
      apiKey: apiKey,
      settingsBox: settingsBox,
    );
  }
}
