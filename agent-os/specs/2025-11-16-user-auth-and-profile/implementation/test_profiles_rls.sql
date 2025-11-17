-- SQL Tests for profiles table and RLS policies
-- These tests verify that RLS policies correctly prevent cross-user access
-- and that the automatic profile creation trigger works as expected.
--
-- To run these tests in a Supabase preview branch:
-- 1. Create test users via Supabase Auth API or SQL
-- 2. Execute these tests using SET LOCAL role to simulate different user contexts
-- 3. Verify expected behavior

-- Test 1: Verify profile is automatically created on user signup
-- This test should be run after creating a new user via auth.users insert
-- Expected: Profile row exists with matching id and name synced from metadata

-- Test 2: Verify users can SELECT their own profile
-- Setup: Create two test users (user_a and user_b)
-- Execute as user_a:
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claim.sub TO 'user_a_uuid_here';
-- Expected: SELECT * FROM public.profiles WHERE id = 'user_a_uuid_here' returns 1 row
-- Expected: SELECT * FROM public.profiles WHERE id = 'user_b_uuid_here' returns 0 rows

-- Test 3: Verify users can UPDATE their own profile
-- Execute as user_a:
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claim.sub TO 'user_a_uuid_here';
-- Expected: UPDATE public.profiles SET name = 'New Name' WHERE id = 'user_a_uuid_here' succeeds
-- Expected: UPDATE public.profiles SET name = 'Hacked' WHERE id = 'user_b_uuid_here' fails with permission denied

-- Test 4: Verify users cannot INSERT profiles directly
-- Execute as user_a:
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claim.sub TO 'user_a_uuid_here';
-- Expected: INSERT INTO public.profiles (id, name) VALUES ('new_uuid', 'Test') fails with permission denied

-- Test 5: Verify users cannot DELETE profiles
-- Execute as user_a:
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claim.sub TO 'user_a_uuid_here';
-- Expected: DELETE FROM public.profiles WHERE id = 'user_a_uuid_here' fails with permission denied

-- Test 6: Verify updated_at trigger works
-- Execute as user_a:
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claim.sub TO 'user_a_uuid_here';
-- Expected: After UPDATE, updated_at timestamp is more recent than created_at

-- Test 7: Verify name extraction from metadata works correctly
-- Test scenarios:
-- 1. User with raw_user_meta_data->>'name' should use that value
-- 2. User with raw_user_meta_data->>'full_name' should use that if name is missing
-- 3. User with neither should use email prefix (split_part(email, '@', 1))

-- Note: These tests require actual Supabase preview branch setup with test users.
-- In practice, these would be run using Supabase's testing framework or
-- a custom test harness that sets up test users and executes queries in their context.

