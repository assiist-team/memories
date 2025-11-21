-- Migration: Create unified memory_processing_status table
-- Description: Implements the unified processing architecture for all memory types.
--              This replaces any previous processing status tracking with a single,
--              unified table that tracks AI processing lifecycle for moments, mementos, and stories.

-- Step 1: Create the processing state enum
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'memory_processing_state') THEN
    CREATE TYPE memory_processing_state AS ENUM (
      'queued',       -- row exists; work not yet started
      'processing',   -- one or more LLM steps are in progress
      'complete',     -- all required processing finished successfully
      'failed'        -- processing failed after retries
    );
  END IF;
END $$;

-- Step 2: Create the unified processing status table
CREATE TABLE IF NOT EXISTS public.memory_processing_status (
  memory_id UUID PRIMARY KEY REFERENCES public.memories(id) ON DELETE CASCADE,

  -- Single lifecycle state for AI processing.
  state memory_processing_state NOT NULL DEFAULT 'queued',

  -- Retry + error metadata.
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  last_error_at TIMESTAMPTZ,

  -- Timestamps.
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  last_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Optional UI/diagnostic payload (e.g., current stage messages, timing, LLM model info).
  metadata JSONB
);

-- Step 3: Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_memory_processing_status_state
  ON public.memory_processing_status(state);

CREATE INDEX IF NOT EXISTS idx_memory_processing_status_created_at
  ON public.memory_processing_status(created_at);

-- Step 4: Create trigger to update last_updated_at on row changes
CREATE OR REPLACE FUNCTION update_memory_processing_status_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.last_updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_memory_processing_status_updated_at ON public.memory_processing_status;
CREATE TRIGGER trigger_update_memory_processing_status_updated_at
  BEFORE UPDATE ON public.memory_processing_status
  FOR EACH ROW
  EXECUTE FUNCTION update_memory_processing_status_updated_at();

-- Step 5: Add comments for documentation
COMMENT ON TABLE public.memory_processing_status IS 'Unified processing status tracking for all memory types (moments, mementos, stories). Tracks AI processing lifecycle from queued to complete/failed.';
COMMENT ON COLUMN public.memory_processing_status.memory_id IS 'Foreign key to memories table. One row per memory that needs processing.';
COMMENT ON COLUMN public.memory_processing_status.state IS 'Current processing state: queued (not started), processing (LLM work in progress), complete (success), failed (error after retries).';
COMMENT ON COLUMN public.memory_processing_status.attempts IS 'Number of processing attempts made. Incremented on each retry.';
COMMENT ON COLUMN public.memory_processing_status.last_error IS 'Error message from the most recent processing failure.';
COMMENT ON COLUMN public.memory_processing_status.last_error_at IS 'Timestamp of the most recent processing failure.';
COMMENT ON COLUMN public.memory_processing_status.metadata IS 'Optional JSONB payload for UI/diagnostic info (e.g., current phase, timing, LLM model used).';

