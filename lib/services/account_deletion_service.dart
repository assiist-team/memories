import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:memories/services/secure_storage_service.dart';
import 'package:memories/services/biometric_service.dart';

/// Service for handling account deletion
/// 
/// Provides functionality to:
/// - Re-authenticate users (password or biometric)
/// - Call Edge Function to delete account server-side
/// - Clear all local data and secure storage
/// 
/// Security:
/// - Requires re-authentication before deletion
/// - Edge Function handles secure deletion with service role key
/// - All local data is cleared after successful deletion
class AccountDeletionService {
  final SupabaseClient _supabase;
  final SecureStorageService _secureStorage;
  final BiometricService _biometricService;

  AccountDeletionService(
    this._supabase,
    this._secureStorage,
    this._biometricService,
  );

  /// Re-authenticate user with password
  /// 
  /// Returns true if authentication succeeds, false otherwise.
  Future<bool> reauthenticate({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      return response.session != null && response.user != null;
    } catch (e) {
      // Authentication failed
      return false;
    }
  }

  /// Re-authenticate user with biometrics
  /// 
  /// Returns true if biometric authentication succeeds, false otherwise.
  Future<bool> reauthenticateWithBiometric() async {
    try {
      final isAvailable = await _biometricService.isAvailable();
      if (!isAvailable) {
        return false;
      }

      final biometricTypeName =
          await _biometricService.getAvailableBiometricTypeName();
      final authenticated = await _biometricService.authenticate(
        reason:
            'Authenticate with ${biometricTypeName ?? 'biometrics'} to confirm account deletion',
      );

      return authenticated;
    } catch (e) {
      // Biometric authentication failed
      return false;
    }
  }

  /// Delete the current user's account
  /// 
  /// This method:
  /// - Verifies the user is authenticated
  /// - Calls the Edge Function to delete the account server-side
  /// - Clears all local data and secure storage
  /// 
  /// Throws an exception if:
  /// - User is not authenticated
  /// - Edge Function call fails
  /// 
  /// Note: This operation is irreversible. All user data will be permanently deleted.
  Future<void> deleteAccount() async {
    final user = _supabase.auth.currentUser;
    final session = _supabase.auth.currentSession;

    if (user == null || session == null) {
      throw Exception('User must be authenticated to delete account');
    }

    try {
      // Call Edge Function to delete account
      final response = await _supabase.functions.invoke(
        'delete-account',
        body: {
          'userId': user.id,
        },
      );

      // Check if response indicates success
      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage = errorData?['message'] as String? ??
            'Failed to delete account';
        throw Exception(errorMessage);
      }

      // Verify response indicates success
      final responseData = response.data as Map<String, dynamic>?;
      if (responseData?['success'] != true) {
        final errorMessage = responseData?['message'] as String? ??
            'Failed to delete account';
        throw Exception(errorMessage);
      }
    } catch (e) {
      // Even if Edge Function call fails, clear local data for security
      // This ensures no sensitive data remains if deletion partially succeeded
      await _secureStorage.clearSession();
      await _secureStorage.clearBiometricPreference();
      rethrow;
    }

    // Clear all local data after successful deletion
    await _secureStorage.clearSession();
    await _secureStorage.clearBiometricPreference();

    // Sign out from Supabase (should already be done server-side, but ensure it)
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      // Ignore errors - account is already deleted server-side
    }
  }
}

