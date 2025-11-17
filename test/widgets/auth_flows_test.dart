import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/screens/auth/login_screen.dart';
import 'package:memories/screens/auth/password_reset_screen.dart';
import 'package:memories/screens/auth/signup_screen.dart';
import 'package:memories/screens/auth/verification_wait_screen.dart';
import 'package:memories/services/auth_error_handler.dart';
import 'package:memories/services/google_oauth_service.dart';

// Mock classes
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

class MockAuthErrorHandler extends Mock implements AuthErrorHandler {}

void main() {
  group('Signup Screen Form Validation', () {
    testWidgets('validates email format', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignupScreen(),
        ),
      );

      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'invalid-email');
      await tester.tap(find.text('Sign Up'));
      await tester.pump();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });

    testWidgets('validates name is required', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignupScreen(),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
      await tester.tap(find.text('Sign Up'));
      await tester.pump();

      expect(find.text('Name is required'), findsOneWidget);
    });

    testWidgets('validates password strength', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignupScreen(),
        ),
      );

      final nameField = find.byType(TextFormField).at(0);
      final emailField = find.byType(TextFormField).at(1);
      final passwordField = find.byType(TextFormField).at(2);

      await tester.enterText(nameField, 'Test User');
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'weak');
      await tester.tap(find.text('Sign Up'));
      await tester.pump();

      expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    });

    testWidgets('validates password has mixed characters', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignupScreen(),
        ),
      );

      final nameField = find.byType(TextFormField).at(0);
      final emailField = find.byType(TextFormField).at(1);
      final passwordField = find.byType(TextFormField).at(2);

      await tester.enterText(nameField, 'Test User');
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'lowercaseonly');
      await tester.tap(find.text('Sign Up'));
      await tester.pump();

      expect(find.text('Password must contain both letters and numbers'), findsOneWidget);
    });
  });

  group('Login Screen', () {
    testWidgets('displays email and password fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(),
        ),
      );

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('displays forgot password link', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(),
        ),
      );

      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('displays Google OAuth button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(),
        ),
      );

      expect(find.text('Continue with Google'), findsOneWidget);
    });
  });

  group('Google OAuth Service', () {
    late MockSupabaseClient mockClient;
    late MockGoTrueClient mockAuth;
    late MockAuthErrorHandler mockErrorHandler;

    setUp(() {
      mockClient = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      mockErrorHandler = MockAuthErrorHandler();
      when(() => mockClient.auth).thenReturn(mockAuth);
    });

    test('calls signInWithOAuth with Google provider', () async {
      when(() => mockAuth.signInWithOAuth(
            OAuthProvider.google,
            redirectTo: any(named: 'redirectTo'),
            authScreenLaunchMode: any(named: 'authScreenLaunchMode'),
          )).thenAnswer((_) async => true);

      final service = GoogleOAuthService(mockClient, mockErrorHandler);
      await service.signIn();

      verify(() => mockAuth.signInWithOAuth(
            OAuthProvider.google,
            redirectTo: any(named: 'redirectTo'),
            authScreenLaunchMode: any(named: 'authScreenLaunchMode'),
          )).called(1);
    });
  });

  group('Verification Wait Screen', () {
    testWidgets('displays resend email button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VerificationWaitScreen(email: 'test@example.com'),
        ),
      );

      expect(find.text('Resend verification email'), findsOneWidget);
    });

    testWidgets('displays email address', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VerificationWaitScreen(email: 'test@example.com'),
        ),
      );

      expect(find.textContaining('test@example.com'), findsOneWidget);
    });
  });

  group('Password Reset Screen', () {
    testWidgets('displays email input field', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PasswordResetScreen(),
        ),
      );

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Send reset link'), findsOneWidget);
    });

    testWidgets('shows confirmation state after submission', (WidgetTester tester) async {
      final mockClient = MockSupabaseClient();
      final mockAuth = MockGoTrueClient();
      when(() => mockClient.auth).thenReturn(mockAuth);
      when(() => mockAuth.resetPasswordForEmail(any())).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWith((ref) => mockClient),
          ],
          child: MaterialApp(
            home: PasswordResetScreen(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'test@example.com');
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(find.text('Check your email'), findsOneWidget);
    });
  });
}

