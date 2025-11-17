import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:memories/services/account_deletion_service.dart';
import 'package:memories/services/secure_storage_service.dart';
import 'package:memories/services/biometric_service.dart';
import 'package:memories/providers/supabase_provider.dart';
import '../helpers/test_supabase_setup.dart';

/// Integration tests for AccountDeletionService using real Supabase
/// 
/// These tests require:
/// - TEST_SUPABASE_URL environment variable
/// - TEST_SUPABASE_ANON_KEY environment variable
/// 
/// Run with:
/// flutter test test/integration/account_deletion_service_integration_test.dart \
///   --dart-define=TEST_SUPABASE_URL=xxx \
///   --dart-define=TEST_SUPABASE_ANON_KEY=xxx
void main() {
  late ProviderContainer container;
  late SupabaseClient supabase;
  late AccountDeletionService accountDeletionService;
  late SecureStorageService secureStorage;
  late BiometricService biometricService;

  setUpAll(() {
    container = createTestSupabaseContainer();
    supabase = container.read(supabaseClientProvider);
    secureStorage = SecureStorageService();
    biometricService = BiometricService();
    accountDeletionService = AccountDeletionService(
      supabase,
      secureStorage,
      biometricService,
    );
  });

  tearDownAll(() {
    container.dispose();
  });

  group('Account Deletion Service Integration Tests', () {
    test('successfully deletes account via Edge Function', () async {
      // Create a test user
      final testEmail = 'test-delete-${DateTime.now().millisecondsSinceEpoch}@test.com';
      final testPassword = 'TestPassword123!';
      
      final testUser = await createTestUser(
        supabase,
        email: testEmail,
        password: testPassword,
      );

      // Verify user exists
      expect(testUser.user.email, equals(testEmail));

      // Delete the account
      await accountDeletionService.deleteAccount();

      // Verify user is deleted (sign in should fail)
      final signInResult = await supabase.auth.signInWithPassword(
        email: testEmail,
        password: testPassword,
      );

      expect(signInResult.session, isNull);
      expect(signInResult.user, isNull);
    });

    test('requires re-authentication before deletion', () async {
      // Create a test user
      final testEmail = 'test-reauth-${DateTime.now().millisecondsSinceEpoch}@test.com';
      final testPassword = 'TestPassword123!';
      
      final testUser = await createTestUser(
        supabase,
        email: testEmail,
        password: testPassword,
      );

      // Verify user was created
      expect(testUser.user.email, equals(testEmail));

      // Sign out
      await supabase.auth.signOut();

      // Try to delete without being authenticated - should throw
      expect(
        () => accountDeletionService.deleteAccount(),
        throwsA(isA<Exception>()),
      );
    });

    test('clears local storage after deletion', () async {
      // Create a test user
      final testEmail = 'test-storage-${DateTime.now().millisecondsSinceEpoch}@test.com';
      final testPassword = 'TestPassword123!';
      
      final testUser = await createTestUser(
        supabase,
        email: testEmail,
        password: testPassword,
      );

      // Verify user was created
      expect(testUser.user.email, equals(testEmail));

      // Store session tokens
      final session = supabase.auth.currentSession;
      if (session != null) {
        await secureStorage.storeSession(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken ?? '',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
      }

      // Verify session is stored
      final hasSession = await secureStorage.hasSession();
      expect(hasSession, isTrue);

      // Delete account
      await accountDeletionService.deleteAccount();

      // Verify session is cleared
      final hasSessionAfter = await secureStorage.hasSession();
      expect(hasSessionAfter, isFalse);
    });
  });
}

