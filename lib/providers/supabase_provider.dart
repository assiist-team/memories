import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_provider.g.dart';

/// Provider for Supabase URL from environment variables
@riverpod
String supabaseUrl(SupabaseUrlRef ref) {
  const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  
  if (url.isEmpty) {
    throw StateError(
      'SUPABASE_URL environment variable is not set. '
      'Please configure it in your environment or build configuration.',
    );
  }
  
  return url;
}

/// Provider for Supabase anonymous key from environment variables
@riverpod
String supabaseAnonKey(SupabaseAnonKeyRef ref) {
  const key = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  
  if (key.isEmpty) {
    throw StateError(
      'SUPABASE_ANON_KEY environment variable is not set. '
      'Please configure it in your environment or build configuration.',
    );
  }
  
  return key;
}

/// Provider for the single Supabase client instance
/// 
/// This provider creates and maintains a single Supabase client instance
/// that is shared app-wide. It uses the anon key for client-side operations
/// and relies on RLS policies for authorization.
@riverpod
SupabaseClient supabaseClient(SupabaseClientRef ref) {
  final url = ref.watch(supabaseUrlProvider);
  final anonKey = ref.watch(supabaseAnonKeyProvider);
  
  return SupabaseClient(
    url,
    anonKey,
    authOptions: const AuthClientOptions(
      autoRefreshToken: true,
    ),
  );
}

