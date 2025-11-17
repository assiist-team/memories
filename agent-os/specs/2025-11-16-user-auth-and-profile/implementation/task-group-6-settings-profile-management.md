# Task Group 6: Settings & Profile Management

## Standards

- `frontend/*`
- `global/validation.md`
- `global/error-handling.md`

## Standards References

Refer to the following standards documents for implementation guidance:

- **Frontend Standards:**
  - [`agent-os/standards/frontend/accessibility.md`](../../standards/frontend/accessibility.md) - Accessibility requirements
  - [`agent-os/standards/frontend/components.md`](../../standards/frontend/components.md) - Component patterns
  - [`agent-os/standards/frontend/css.md`](../../standards/frontend/css.md) - Styling guidelines
  - [`agent-os/standards/frontend/responsive.md`](../../standards/frontend/responsive.md) - Responsive design

- **Global Standards:**
  - [`agent-os/standards/global/validation.md`](../../standards/global/validation.md) - Input validation requirements
  - [`agent-os/standards/global/error-handling.md`](../../standards/global/error-handling.md) - Error handling patterns
  - [`agent-os/standards/global/coding-style.md`](../../standards/global/coding-style.md) - Code style conventions
  - [`agent-os/standards/global/conventions.md`](../../standards/global/conventions.md) - Naming and structure conventions

## Overview

This task group implements the settings screen and profile management functionality, allowing users to edit their profile information, change passwords, view account details, and log out.

## Dependencies

- Task Group 1: Database & RLS Foundation (profiles table exists)
- Task Group 2: Supabase Client & Session Plumbing (client exists)
- Task Group 3: Authentication UX (auth flows exist)

## Implementation Steps

### 1. Create Test File: `test/widgets/settings_test.dart`

- Name edit validation tests (trim, non-empty)
- Password change tests
- Logout tests
- Profile update success/error scenarios

### 2. Create Settings Screen: `lib/screens/settings/settings_screen.dart`

- Sections: Account, Security, Support (placeholder links)
- Navigation from main shell
- Clean, organized layout
- Accessible navigation structure

### 3. Create Profile Edit Form: `lib/widgets/profile_edit_form.dart`

- Name edit field with validation
  - Trim whitespace
  - Non-empty validation
  - Update Supabase profile table
- Success/error messaging
- Loading states during update

### 4. Create Password Change Widget: `lib/widgets/password_change_widget.dart`

- Hook into Supabase `updateUser` method
- Current password verification
- New password strength validation (≥8 chars, mixed)
- Success/error messaging
- Secure input handling

### 5. Create Logout Handler: `lib/services/logout_service.dart`

- Clear Supabase session
- Clear secure storage (including biometric tokens)
- Route to auth stack
- Handle errors gracefully

### 6. Display User Info: `lib/widgets/user_info_display.dart`

- Read-only email (from auth.users)
- Last sign-in timestamp
- Profile name display
- Account creation date (optional)

### 7. Update `tasks.md`

- Mark tasks 6.0-6.7 as complete

## File Structure

```
lib/
├── screens/
│   └── settings/
│       └── settings_screen.dart
├── widgets/
│   ├── profile_edit_form.dart
│   ├── password_change_widget.dart
│   └── user_info_display.dart
└── services/
    └── logout_service.dart

test/
└── widgets/
    └── settings_test.dart
```

## Implementation Notes

- Follow Flutter/Dart conventions and standards
- Use Riverpod for state management
- All form inputs must have proper validation per `global/validation.md`
- Error handling must be user-friendly per `global/error-handling.md`
- Ensure UI is accessible (semantic labels, error messages, focus order)
- Secure storage must be cleared on logout
- Profile updates must respect RLS policies
- Password changes should require re-authentication for security

