import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Test helper for setting up a real Supabase client for integration tests
/// 
/// Usage:
/// ```dart
/// final container = createTestSupabaseContainer();
/// final supabase = container.read(supabaseClientProvider);
/// ```
/// 
/// Set these environment variables before running integration tests:
/// - TEST_SUPABASE_URL
/// - TEST_SUPABASE_ANON_KEY
/// 
/// Or use --dart-define flags:
/// flutter test --dart-define=TEST_SUPABASE_URL=xxx --dart-define=TEST_SUPABASE_ANON_KEY=xxx
ProviderContainer createTestSupabaseContainer() {
  // Get test credentials from environment
  const testUrl = String.fromEnvironment(
    'TEST_SUPABASE_URL',
    defaultValue: '',
  );
  const testAnonKey = String.fromEnvironment(
    'TEST_SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  if (testUrl.isEmpty || testAnonKey.isEmpty) {
    throw StateError(
      'Test Supabase credentials not found. '
      'Set TEST_SUPABASE_URL and TEST_SUPABASE_ANON_KEY environment variables '
      'or use --dart-define flags when running tests.',
    );
  }

  return ProviderContainer(
    overrides: [
      supabaseUrlProvider.overrideWith((ref) => testUrl),
      supabaseAnonKeyProvider.overrideWith((ref) => testAnonKey),
    ],
  );
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

