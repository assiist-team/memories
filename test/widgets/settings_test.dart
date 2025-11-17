import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:memories/services/secure_storage_service.dart';
import 'package:memories/services/logout_service.dart';
import 'package:memories/widgets/profile_edit_form.dart';
import 'package:memories/widgets/password_change_widget.dart';
import 'package:memories/widgets/user_info_display.dart';
import 'package:memories/screens/settings/settings_screen.dart';

// Mock classes
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

void main() {
  group('Profile Edit Form Validation', () {
    testWidgets('validates name is required', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileEditForm(),
          ),
        ),
      );

      final nameField = find.byType(TextFormField).first;
      await tester.enterText(nameField, '   '); // Only whitespace
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('Name is required'), findsOneWidget);
    });

    testWidgets('displays name input field', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileEditForm(),
          ),
        ),
      );

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });
  });

  group('Password Change Widget', () {
    testWidgets('validates password strength', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PasswordChangeWidget(),
          ),
        ),
      );

      final newPasswordField = find.byType(TextFormField).at(1);
      await tester.enterText(newPasswordField, 'weak');
      await tester.tap(find.text('Change Password'));
      await tester.pump();

      expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    });

    testWidgets('validates password has mixed characters', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PasswordChangeWidget(),
          ),
        ),
      );

      final newPasswordField = find.byType(TextFormField).at(1);
      await tester.enterText(newPasswordField, 'lowercaseonly');
      await tester.tap(find.text('Change Password'));
      await tester.pump();

      expect(find.text('Password must contain both letters and numbers'), findsOneWidget);
    });

    testWidgets('validates password confirmation matches', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PasswordChangeWidget(),
          ),
        ),
      );

      final newPasswordField = find.byType(TextFormField).at(1);
      final confirmPasswordField = find.byType(TextFormField).at(2);
      
      await tester.enterText(newPasswordField, 'newpassword123');
      await tester.enterText(confirmPasswordField, 'differentpass123');
      await tester.tap(find.text('Change Password'));
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('displays password change form fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PasswordChangeWidget(),
          ),
        ),
      );

      expect(find.text('Current Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
    });
  });

  group('Logout Service', () {
    late MockSupabaseClient mockClient;
    late MockGoTrueClient mockAuth;
    late SecureStorageService secureStorage;

    setUp(() {
      mockClient = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      when(() => mockClient.auth).thenReturn(mockAuth);
      secureStorage = SecureStorageService();
    });

    test('clears Supabase session on logout', () async {
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      final logoutService = LogoutService(mockClient, secureStorage);
      await logoutService.logout();

      verify(() => mockAuth.signOut()).called(1);
    });

    test('clears secure storage on logout', () async {
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      // Store something first
      await secureStorage.setBiometricEnabled(true);
      expect(await secureStorage.isBiometricEnabled(), isTrue);

      final logoutService = LogoutService(mockClient, secureStorage);
      await logoutService.logout();

      // Verify secure storage is cleared
      expect(await secureStorage.isBiometricEnabled(), isFalse);
      expect(await secureStorage.hasSession(), isFalse);
    });
  });

  group('User Info Display', () {
    testWidgets('displays user info section', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserInfoDisplay(),
          ),
        ),
      );

      // Widget should render (may show "Not signed in" if no user)
      expect(find.byType(UserInfoDisplay), findsOneWidget);
    });
  });

  group('Settings Screen', () {
    testWidgets('displays Account section', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(),
        ),
      );

      expect(find.text('Account'), findsOneWidget);
    });

    testWidgets('displays Security section', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(),
        ),
      );

      expect(find.text('Security'), findsOneWidget);
    });

    testWidgets('displays Support section', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(),
        ),
      );

      expect(find.text('Support'), findsOneWidget);
    });
  });
}

