-- Migration: Update memory_processing_state enum from 'queued' to 'scheduled'
-- Description: Renames the 'queued' state to 'scheduled' to align with the unified
--              processing architecture spec. This migration:
--              1. Adds 'scheduled' to the enum
--              2. Updates all existing 'queued' rows to 'scheduled'
--              3. Removes 'queued' from the enum

-- Step 1: Add 'scheduled' to the enum if it doesn't exist
DO $$
BEGIN
  -- Check if 'scheduled' already exists in the enum
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum 
    WHERE enumlabel = 'scheduled' 
    AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'memory_processing_state')
  ) THEN
    -- Add 'scheduled' to the enum
    ALTER TYPE memory_processing_state ADD VALUE 'scheduled';
  END IF;
END $$;

-- Step 2: Update all existing 'queued' rows to 'scheduled'
UPDATE public.memory_processing_status
SET state = 'scheduled'::memory_processing_state
WHERE state = 'queued'::memory_processing_state;

-- Step 3: Update the default value for new rows
ALTER TABLE public.memory_processing_status
ALTER COLUMN state SET DEFAULT 'scheduled'::memory_processing_state;

-- Step 4: Remove 'queued' from the enum
-- First, check if there are any remaining 'queued' values (should be none after update)
DO $$
DECLARE
  queued_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO queued_count
  FROM public.memory_processing_status
  WHERE state = 'queued'::memory_processing_state;
  
  IF queued_count > 0 THEN
    RAISE EXCEPTION 'Cannot remove queued from enum: % rows still have queued state', queued_count;
  END IF;
  
  -- Remove 'queued' from the enum
  ALTER TYPE memory_processing_state DROP VALUE IF EXISTS 'queued';
END $$;

-- Step 5: Update comments to reflect the new state name
COMMENT ON COLUMN public.memory_processing_status.state IS 'Current processing state: scheduled (not started), processing (LLM work in progress), complete (success), failed (error after retries).';

