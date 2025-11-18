import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_provider.g.dart';

/// Provider for Supabase URL from .env file
@riverpod
String supabaseUrl(SupabaseUrlRef ref) {
  try {
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    
    if (url.isEmpty) {
      throw StateError(
        'SUPABASE_URL not found in .env file. '
        'Please create a .env file with SUPABASE_URL set.',
      );
    }
    
    return url;
  } catch (e) {
    debugPrint('ERROR in supabaseUrlProvider: $e');
    rethrow;
  }
}

/// Provider for Supabase anonymous key from .env file
@riverpod
String supabaseAnonKey(SupabaseAnonKeyRef ref) {
  try {
    final key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    
    if (key.isEmpty) {
      throw StateError(
        'SUPABASE_ANON_KEY not found in .env file. '
        'Please create a .env file with SUPABASE_ANON_KEY set.',
      );
    }
    
    return key;
  } catch (e) {
    debugPrint('ERROR in supabaseAnonKeyProvider: $e');
    rethrow;
  }
}

/// Provider for the single Supabase client instance
/// 
/// This provider returns the Supabase client instance that was initialized
/// in main.dart. It uses the anon key for client-side operations
/// and relies on RLS policies for authorization.
/// 
/// The client is initialized with asyncStorage (FlutterSecureStorage) to
/// support OAuth PKCE flows.
@riverpod
SupabaseClient supabaseClient(SupabaseClientRef ref) {
  // Use the initialized Supabase instance from main.dart
  // This instance has asyncStorage configured for OAuth flows
  return Supabase.instance.client;
}

