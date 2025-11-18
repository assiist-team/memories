-- Migration: Create profiles table with RLS policies
-- Description: Creates the profiles table for user profile data, including
--              automatic profile creation trigger and RLS policies for security.

-- Create profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  biometric_enabled BOOLEAN NOT NULL DEFAULT false,
  onboarding_completed_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index on id for faster lookups (though PK already provides one)
-- Index on onboarding_completed_at for querying users who haven't completed onboarding
CREATE INDEX IF NOT EXISTS idx_profiles_onboarding_completed_at 
  ON public.profiles(onboarding_completed_at) 
  WHERE onboarding_completed_at IS NULL;

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update updated_at on row updates
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- Create function to automatically create profile on user signup
-- This function syncs the name from auth.users metadata if available
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  user_name TEXT;
BEGIN
  -- Extract name from raw_user_meta_data if available, otherwise use email prefix
  user_name := COALESCE(
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'full_name',
    SPLIT_PART(NEW.email, '@', 1)
  );
  
  -- Insert profile row
  INSERT INTO public.profiles (id, name)
  VALUES (NEW.id, user_name)
  ON CONFLICT (id) DO NOTHING;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to call handle_new_user on auth.users insert
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can select their own profile
CREATE POLICY "Users can view their own profile"
  ON public.profiles
  FOR SELECT
  USING (auth.uid() = id);

-- RLS Policy: Users can update their own profile
CREATE POLICY "Users can update their own profile"
  ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- RLS Policy: Block all inserts (handled by trigger)
-- Users cannot directly insert profiles
CREATE POLICY "No direct profile inserts"
  ON public.profiles
  FOR INSERT
  WITH CHECK (false);

-- RLS Policy: Block all deletes (service role only for cleanup)
-- Users cannot delete their own profiles
CREATE POLICY "No profile deletes"
  ON public.profiles
  FOR DELETE
  USING (false);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT, UPDATE ON public.profiles TO authenticated;

