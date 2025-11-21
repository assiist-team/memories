-- Migration: Remove story_status from story_fields table
-- Description: Processing status is now unified in memory_processing_status table.
--              The story_status column in story_fields is redundant and should be removed.
--              Other story-specific fields (audio_path, narrative_generated_at, etc.) remain in story_fields.

-- Step 1: Drop the story_status column from story_fields
ALTER TABLE public.story_fields
  DROP COLUMN IF EXISTS story_status;

-- Step 2: Drop the index on story_status if it exists
DROP INDEX IF EXISTS idx_story_fields_story_status;

-- Step 3: Update comments to reflect that processing status is in memory_processing_status
COMMENT ON TABLE public.story_fields IS 'Story-specific extension fields. Processing status is tracked in memory_processing_status table.';
COMMENT ON COLUMN public.story_fields.audio_path IS 'Supabase Storage path for story audio file.';
COMMENT ON COLUMN public.story_fields.narrative_generated_at IS 'Timestamp when processed_text (narrative) was generated for this story.';
COMMENT ON COLUMN public.story_fields.processing_error IS 'Deprecated: Error messages are now tracked in memory_processing_status.last_error. Kept for backward compatibility during migration.';
COMMENT ON COLUMN public.story_fields.retry_count IS 'Deprecated: Retry attempts are now tracked in memory_processing_status.attempts. Kept for backward compatibility during migration.';

