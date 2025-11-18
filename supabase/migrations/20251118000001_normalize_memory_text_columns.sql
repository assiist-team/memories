-- Migration: Normalize memory text columns
-- Description: Renames text_description to input_text and adds processed_text column.
--              This establishes the normalized text model: input_text (raw) and processed_text (LLM-processed).
--              Idempotent: handles both cases where text_description exists or input_text already exists.

-- Step 1: Rename text_description to input_text (if text_description exists and input_text doesn't)
-- Handle both 'moments' and 'memories' table names (table gets renamed in previous migration)
DO $$
BEGIN
  -- Check if table is still called 'moments'
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'moments') THEN
    -- Rename text_description to input_text if text_description exists and input_text doesn't
    IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'moments' 
      AND column_name = 'text_description'
    ) AND NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'moments' 
      AND column_name = 'input_text'
    ) THEN
      ALTER TABLE public.moments RENAME COLUMN text_description TO input_text;
    END IF;
  END IF;
  
  -- Check if table is called 'memories'
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'memories') THEN
    -- Rename text_description to input_text if text_description exists and input_text doesn't
    IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'memories' 
      AND column_name = 'text_description'
    ) AND NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' 
      AND table_name = 'memories' 
      AND column_name = 'input_text'
    ) THEN
      ALTER TABLE public.memories RENAME COLUMN text_description TO input_text;
    END IF;
  END IF;
END $$;

-- Step 2: Add processed_text column (handle both table names)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'moments') THEN
    ALTER TABLE public.moments ADD COLUMN IF NOT EXISTS processed_text TEXT;
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'memories') THEN
    ALTER TABLE public.memories ADD COLUMN IF NOT EXISTS processed_text TEXT;
  END IF;
END $$;

-- Step 3: Update comments (handle both table names)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'moments') THEN
    COMMENT ON COLUMN public.moments.input_text IS
      'Canonical raw user text from dictation or typing. Edited in capture UI.';
    COMMENT ON COLUMN public.moments.processed_text IS
      'LLM-processed version of input_text (cleaned description or narrative). For stories, full narrative; for other types, cleaned description.';
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'memories') THEN
    COMMENT ON COLUMN public.memories.input_text IS
      'Canonical raw user text from dictation or typing. Edited in capture UI.';
    COMMENT ON COLUMN public.memories.processed_text IS
      'LLM-processed version of input_text (cleaned description or narrative). For stories, full narrative; for other types, cleaned description.';
  END IF;
END $$;

-- Note: We do NOT backfill processed_text from input_text.
-- processed_text must only contain LLM-processed content.
-- Until the LLM pipeline runs successfully, processed_text stays NULL.

