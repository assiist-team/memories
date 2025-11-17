# Testing Guide

This project uses a hybrid testing approach: **mocks for unit tests**, **real Supabase for integration tests**.

## Test Structure

- **`test/`** - Unit tests with mocks (fast, isolated)
- **`test/integration/`** - Integration tests with real Supabase (tests actual integration)
- **`integration_test/`** - E2E tests with real Supabase (full user flows)

## Setting Up Test Supabase Instance

### Option 1: Use Supabase CLI (Recommended)

1. Create a separate Supabase project for testing:
   ```bash
   supabase projects create memories-test
   ```

2. Get your test project credentials:
   - Project URL: `https://xxxxx.supabase.co`
   - Anon Key: Found in Project Settings > API

3. Run migrations on test instance:
   ```bash
   supabase db push --project-ref your-test-project-ref
   ```

### Option 2: Use Local Supabase

1. Start local Supabase:
   ```bash
   supabase start
   ```

2. Use local credentials:
   - URL: `http://localhost:54321`
   - Anon Key: Found in `supabase/.env` or `supabase status`

## Running Tests

### Unit Tests (with mocks)
```bash
flutter test
```

### Integration Tests (with real Supabase)
```bash
flutter test test/integration/ \
  --dart-define=TEST_SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=TEST_SUPABASE_ANON_KEY=your-anon-key
```

Or set environment variables:
```bash
export TEST_SUPABASE_URL=https://xxxxx.supabase.co
export TEST_SUPABASE_ANON_KEY=your-anon-key
flutter test test/integration/
```

### E2E Tests
```bash
flutter test integration_test/ \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## Test Helpers

Use `test/helpers/test_supabase_setup.dart` for integration tests:

```dart
import '../helpers/test_supabase_setup.dart';

void main() {
  late ProviderContainer container;
  late SupabaseClient supabase;

  setUpAll(() {
    container = createTestSupabaseContainer();
    supabase = container.read(supabaseClientProvider);
  });

  test('my integration test', () async {
    // Create test user
    final testUser = await createTestUser(
      supabase,
      email: 'test@example.com',
      password: 'password123',
    );

    // Your test code here...

    // Cleanup (optional - test users can be isolated)
    await cleanupTestUser(supabase, testUser.user.id);
  });
}
```

## Benefits of Real Supabase for Integration Tests

✅ **No mocking complexity** - Tests actual API contracts  
✅ **Catches integration issues** - Real RLS policies, Edge Functions, etc.  
✅ **More confidence** - Tests what users actually experience  
✅ **Easier to write** - No need to mock complex response types  

## When to Use Mocks vs Real Supabase

**Use Mocks (Unit Tests):**
- Testing business logic in isolation
- Testing error handling paths
- Fast feedback during development
- Testing edge cases that are hard to reproduce

**Use Real Supabase (Integration Tests):**
- Testing service integrations
- Testing RLS policies
- Testing Edge Function calls
- Testing auth flows
- Testing data persistence

## CI/CD Setup

For CI/CD, set test credentials as secrets:

```yaml
# GitHub Actions example
env:
  TEST_SUPABASE_URL: ${{ secrets.TEST_SUPABASE_URL }}
  TEST_SUPABASE_ANON_KEY: ${{ secrets.TEST_SUPABASE_ANON_KEY }}
```

## Test Data Cleanup

Integration tests should clean up after themselves:

```dart
tearDown(() async {
  final user = supabase.auth.currentUser;
  if (user != null) {
    await cleanupTestUser(supabase, user.id);
  }
  await supabase.auth.signOut();
});
```

**Note:** For Edge Function tests (like account deletion), cleanup happens automatically since the function deletes the user.

