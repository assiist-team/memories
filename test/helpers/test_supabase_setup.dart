import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Test helper for setting up a real Supabase client for integration tests
///
/// Usage:
/// ```dart
/// await dotenv.load(fileName: '.env');
/// final container = createTestSupabaseContainer();
/// final supabase = container.read(supabaseClientProvider);
/// ```
///
/// Credentials are loaded from `.env` file:
/// - SUPABASE_URL
/// - SUPABASE_ANON_KEY
///
/// Or use --dart-define flags (takes precedence):
/// flutter test --dart-define=SUPABASE_URL=xxx --dart-define=SUPABASE_ANON_KEY=xxx
ProviderContainer createTestSupabaseContainer() {
  // First try dart-define flags (highest priority)
  const dartDefineUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  const dartDefineKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  String testUrl;
  String testAnonKey;

  if (dartDefineUrl.isNotEmpty && dartDefineKey.isNotEmpty) {
    // Use dart-define values
    testUrl = dartDefineUrl;
    testAnonKey = dartDefineKey;
  } else {
    // Load from .env file (must be loaded before calling this function)
    testUrl = dotenv.env['SUPABASE_URL'] ?? '';
    testAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (testUrl.isEmpty || testAnonKey.isEmpty) {
      throw StateError(
        'Supabase credentials not found.\n'
        'Add to .env file:\n'
        '  SUPABASE_URL=https://xxxxx.supabase.co\n'
        '  SUPABASE_ANON_KEY=your-anon-key\n'
        '\n'
        'Or use --dart-define flags:\n'
        '  flutter test --dart-define=SUPABASE_URL=xxx --dart-define=SUPABASE_ANON_KEY=xxx',
      );
    }
  }

  // Note: Supabase must be initialized before calling this function
  // The supabaseClientProvider will use Supabase.instance.client
  return ProviderContainer(
    overrides: [
      supabaseUrlProvider.overrideWith((ref) => testUrl),
      supabaseAnonKeyProvider.overrideWith((ref) => testAnonKey),
      // Don't override supabaseClientProvider - use Supabase.instance.client
      // which should be initialized before calling this function
    ],
  );
}

/// Simple in-memory storage for tests (doesn't persist between test runs)
class _TestStorage implements LocalStorage {
  final Map<String, String> _storage = {};

  @override
  Future<void> initialize() async {
    // No initialization needed for in-memory storage
  }

  @override
  Future<String?> accessToken() async {
    // Parse session JSON if it exists
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
  Future<bool> hasAccessToken() async {
    return await accessToken() != null;
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    _storage[supabasePersistSessionKey] = persistSessionString;
  }

  @override
  Future<void> removePersistedSession() async {
    _storage.remove(supabasePersistSessionKey);
  }
}

/// Helper to clean up test data after integration tests
///
/// Call this in tearDown to ensure test isolation
Future<void> cleanupTestUser(SupabaseClient supabase, String userId) async {
  try {
    // Delete user profile (will cascade to auth.users if RLS allows)
    await supabase.from('profiles').delete().eq('id', userId);
  } catch (e) {
    // Ignore errors - user might not exist or RLS might prevent deletion
    // In a real test setup, you'd use a service role key for cleanup
  }
}

/// Create a test user for integration tests
///
/// Returns the created user and session
Future<({User user, Session session})> createTestUser(
  SupabaseClient supabase, {
  required String email,
  required String password,
  String? displayName,
}) async {
  // Sign up
  final signUpResponse = await supabase.auth.signUp(
    email: email,
    password: password,
    data: displayName != null ? {'display_name': displayName} : null,
  );

  if (signUpResponse.user == null || signUpResponse.session == null) {
    throw Exception('Failed to create test user');
  }

  return (user: signUpResponse.user!, session: signUpResponse.session!);
}

/// Sign in as a test user
Future<Session> signInTestUser(
  SupabaseClient supabase, {
  required String email,
  required String password,
}) async {
  final response = await supabase.auth.signInWithPassword(
    email: email,
    password: password,
  );

  if (response.session == null) {
    throw Exception('Failed to sign in test user');
  }

  return response.session!;
}
