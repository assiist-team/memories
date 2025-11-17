<!-- 61d35854-e15f-4ea8-a2df-1ff337546885 a7d7bcbe-2f5b-4a1d-82d5-ee47ca69bdaa -->
# Implementation Plan: User Authentication & Profile

## Overview

This plan covers the implementation of task groups 2-8 for the User Authentication & Profile feature. Task Group 1 (Database & RLS Foundation) is already complete. Each task group will be implemented following the assigned subagent roles and standards specified in `orchestration.yml`.

## Task Group 2: Supabase Client & Session Plumbing

**Assigned to:** backend-specialist

**Standards:** `backend/*`, `global/security.md`, `global/error-handling.md`

### Implementation Steps

1. Create Dart test file: `test/providers/supabase_client_test.dart`

   - Mock Supabase client for testing
   - Test session refresh logic
   - Test auth state changes
   - Test secure storage persistence

2. Create Riverpod provider: `lib/providers/supabase_provider.dart`

   - Single Supabase client instance using anon key
   - Environment variable handling for Supabase URL and anon key
   - Export provider for app-wide access

3. Create auth state provider: `lib/providers/auth_state_provider.dart`

   - Listen to Supabase auth state changes
   - Route logic: auth stack → verification wait → onboarding → main shell
   - Handle session refresh and expiration

4. Create secure storage service: `lib/services/secure_storage_service.dart`

   - Use `flutter_secure_storage` for session tokens
   - Hydrate session on app start
   - Clear storage on logout

5. Create error handling/logging: `lib/services/auth_error_handler.dart`

   - Offline detection and handling
   - Error logging hooks per security standards
   - User-friendly error messages

6. Update `tasks.md` to mark 2.0-2.6 as complete

## Task Group 3: Authentication UX (Email + Google + Verification)

**Assigned to:** frontend-specialist

**Standards:** `frontend/*`, `global/validation.md`, `global/error-handling.md`, `global/security.md`

### Implementation Steps

1. Create test file: `test/widgets/auth_flows_test.dart`

   - Form validation tests
   - Google OAuth intent tests
   - Verification wait state tests
   - Password reset flow tests

2. Create signup screen: `lib/screens/auth/signup_screen.dart`

   - Email/password form with validation
   - Name field (required)
   - Password strength validation (≥8 chars, mixed)
   - Error handling and display

3. Create login screen: `lib/screens/auth/login_screen.dart`

   - Email/password form
   - "Forgot password?" link
   - Google OAuth button
   - Error handling

4. Create Google OAuth handler: `lib/services/google_oauth_service.dart`

   - Integrate Supabase `signInWithOAuth(provider: Provider.google)`
   - Deep link callback handling (iOS/Android)
   - Universal Links configuration

5. Create verification wait screen: `lib/screens/auth/verification_wait_screen.dart`

   - Resend email button
   - Polling/resume logic for verification
   - Deep link handling for verification callback

6. Create password reset screens: `lib/screens/auth/password_reset_screen.dart`

   - Trigger password reset
   - Confirmation state handling

7. Ensure accessibility: Add semantic labels, error messaging, focus order
8. Update `tasks.md` to mark 3.0-3.7 as complete

## Task Group 4: Biometric Login Support

**Assigned to:** frontend-specialist

**Standards:** `frontend/*`, `global/security.md`, `global/error-handling.md`

### Implementation Steps

1. Create test file: `test/services/biometric_service_test.dart`

   - Mock platform channels
   - Test enable/disable flows
   - Test fallback scenarios

2. Create biometric service: `lib/services/biometric_service.dart`

   - Integrate `local_auth` package
   - Detect available biometrics (Face ID/Touch ID/Fingerprint)
   - Authenticate user with biometrics

3. Create biometric prompt: `lib/widgets/biometric_prompt_widget.dart`

   - Prompt after first successful login
   - Store preference in `profiles` table and secure storage
   - Settings toggle widget

4. Update app launch logic: `lib/main.dart` or `lib/app_router.dart`

   - Intercept app launch
   - Present biometric challenge before Supabase when enabled
   - Fallback to password on failure

5. Update settings to include biometric toggle: `lib/screens/settings/security_settings_screen.dart`

   - Toggle that clears secure storage when disabled

6. Update `tasks.md` to mark 4.0-4.6 as complete

## Task Group 5: Onboarding & Tutorial Flow

**Assigned to:** frontend-specialist

**Standards:** `frontend/*`

### Implementation Steps

1. Create test file: `test/widgets/onboarding_test.dart`

   - Test onboarding completion
   - Test routing after completion

2. Create onboarding screens: `lib/screens/onboarding/`

   - `onboarding_capture_screen.dart` - Capture pillar
   - `onboarding_timeline_screen.dart` - Timeline pillar
   - `onboarding_privacy_screen.dart` - Privacy pillar
   - Align with mission visuals (clean, elegant, scrapbook-inspired)

3. Create onboarding service: `lib/services/onboarding_service.dart`

   - Track completion (`onboarding_completed_at`) in Supabase profile
   - Cache completion locally
   - Check if onboarding should be shown

4. Update routing logic: `lib/app_router.dart`

   - Show onboarding once per account/session
   - Route to main timeline CTA after completion

5. Update `tasks.md` to mark 5.0-5.5 as complete

## Task Group 6: Settings & Profile Management

**Assigned to:** frontend-specialist

**Standards:** `frontend/*`, `global/validation.md`, `global/error-handling.md`

### Implementation Steps

1. Create test file: `test/widgets/settings_test.dart`

   - Name edit validation tests
   - Password change tests
   - Logout tests

2. Create settings screen: `lib/screens/settings/settings_screen.dart`

   - Sections: Account, Security, Support (placeholder links)
   - Navigation from main shell

3. Create profile edit form: `lib/widgets/profile_edit_form.dart`

   - Name edit (trim, non-empty validation)
   - Update Supabase profile
   - Success/error messaging

4. Create password change widget: `lib/widgets/password_change_widget.dart`

   - Hook into Supabase `updateUser`
   - Success/error messaging

5. Create logout handler: `lib/services/logout_service.dart`

   - Clear Supabase session
   - Clear secure storage
   - Route to auth stack

6. Display user info: `lib/widgets/user_info_display.dart`

   - Read-only email (from auth.users)
   - Last sign-in timestamp

7. Update `tasks.md` to mark 6.0-6.7 as complete

## Task Group 7: Account Deletion Service & UI

**Assigned to:** backend-specialist

**Standards:** `backend/*`, `frontend/*`, `global/security.md`, `global/error-handling.md`

### Implementation Steps

1. Create test file: `test/integration/account_deletion_test.dart`

   - Mock Edge Function
   - Test confirmation flow
   - Test failure states

2. Create Edge Function: `supabase/functions/delete-account/index.ts`

   - Deno TypeScript implementation
   - Authenticated delete: remove `auth.users`, cascade `profiles`
   - Trigger audit log
   - Secure with service role key (server-side env)
   - Verify user JWT

3. Create deletion UI flow: `lib/screens/settings/account_deletion_flow.dart`

   - Warning screen
   - Password/biometric re-check
   - Final confirmation button

4. Create deletion service: `lib/services/account_deletion_service.dart`

   - Call Edge Function
   - Handle success/error states
   - Clear local data/secure storage post-delete
   - Show confirmation toast
   - Redirect to intro screen

5. Update `tasks.md` to mark 7.0-7.7 as complete

## Task Group 8: QA & Verification

**Assigned to:** qa-specialist

**Standards:** `testing/*`, `global/*`

### Implementation Steps

1. Review all tests from groups 1-7 (16-28 total tests)

   - Check coverage
   - Identify flakiness
   - Fix any issues

2. Create end-to-end tests: `integration_test/auth_flows_e2e_test.dart`

   - Signup → onboarding → settings edit → delete workflow
   - Up to 6 critical workflow tests
   - Use Flutter integration test harness

3. Manual verification:

   - Test biometric flows on iOS simulator
   - Test biometric flows on Android emulator
   - Test Google OAuth on both platforms

4. Security review: `docs/security_review.md`

   - Review token storage implementation
   - Review logging implementation
   - Review RLS policies
   - Review environment variable handling
   - Compare against `standards/security.md`

5. Create release documentation: `docs/release_notes_auth.md`

   - Release notes
   - Manual test checklist

6. Update `tasks.md` to mark 8.0-8.5 as complete

## File Structure Summary

```
lib/
├── providers/
│   ├── supabase_provider.dart
│   └── auth_state_provider.dart
├── services/
│   ├── secure_storage_service.dart
│   ├── auth_error_handler.dart
│   ├── google_oauth_service.dart
│   ├── biometric_service.dart
│   ├── onboarding_service.dart
│   ├── logout_service.dart
│   └── account_deletion_service.dart
├── screens/
│   ├── auth/
│   │   ├── signup_screen.dart
│   │   ├── login_screen.dart
│   │   ├── verification_wait_screen.dart
│   │   └── password_reset_screen.dart
│   ├── onboarding/
│   │   ├── onboarding_capture_screen.dart
│   │   ├── onboarding_timeline_screen.dart
│   │   └── onboarding_privacy_screen.dart
│   └── settings/
│       ├── settings_screen.dart
│       └── account_deletion_flow.dart
├── widgets/
│   ├── biometric_prompt_widget.dart
│   ├── profile_edit_form.dart
│   ├── password_change_widget.dart
│   └── user_info_display.dart
└── app_router.dart

test/
├── providers/
│   └── supabase_client_test.dart
├── widgets/
│   ├── auth_flows_test.dart
│   ├── onboarding_test.dart
│   └── settings_test.dart
├── services/
│   └── biometric_service_test.dart
└── integration/
    └── account_deletion_test.dart

integration_test/
└── auth_flows_e2e_test.dart

supabase/
└── functions/
    └── delete-account/
        └── index.ts

docs/
├── security_review.md
└── release_notes_auth.md
```

## Dependencies Between Task Groups

- Task Group 2 depends on Task Group 1 (database exists)
- Task Group 3 depends on Task Group 2 (Supabase client exists)
- Task Group 4 depends on Task Group 3 (auth flows exist)
- Task Group 5 depends on Task Group 3 (auth flows exist)
- Task Group 6 depends on Task Groups 1-3 (database, client, auth exist)
- Task Group 7 depends on Task Groups 1-3, 6 (database, client, auth, settings exist)
- Task Group 8 depends on all previous groups (final verification)

## Implementation Notes

- All code must follow Flutter/Dart conventions and standards
- Use Riverpod for state management throughout
- Secure storage must use `flutter_secure_storage` for sensitive data
- Edge Function must use service role key from environment variables
- All UI must be accessible (labels, error messages, focus order)
- Error handling must be user-friendly and logged appropriately
- Tests must be written before or alongside implementation
- Update `tasks.md` after completing each task group

### To-dos

- [ ] Task Group 2: Implement Supabase client provider, auth state handling, secure storage, and error handling
- [ ] Task Group 3: Build signup/login screens, Google OAuth integration, verification wait screen, and password reset
- [ ] Task Group 4: Add biometric login support with local_auth integration and app launch interception
- [ ] Task Group 5: Create onboarding tutorial flow with 3 screens and completion tracking
- [ ] Task Group 6: Build settings screen with profile management, password change, and logout
- [ ] Task Group 7: Implement account deletion Edge Function and multi-step UI flow
- [ ] Task Group 8: Conduct QA verification, security review, and create release documentation