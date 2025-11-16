# Specification: User Authentication & Profile

## Goal
Deliver a secure, polished authentication experience powered by Supabase that supports email/password and Google login, captures each user’s name, and provides essential settings (biometric toggle, password change, logout, account deletion) plus a first-run onboarding tutorial.

## User Stories
- As a new user, I want to sign up with email or Google and confirm my account so I can start saving memories immediately.
- As a returning user, I want to enable biometrics and manage my profile so that signing in stays effortless and secure.
- As a privacy-conscious user, I want an intuitive settings area where I can change my password, log out everywhere, or delete my account whenever needed.

## Specific Requirements

**Supabase Authentication Flow**
- Use a single Supabase client (anon key) shared via Riverpod providers for signup, login, session refresh, and logout.
- Support email/password signup + login, persist sessions via Supabase auto-refresh, and block access until a valid session exists.
- Implement Google OAuth through Supabase `signInWithOAuth(provider: Provider.google)` with deep-link handling per platform.
- Provide auth state observers to redirect unauthenticated users to the auth stack and route verified sessions into the app shell.
- Surface inline error states (invalid credentials, network loss, revoked consent) with retry paths and logging hooks.

**Email Verification & Password Recovery**
- Require email verification before onboarding; show waiting state with “Resend verification email” using Supabase API.
- Handle verification deep-link/Universal Link callbacks that resume the app and re-check session validity.
- Use Supabase built-in password reset emails; expose “Forgot password?” from login to trigger the flow.
- Enforce password strength rules (min length 8+, mixed characters) client-side per validation standards.

**User Profile Data Model**
- Create `profiles` table keyed by `uuid` (matches `auth.users.id`) storing `name text`, `biometric_enabled boolean default false`, timestamps.
- Enforce RLS: users can select/update rows where `id = auth.uid()`; block inserts except via trigger on signup.
- Sync profile data immediately after signup (require name field) and whenever settings update occurs.
- Keep email read-only by mirroring from `auth.users` when displaying profile screens.

**Biometric Authentication**
- Integrate Flutter `local_auth` (or preferred package) to detect availability and capture Face ID/Touch ID/Fingerprint enrollment.
- Prompt users to enable biometrics after first successful login; store preference in both `profiles.biometric_enabled` and `flutter_secure_storage`.
- When enabled, show biometric prompt before hitting Supabase (unlock cached session) while falling back to password if the biometric check fails.
- Allow toggling biometrics inside settings; disabling clears secure storage tokens.

**Onboarding & Tutorial Flow**
- First-time verified sessions must see a lightweight onboarding stack (3 screens max) describing capture, timeline, and privacy pillars.
- Persist an `onboarding_completed_at` timestamp in `profiles` (nullable) to ensure the tutorial only runs once per account.
- Include CTA to “Create first memory” or “Import later” that routes to the main timeline.

**Settings & Profile Management**
- Build a dedicated Settings screen reachable from the main shell with sections: Account, Security, Support.
- Profile section lets users edit Name only; validate non-empty, trimmed input before patching Supabase via `update`.
- Security section houses “Change password” (Supabase `updateUser`), “Biometric login” toggle, and “Log out” (clears session + secure storage).
- Show last sign-in timestamp pulled from session metadata for transparency.

**Account Deletion Flow**
- Provide multi-step confirmation (warning screen → credential re-check → final confirmation) before deletion.
- Implement deletion via Supabase Edge Function (service role key stored server-side) that deletes `auth.users` row, cascade-deletes `profiles`, and scrubs user-owned data.
- After successful deletion, clear local caches, secure storage, and navigate to intro screen with confirmation toast + email receipt.

**Security & Compliance**
- Store sensitive tokens/preferences in `flutter_secure_storage`; never log secrets per security standards.
- Respect mission-aligned UI tone (clean, elegant) while ensuring high-contrast text and accessible touch targets ≥ 44px.
- Add audit logging hooks (Edge Function) for deletion and password changes (user id, timestamp) and expose to support tooling later.

## Visual Design
- No visual assets provided; follow mission document guidance for a clean, elegant, scrapbook-inspired mobile UI using native Flutter theming.

## Existing Code to Leverage
- No existing authentication or profile modules currently ship in the app; treat this as a greenfield implementation while adhering to the documented tech stack and standards.

## Out of Scope
- Apple Sign-In and any providers beyond Google.
- Multi-factor authentication or SMS/phone-based auth.
- Profile photos or additional profile fields (bio, location, DOB, etc.).
- Notification preferences, push settings, or theme toggles.
- Account linking/merging across multiple providers.
- Social profile importers or contact sync.
- Payment/subscription management flows.
- Server-driven onboarding personalization beyond the described tutorial.

