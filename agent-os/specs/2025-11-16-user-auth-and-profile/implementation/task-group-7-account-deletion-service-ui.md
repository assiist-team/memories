# Task Group 7: Account Deletion Service & UI

## Standards

- `backend/*`
- `frontend/*`
- `global/security.md`
- `global/error-handling.md`

## Standards References

Refer to the following standards documents for implementation guidance:

- **Backend Standards:**
  - [`agent-os/standards/backend/api.md`](../../standards/backend/api.md) - API design patterns
  - [`agent-os/standards/backend/migrations.md`](../../standards/backend/migrations.md) - Database migration guidelines
  - [`agent-os/standards/backend/models.md`](../../standards/backend/models.md) - Data model patterns
  - [`agent-os/standards/backend/queries.md`](../../standards/backend/queries.md) - Query patterns

- **Frontend Standards:**
  - [`agent-os/standards/frontend/accessibility.md`](../../standards/frontend/accessibility.md) - Accessibility requirements
  - [`agent-os/standards/frontend/components.md`](../../standards/frontend/components.md) - Component patterns
  - [`agent-os/standards/frontend/css.md`](../../standards/frontend/css.md) - Styling guidelines
  - [`agent-os/standards/frontend/responsive.md`](../../standards/frontend/responsive.md) - Responsive design

- **Global Standards:**
  - [`agent-os/standards/global/security.md`](../../standards/global/security.md) - Security requirements and best practices
  - [`agent-os/standards/global/error-handling.md`](../../standards/global/error-handling.md) - Error handling patterns
  - [`agent-os/standards/global/coding-style.md`](../../standards/global/coding-style.md) - Code style conventions
  - [`agent-os/standards/global/conventions.md`](../../standards/global/conventions.md) - Naming and structure conventions

## Overview

This task group implements the account deletion functionality, including a secure Edge Function for server-side account deletion and a multi-step UI flow that requires user confirmation and re-authentication.

## Dependencies

- Task Group 1: Database & RLS Foundation (database exists)
- Task Group 2: Supabase Client & Session Plumbing (client exists)
- Task Group 3: Authentication UX (auth flows exist)
- Task Group 6: Settings & Profile Management (settings screen exists)

## Implementation Steps

### 1. Create Test File: `test/integration/account_deletion_test.dart`

- Mock Edge Function calls
- Test confirmation flow
- Test failure states
- Test error handling
- Test local data cleanup

### 2. Create Edge Function: `supabase/functions/delete-account/index.ts`

- Deno TypeScript implementation
- Authenticated delete operation:
  - Remove `auth.users` entry (cascades to `profiles`)
  - Trigger audit log entry
- Security requirements:
  - Secure with service role key (server-side environment variable)
  - Verify user JWT token
  - Ensure user can only delete their own account
- Error handling and logging

### 3. Create Deletion UI Flow: `lib/screens/settings/account_deletion_flow.dart`

- Multi-step confirmation flow:
  - **Warning screen**: Clear explanation of consequences
  - **Re-authentication**: Password/biometric verification
  - **Final confirmation**: Explicit confirmation button
- Accessible design with proper error messaging
- Loading states during deletion

### 4. Create Deletion Service: `lib/services/account_deletion_service.dart`

- Call Edge Function with proper authentication
- Handle success/error states
- Clear local data and secure storage post-deletion
- Show confirmation toast/notification
- Redirect to intro/auth screen after successful deletion

### 5. Update `tasks.md`

- Mark tasks 7.0-7.7 as complete

## File Structure

```
lib/
├── screens/
│   └── settings/
│       └── account_deletion_flow.dart
└── services/
    └── account_deletion_service.dart

test/
└── integration/
    └── account_deletion_test.dart

supabase/
└── functions/
    └── delete-account/
        └── index.ts
```

## Implementation Notes

- Follow Flutter/Dart conventions and standards
- Use Riverpod for state management
- Edge Function must use service role key from environment variables (never expose in client)
- Edge Function must verify JWT and ensure user can only delete their own account
- Account deletion is irreversible - ensure clear warnings
- All local data must be cleared after successful deletion
- Error handling must be user-friendly per `global/error-handling.md`
- Security review required per `global/security.md`
- Edge Function should log deletion events for audit purposes
- UI must require explicit confirmation and re-authentication

## Security Considerations

- Service role key must never be exposed to client
- JWT verification required on Edge Function
- Re-authentication required before deletion
- Audit logging for compliance
- Secure deletion of all user data (auth.users, profiles, related data)

