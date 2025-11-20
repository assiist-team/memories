import 'package:flutter/material.dart';
import 'package:memories/models/memory_type.dart';

/// First onboarding screen explaining the Capture pillar
/// 
/// Introduces users to how they can capture memories in the app.
/// Part of the three-pillar onboarding flow: Capture, Timeline, Privacy.
class OnboardingCaptureScreen extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const OnboardingCaptureScreen({
    super.key,
    required this.onNext,
    required this.onSkip,
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
                label: 'Capture icon',
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: 100,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              // Title
              Text(
                'Capture Your Memories',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Description
              Text(
                'Record voice stories, snap photos with context, or preserve meaningful objects. '
                'Capture stories, moments, and mementos in seconds.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Visual examples (placeholder - can be enhanced with actual examples)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildExampleIcon(
                          context,
                          MemoryType.story.icon,
                          'Story',
                        ),
                        _buildExampleIcon(
                          context,
                          MemoryType.moment.icon,
                          'Moment',
                        ),
                        _buildExampleIcon(
                          context,
                          MemoryType.memento.icon,
                          'Memento',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Next button
              Semantics(
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
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExampleIcon(BuildContext context, IconData icon, String label) {
    return Semantics(
      label: label,
      child: Column(
        children: [
          Icon(
            icon,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

