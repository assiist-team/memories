-- Migration: Add memory_location_data column to memories table
-- Description: Adds JSONB field to store memory location information (where the event happened)
--              This is separate from captured_location (where the phone was when capturing)
--              Stores display_name, latitude, longitude, city, state, country, provider, source

-- Add memory_location_data column to memories table
ALTER TABLE public.memories
  ADD COLUMN IF NOT EXISTS memory_location_data JSONB;

-- Add comment explaining the column
COMMENT ON COLUMN public.memories.memory_location_data IS 
'Memory location metadata stored as JSONB. Contains where the memory event happened (distinct from captured_location which is where the phone was). Fields: display_name (primary UI label), latitude, longitude, optional city/state/country, provider (geocoding service), source (gps_suggestion/manual_text_only/manual_with_suggestion).';

-- Add GIN index for efficient JSONB queries (optional, for future filtering/search)
CREATE INDEX IF NOT EXISTS idx_memories_memory_location_data 
  ON public.memories USING GIN (memory_location_data) 
  WHERE memory_location_data IS NOT NULL;

