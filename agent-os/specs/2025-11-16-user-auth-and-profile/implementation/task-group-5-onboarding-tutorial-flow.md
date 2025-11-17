# Task Group 5: Onboarding & Tutorial Flow

## Standards

- `frontend/*`
- `global/*` (as applicable)

## Standards References

Refer to the following standards documents for implementation guidance:

- **Frontend Standards:**
  - [`agent-os/standards/frontend/accessibility.md`](../../standards/frontend/accessibility.md) - Accessibility requirements
  - [`agent-os/standards/frontend/components.md`](../../standards/frontend/components.md) - Component patterns
  - [`agent-os/standards/frontend/css.md`](../../standards/frontend/css.md) - Styling guidelines
  - [`agent-os/standards/frontend/responsive.md`](../../standards/frontend/responsive.md) - Responsive design

- **Global Standards:**
  - [`agent-os/standards/global/coding-style.md`](../../standards/global/coding-style.md) - Code style conventions
  - [`agent-os/standards/global/conventions.md`](../../standards/global/conventions.md) - Naming and structure conventions
  - [`agent-os/standards/global/error-handling.md`](../../standards/global/error-handling.md) - Error handling patterns
  - [`agent-os/standards/global/performance.md`](../../standards/global/performance.md) - Performance considerations

## Overview

This task group implements the onboarding tutorial flow that introduces new users to the three core pillars of the Memories app: Capture, Timeline, and Privacy. The onboarding flow should be shown once per account and guide users through the app's key concepts.

## Dependencies

- Task Group 3: Authentication UX (auth flows must exist)

## Implementation Steps

### 1. Create Test File: `test/widgets/onboarding_test.dart`

- Test onboarding completion tracking
- Test routing after completion
- Test that onboarding is shown only once per account
- Test navigation between onboarding screens

### 2. Create Onboarding Screens: `lib/screens/onboarding/`

Create three onboarding screens that align with the mission visuals (clean, elegant, scrapbook-inspired):

- **`onboarding_capture_screen.dart`** - Capture pillar
  - Explain how to capture moments
  - Visual examples of moment creation
  - Emphasize ease of capturing memories

- **`onboarding_timeline_screen.dart`** - Timeline pillar
  - Explain the timeline view
  - Show how memories are organized chronologically
  - Highlight the unified feed concept

- **`onboarding_privacy_screen.dart`** - Privacy pillar
  - Explain privacy controls
  - Show how users control their data
  - Emphasize security and user control

### 3. Create Onboarding Service: `lib/services/onboarding_service.dart`

- Track completion (`onboarding_completed_at`) in Supabase profile table
- Cache completion status locally for performance
- Provide method to check if onboarding should be shown
- Handle edge cases (e.g., user already completed onboarding)

### 4. Update Routing Logic: `lib/app_router.dart`

- Integrate onboarding check into auth state routing
- Show onboarding once per account/session
- Route to main timeline CTA after completion
- Handle navigation flow: auth → verification → onboarding → main shell

### 5. Update `tasks.md`

- Mark tasks 5.0-5.5 as complete

## File Structure

```
lib/
├── screens/
│   └── onboarding/
│       ├── onboarding_capture_screen.dart
│       ├── onboarding_timeline_screen.dart
│       └── onboarding_privacy_screen.dart
├── services/
│   └── onboarding_service.dart
└── app_router.dart

test/
└── widgets/
    └── onboarding_test.dart
```

## Implementation Notes

- Follow Flutter/Dart conventions and standards
- Use Riverpod for state management
- Ensure UI is accessible (semantic labels, proper focus order)
- Align visual design with mission statement (scrapbook-inspired, elegant)
- Onboarding should be skippable but encouraged
- Store completion timestamp in `profiles.onboarding_completed_at` column

