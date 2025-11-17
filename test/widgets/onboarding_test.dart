import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/screens/onboarding/onboarding_capture_screen.dart';
import 'package:memories/screens/onboarding/onboarding_flow_screen.dart';
import 'package:memories/screens/onboarding/onboarding_privacy_screen.dart';
import 'package:memories/screens/onboarding/onboarding_timeline_screen.dart';
import 'package:memories/services/auth_error_handler.dart';
import 'package:memories/services/onboarding_service.dart';

// Mock classes
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAuthErrorHandler extends Mock implements AuthErrorHandler {}

class MockUser extends Mock implements User {}

void main() {
  group('OnboardingService', () {
    late MockSupabaseClient mockSupabase;
    late MockAuthErrorHandler mockErrorHandler;
    late OnboardingService onboardingService;
    late Map<String, dynamic> profileResponse;
    late int fetchCallCount;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockErrorHandler = MockAuthErrorHandler();
      profileResponse = {'onboarding_completed_at': null};
      fetchCallCount = 0;

      onboardingService = OnboardingService(
        mockSupabase,
        mockErrorHandler,
        profileFetcher: (_) async {
          fetchCallCount++;
          return profileResponse;
        },
        onboardingCompleter: (_) async {
          profileResponse = {
            'onboarding_completed_at': DateTime.now().toIso8601String(),
          };
          return profileResponse;
        },
      );
    });

    test('shouldShowOnboarding returns true when onboarding not completed',
        () async {
      const userId = 'test-user-id';

      final result = await onboardingService.shouldShowOnboarding(userId);

      expect(result, isTrue);
      expect(fetchCallCount, 1);
    });

    test('shouldShowOnboarding returns false when onboarding completed',
        () async {
      const userId = 'test-user-id';
      profileResponse = {
        'onboarding_completed_at': DateTime.now().toIso8601String(),
      };

      final result = await onboardingService.shouldShowOnboarding(userId);

      expect(result, isFalse);
    });

    test('shouldShowOnboarding caches result', () async {
      const userId = 'test-user-id';

      await onboardingService.shouldShowOnboarding(userId);
      await onboardingService.shouldShowOnboarding(userId);

      expect(fetchCallCount, 1);
    });

    test('completeOnboarding updates profile and cache', () async {
      const userId = 'test-user-id';

      final result = await onboardingService.completeOnboarding(userId);
      expect(result, isTrue);

      final shouldShow = await onboardingService.shouldShowOnboarding(userId);
      expect(shouldShow, isFalse);
    });

    test('clearCache clears cached values', () {
      onboardingService.clearCache();
      expect(() => onboardingService.clearCache(), returnsNormally);
    });
  });

  group('Onboarding Screens', () {
    testWidgets('OnboardingCaptureScreen displays correctly', (tester) async {
      bool nextCalled = false;
      bool skipCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingCaptureScreen(
            onNext: () => nextCalled = true,
            onSkip: () => skipCalled = true,
          ),
        ),
      );

      expect(find.text('Capture Your Moments'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Test next button
      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(nextCalled, isTrue);

      // Reset and test skip button
      nextCalled = false;
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(skipCalled, isTrue);
    });

    testWidgets('OnboardingTimelineScreen displays correctly', (tester) async {
      bool nextCalled = false;
      bool previousCalled = false;
      bool skipCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingTimelineScreen(
            onNext: () => nextCalled = true,
            onPrevious: () => previousCalled = true,
            onSkip: () => skipCalled = true,
          ),
        ),
      );

      expect(find.text('Your Memory Timeline'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Previous'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Test navigation buttons
      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(nextCalled, isTrue);

      await tester.tap(find.text('Previous'));
      await tester.pump();
      expect(previousCalled, isTrue);

      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(skipCalled, isTrue);
    });

    testWidgets('OnboardingPrivacyScreen displays correctly', (tester) async {
      bool completeCalled = false;
      bool previousCalled = false;
      bool skipCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingPrivacyScreen(
            onComplete: () => completeCalled = true,
            onPrevious: () => previousCalled = true,
            onSkip: () => skipCalled = true,
          ),
        ),
      );

      expect(find.text('Your Privacy, Your Control'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Previous'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Test complete button
      await tester.tap(find.text('Get Started'));
      await tester.pump();
      expect(completeCalled, isTrue);

      await tester.tap(find.text('Previous'));
      await tester.pump();
      expect(previousCalled, isTrue);

      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(skipCalled, isTrue);
    });
  });

  group('OnboardingFlowScreen', () {
    testWidgets('navigates between screens correctly', (tester) async {
      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn('test-user-id');

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWith((ref) => MockSupabaseClient()),
          authErrorHandlerProvider
              .overrideWith((ref) => MockAuthErrorHandler()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: OnboardingFlowScreen(user: mockUser),
          ),
        ),
      );

      // Should start on capture screen
      expect(find.text('Capture Your Moments'), findsOneWidget);

      // Navigate to next screen
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Should be on timeline screen
      expect(find.text('Your Memory Timeline'), findsOneWidget);
    });
  });
}
