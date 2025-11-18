-- Migration: Phase 7 - Drop Story Fields From Core Memories Table
-- Description: Removes story-specific columns from memories table after migration to story_fields table.
--              This migration should be run after code has been updated to use story_fields.

-- Step 1: Drop story-specific indexes on memories table
DROP INDEX IF EXISTS idx_memories_story_status;
DROP INDEX IF EXISTS idx_memories_processing_started_at;
DROP INDEX IF EXISTS idx_memories_processing_completed_at;
DROP INDEX IF EXISTS idx_memories_story_retry_count;
DROP INDEX IF EXISTS idx_memories_narrative_generated_at;

-- Step 2: Drop story-specific columns from memories table
ALTER TABLE public.memories
  DROP COLUMN IF EXISTS story_status,
  DROP COLUMN IF EXISTS processing_started_at,
  DROP COLUMN IF EXISTS processing_completed_at,
  DROP COLUMN IF EXISTS narrative_generated_at,
  DROP COLUMN IF EXISTS audio_path,
  DROP COLUMN IF EXISTS retry_count,
  DROP COLUMN IF EXISTS last_retry_at,
  DROP COLUMN IF EXISTS processing_error;

-- Note: narrative_text was already dropped in a previous migration (20251118000003_align_story_processing_with_text_normalization.sql)

