# Task Breakdown: User Authentication & Profile

## Overview
Total Tasks: 8 groups / 37 sub-tasks

## Task List

### Database & RLS Foundation
**Dependencies:** None

- [x] 1.0 Complete database layer
  - [x] 1.1 Write 2-4 focused SQL tests for profiles table + RLS (Supabase preview branch)
  - [x] 1.2 Create `profiles` table migration (id uuid PK referencing auth.users, name text not null, biometric_enabled bool default false, onboarding_completed_at timestamptz null, timestamps)
  - [x] 1.3 Add trigger or RPC to auto-insert profile row on signup (syncing name field)
  - [x] 1.4 Implement RLS policies (select/update restricted to `auth.uid()`, block delete; service role only for cleanup)
  - [x] 1.5 Document schema + RLS in README snippet for future reference
  - [x] 1.6 Run ONLY tests from 1.1 plus `supabase db push` dry-run to validate migration

**Acceptance Criteria**
- Profiles table exists with correct columns/defaults
- RLS prevents cross-user access
- Automated profile creation works for email + Google signups
- Tests in 1.1 pass

### Supabase Client & Session Plumbing
**Dependencies:** Task Group 1

- [x] 2.0 Implement shared Supabase client + auth state handling
  - [x] 2.1 Write 2-4 focused Dart tests around auth provider/session refresh logic (mock Supabase client)
  - [x] 2.2 Create Riverpod provider that configures single Supabase client using anon key/env handling
  - [x] 2.3 Add auth state listener to route users between auth stack, verification wait, onboarding, and main shell
  - [x] 2.4 Persist session tokens securely (`flutter_secure_storage`) and hydrate on app start
  - [x] 2.5 Implement offline/error handling + logging hooks per security standards
  - [x] 2.6 Run ONLY tests from 2.1

**Acceptance Criteria**
- One Supabase client instance shared app-wide
- Auth state changes update navigation consistently
- Sessions persist across app restarts securely
- Tests in 2.1 pass

### Authentication UX (Email + Google + Verification)
**Dependencies:** Task Group 2

- [x] 3.0 Build signup/login flows
  - [x] 3.1 Write 3-5 widget/integration tests for form validation, Google OAuth intent, verification wait state
  - [x] 3.2 Implement email/password signup/login UI with validation (name required, password strength ≥ 8 chars mixed)
  - [x] 3.3 Integrate Google OAuth via Supabase `signInWithOAuth` + deep link callbacks per platform
  - [x] 3.4 Add verification wait screen with resend email + polling/resume logic
  - [x] 3.5 Implement password reset trigger + confirmation states
  - [x] 3.6 Localize copy + ensure accessibility (labels, error messaging, focus order)
  - [x] 3.7 Run ONLY tests from 3.1

**Acceptance Criteria**
- Users can sign up/login with email or Google
- Email verification enforced before onboarding
- Password reset flow works end-to-end
- Tests in 3.1 pass

### Biometric Login Support
**Dependencies:** Task Group 3

- [x] 4.0 Add biometric preference + unlock path
  - [x] 4.1 Write 2-3 focused tests (platform channels mocked) covering enable/disable + fallback
  - [x] 4.2 Integrate `local_auth` (or approved plugin) to detect available biometrics
  - [x] 4.3 Prompt users after first successful login; store preference in `profiles` and secure storage
  - [x] 4.4 Intercept app launch to present biometric challenge prior to hitting Supabase when enabled
  - [x] 4.5 Provide settings toggle that clears secure storage when disabled
  - [x] 4.6 Run ONLY tests from 4.1

**Acceptance Criteria**
- Biometrics optional, enabled post-login, works across app launches
- Disabling biometrics removes stored secrets
- Graceful fallback to password when biometric fails
- Tests in 4.1 pass

### Onboarding & Tutorial Flow
**Dependencies:** Task Group 3

- [x] 5.0 Deliver first-run tutorial
  - [x] 5.1 Write 2-3 widget tests covering onboarding completion + routing
  - [x] 5.2 Design 2-3 onboarding screens (capture, timeline, privacy) aligned with mission visuals
  - [x] 5.3 Track completion (`onboarding_completed_at`) in Supabase profile and cache locally
  - [x] 5.4 Ensure onboarding shows once per account/session and routes to main timeline CTA
  - [x] 5.5 Run ONLY tests from 5.1

**Acceptance Criteria**
- First verified session must see onboarding
- Proper persistence prevents repeated onboarding
- CTA routes to main experience
- Tests in 5.1 pass

### Settings & Profile Management
**Dependencies:** Task Groups 1-3

- [x] 6.0 Build settings surface
  - [x] 6.1 Write 3-4 widget tests for name edit validation, password change, logout
  - [x] 6.2 Create Settings screen with sections: Account, Security, Support (placeholder links)
  - [x] 6.3 Implement Name edit form (trim, non-empty) updating Supabase profile
  - [x] 6.4 Hook Change Password into Supabase `updateUser` with success/error messaging
  - [x] 6.5 Implement logout that clears Supabase session + secure storage and routes to auth stack
  - [x] 6.6 Display read-only email + last sign-in timestamp
  - [x] 6.7 Run ONLY tests from 6.1

**Acceptance Criteria**
- Settings reachable from main shell
- Profile updates sync immediately
- Password changes/logouts confirm success
- Tests in 6.1 pass

### Account Deletion Service & UI
**Dependencies:** Task Groups 1-3, 6

- [x] 7.0 Implement multi-step account deletion
  - [x] 7.1 Write 2-4 integration tests (mock Edge Function) covering confirmation flow + failure states
  - [x] 7.2 Build Supabase Edge Function (Deno) performing authenticated delete: remove `auth.users`, cascade `profiles`, trigger audit log
  - [x] 7.3 Secure function with service role key (server-side env) and user JWT verification
  - [x] 7.4 Create UI flow: warning screen → password/biometric re-check → final confirm button
  - [x] 7.5 Send confirmation email or in-app receipt; show final toast + redirect to intro
  - [x] 7.6 Ensure local data/secure storage cleared post-delete
  - [ ] 7.7 Run ONLY tests from 7.1

**Acceptance Criteria**
- Deletion requires explicit confirmation steps
- Edge Function removes auth + profile data safely
- App state fully resets after deletion
- Tests in 7.1 pass

### QA & Verification
**Dependencies:** Task Groups 1-7

- [x] 8.0 Feature-level validation
  - [x] 8.1 Review tests from groups 1-7 (approximately 16-28 total) for coverage + flakiness
  - [x] 8.2 Identify critical workflow gaps (e.g., signup → onboarding → settings edit → delete) and add up to 6 end-to-end tests using Flutter integration harness
  - [x] 8.3 Verify biometric + Google flows on both iOS and Android simulators/devices
  - [x] 8.4 Conduct security review (token storage, logs, RLS, Env vars) against standards/security.md
  - [x] 8.5 Document release notes + manual test checklist

**Acceptance Criteria**
- All feature-specific automated tests pass
- Manual verification checklist completed across target devices
- Security review documented with any follow-ups

## Execution Order
1. Database & RLS Foundation
2. Supabase Client & Session Plumbing
3. Authentication UX
4. Biometric Login Support
5. Onboarding Flow
6. Settings & Profile Management
7. Account Deletion Service & UI
8. QA & Verification

