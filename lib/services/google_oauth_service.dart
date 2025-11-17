import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/auth_error_handler.dart';

part 'google_oauth_service.g.dart';

/// Service for handling Google OAuth authentication
///
/// Integrates with Supabase signInWithOAuth to handle Google authentication
/// with deep link callback handling for iOS/Android.
class GoogleOAuthService {
  final SupabaseClient _supabase;
  final AuthErrorHandler _errorHandler;

  GoogleOAuthService(this._supabase, this._errorHandler);

  /// Sign in with Google OAuth
  ///
  /// Initiates the Google OAuth flow using Supabase's signInWithOAuth.
  /// The redirect URL should be configured in Supabase dashboard to handle
  /// deep link callbacks on iOS/Android.
  ///
  /// For iOS: Configure Universal Links in Xcode
  /// For Android: Configure App Links in AndroidManifest.xml
  Future<void> signIn() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _getRedirectUrl(),
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e, stackTrace) {
      _errorHandler.logError(e, stackTrace);
      rethrow;
    }
  }

  /// Get the redirect URL for OAuth callback
  ///
  /// Returns the appropriate redirect URL based on platform.
  /// This should match the URL configured in Supabase dashboard.
  String _getRedirectUrl() {
    // In production, this should be your app's deep link URL
    // Example: 'com.yourapp.memories://auth-callback'
    // For now, using a placeholder that should be configured per platform
    return 'memories://auth-callback';
  }

  /// Handle OAuth callback from deep link
  ///
  /// Call this method when the app receives a deep link callback
  /// from the OAuth provider. The URL should contain the auth tokens.
  Future<void> handleCallback(Uri callbackUrl) async {
    try {
      // Supabase will automatically handle the callback if the URL
      // matches the redirect URL configured in signInWithOAuth
      // The auth state listener will pick up the session change
    } catch (e, stackTrace) {
      _errorHandler.logError(e, stackTrace);
      rethrow;
    }
  }
}

/// Provider for Google OAuth service
@riverpod
GoogleOAuthService googleOAuthService(GoogleOAuthServiceRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final errorHandler = ref.watch(authErrorHandlerProvider);
  return GoogleOAuthService(supabase, errorHandler);
}
