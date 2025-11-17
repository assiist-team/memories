import 'package:flutter/material.dart';

/// Second onboarding screen explaining the Timeline pillar
/// 
/// Introduces users to how memories are organized chronologically.
/// Part of the three-pillar onboarding flow: Capture, Timeline, Privacy.
class OnboardingTimelineScreen extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onPrevious;

  const OnboardingTimelineScreen({
    super.key,
    required this.onNext,
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
                label: 'Timeline icon',
                child: Icon(
                  Icons.timeline_outlined,
                  size: 100,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              // Title
              Text(
                'Your Memory Timeline',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Description
              Text(
                'All your stories, moments, and mementos come together in one beautiful timeline. '
                'See your memories organized chronologically, ready to revisit and share.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Visual example (placeholder - can be enhanced with actual timeline preview)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildTimelineItem(
                      context,
                      'Today',
                      'Morning walk',
                      Icons.directions_walk_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildTimelineItem(
                      context,
                      'Yesterday',
                      'Family dinner',
                      Icons.restaurant_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildTimelineItem(
                      context,
                      'Last week',
                      'Beach trip',
                      Icons.beach_access_outlined,
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
                  // Next button
                  Expanded(
                    child: Semantics(
                      label: 'Continue to next onboarding screen',
                      button: true,
                      child: ElevatedButton(
                        onPressed: onNext,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(0, 48),
                        ),
                        child: const Text('Next'),
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

  Widget _buildTimelineItem(
    BuildContext context,
    String date,
    String title,
    IconData icon,
  ) {
    return Semantics(
      label: '$date: $title',
      child: Row(
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
                Text(
                  date,
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

