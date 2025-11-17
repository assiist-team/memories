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

  // Hydrate session from secure storage on app start
  // This will check for biometric authentication if enabled
  await _hydrateSession(supabase, secureStorage, biometricService);

  // Listen to auth state changes
  await for (final authState in supabase.auth.onAuthStateChange) {
    try {
      final session = authState.session;
      final user = authState.session?.user;

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
    final hasStoredSession = await secureStorage.hasSession();
    if (!hasStoredSession) {
      return;
    }

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
      return;
    }

    // Attempt to refresh session using stored refresh token
    final response = await supabase.auth.refreshSession();
    
    if (response.session != null) {
      // Session refreshed successfully, it will be persisted by auth state listener
      return;
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
        .single();

    final onboardingCompletedAt = profileResponse['onboarding_completed_at'];
    
    if (onboardingCompletedAt == null) {
      return AuthRouteState.onboarding;
    }
  } catch (e) {
    // If profile doesn't exist or query fails, assume onboarding needed
    // This handles edge cases where profile creation might be delayed
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

