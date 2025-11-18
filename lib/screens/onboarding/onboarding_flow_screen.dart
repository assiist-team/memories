import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:memories/services/onboarding_service.dart';
import 'package:memories/providers/auth_state_provider.dart';
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
  late final PageController _pageController;
  int _currentPageIndex = 0;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPageIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
        
        // Invalidate auth state provider to trigger re-check of onboarding status
        // This will cause it to query the database again and detect that
        // onboarding is now complete, triggering navigation to the main app
        container.invalidate(authStateProvider);
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
      _pageController.animateToPage(
        _currentPageIndex + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handlePrevious() {
    if (_currentPageIndex > 0) {
      _pageController.animateToPage(
        _currentPageIndex - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
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

