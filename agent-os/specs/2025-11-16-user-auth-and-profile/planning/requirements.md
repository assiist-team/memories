# Spec Requirements: User Authentication & Profile

## Initial Description
**User Authentication & Profile** — Implement Supabase Auth with email/password and social login; create user profile with basic settings.

Size: XS
Phase: MVP - Core Memory Capture & Viewing

## Requirements Discussion

### First Round Questions

**Q1:** Social Login Providers - I assume we should implement both Google Sign-In and Apple Sign-In for the MVP since the tech stack mentions both. Should we launch with both providers, or prioritize one first (e.g., Apple for iOS TestFlight, then add Google)?
**Answer:** We'll just do Google for social login providers.

**Q2:** Email Verification - I'm thinking we should require email verification for email/password signups to prevent spam accounts and ensure valid contact info. Should users be able to access the app immediately after signup, or must they verify their email before accessing any features?
**Answer:** User is fine with email verification (standard flow).

**Q3:** Password Reset Flow - I assume we'll use Supabase's built-in password reset functionality (email with reset link). Should this be a standard email-based flow, or do you want any customization to the reset process?
**Answer:** Supabase built-in password reset functionality sounds good.

**Q4:** Profile Information - For the basic user profile, I'm thinking we collect: Display name (required), Profile photo (optional), Email (from auth, read-only). Is this sufficient for MVP, or are there other profile fields needed (e.g., date of birth, bio, location)?
**Answer:** User doesn't like "display name" as it's unintuitive. Prefers calling it "Name". No profile photo needed for MVP. Just Name (required) and Email (read-only from auth).

**Q5:** Basic Settings - I assume "basic settings" includes: Change password, Update profile (name/photo), Notification preferences (on/off toggle for future features), Account deletion. Is this the right scope, or should we include other settings like privacy defaults or theme preferences?
**Answer:** Notification stuff is V2. Account deletion was questioned initially but confirmed after clarifying iOS App Store requirements and privacy compliance (GDPR). Basic settings = Change password, Update profile (name only), Log out, Account deletion.

**Q6:** Onboarding Experience - Should first-time users go through an onboarding flow after signup (e.g., welcome screen, quick tutorial), or should they land directly on an empty timeline feed with a prompt to create their first memory?
**Answer:** People should go through a basic onboarding experience with a quick tutorial.

**Q7:** Biometric Authentication - Should we implement biometric login (Face ID/Touch ID on iOS, fingerprint on Android) for returning users, or keep it simple with traditional login for MVP?
**Answer:** Biometric login would be really good. Should be optional and prompted after first successful login.

**Q8:** Out of Scope - I assume the following are out of scope for this feature: Multi-factor authentication (2FA), Phone number authentication, Account linking (merging accounts from different providers), Social profile imports. Anything else you want to explicitly exclude from this initial auth implementation?
**Answer:** User doesn't care about multi-factor authentication, phone number authentication, merging accounts, or social profile imports. All are out of scope.

### Existing Code to Reference

No similar existing features identified for reference. This is a greenfield implementation.

### Follow-up Questions

**Follow-up 1:** Name Field - I'd suggest we simply label it as "Name" (not "display name" or "full name") - it's clearest and least confusing. We'll make it a required field during signup. Does that work for you?
**Answer:** Calling it "Name" works.

**Follow-up 2:** Account Deletion - Important Context - For a paid app, account deletion is actually crucial for several reasons: iOS App Store Requirement (Apple requires account deletion if users can create accounts), Privacy Compliance (GDPR), Subscription Management. Given this, I recommend including account deletion in MVP with a clear multi-step confirmation process. Should we include this?
**Answer:** Sure, account deletion is fine.

**Follow-up 3:** Basic Settings Scope - If we remove notifications (V2) and include account deletion, the minimal settings would be: Change password, Update profile (name only), Log out, Account deletion. Is this the right minimal set for MVP?
**Answer:** Confirmed this scope.

**Follow-up 4:** Biometric Authentication Details - Should biometric login be: Optional (user can enable it in settings), Prompted after first successful login, Something users can toggle on/off in settings?
**Answer:** Biometric is optional and prompted.

**Follow-up 5:** Visual Characteristics - You mentioned describing the app as clean, simple, and elegant in your original description under the products section. Should I look for and read that file to understand the visual direction, or is the mission document I already read sufficient for now?
**Answer:** The mission doc is sufficient for now for visuals.

## Visual Assets

No visual assets provided.

## Requirements Summary

### Functional Requirements

**Authentication Methods:**
- Email/password signup and login
- Google Sign-In (OAuth)
- Email verification required for email/password signups
- Password reset via Supabase built-in functionality (email with reset link)
- Biometric authentication (Face ID/Touch ID on iOS, fingerprint on Android) - optional and prompted after first successful login

**User Profile:**
- Name (required text field during signup)
- Email (read-only, from auth provider)
- Profile data stored and associated with authenticated user

**Onboarding:**
- First-time users go through a basic onboarding experience with quick tutorial after signup/login

**Basic Settings:**
- Change password
- Update profile (name only)
- Toggle biometric login on/off
- Log out
- Account deletion (with multi-step confirmation to prevent accidents)

### Reusability Opportunities

This is a greenfield implementation. No existing similar features to reference.

### Scope Boundaries

**In Scope:**
- Email/password authentication with email verification
- Google OAuth social login
- User profile with name field
- Basic settings (password change, profile update, biometric toggle, logout, account deletion)
- Biometric login (optional, prompted)
- Onboarding flow with quick tutorial
- Supabase Auth integration
- Row-level security policies for user data

**Out of Scope:**
- Apple Sign-In (deferred, only Google for MVP)
- Multi-factor authentication (2FA)
- Phone number authentication
- Account linking/merging from different providers
- Social profile imports
- Profile photo
- Additional profile fields (bio, location, date of birth, etc.)
- Notification preferences (V2)
- Theme preferences
- Privacy setting defaults

### Technical Considerations

**Technology Stack:**
- Flutter (mobile app framework)
- Supabase Auth for authentication
- Supabase PostgreSQL for user profile data storage
- Biometric authentication using Flutter plugins (local_auth or similar)
- Row-Level Security (RLS) policies to ensure users can only access their own data

**Integration Points:**
- Supabase Auth API for signup, login, password reset, email verification
- Google OAuth SDK/plugin for Flutter
- Flutter biometric authentication plugin for Face ID/Touch ID/Fingerprint
- Supabase database for storing user profile information (linked to auth.users)

**Design Characteristics (from Mission):**
- Clean, simple, and elegant UI
- Mobile-first approach (iOS and Android)
- Beautiful, classy presentation
- Scrapbook-inspired interface aesthetic

**Privacy & Compliance:**
- iOS App Store requirement: users must be able to delete accounts created in-app
- GDPR compliance: account deletion capability required
- Email verification to ensure valid contact info and prevent spam

**Subscription Context (Future):**
- App will eventually be paid with credits system (certain number of credits per month + pay-as-you-go)
- Account deletion important for subscription management

