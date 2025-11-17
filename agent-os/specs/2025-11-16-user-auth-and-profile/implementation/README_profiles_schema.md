# Profiles Table Schema & RLS Documentation

## Table: `public.profiles`

### Purpose
Stores user profile information that extends Supabase Auth's `auth.users` table. Each authenticated user has exactly one profile row that is automatically created on signup.

### Schema

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, FK → `auth.users(id)` | References the user's auth ID |
| `name` | TEXT | NOT NULL | User's display name (synced from auth metadata on signup) |
| `biometric_enabled` | BOOLEAN | NOT NULL, DEFAULT false | Whether user has enabled biometric login |
| `onboarding_completed_at` | TIMESTAMPTZ | NULL | Timestamp when user completed onboarding (NULL = not completed) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Row creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Row last update timestamp (auto-updated via trigger) |

### Indexes
- Primary key index on `id` (automatic)
- Partial index on `onboarding_completed_at` for NULL values (finds users who haven't completed onboarding)

### Automatic Profile Creation

When a new user signs up (insert into `auth.users`), the trigger `on_auth_user_created` automatically:
1. Extracts the name from `raw_user_meta_data->>'name'` or `raw_user_meta_data->>'full_name'`
2. Falls back to email prefix (`split_part(email, '@', 1)`) if no name metadata exists
3. Inserts a new profile row with the extracted name

This works for both email/password and OAuth (Google) signups, as Supabase populates metadata appropriately.

### Row Level Security (RLS) Policies

RLS is **enabled** on this table. All policies enforce user isolation:

#### SELECT Policy: "Users can view their own profile"
- **Rule**: `auth.uid() = id`
- **Effect**: Users can only SELECT their own profile row
- **Use case**: Profile display in settings, user info display

#### UPDATE Policy: "Users can update their own profile"
- **Rule**: `auth.uid() = id` (both USING and WITH CHECK)
- **Effect**: Users can only UPDATE their own profile row
- **Use case**: Name changes, biometric toggle, onboarding completion

#### INSERT Policy: "No direct profile inserts"
- **Rule**: `WITH CHECK (false)`
- **Effect**: Blocks all direct INSERTs (profiles created via trigger only)
- **Rationale**: Ensures profile creation is always tied to auth.users creation

#### DELETE Policy: "No profile deletes"
- **Rule**: `USING (false)`
- **Effect**: Blocks all DELETEs (service role can delete for cleanup if needed)
- **Rationale**: Profile deletion should cascade from auth.users deletion, not be user-initiated

### Service Role Access

The service role (bypasses RLS) can:
- SELECT any profile (for admin operations)
- UPDATE any profile (for support operations)
- DELETE profiles (for account cleanup, cascades from auth.users deletion)

**Important**: Never use service role key in client applications. Use only in Edge Functions or server-side code.

### Common Queries

#### Get current user's profile
```sql
SELECT * FROM public.profiles WHERE id = auth.uid();
```

#### Check if user completed onboarding
```sql
SELECT onboarding_completed_at IS NOT NULL AS has_completed_onboarding
FROM public.profiles
WHERE id = auth.uid();
```

#### Update user's name
```sql
UPDATE public.profiles
SET name = 'New Name'
WHERE id = auth.uid();
```

#### Mark onboarding as complete
```sql
UPDATE public.profiles
SET onboarding_completed_at = NOW()
WHERE id = auth.uid()
AND onboarding_completed_at IS NULL;
```

### Migration Notes

- Migration file: `20250117000000_create_profiles_table.sql`
- This migration is **idempotent** (uses `IF NOT EXISTS` clauses)
- The trigger function `handle_new_user()` uses `SECURITY DEFINER` to allow inserts
- The `updated_at` trigger uses a reusable function `handle_updated_at()` that can be applied to other tables

### Testing

See `test_profiles_rls.sql` for SQL test scenarios that verify:
- Automatic profile creation on signup
- RLS policies prevent cross-user access
- Update triggers work correctly
- Name extraction from metadata works for different signup methods

