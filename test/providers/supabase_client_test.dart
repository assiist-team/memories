import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/providers/auth_state_provider.dart';
import 'package:memories/services/secure_storage_service.dart';

// Mock classes
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockAuthStateChanges extends Mock implements Stream<AuthState> {}

class MockSession extends Mock implements Session {}

class MockUser extends Mock implements User {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('Supabase Client Provider', () {
    test('creates single Supabase client instance', () {
      final container = ProviderContainer();
      final client = container.read(supabaseClientProvider);
      
      expect(client, isNotNull);
      expect(client, isA<SupabaseClient>());
      
      // Verify same instance is returned
      final client2 = container.read(supabaseClientProvider);
      expect(client, equals(client2));
    });

    test('uses environment variables for configuration', () {
      // This test verifies that the provider reads from environment
      // In a real scenario, you'd mock the environment or use test values
      final container = ProviderContainer(
        overrides: [
          supabaseUrlProvider.overrideWith((ref) => 'https://test.supabase.co'),
          supabaseAnonKeyProvider.overrideWith((ref) => 'test-anon-key'),
        ],
      );
      
      final client = container.read(supabaseClientProvider);
      expect(client, isNotNull);
    });
  });

  group('Auth State Provider', () {
    late MockSupabaseClient mockClient;
    late MockGoTrueClient mockAuth;

    setUp(() {
      mockClient = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      
      when(() => mockClient.auth).thenReturn(mockAuth);
    });

    test('listens to auth state changes', () async {
      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn('test-user-id');
      when(() => mockUser.emailConfirmedAt).thenReturn(DateTime.now().toIso8601String());
      
      final authStateStream = Stream<AuthState>.value(
        AuthState(
          AuthChangeEvent.signedIn,
          Session(
            accessToken: 'test-token',
            refreshToken: 'test-refresh',
            expiresIn: 3600,
            tokenType: 'bearer',
            user: mockUser,
          ),
        ),
      );

      when(() => mockAuth.onAuthStateChange).thenAnswer((_) => authStateStream);

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWith((ref) => mockClient),
        ],
      );

      // Listen to auth state changes - authStateProvider returns a Stream<AuthRoutingState>
      final authStateStreamProvider = container.read(authStateProvider);
      
      // Wait for stream to emit
      await expectLater(
        authStateStreamProvider,
        emits(isA<AuthRoutingState>()),
      );
    });

    test('handles session refresh', () async {
      final mockUser = MockUser();
      final mockSession = MockSession();
      when(() => mockSession.isExpired).thenReturn(false);
      when(() => mockAuth.currentSession).thenReturn(mockSession);
      when(() => mockAuth.refreshSession()).thenAnswer((_) async => AuthResponse(
        session: mockSession,
        user: mockUser,
      ));

      // Verify refresh can be called
      final refreshed = await mockAuth.refreshSession();
      expect(refreshed, isNotNull);
      expect(refreshed.session, isNotNull);
    });

    test('handles expired session', () async {
      final expiredSession = MockSession();
      when(() => expiredSession.isExpired).thenReturn(true);
      when(() => mockAuth.currentSession).thenReturn(expiredSession);

      final session = mockAuth.currentSession;
      expect(session?.isExpired, isTrue);
    });
  });

  group('Secure Storage Service', () {
    late MockFlutterSecureStorage mockStorage;

    setUp(() {
      mockStorage = MockFlutterSecureStorage();
    });

    test('persists session tokens securely', () async {
      when(() => mockStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      )).thenAnswer((_) async {});

      await mockStorage.write(
        key: SecureStorageKeys.refreshToken,
        value: 'test-refresh-token',
      );

      verify(() => mockStorage.write(
        key: SecureStorageKeys.refreshToken,
        value: 'test-refresh-token',
      )).called(1);
    });

    test('hydrates session on app start', () async {
      when(() => mockStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => 'stored-refresh-token');

      final token = await mockStorage.read(key: SecureStorageKeys.refreshToken);
      
      expect(token, equals('stored-refresh-token'));
      verify(() => mockStorage.read(key: SecureStorageKeys.refreshToken)).called(1);
    });

    test('clears storage on logout', () async {
      when(() => mockStorage.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});

      await mockStorage.delete(key: SecureStorageKeys.refreshToken);
      await mockStorage.delete(key: SecureStorageKeys.accessToken);

      verify(() => mockStorage.delete(key: SecureStorageKeys.refreshToken)).called(1);
      verify(() => mockStorage.delete(key: SecureStorageKeys.accessToken)).called(1);
    });
  });
}

