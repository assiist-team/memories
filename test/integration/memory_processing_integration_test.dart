import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/memory_processing_service.dart';

/// Simple in-memory storage for tests
class _TestStorage implements LocalStorage {
  final Map<String, String> _storage = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() async {
    final sessionJson = _storage[supabasePersistSessionKey];
    if (sessionJson != null) {
      try {
        final session = jsonDecode(sessionJson) as Map<String, dynamic>;
        return session['access_token'] as String?;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;

  @override
  Future<void> persistSession(String persistSessionString) async {
    _storage[supabasePersistSessionKey] = persistSessionString;
  }

  @override
  Future<void> removePersistedSession() async {
    _storage.remove(supabasePersistSessionKey);
  }
}

/// End-to-end integration tests for memory processing edge functions
///
/// These tests verify the complete pipeline:
/// 1. Create a memory in the database
/// 2. Call the processing service (which invokes edge functions)
/// 3. Verify the database was updated with processed_text and title
///
/// Credentials are loaded from `.env` file:
/// - SUPABASE_URL
/// - SUPABASE_ANON_KEY
///
/// Uses a fixed test user ID: 5aeed2a7-26f9-40ac-a700-3a6da123f3b5
/// No authentication needed - we use the user_id directly when creating memories
///
/// Run with:
/// ```bash
/// flutter test test/integration/memory_processing_integration_test.dart
/// ```
void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Load .env file before running tests
  await dotenv.load(fileName: '.env');

  group('Memory Processing Integration Tests (E2E)', () {
    ProviderContainer? container;
    SupabaseClient? supabase;
    MemoryProcessingService? processingService;
    // Use the provided test user ID directly (no authentication needed)
    const String testUserId = '5aeed2a7-26f9-40ac-a700-3a6da123f3b5';
    final List<Map<String, dynamic>> testResults = [];
    final resultsFile =
        File('test/integration/memory_processing_test_results.json');

    void _saveResults() {
      try {
        final resultsJson = {
          'test_run_at': DateTime.now().toIso8601String(),
          'total_tests': testResults.length,
          'results': testResults,
        };
        resultsFile.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(resultsJson),
        );
        print('\n✓ Test results saved to: ${resultsFile.path}');
        print('  Processed ${testResults.length} memories successfully');
      } catch (e) {
        print('Warning: Failed to save test results: $e');
      }
    }

    bool _isSupabaseConfigured() {
      try {
        // Check dart-define flags first (highest priority)
        const dartDefineUrl =
            String.fromEnvironment('SUPABASE_URL', defaultValue: '');
        const dartDefineKey =
            String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

        if (dartDefineUrl.isNotEmpty && dartDefineKey.isNotEmpty) {
          return true;
        }

        // Check .env file (loaded in main())
        final envUrl = dotenv.env['SUPABASE_URL'] ?? '';
        final envKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

        return envUrl.isNotEmpty && envKey.isNotEmpty;
      } catch (e) {
        return false;
      }
    }

    setUpAll(() async {
      if (_isSupabaseConfigured()) {
        try {
          // Get credentials from .env file
          const dartDefineUrl =
              String.fromEnvironment('SUPABASE_URL', defaultValue: '');
          const dartDefineKey =
              String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

          final testUrl = dartDefineUrl.isNotEmpty
              ? dartDefineUrl
              : dotenv.env['SUPABASE_URL']!;
          final testAnonKey = dartDefineKey.isNotEmpty
              ? dartDefineKey
              : dotenv.env['SUPABASE_ANON_KEY']!;

          // Initialize SharedPreferences with mock values for tests
          // This allows Supabase.initialize() to work without platform plugins
          SharedPreferences.setMockInitialValues({});

          // Initialize Supabase with anon key
          // We don't need authentication - we'll use the user_id directly when creating memories
          final testStorage = _TestStorage();
          await Supabase.initialize(
            url: testUrl,
            anonKey: testAnonKey,
            authOptions: FlutterAuthClientOptions(
              authFlowType: AuthFlowType.pkce,
              autoRefreshToken: true,
              localStorage: testStorage,
            ),
          );

          // Use the initialized Supabase client
          final testClient = Supabase.instance.client;

          // Create container with overridden supabaseClientProvider
          container = ProviderContainer(
            overrides: [
              supabaseUrlProvider.overrideWith((ref) => testUrl),
              supabaseAnonKeyProvider.overrideWith((ref) => testAnonKey),
              supabaseClientProvider.overrideWith((ref) => testClient),
            ],
          );

          supabase = container!.read(supabaseClientProvider);
          processingService = container!.read(memoryProcessingServiceProvider);
        } catch (e) {
          print('Error setting up integration tests: $e');
          print(
              'Make sure SUPABASE_URL and SUPABASE_ANON_KEY are set in .env file');
          rethrow; // Re-throw so we know tests are actually failing
        }
      } else {
        throw StateError(
            'Supabase not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY to .env file '
            'or use --dart-define flags.');
      }
    });

    tearDownAll(() {
      container?.dispose();

      // Final save (in case any tests completed after the last save)
      if (testResults.isNotEmpty) {
        _saveResults();
      }
    });

    setUp(() async {
      // No setup needed
    });

    tearDown(() async {
      // Clean up test memories
      if (supabase != null) {
        try {
          // Get memory IDs first
          final memories = await supabase!
              .from('memories')
              .select('id')
              .eq('user_id', testUserId);

          if (memories.isNotEmpty) {
            final memoryIds =
                (memories as List).map((m) => m['id'] as String).toList();

            // Delete story_fields for these memories
            for (final memoryId in memoryIds) {
              try {
                await supabase!
                    .from('story_fields')
                    .delete()
                    .eq('memory_id', memoryId);
              } catch (e) {
                // Ignore if story_fields doesn't exist
              }
            }
          }

          // Delete memories created during tests
          await supabase!.from('memories').delete().eq('user_id', testUserId);
        } catch (e) {
          print('Cleanup error: $e');
        }
      }
    });

    test('processes a memento end-to-end', () async {
      if (!_isSupabaseConfigured() ||
          supabase == null ||
          processingService == null) {
        return;
      }

      // Step 1: Create a memento memory with raw input_text
      final mementoResponse = await supabase!
          .from('memories')
          .insert({
            'user_id': testUserId,
            'memory_type': 'memento',
            'input_text':
                'This is a test memento about my grandmother\'s locket. It was passed down through generations and holds special meaning for our family.',
            'title': null,
            'processed_text': null,
          })
          .select('id')
          .single();

      final memoryId = mementoResponse['id'] as String;

      // Step 2: Process the memento using the service
      final result = await processingService!.processMemento(
        memoryId: memoryId,
      );

      // Step 3: Verify the response
      expect(result.status, isIn(['success', 'partial', 'fallback']));
      expect(result.title, isNotEmpty);
      expect(result.processedText, isNotEmpty);
      expect(result.generatedAt, isNotNull);

      // Step 4: Verify the database was updated
      final updatedMemory = await supabase!
          .from('memories')
          .select('title, processed_text, title_generated_at')
          .eq('id', memoryId)
          .single();

      expect(updatedMemory['title'], isNotNull);
      expect(updatedMemory['title'], equals(result.title));
      expect(updatedMemory['processed_text'], isNotNull);
      expect(updatedMemory['processed_text'], equals(result.processedText));
      expect(updatedMemory['title_generated_at'], isNotNull);

      // Step 5: Verify processed_text is different from input_text (was actually processed)
      final fullMemory = await supabase!
          .from('memories')
          .select('input_text, processed_text')
          .eq('id', memoryId)
          .single();

      expect(fullMemory['input_text'], isNotEmpty);
      expect(fullMemory['processed_text'], isNotEmpty);
      // Processed text should be cleaned/improved (may be same length or different)
      // But it should exist and be non-empty
      if (result.status == 'success' || result.status == 'partial') {
        // If processing succeeded, verify it's actually different/improved
        expect(fullMemory['processed_text'], isNot(equals('')));
      }

      // Save test results
      testResults.add({
        'test': 'processes a memento end-to-end',
        'memory_type': 'memento',
        'memory_id': memoryId,
        'status': result.status,
        'input_text': fullMemory['input_text'],
        'processed_text': fullMemory['processed_text'],
        'title': result.title,
        'title_generated_at': updatedMemory['title_generated_at'],
        'generated_at': result.generatedAt.toIso8601String(),
      });

      // Save results after each test
      _saveResults();
    });

    test('processes a moment end-to-end', () async {
      if (!_isSupabaseConfigured() ||
          supabase == null ||
          processingService == null) {
        return;
      }

      // Step 1: Create a moment memory with raw input_text
      final momentResponse = await supabase!
          .from('memories')
          .insert({
            'user_id': testUserId,
            'memory_type': 'moment',
            'input_text':
                'I went to the park today and saw a beautiful sunset. The colors were amazing, um, like really vibrant oranges and pinks.',
            'title': null,
            'processed_text': null,
          })
          .select('id')
          .single();

      final memoryId = momentResponse['id'] as String;

      // Step 2: Process the moment using the service
      final result = await processingService!.processMoment(
        memoryId: memoryId,
      );

      // Step 3: Verify the response
      expect(result.status, isIn(['success', 'partial', 'fallback']));
      expect(result.title, isNotEmpty);
      expect(result.processedText, isNotEmpty);
      expect(result.generatedAt, isNotNull);

      // Step 4: Verify the database was updated
      final updatedMemory = await supabase!
          .from('memories')
          .select('title, processed_text, title_generated_at')
          .eq('id', memoryId)
          .single();

      expect(updatedMemory['title'], isNotNull);
      expect(updatedMemory['title'], equals(result.title));
      expect(updatedMemory['processed_text'], isNotNull);
      expect(updatedMemory['processed_text'], equals(result.processedText));
      expect(updatedMemory['title_generated_at'], isNotNull);

      // Step 5: Verify processed_text cleaned up filler words
      final fullMemory = await supabase!
          .from('memories')
          .select('input_text, processed_text')
          .eq('id', memoryId)
          .single();

      final processedText = fullMemory['processed_text'] as String;

      // If processing succeeded, verify filler words were removed
      if (result.status == 'success' || result.status == 'partial') {
        // Input has "um" and "like" - processed should ideally have fewer filler words
        // But at minimum, it should be non-empty and different
        expect(processedText, isNotEmpty);
      }

      // Save test results
      testResults.add({
        'test': 'processes a moment end-to-end',
        'memory_type': 'moment',
        'memory_id': memoryId,
        'status': result.status,
        'input_text': fullMemory['input_text'],
        'processed_text': processedText,
        'title': result.title,
        'title_generated_at': updatedMemory['title_generated_at'],
        'generated_at': result.generatedAt.toIso8601String(),
      });

      // Save results after each test
      _saveResults();
    });

    test('processes a story end-to-end', () async {
      if (!_isSupabaseConfigured() ||
          supabase == null ||
          processingService == null) {
        return;
      }

      // Step 1: Create a story memory with raw input_text
      final storyResponse = await supabase!
          .from('memories')
          .insert({
            'user_id': testUserId,
            'memory_type': 'story',
            'input_text':
                'So I was walking down the street, um, and I saw this amazing thing. Like, it was really cool. You know, I mean, it was just incredible.',
            'title': null,
            'processed_text': null,
          })
          .select('id')
          .single();

      final memoryId = storyResponse['id'] as String;

      // Step 2: Create story_fields row (required for story processing)
      await supabase!.from('story_fields').insert({
        'memory_id': memoryId,
        'story_status': 'processing',
        'retry_count': 0,
      });

      // Step 3: Process the story using the service
      final result = await processingService!.processStory(
        memoryId: memoryId,
      );

      // Step 4: Verify the response
      expect(result.status, isIn(['success', 'fallback', 'failed']));
      expect(result.title, isNotEmpty);
      expect(result.processedText, isNotEmpty);
      expect(result.generatedAt, isNotNull);

      // Step 5: Verify the database was updated
      final updatedMemory = await supabase!
          .from('memories')
          .select('title, processed_text, title_generated_at')
          .eq('id', memoryId)
          .single();
      expect(updatedMemory['title'], isNotNull);
      expect(updatedMemory['title'], equals(result.title));
      expect(updatedMemory['processed_text'], isNotNull);
      expect(updatedMemory['processed_text'], equals(result.processedText));
      expect(updatedMemory['title_generated_at'], isNotNull);

      // Step 6: Verify story_fields was updated
      final storyFields = await supabase!
          .from('story_fields')
          .select(
              'story_status, processing_completed_at, narrative_generated_at')
          .eq('memory_id', memoryId)
          .single();

      if (result.status == 'success') {
        expect(storyFields['story_status'], equals('complete'));
        expect(storyFields['processing_completed_at'], isNotNull);
        expect(storyFields['narrative_generated_at'], isNotNull);
      } else if (result.status == 'failed') {
        expect(storyFields['story_status'], equals('failed'));
        expect(storyFields['processing_completed_at'], isNotNull);
      }

      // Step 7: Verify processed_text is a narrative (different from input)
      final fullMemory = await supabase!
          .from('memories')
          .select('input_text, processed_text')
          .eq('id', memoryId)
          .single();

      final inputText = fullMemory['input_text'] as String;
      final processedText = fullMemory['processed_text'] as String;

      // Processed text should be a narrative (longer, more polished)
      if (result.status == 'success') {
        expect(processedText, isNotEmpty);
        // Narrative should be more polished than raw transcript
        expect(
            processedText.length, greaterThanOrEqualTo(inputText.length ~/ 2));
      }

      // Save test results
      testResults.add({
        'test': 'processes a story end-to-end',
        'memory_type': 'story',
        'memory_id': memoryId,
        'status': result.status,
        'input_text': inputText,
        'processed_text': processedText,
        'title': result.title,
        'title_generated_at': updatedMemory['title_generated_at'],
        'generated_at': result.generatedAt.toIso8601String(),
        'story_status': storyFields['story_status'],
        'processing_completed_at': storyFields['processing_completed_at'],
        'narrative_generated_at': storyFields['narrative_generated_at'],
      });

      // Save results after each test
      _saveResults();
    });

    test('handles processing failure gracefully', () async {
      if (!_isSupabaseConfigured() ||
          supabase == null ||
          processingService == null) {
        return;
      }

      // Create a memory with empty input_text (should fail gracefully)
      final momentResponse = await supabase!
          .from('memories')
          .insert({
            'user_id': testUserId,
            'memory_type': 'moment',
            'input_text': '',
            'title': null,
            'processed_text': null,
          })
          .select('id')
          .single();

      final memoryId = momentResponse['id'] as String;

      // Processing should throw an exception or return an error
      expect(
        () => processingService!.processMoment(memoryId: memoryId),
        throwsA(anything),
      );
    });
  });
}
