# Task Group 8: QA & Verification

## Standards

- `testing/*`
- `global/*`

## Standards References

Refer to the following standards documents for implementation guidance:

- **Testing Standards:**
  - [`agent-os/standards/testing/test-writing.md`](../../standards/testing/test-writing.md) - Test writing guidelines and patterns

- **Global Standards:**
  - [`agent-os/standards/global/security.md`](../../standards/global/security.md) - Security requirements and best practices
  - [`agent-os/standards/global/error-handling.md`](../../standards/global/error-handling.md) - Error handling patterns
  - [`agent-os/standards/global/validation.md`](../../standards/global/validation.md) - Input validation requirements
  - [`agent-os/standards/global/coding-style.md`](../../standards/global/coding-style.md) - Code style conventions
  - [`agent-os/standards/global/conventions.md`](../../standards/global/conventions.md) - Naming and structure conventions
  - [`agent-os/standards/global/performance.md`](../../standards/global/performance.md) - Performance considerations
  - [`agent-os/standards/global/commenting.md`](../../standards/global/commenting.md) - Code commenting standards

## Overview

This task group covers comprehensive QA verification, security review, and release documentation for the User Authentication & Profile feature. It ensures all previous task groups are properly tested, secure, and ready for release.

## Dependencies

- All previous task groups (1-7) must be complete

## Implementation Steps

### 1. Review All Tests from Groups 1-7

Review and verify all tests from previous task groups (16-28 total tests expected):

- **Task Group 1**: Database & RLS tests
- **Task Group 2**: Supabase client, auth state, secure storage tests
- **Task Group 3**: Auth flow tests (signup, login, OAuth, verification, password reset)
- **Task Group 4**: Biometric service tests
- **Task Group 5**: Onboarding tests
- **Task Group 6**: Settings and profile management tests
- **Task Group 7**: Account deletion integration tests

**Actions:**
- Check test coverage (aim for >80% coverage)
- Identify and fix flaky tests
- Ensure all edge cases are covered
- Verify error handling in tests
- Fix any failing tests

### 2. Create End-to-End Tests: `integration_test/auth_flows_e2e_test.dart`

Create comprehensive end-to-end tests using Flutter integration test harness:

- **Signup → Onboarding → Settings Edit → Delete Workflow**
  - Complete user journey from signup to account deletion
- **Critical workflow tests (up to 6 tests):**
  - Email signup → verification → onboarding → main app
  - Google OAuth → onboarding → main app
  - Login → biometric setup → logout → biometric login
  - Profile edit → password change → logout
  - Account deletion flow
  - Password reset flow

### 3. Manual Verification

Perform manual testing on both platforms:

- **iOS Simulator:**
  - Test biometric flows (Face ID simulation)
  - Test Google OAuth flow
  - Test all auth screens and flows
  - Test settings and profile management

- **Android Emulator:**
  - Test biometric flows (Fingerprint simulation)
  - Test Google OAuth flow
  - Test all auth screens and flows
  - Test settings and profile management

**Checklist:**
- [ ] All auth flows work correctly
- [ ] Biometric authentication works on both platforms
- [ ] Google OAuth works on both platforms
- [ ] Onboarding displays correctly
- [ ] Settings and profile management function properly
- [ ] Account deletion works end-to-end
- [ ] Error states display appropriately
- [ ] Offline scenarios handled gracefully

### 4. Security Review: `docs/security_review.md`

Create comprehensive security review document covering:

- **Token Storage Implementation:**
  - Verify secure storage usage for session tokens
  - Verify secure storage usage for biometric preferences
  - Ensure no sensitive data in plain text storage

- **Logging Implementation:**
  - Review error logging hooks
  - Ensure no sensitive data in logs
  - Verify logging follows security standards

- **RLS Policies:**
  - Review all Row Level Security policies
  - Verify user data isolation
  - Test unauthorized access attempts

- **Environment Variable Handling:**
  - Verify Supabase URL and keys are properly configured
  - Ensure service role key is never exposed to client
  - Review Edge Function environment variable usage

- **Compare Against Standards:**
  - Review implementation against `standards/global/security.md`
  - Document any deviations and justifications
  - Create remediation plan for any issues found

### 5. Create Release Documentation: `docs/release_notes_auth.md`

Create release documentation including:

- **Release Notes:**
  - Feature summary
  - New capabilities
  - Known issues (if any)
  - Migration notes (if applicable)

- **Manual Test Checklist:**
  - Step-by-step test procedures
  - Expected results for each test
  - Platform-specific notes
  - Edge cases to verify

### 6. Update `tasks.md`

- Mark tasks 8.0-8.5 as complete

## File Structure

```
test/
├── [all previous test files from groups 1-7]
└── integration/
    └── account_deletion_test.dart

integration_test/
└── auth_flows_e2e_test.dart

docs/
├── security_review.md
└── release_notes_auth.md
```

## Implementation Notes

- Follow Flutter/Dart testing conventions
- Use Flutter integration test framework for E2E tests
- Security review must be thorough and documented
- All identified issues must be tracked and resolved
- Release documentation should be clear and actionable
- Manual testing should cover all user-facing features
- Test coverage should meet project standards (>80%)

## QA Checklist

- [ ] All unit tests pass
- [ ] All widget tests pass
- [ ] All integration tests pass
- [ ] All E2E tests pass
- [ ] Test coverage >80%
- [ ] No flaky tests
- [ ] Manual testing completed on iOS
- [ ] Manual testing completed on Android
- [ ] Security review completed
- [ ] Security issues resolved
- [ ] Release documentation created
- [ ] All tasks marked complete in `tasks.md`

