import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/auth_error_handler.dart';

part 'onboarding_service.g.dart';

/// Service for managing onboarding completion status
///
/// Handles:
/// - Checking if onboarding should be shown
/// - Marking onboarding as complete
/// - Caching completion status locally for performance
typedef ProfileFetcher = Future<Map<String, dynamic>> Function(String userId);
typedef OnboardingCompleter = Future<Map<String, dynamic>> Function(
    String userId);

class OnboardingService {
  final SupabaseClient _supabase;
  final AuthErrorHandler _errorHandler;
  late final ProfileFetcher _profileFetcher;
  late final OnboardingCompleter _onboardingCompleter;

  // Cache for onboarding completion status
  bool? _cachedCompletionStatus;
  String? _cachedUserId;

  OnboardingService(
    this._supabase,
    this._errorHandler, {
    ProfileFetcher? profileFetcher,
    OnboardingCompleter? onboardingCompleter,
  }) {
    _profileFetcher = profileFetcher ?? _fetchProfileFromSupabase;
    _onboardingCompleter = onboardingCompleter ?? _completeOnboardingInSupabase;
  }

  /// Check if onboarding should be shown for the current user
  ///
  /// Returns true if onboarding should be shown (user hasn't completed it),
  /// false if onboarding is already completed.
  ///
  /// Caches the result locally to avoid repeated database queries.
  Future<bool> shouldShowOnboarding(String userId) async {
    // Return cached value if available and for the same user
    if (_cachedCompletionStatus != null && _cachedUserId == userId) {
      return !_cachedCompletionStatus!;
    }

    try {
      final profileResponse = await _profileFetcher(userId);

      final onboardingCompletedAt = profileResponse['onboarding_completed_at'];
      final isCompleted = onboardingCompletedAt != null;

      // Cache the result
      _cachedCompletionStatus = isCompleted;
      _cachedUserId = userId;

      return !isCompleted;
    } catch (e, stackTrace) {
      _errorHandler.logError(e, stackTrace);
      // If query fails, assume onboarding should be shown
      // This handles edge cases where profile doesn't exist yet
      return true;
    }
  }

  /// Mark onboarding as complete for the current user
  ///
  /// Updates the `onboarding_completed_at` timestamp in the profiles table.
  /// Also updates the local cache.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> completeOnboarding(String userId) async {
    try {
      final response = await _onboardingCompleter(userId);

      // Update cache
      _cachedCompletionStatus = true;
      _cachedUserId = userId;

      return response['onboarding_completed_at'] != null;
    } catch (e, stackTrace) {
      _errorHandler.logError(e, stackTrace);
      return false;
    }
  }

  /// Clear the local cache
  ///
  /// Useful when user logs out or switches accounts.
  void clearCache() {
    _cachedCompletionStatus = null;
    _cachedUserId = null;
  }

  Future<Map<String, dynamic>> _fetchProfileFromSupabase(String userId) {
    return _supabase
        .from('profiles')
        .select('onboarding_completed_at')
        .eq('id', userId)
        .single();
  }

  Future<Map<String, dynamic>> _completeOnboardingInSupabase(String userId) async {
    // First check if profile exists
    final existingProfile = await _supabase
        .from('profiles')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    
    if (existingProfile == null) {
      // Profile doesn't exist - this shouldn't happen if trigger worked,
      // but handle gracefully. Since RLS blocks direct inserts, we can't create it here.
      // The trigger should have created it on signup, so this is an edge case.
      // Return a response that indicates failure
      throw Exception('Profile does not exist for user. The profile should have been created automatically. Please try signing out and back in, or contact support.');
    }
    
    // Profile exists, proceed with update
    final result = await _supabase
        .from('profiles')
        .update({
          'onboarding_completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId)
        .select()
        .maybeSingle();
    
    if (result == null) {
      throw Exception('Failed to update onboarding status. No rows were updated.');
    }
    
    return result;
  }
}

/// Provider for onboarding service
@riverpod
OnboardingService onboardingService(OnboardingServiceRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final errorHandler = ref.watch(authErrorHandlerProvider);
  return OnboardingService(supabase, errorHandler);
}
