import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:habit_tracker/data/services/gemini_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late Box settingsBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('gemini_client_test_');
    Hive.init(tempDir.path);
    settingsBox = await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    await settingsBox.clear();
  });

  group('GeminiClient tests (P0-2)', () {
    test('Success path: first model returns 200 and text', () async {
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/models')) {
          return http.Response('Error', 500); // Forces fallback list
        }
        if (request.url.path.contains('generateContent')) {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': '{"message":"Hello from Gemini"}'}
                    ]
                  }
                }
              ]
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final client = GeminiClient(client: mock);
      final result = await client.generateContent(
        requestBody: {'contents': []},
        apiKey: 'test-api-key',
        settingsBox: settingsBox,
      );

      expect(result.isSuccess, isTrue);
      expect(result.text, equals('{"message":"Hello from Gemini"}'));
      expect(result.modelUsed, equals(GeminiClient.fallbackModels.first));
      expect(result.statusCode, equals(200));
    });

    test('404 -> next model: first model 404, second model 200', () async {
      int generateContentAttempts = 0;
      final requestedModels = <String>[];

      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/models')) {
          return http.Response('Error', 500); // Forces fallback list
        }

        if (request.url.path.contains('generateContent')) {
          generateContentAttempts++;
          final path = request.url.path;
          final model = path.split('/models/')[1].split(':')[0];
          requestedModels.add(model);

          if (generateContentAttempts == 1) {
            return http.Response('Model not found', 404);
          } else {
            return http.Response(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {'text': '{"message":"Second model worked"}'}
                      ]
                    }
                  }
                ]
              }),
              200,
            );
          }
        }

        return http.Response('Not found', 404);
      });

      final client = GeminiClient(client: mock);
      final result = await client.generateContent(
        requestBody: {'contents': []},
        apiKey: 'test-api-key',
        settingsBox: settingsBox,
      );

      expect(result.isSuccess, isTrue);
      expect(result.text, equals('{"message":"Second model worked"}'));
      expect(generateContentAttempts, equals(2));
      expect(requestedModels.length, equals(2));
      expect(requestedModels[0], equals(GeminiClient.fallbackModels[0]));
      expect(requestedModels[1], equals(GeminiClient.fallbackModels[1]));
    });

    test('429 -> backoff and retry: succeeds on retry', () async {
      int postCount = 0;
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/models')) {
          return http.Response('Error', 500);
        }
        if (request.url.path.contains('generateContent')) {
          postCount++;
          if (postCount == 1) {
            return http.Response('Quota exceeded', 429,
                headers: {'retry-after': '1'});
          }
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Success after backoff'}
                    ]
                  }
                }
              ]
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final client = GeminiClient(client: mock);
      final result = await client.generateContent(
        requestBody: {'contents': []},
        apiKey: 'test-api-key',
        settingsBox: settingsBox,
      );

      expect(result.isSuccess, isTrue);
      expect(result.text, equals('Success after backoff'));
      expect(postCount, equals(2));
    });

    test('403 -> stop immediately with key guidance', () async {
      int generateCalls = 0;
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/models')) {
          return http.Response('Error', 500);
        }
        if (request.url.path.contains('generateContent')) {
          generateCalls++;
          return http.Response('Forbidden', 403);
        }
        return http.Response('Not found', 404);
      });

      final client = GeminiClient(client: mock);
      final result = await client.generateContent(
        requestBody: {'contents': []},
        apiKey: 'bad-key',
        activeApiKeySource: 'custom',
        settingsBox: settingsBox,
      );

      expect(result.isSuccess, isFalse);
      expect(result.statusCode, equals(403));
      expect(result.errorMessage, contains('custom key'));
      expect(result.errorMessage, contains('Recheck the key in Settings'));
      // Must not try subsequent models on 403
      expect(generateCalls, equals(1));
    });

    test('400 -> stop immediately and surface bad request', () async {
      int generateCalls = 0;
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/models')) {
          return http.Response('Error', 500);
        }
        if (request.url.path.contains('generateContent')) {
          generateCalls++;
          return http.Response('Invalid JSON body syntax', 400);
        }
        return http.Response('Not found', 404);
      });

      final client = GeminiClient(client: mock);
      final result = await client.generateContent(
        requestBody: {'invalid': 'payload'},
        apiKey: 'test-key',
        settingsBox: settingsBox,
      );

      expect(result.isSuccess, isFalse);
      expect(result.statusCode, equals(400));
      expect(result.errorMessage, contains('Gemini Bad Request (400'));
      expect(generateCalls, equals(1));
    });

    test('ListModels failure -> falls back to built-in fallback list',
        () async {
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/models')) {
          return http.Response('Server error', 500);
        }
        return http.Response('Not found', 404);
      });

      final client = GeminiClient(client: mock);
      final models = await client.resolveModels(
        apiKey: 'test-key',
        settingsBox: settingsBox,
      );

      expect(models, equals(GeminiClient.fallbackModels));
    });

    test('ListModels success -> caches and filters to flash + generateContent',
        () async {
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/models')) {
          return http.Response(
            jsonEncode({
              'models': [
                {
                  'name': 'models/gemini-pro',
                  'supportedGenerationMethods': ['generateContent']
                },
                {
                  'name': 'models/gemini-3.8-flash',
                  'supportedGenerationMethods': ['generateContent']
                },
                {
                  'name': 'models/gemini-embedding-001',
                  'supportedGenerationMethods': ['embedContent']
                },
                {
                  'name': 'models/gemini-3.6-flash',
                  'supportedGenerationMethods': ['generateContent']
                }
              ]
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final client = GeminiClient(client: mock);
      final models = await client.resolveModels(
        apiKey: 'test-key',
        settingsBox: settingsBox,
      );

      expect(models, contains('gemini-3.8-flash'));
      expect(models, contains('gemini-3.6-flash'));
      expect(models, isNot(contains('gemini-pro')));
      expect(models, isNot(contains('gemini-embedding-001')));

      // Check cache in settings box
      final cached = settingsBox.get('gemini_cached_models');
      expect(cached, isNotNull);
      expect(cached, contains('gemini-3.8-flash'));
    });

    test('Settings model override takes precedence over everything', () async {
      await settingsBox.put('gemini_model', 'custom-model-override');

      final mock = MockClient((request) async {
        return http.Response('Should not be called', 500);
      });

      final client = GeminiClient(client: mock);
      final models = await client.resolveModels(
        apiKey: 'test-key',
        settingsBox: settingsBox,
      );

      expect(models, equals(['custom-model-override']));
    });
  });
}
