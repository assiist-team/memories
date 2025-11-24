-- Migration: Update search_memories to support partial matches on tags/text
-- Description: Expands the search_memories RPC to also match queries as
--              case-insensitive substrings on tags and text fields, so that
--              short queries like 'cam' can match tags like 'camera'. This
--              keeps full-text search as the primary mechanism while adding
--              a pragmatic fallback for partial matches.

-- Recreate search_memories function with updated WHERE clause
CREATE OR REPLACE FUNCTION public.search_memories(
  p_query TEXT,
  p_page INT DEFAULT 1,
  p_page_size INT DEFAULT 20,
  p_memory_type TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_query_normalized TEXT;
  v_tsquery tsquery;
  v_offset_val INT;
  v_limit_val INT;
  v_memory_type_filter TEXT;
  v_start_time TIMESTAMPTZ;
  v_duration_ms NUMERIC;
  v_result_count INT;
  v_has_more BOOLEAN;
  v_items JSONB;
BEGIN
  -- Get authenticated user ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: User must be authenticated';
  END IF;
  
  -- Validate and normalize query (reject empty/whitespace-only)
  v_query_normalized := trim(p_query);
  IF v_query_normalized IS NULL OR v_query_normalized = '' THEN
    RAISE EXCEPTION 'Invalid query: query cannot be empty or whitespace-only';
  END IF;
  
  -- Validate page (must be >= 1)
  IF p_page IS NULL OR p_page < 1 THEN
    RAISE EXCEPTION 'Invalid page: must be >= 1';
  END IF;
  
  -- Validate page_size (default 20, max 50 per spec)
  v_limit_val := LEAST(COALESCE(p_page_size, 20), 50);
  IF v_limit_val < 1 THEN
    RAISE EXCEPTION 'Invalid page_size: must be >= 1';
  END IF;
  
  -- Calculate offset
  v_offset_val := (p_page - 1) * v_limit_val;
  
  -- Validate and normalize memory_type parameter
  IF p_memory_type IS NULL OR LOWER(p_memory_type) = 'all' THEN
    v_memory_type_filter := NULL; -- NULL means all types
  ELSIF LOWER(p_memory_type) IN ('story', 'moment', 'memento') THEN
    v_memory_type_filter := LOWER(p_memory_type);
  ELSE
    RAISE EXCEPTION 'Invalid memory_type: must be all, story, moment, or memento';
  END IF;
  
  -- Build safe tsquery from normalized query
  -- Use plainto_tsquery for simple keyword search (handles multi-word queries)
  -- This is safer than to_tsquery as it handles user input better
  BEGIN
    v_tsquery := plainto_tsquery('english', v_query_normalized);
    
    -- If plainto_tsquery returns empty (e.g., only stopwords), try phraseto_tsquery
    IF v_tsquery IS NULL OR v_tsquery = '' THEN
      v_tsquery := phraseto_tsquery('english', v_query_normalized);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    -- If tsquery building fails, log and raise
    RAISE EXCEPTION 'Invalid query format: %', SQLERRM;
  END;
  
  -- Start timing for performance logging
  v_start_time := clock_timestamp();
  
  -- Execute search query with ranking
  -- Order by ts_rank_cd (coverage density ranking) DESC, then recency as tiebreaker
  -- Fetch one extra row to determine has_more
  WITH ranked_results AS (
    SELECT 
      m.id,
      m.memory_type::TEXT as memory_type,
      m.title,
      -- Snippet text: prefer processed_text, fallback to input_text, trim to ~200 chars
      LEFT(
        COALESCE(
          NULLIF(trim(m.processed_text), ''),
          NULLIF(trim(m.input_text), '')
        ),
        200
      ) as snippet_text,
      m.created_at
    FROM public.memories m
    WHERE m.user_id = v_user_id
      -- Memory type filter
      AND (
        v_memory_type_filter IS NULL 
        OR m.memory_type::TEXT = v_memory_type_filter
      )
      -- Match using full-text search OR a pragmatic substring fallback on
      -- tags/title/text so short queries like 'cam' can match 'camera'.
      AND (
        m.search_vector @@ v_tsquery
        OR COALESCE(array_to_string(m.tags, ' '), '') ILIKE '%' || v_query_normalized || '%'
        OR COALESCE(m.title, '') ILIKE '%' || v_query_normalized || '%'
        OR COALESCE(m.generated_title, '') ILIKE '%' || v_query_normalized || '%'
        OR COALESCE(m.input_text, '') ILIKE '%' || v_query_normalized || '%'
        OR COALESCE(m.processed_text, '') ILIKE '%' || v_query_normalized || '%'
      )
    ORDER BY 
      ts_rank_cd(m.search_vector, v_tsquery) DESC,
      m.created_at DESC NULLS LAST,
      m.id DESC
    LIMIT v_limit_val + 1  -- Fetch one extra to determine has_more
    OFFSET v_offset_val
  ),
  limited_results AS (
    SELECT 
      id,
      memory_type,
      title,
      snippet_text,
      created_at
    FROM ranked_results
    LIMIT v_limit_val  -- Only include the first v_limit_val rows in results
  )
  SELECT 
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', id,
          'memory_type', memory_type,
          'title', title,
          'snippet_text', snippet_text,
          'created_at', created_at
        )
      ),
      '[]'::jsonb
    ),
    (SELECT COUNT(*) FROM ranked_results) > v_limit_val as has_more
  INTO v_items, v_has_more
  FROM limited_results;
  
  -- Calculate duration for logging
  v_duration_ms := EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time)) * 1000;
  v_result_count := jsonb_array_length(COALESCE(v_items, '[]'::jsonb));
  
  -- Log slow queries (>1000ms) and basic metrics
  -- Note: In production, you might want to use a logging table or external service
  -- For now, we'll use RAISE NOTICE for development/debugging
  IF v_duration_ms > 1000 THEN
    RAISE NOTICE 'Slow search query detected: query_length=%, duration_ms=%, result_count=%, page=%, memory_type=%',
      length(v_query_normalized), v_duration_ms, v_result_count, p_page, p_memory_type;
  END IF;
  
  -- Return paginated results
  RETURN jsonb_build_object(
    'items', COALESCE(v_items, '[]'::jsonb),
    'page', p_page,
    'page_size', v_limit_val,
    'has_more', COALESCE(v_has_more, false)
  );
END;
$$;

COMMENT ON FUNCTION public.search_memories IS 
'Full-text search function for memories. Searches across title, generated_title, input_text, processed_text, and tags. '
'Supports both full-text search and a substring fallback so short queries like \"cam\" can match \"camera\". '
'Returns paginated results ordered by relevance (ts_rank_cd) and recency. Supports optional memory_type filtering.';


