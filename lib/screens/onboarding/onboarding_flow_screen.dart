import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:memories/services/onboarding_service.dart';
import 'package:memories/screens/onboarding/onboarding_capture_screen.dart';
import 'package:memories/screens/onboarding/onboarding_timeline_screen.dart';
import 'package:memories/screens/onboarding/onboarding_privacy_screen.dart';

/// Main onboarding flow screen that manages navigation between onboarding screens
/// 
/// Handles:
/// - Navigation between the three onboarding screens
/// - Completion tracking
/// - Skipping the onboarding flow
class OnboardingFlowScreen extends StatefulWidget {
  final User user;

  const OnboardingFlowScreen({
    super.key,
    required this.user,
  });

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  int _currentPageIndex = 0;
  bool _isCompleting = false;

  Future<void> _handleComplete() async {
    if (_isCompleting) return;

    setState(() {
      _isCompleting = true;
    });

    try {
      final container = ProviderScope.containerOf(context);
      final onboardingService = container.read(onboardingServiceProvider);
      
      final success = await onboardingService.completeOnboarding(widget.user.id);
      
      if (success && mounted) {
        // Clear cache to ensure fresh state
        onboardingService.clearCache();
        // Navigation will be handled by auth state provider
        // The auth state will update and route to authenticated state
      } else if (mounted) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to complete onboarding. Please try again.'),
          ),
        );
        setState(() {
          _isCompleting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred. Please try again.'),
          ),
        );
        setState(() {
          _isCompleting = false;
        });
      }
    }
  }

  Future<void> _handleSkip() async {
    // Skip also completes onboarding
    await _handleComplete();
  }

  void _handleNext() {
    if (_currentPageIndex < 2) {
      setState(() {
        _currentPageIndex++;
      });
    }
  }

  void _handlePrevious() {
    if (_currentPageIndex > 0) {
      setState(() {
        _currentPageIndex--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: PageController(initialPage: _currentPageIndex),
      onPageChanged: (index) {
        setState(() {
          _currentPageIndex = index;
        });
      },
      children: [
        OnboardingCaptureScreen(
          onNext: _handleNext,
          onSkip: _handleSkip,
        ),
        OnboardingTimelineScreen(
          onNext: _handleNext,
          onSkip: _handleSkip,
          onPrevious: _handlePrevious,
        ),
        OnboardingPrivacyScreen(
          onComplete: _handleComplete,
          onSkip: _handleSkip,
          onPrevious: _handlePrevious,
        ),
      ],
    );
  }
}

