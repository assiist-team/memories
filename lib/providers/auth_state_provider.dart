import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/providers/biometric_provider.dart';
import 'package:memories/services/secure_storage_service.dart';
import 'package:memories/services/auth_error_handler.dart';
import 'package:memories/services/biometric_service.dart';

part 'auth_state_provider.g.dart';

/// Enum representing the current authentication routing state
enum AuthRouteState {
  /// User is not authenticated - show auth stack (login/signup)
  unauthenticated,
  
  /// User is authenticated but email not verified - show verification wait screen
  unverified,
  
  /// User is authenticated and verified but onboarding not completed - show onboarding
  onboarding,
  
  /// User is fully authenticated, verified, and onboarded - show main shell
  authenticated,
}

/// State class for authentication routing
class AuthRoutingState {
  final AuthRouteState routeState;
  final User? user;
  final Session? session;
  final String? errorMessage;

  const AuthRoutingState({
    required this.routeState,
    this.user,
    this.session,
    this.errorMessage,
  });

  AuthRoutingState copyWith({
    AuthRouteState? routeState,
    User? user,
    Session? session,
    String? errorMessage,
  }) {
    return AuthRoutingState(
      routeState: routeState ?? this.routeState,
      user: user ?? this.user,
      session: session ?? this.session,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Provider for secure storage service
@riverpod
SecureStorageService secureStorageService(SecureStorageServiceRef ref) {
  return SecureStorageService();
}

/// Provider that listens to Supabase auth state changes and determines routing
/// 
/// This provider:
/// - Listens to auth state changes from Supabase
/// - Determines the appropriate route state based on user authentication,
///   email verification, and onboarding completion
/// - Handles session refresh and expiration
/// - Persists session tokens securely
@riverpod
Stream<AuthRoutingState> authState(AuthStateRef ref) async* {
  final supabase = ref.watch(supabaseClientProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);
  final biometricService = ref.watch(biometricServiceProvider);
  final errorHandler = ref.watch(authErrorHandlerProvider);

  try {
    // Hydrate session from secure storage on app start
    // This will check for biometric authentication if enabled
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('Initializing auth state provider...');
    debugPrint('═══════════════════════════════════════════════════════');
    await _hydrateSession(supabase, secureStorage, biometricService);

    // Get initial auth state immediately (before waiting for stream)
    final initialSession = supabase.auth.currentSession;
    final initialUser = supabase.auth.currentUser;
    
    debugPrint('Initial auth state:');
    debugPrint('  User: ${initialUser?.id ?? "null"} (${initialUser?.email ?? "no email"})');
    debugPrint('  Session: ${initialSession != null ? "exists" : "null"}');
    if (initialSession != null) {
      debugPrint('  Access token: ${initialSession.accessToken.substring(0, 20)}...');
    }
    
    // Emit initial state right away
    final initialRouteState = await _determineRouteState(
      supabase,
      initialUser,
      initialSession,
    );
    
    debugPrint('  Route state: $initialRouteState');
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('');
    
    yield AuthRoutingState(
      routeState: initialRouteState,
      user: initialUser,
      session: initialSession,
    );

    // Listen to auth state changes
    await for (final authState in supabase.auth.onAuthStateChange) {
      try {
        debugPrint('');
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint('Auth state changed: ${authState.event}');
        debugPrint('═══════════════════════════════════════════════════════');
        final session = authState.session;
        final user = authState.session?.user;
        
        if (authState.event == AuthChangeEvent.signedIn) {
          debugPrint('✓ User signed in via OAuth');
          debugPrint('  User ID: ${user?.id}');
          debugPrint('  Email: ${user?.email}');
          debugPrint('  Session exists: ${session != null}');
        } else if (authState.event == AuthChangeEvent.signedOut) {
          debugPrint('✗ User signed out');
        } else if (authState.event == AuthChangeEvent.tokenRefreshed) {
          debugPrint('↻ Token refreshed');
        }
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint('');

        // Handle session persistence
        if (session != null) {
          // Calculate expiration time from expiresIn (seconds)
          final expiresAt = session.expiresIn != null
              ? DateTime.now().add(Duration(seconds: session.expiresIn!))
              : DateTime.now().add(const Duration(hours: 1));
          
          await secureStorage.storeSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken ?? '',
            expiresAt: expiresAt,
          );
        } else {
          await secureStorage.clearSession();
        }

        // Determine route state
        final routeState = await _determineRouteState(
          supabase,
          user,
          session,
        );

        yield AuthRoutingState(
          routeState: routeState,
          user: user,
          session: session,
        );
      } catch (e, stackTrace) {
        // Handle errors gracefully
        final errorMessage = errorHandler.handleAuthError(e);
        
        yield AuthRoutingState(
          routeState: AuthRouteState.unauthenticated,
          errorMessage: errorMessage,
        );
        
        // Log error for debugging
        errorHandler.logError(e, stackTrace);
      }
    }
  } catch (e, stackTrace) {
    // Handle initialization errors
    debugPrint('ERROR in authStateProvider initialization: $e');
    errorHandler.logError(e, stackTrace);
    
    yield AuthRoutingState(
      routeState: AuthRouteState.unauthenticated,
      errorMessage: errorHandler.handleAuthError(e),
    );
  }
}

/// Hydrate session from secure storage on app start
/// 
/// This function:
/// - Checks if biometric authentication is enabled and required
/// - If biometrics are enabled, prompts for biometric authentication before hydrating session
/// - Falls back to password if biometric authentication fails
Future<void> _hydrateSession(
  SupabaseClient supabase,
  SecureStorageService secureStorage,
  BiometricService biometricService,
) async {
  try {
    debugPrint('Checking for stored session...');
    final hasStoredSession = await secureStorage.hasSession();
    if (!hasStoredSession) {
      debugPrint('  No stored session found - user needs to sign in');
      return;
    }
    
    debugPrint('  ✓ Stored session found - hydrating...');

    // Check if biometric authentication is enabled
    final biometricEnabled = await secureStorage.isBiometricEnabled();
    if (biometricEnabled) {
      // Check if biometrics are available
      final isAvailable = await biometricService.isAvailable();
      if (isAvailable) {
        // Prompt for biometric authentication
        final biometricTypeName = await biometricService.getAvailableBiometricTypeName();
        final authenticated = await biometricService.authenticate(
          reason: 'Authenticate with ${biometricTypeName ?? 'biometrics'} to access your account',
        );

        if (!authenticated) {
          // Biometric authentication failed - clear session and require password login
          await secureStorage.clearSession();
          await secureStorage.clearBiometricPreference();
          // Also update Supabase profile to disable biometrics
          try {
            final user = supabase.auth.currentUser;
            if (user != null) {
              await supabase
                  .from('profiles')
                  .update({'biometric_enabled': false})
                  .eq('id', user.id);
            }
          } catch (e) {
            // Ignore errors updating profile - user will need to login with password
          }
          return;
        }
      } else {
        // Biometrics no longer available - clear preference
        await secureStorage.clearBiometricPreference();
        try {
          final user = supabase.auth.currentUser;
          if (user != null) {
            await supabase
                .from('profiles')
                .update({'biometric_enabled': false})
                .eq('id', user.id);
          }
        } catch (e) {
          // Ignore errors updating profile
        }
      }
    }

    final refreshToken = await secureStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      debugPrint('  No refresh token found');
      return;
    }

    debugPrint('  Refreshing session with stored refresh token...');
    // Attempt to refresh session using stored refresh token
    final response = await supabase.auth.refreshSession();
    
    if (response.session != null) {
      debugPrint('  ✓ Session refreshed successfully');
      debugPrint('    User ID: ${response.session!.user.id}');
      debugPrint('    Email: ${response.session!.user.email}');
      // Session refreshed successfully, it will be persisted by auth state listener
      return;
    } else {
      debugPrint('  ✗ Session refresh failed - clearing stored session');
    }
  } catch (e) {
    // If hydration fails, clear stored session
    await secureStorage.clearSession();
    // Don't throw - let user authenticate fresh
  }
}

/// Determine the appropriate route state based on user status
Future<AuthRouteState> _determineRouteState(
  SupabaseClient supabase,
  User? user,
  Session? session,
) async {
  // No user or session - unauthenticated
  if (user == null || session == null) {
    return AuthRouteState.unauthenticated;
  }

  // Check if email is verified
  if (user.emailConfirmedAt == null) {
    return AuthRouteState.unverified;
  }

  // Check if onboarding is completed
  // Query profiles table to check onboarding_completed_at
  try {
    final profileResponse = await supabase
        .from('profiles')
        .select('onboarding_completed_at')
        .eq('id', user.id)
        .maybeSingle();

    // If profile doesn't exist, assume onboarding needed
    if (profileResponse == null) {
      return AuthRouteState.onboarding;
    }

    final onboardingCompletedAt = profileResponse['onboarding_completed_at'];
    
    if (onboardingCompletedAt == null) {
      return AuthRouteState.onboarding;
    }
  } catch (e) {
    // If query fails, assume onboarding needed
    // This handles edge cases where profile creation might be delayed
    // Don't log this as an error - it's an expected edge case
    return AuthRouteState.onboarding;
  }

  // User is authenticated, verified, and onboarded
  return AuthRouteState.authenticated;
}

/// Provider for current auth routing state (non-stream, synchronous access)
/// 
/// Note: This provider watches the auth state stream. In practice, you may want
/// to use AsyncValue or a StateNotifier to track the latest state more explicitly.
/// For now, components should watch authStateProvider directly to get stream updates.
@riverpod
Stream<AuthRoutingState> currentAuthState(CurrentAuthStateRef ref) {
  return ref.watch(authStateProvider.stream);
}

