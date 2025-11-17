import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:memories/services/secure_storage_service.dart';

/// Service for handling user logout
/// 
/// Clears Supabase session and secure storage, then routes to auth stack.
/// Per security standards, all sensitive data must be cleared on logout.
class LogoutService {
  final SupabaseClient _supabase;
  final SecureStorageService _secureStorage;

  LogoutService(this._supabase, this._secureStorage);

  /// Logout the current user
  /// 
  /// This method:
  /// - Signs out from Supabase (clears session)
  /// - Clears all secure storage (including biometric tokens)
  /// - Navigation to auth stack will be handled by auth state provider
  /// 
  /// Errors are handled gracefully - if logout fails, secure storage
  /// is still cleared to ensure no sensitive data remains.
  Future<void> logout() async {
    try {
      // Sign out from Supabase
      await _supabase.auth.signOut();
    } catch (e) {
      // Even if signOut fails, we should clear local storage
      // This ensures no sensitive data remains on the device
    } finally {
      // Always clear secure storage, including biometric preferences
      await _secureStorage.clearSession();
      await _secureStorage.clearBiometricPreference();
    }
  }
}

