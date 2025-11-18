-- Migration: Phase 7 - Story Fields Extension & Title Nullability
-- Description: Makes title optional and moves story-specific fields to dedicated story_fields table.
--              This separates shared memory fields from story-specific processing fields.

-- Step 1: Make title nullable
DO $$
BEGIN
  -- Check if title column exists and has NOT NULL constraint
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'memories' 
    AND column_name = 'title'
    AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE public.memories ALTER COLUMN title DROP NOT NULL;
  END IF;
END $$;

-- Step 2: Update title-related comments
COMMENT ON COLUMN public.memories.title IS 'Current display title. May be NULL on insert; often generated from input_text.';
COMMENT ON COLUMN public.memories.generated_title IS 'Last auto-generated title suggestion from LLM/title service.';
COMMENT ON COLUMN public.memories.title_generated_at IS 'Timestamp when generated_title was created.';

-- Step 3: Ensure story_status enum exists (it should already exist from previous migration)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'story_status') THEN
    CREATE TYPE story_status AS ENUM ('processing', 'complete', 'failed');
  END IF;
END $$;

-- Step 4: Create story_fields extension table
CREATE TABLE IF NOT EXISTS public.story_fields (
  memory_id UUID PRIMARY KEY REFERENCES public.memories(id) ON DELETE CASCADE,
  
  -- Processing status
  story_status story_status,
  
  -- Processing timestamps
  processing_started_at TIMESTAMPTZ,
  processing_completed_at TIMESTAMPTZ,
  narrative_generated_at TIMESTAMPTZ,
  
  -- Audio storage path
  audio_path TEXT,
  
  -- Retry logic
  retry_count INTEGER NOT NULL DEFAULT 0,
  last_retry_at TIMESTAMPTZ,
  
  -- Error context
  processing_error TEXT,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Step 5: Create indexes on story_fields
CREATE INDEX IF NOT EXISTS idx_story_fields_story_status 
  ON public.story_fields(story_status) 
  WHERE story_status IN ('processing', 'failed');

CREATE INDEX IF NOT EXISTS idx_story_fields_processing_started_at 
  ON public.story_fields(processing_started_at) 
  WHERE processing_started_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_story_fields_processing_completed_at 
  ON public.story_fields(processing_completed_at) 
  WHERE processing_completed_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_story_fields_narrative_generated_at 
  ON public.story_fields(narrative_generated_at) 
  WHERE narrative_generated_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_story_fields_retry_count 
  ON public.story_fields(retry_count) 
  WHERE retry_count > 0;

-- Step 6: Create trigger to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_story_fields_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_story_fields_updated_at
  BEFORE UPDATE ON public.story_fields
  FOR EACH ROW
  EXECUTE FUNCTION update_story_fields_updated_at();

-- Step 7: Enable Row Level Security
ALTER TABLE public.story_fields ENABLE ROW LEVEL SECURITY;

-- Step 8: RLS Policies for story_fields
-- Users can only see story_fields for their own memories
CREATE POLICY "Users can view story_fields for their own memories"
  ON public.story_fields
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.memories 
      WHERE memories.id = story_fields.memory_id 
      AND memories.user_id = auth.uid()
    )
  );

-- Users can insert story_fields for their own memories
CREATE POLICY "Users can insert story_fields for their own memories"
  ON public.story_fields
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.memories 
      WHERE memories.id = story_fields.memory_id 
      AND memories.user_id = auth.uid()
    )
  );

-- Users can update story_fields for their own memories
CREATE POLICY "Users can update story_fields for their own memories"
  ON public.story_fields
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.memories 
      WHERE memories.id = story_fields.memory_id 
      AND memories.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.memories 
      WHERE memories.id = story_fields.memory_id 
      AND memories.user_id = auth.uid()
    )
  );

-- Users can delete story_fields for their own memories
CREATE POLICY "Users can delete story_fields for their own memories"
  ON public.story_fields
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.memories 
      WHERE memories.id = story_fields.memory_id 
      AND memories.user_id = auth.uid()
    )
  );

-- Step 9: Add column comments for story_fields
COMMENT ON TABLE public.story_fields IS 'Extension table for story-specific processing fields. One row per story memory (memory_type = ''story'').';
COMMENT ON COLUMN public.story_fields.memory_id IS 'Foreign key reference to memories.id. One-to-one relationship with story memories.';
COMMENT ON COLUMN public.story_fields.story_status IS 'Story processing status: processing (awaiting/undergoing processing), complete (narrative generated), failed (processing error).';
COMMENT ON COLUMN public.story_fields.processing_started_at IS 'Timestamp when backend processing began for story narrative generation';
COMMENT ON COLUMN public.story_fields.processing_completed_at IS 'Timestamp when backend processing finished (success or failure) for story narrative generation';
COMMENT ON COLUMN public.story_fields.narrative_generated_at IS 'Timestamp when processed_text was generated for story (narrative text lives in memories.processed_text)';
COMMENT ON COLUMN public.story_fields.audio_path IS 'Supabase Storage path for audio file (stories/audio/{userId}/{storyId}/{timestamp}.m4a)';
COMMENT ON COLUMN public.story_fields.retry_count IS 'Number of times story processing has been retried after failure';
COMMENT ON COLUMN public.story_fields.last_retry_at IS 'Timestamp of most recent retry attempt for story processing';
COMMENT ON COLUMN public.story_fields.processing_error IS 'Error message or context if story processing failed';

