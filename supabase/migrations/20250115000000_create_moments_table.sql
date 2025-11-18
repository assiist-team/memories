-- Migration: Create base moments table
-- Description: Creates the foundational moments table with core columns for storing user memories.
--              This table will be extended by subsequent migrations to support text/media capture,
--              voice processing, and unified memory types (moments, stories, mementos).

-- Create the moments table
CREATE TABLE IF NOT EXISTS public.moments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  input_text TEXT,
  processed_text TEXT,
  photo_urls TEXT[] DEFAULT '{}',
  video_urls TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_moments_user_id 
  ON public.moments (user_id);

CREATE INDEX IF NOT EXISTS idx_moments_created_at 
  ON public.moments (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_moments_updated_at 
  ON public.moments (updated_at DESC);

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at on row updates
CREATE TRIGGER update_moments_updated_at
  BEFORE UPDATE ON public.moments
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security
ALTER TABLE public.moments ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only see their own moments
CREATE POLICY "Users can view their own moments"
  ON public.moments
  FOR SELECT
  USING (auth.uid() = user_id);

-- RLS Policy: Users can insert their own moments
CREATE POLICY "Users can insert their own moments"
  ON public.moments
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- RLS Policy: Users can update their own moments
CREATE POLICY "Users can update their own moments"
  ON public.moments
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- RLS Policy: Users can delete their own moments
CREATE POLICY "Users can delete their own moments"
  ON public.moments
  FOR DELETE
  USING (auth.uid() = user_id);

-- Add column comments for documentation
COMMENT ON TABLE public.moments IS 'Unified table storing all memory types (moments, stories, mementos). Extended by subsequent migrations with capture_type enum and additional columns.';
COMMENT ON COLUMN public.moments.id IS 'Primary key UUID for the moment';
COMMENT ON COLUMN public.moments.user_id IS 'Foreign key reference to auth.users. User who created this moment.';
COMMENT ON COLUMN public.moments.title IS 'Title of the moment (required)';
COMMENT ON COLUMN public.moments.input_text IS 'Canonical raw user text from dictation or typing. Edited in capture UI.';
COMMENT ON COLUMN public.moments.processed_text IS 'LLM-processed version of input_text (cleaned description or narrative). For stories, full narrative; for other types, cleaned description.';
COMMENT ON COLUMN public.moments.photo_urls IS 'Array of Supabase Storage paths for photos associated with this moment';
COMMENT ON COLUMN public.moments.video_urls IS 'Array of Supabase Storage paths for videos associated with this moment';
COMMENT ON COLUMN public.moments.created_at IS 'Timestamp when the moment was created';
COMMENT ON COLUMN public.moments.updated_at IS 'Timestamp when the moment was last updated (automatically maintained by trigger)';

