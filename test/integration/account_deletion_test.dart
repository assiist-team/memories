import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:memories/services/account_deletion_service.dart';
import 'package:memories/services/secure_storage_service.dart';
import 'package:memories/services/biometric_service.dart';

// Mock classes
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockAuthClient extends Mock implements GoTrueClient {}
class MockFunctionsClient extends Mock implements FunctionsClient {}
class MockSecureStorageService extends Mock implements SecureStorageService {}
class MockBiometricService extends Mock implements BiometricService {}

// Mock FunctionResponse for testing
// FunctionResponse from Supabase has status (int) and data (dynamic) properties
class MockFunctionResponse extends Mock {
  final int status;
  final dynamic data;

  MockFunctionResponse({required this.status, required this.data});
}

void main() {
  group('Account Deletion Service', () {
    late MockSupabaseClient mockSupabase;
    late MockAuthClient mockAuth;
    late MockFunctionsClient mockFunctions;
    late MockSecureStorageService mockSecureStorage;
    late MockBiometricService mockBiometricService;
    late AccountDeletionService accountDeletionService;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockAuth = MockAuthClient();
      mockFunctions = MockFunctionsClient();
      mockSecureStorage = MockSecureStorageService();
      mockBiometricService = MockBiometricService();

      when(() => mockSupabase.auth).thenReturn(mockAuth);
      when(() => mockSupabase.functions).thenReturn(mockFunctions);

      accountDeletionService = AccountDeletionService(
        mockSupabase,
        mockSecureStorage,
        mockBiometricService,
      );
    });

    group('deleteAccount', () {
      test('successfully deletes account and clears local data', () async {
        // Setup mocks
        final mockUser = User(
          id: 'test-user-id',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        );

        when(() => mockAuth.currentUser).thenReturn(mockUser);
        when(() => mockAuth.currentSession).thenReturn(
          Session(
            accessToken: 'test-token',
            refreshToken: 'test-refresh',
            expiresIn: 3600,
            tokenType: 'bearer',
            user: mockUser,
          ),
        );

        // Mock FunctionResponse - functions.invoke returns a Future<FunctionResponse>
        // FunctionResponse has status (int) and data (dynamic) properties
        final mockResponse = MockFunctionResponse(
          status: 200,
          data: {'success': true, 'message': 'Account deleted successfully'},
        );
        when(() => mockFunctions.invoke(
          'delete-account',
          body: any(named: 'body'),
        )).thenAnswer((_) async => FunctionResponse(
          status: mockResponse.status,
          data: mockResponse.data,
        ));

        when(() => mockSecureStorage.clearSession()).thenAnswer((_) async {});
        when(() => mockSecureStorage.clearBiometricPreference())
            .thenAnswer((_) async {});

        // Execute
        await accountDeletionService.deleteAccount();

        // Verify
        verify(() => mockFunctions.invoke(
          'delete-account',
          body: any(named: 'body'),
        )).called(1);
        verify(() => mockSecureStorage.clearSession()).called(1);
        verify(() => mockSecureStorage.clearBiometricPreference()).called(1);
      });

      test('throws exception when user is not authenticated', () async {
        when(() => mockAuth.currentUser).thenReturn(null);
        when(() => mockAuth.currentSession).thenReturn(null);

        expect(
          () => accountDeletionService.deleteAccount(),
          throwsA(isA<Exception>()),
        );

        verifyNever(() => mockFunctions.invoke(any(), body: any(named: 'body')));
      });

      test('handles Edge Function errors gracefully', () async {
        final mockUser = User(
          id: 'test-user-id',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        );

        when(() => mockAuth.currentUser).thenReturn(mockUser);
        when(() => mockAuth.currentSession).thenReturn(
          Session(
            accessToken: 'test-token',
            refreshToken: 'test-refresh',
            expiresIn: 3600,
            tokenType: 'bearer',
            user: mockUser,
          ),
        );

        when(() => mockFunctions.invoke(
          'delete-account',
          body: any(named: 'body'),
        )).thenThrow(Exception('Edge Function error'));

        when(() => mockSecureStorage.clearSession()).thenAnswer((_) async {});
        when(() => mockSecureStorage.clearBiometricPreference())
            .thenAnswer((_) async {});

        expect(
          () => accountDeletionService.deleteAccount(),
          throwsA(isA<Exception>()),
        );
      });

      test('clears local data even if Edge Function call fails', () async {
        final mockUser = User(
          id: 'test-user-id',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        );

        when(() => mockAuth.currentUser).thenReturn(mockUser);
        when(() => mockAuth.currentSession).thenReturn(
          Session(
            accessToken: 'test-token',
            refreshToken: 'test-refresh',
            expiresIn: 3600,
            tokenType: 'bearer',
            user: mockUser,
          ),
        );

        when(() => mockFunctions.invoke(
          'delete-account',
          body: any(named: 'body'),
        )).thenThrow(Exception('Network error'));

        when(() => mockSecureStorage.clearSession()).thenAnswer((_) async {});
        when(() => mockSecureStorage.clearBiometricPreference())
            .thenAnswer((_) async {});

        try {
          await accountDeletionService.deleteAccount();
        } catch (e) {
          // Expected to throw
        }

        // Verify local data is still cleared even on error
        verify(() => mockSecureStorage.clearSession()).called(1);
        verify(() => mockSecureStorage.clearBiometricPreference()).called(1);
      });
    });

    group('reauthenticate', () {
      test('returns true when password authentication succeeds', () async {
        when(() => mockAuth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => AuthResponse(
          session: Session(
            accessToken: 'test-token',
            refreshToken: 'test-refresh',
            expiresIn: 3600,
            tokenType: 'bearer',
            user: User(
              id: 'test-user-id',
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              createdAt: DateTime.now().toIso8601String(),
            ),
          ),
          user: User(
            id: 'test-user-id',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: DateTime.now().toIso8601String(),
          ),
        ));

        final result = await accountDeletionService.reauthenticate(
          email: 'test@example.com',
          password: 'password123',
        );

        expect(result, isTrue);
        verify(() => mockAuth.signInWithPassword(
          email: 'test@example.com',
          password: 'password123',
        )).called(1);
      });

      test('returns false when password authentication fails', () async {
        when(() => mockAuth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenThrow(AuthException('Invalid credentials'));

        final result = await accountDeletionService.reauthenticate(
          email: 'test@example.com',
          password: 'wrong-password',
        );

        expect(result, isFalse);
      });

      test('returns true when biometric authentication succeeds', () async {
        when(() => mockBiometricService.isAvailable())
            .thenAnswer((_) async => true);
        when(() => mockBiometricService.getAvailableBiometricTypeName())
            .thenAnswer((_) async => 'Face ID');
        when(() => mockBiometricService.authenticate(
          reason: any(named: 'reason'),
        )).thenAnswer((_) async => true);

        final result = await accountDeletionService.reauthenticateWithBiometric();

        expect(result, isTrue);
        verify(() => mockBiometricService.isAvailable()).called(1);
        verify(() => mockBiometricService.getAvailableBiometricTypeName()).called(1);
        verify(() => mockBiometricService.authenticate(
          reason: any(named: 'reason'),
        )).called(1);
      });

      test('returns false when biometric authentication fails', () async {
        when(() => mockBiometricService.isAvailable())
            .thenAnswer((_) async => true);
        when(() => mockBiometricService.authenticate(
          reason: any(named: 'reason'),
        )).thenAnswer((_) async => false);

        final result = await accountDeletionService.reauthenticateWithBiometric();

        expect(result, isFalse);
      });

      test('returns false when biometrics are not available', () async {
        when(() => mockBiometricService.isAvailable())
            .thenAnswer((_) async => false);

        final result = await accountDeletionService.reauthenticateWithBiometric();

        expect(result, isFalse);
        verifyNever(() => mockBiometricService.authenticate(
          reason: any(named: 'reason'),
        ));
      });
    });
  });
}

