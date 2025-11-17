import 'package:flutter/material.dart';

/// Third onboarding screen explaining the Privacy pillar
/// 
/// Introduces users to privacy controls and data security.
/// Part of the three-pillar onboarding flow: Capture, Timeline, Privacy.
class OnboardingPrivacyScreen extends StatelessWidget {
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final VoidCallback onPrevious;

  const OnboardingPrivacyScreen({
    super.key,
    required this.onComplete,
    required this.onSkip,
    required this.onPrevious,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Semantics(
                  label: 'Skip onboarding',
                  button: true,
                  child: TextButton(
                    onPressed: onSkip,
                    child: const Text('Skip'),
                  ),
                ),
              ),
              const Spacer(),
              // Icon
              Semantics(
                label: 'Privacy icon',
                child: Icon(
                  Icons.lock_outline,
                  size: 100,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              // Title
              Text(
                'Your Privacy, Your Control',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Description
              Text(
                'Your memories are yours alone. You control who sees what, '
                'when to share, and how your data is protected. Security and privacy come first.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Privacy features list
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildPrivacyFeature(
                      context,
                      Icons.verified_user_outlined,
                      'Secure storage',
                      'Your data is encrypted and protected',
                    ),
                    const SizedBox(height: 16),
                    _buildPrivacyFeature(
                      context,
                      Icons.share_outlined,
                      'Choose what to share',
                      'You decide which memories are private or shared',
                    ),
                    const SizedBox(height: 16),
                    _buildPrivacyFeature(
                      context,
                      Icons.settings_outlined,
                      'Full control',
                      'Manage your account and data anytime',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Navigation buttons
              Row(
                children: [
                  // Previous button
                  Expanded(
                    child: Semantics(
                      label: 'Go to previous onboarding screen',
                      button: true,
                      child: OutlinedButton(
                        onPressed: onPrevious,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(0, 48),
                        ),
                        child: const Text('Previous'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Complete button
                  Expanded(
                    child: Semantics(
                      label: 'Complete onboarding and start using the app',
                      button: true,
                      child: ElevatedButton(
                        onPressed: onComplete,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(0, 48),
                        ),
                        child: const Text('Get Started'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyFeature(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Semantics(
      label: '$title: $description',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 24,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

