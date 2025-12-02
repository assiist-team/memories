-- Migration: Add database trigger to invoke dispatcher on scheduled job insert
-- Description: Implements event-driven invocation of dispatch-memory-processing
--              when a new memory_processing_status row with state='scheduled' is inserted
--              or when state transitions to 'scheduled' on update.
--              This ensures processing starts immediately without polling or cron.

-- Step 1: Enable pg_net extension for HTTP requests from PostgreSQL
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Step 2: Create configuration table for dispatcher settings
-- This allows configuring the Supabase URL without hardcoding
-- Note: Service role key is not stored here for security; dispatcher uses its own env var
CREATE TABLE IF NOT EXISTS public.dispatcher_config (
  id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1), -- Singleton table
  supabase_url TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT single_row CHECK (id = 1)
);

-- Enable RLS on dispatcher_config (only service role should access this)
ALTER TABLE public.dispatcher_config ENABLE ROW LEVEL SECURITY;

-- Policy: Only service role can read/write dispatcher config
-- Regular users don't need access to this table
CREATE POLICY "Service role only" ON public.dispatcher_config
  FOR ALL
  USING (auth.role() = 'service_role');

-- Step 2.1: Automatically populate dispatcher_config with Supabase URL
-- The URL is automatically detected from the project configuration
-- Use a SECURITY DEFINER function to bypass RLS during migration
CREATE OR REPLACE FUNCTION initialize_dispatcher_config()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  project_url TEXT;
BEGIN
  -- Use known project URL from codebase configuration
  -- This project: https://cgppebaekutbacvuaioa.supabase.co
  project_url := 'https://cgppebaekutbacvuaioa.supabase.co';
  
  -- Insert or update the config
  INSERT INTO public.dispatcher_config (id, supabase_url, updated_at)
  VALUES (1, project_url, NOW())
  ON CONFLICT (id) DO UPDATE
  SET supabase_url = EXCLUDED.supabase_url,
      updated_at = NOW();
  
  RAISE NOTICE 'Dispatcher config initialized with URL: %', project_url;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Could not auto-configure dispatcher_config: %', SQLERRM;
END;
$$;

-- Execute the initialization function
SELECT initialize_dispatcher_config();

-- Drop the temporary function
DROP FUNCTION initialize_dispatcher_config();

-- Step 4: Create function to invoke dispatcher edge function
-- This function will be called by the trigger to invoke dispatch-memory-processing
CREATE OR REPLACE FUNCTION invoke_memory_processing_dispatcher()
RETURNS TRIGGER AS $$
DECLARE
  config_record RECORD;
  function_url TEXT;
BEGIN
  -- Only invoke dispatcher when state is 'scheduled'
  IF NEW.state = 'scheduled' THEN
    -- Get configuration from dispatcher_config table
    SELECT * INTO config_record
    FROM public.dispatcher_config
    WHERE id = 1;
    
    -- If config not found, log warning and return (dispatcher won't be invoked)
    IF NOT FOUND THEN
      RAISE WARNING 'Dispatcher config not found. Please configure dispatcher_config table with supabase_url. Memory % will remain scheduled until manually processed.', NEW.memory_id;
      RETURN NEW;
    END IF;
    
    -- Construct function URL
    function_url := config_record.supabase_url || '/functions/v1/dispatch-memory-processing';
    
    -- Invoke dispatcher via HTTP POST (fire and forget - don't block the transaction)
    -- Use pg_net for async HTTP requests
    -- Note: No Authorization header - dispatcher will detect internal trigger call
    -- and use its own service role key from environment
    PERFORM net.http_post(
      url := function_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Internal-Trigger', 'true'
      ),
      body := jsonb_build_object(
        'triggered_by', 'database_trigger',
        'memory_id', NEW.memory_id::text
      )
    );
    
    -- Log invocation (optional, for debugging)
    RAISE LOG 'Invoked dispatcher for memory_id: %', NEW.memory_id;
  END IF;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the transaction
    RAISE WARNING 'Failed to invoke dispatcher for memory_id %: %', NEW.memory_id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 5: Create trigger on INSERT
DROP TRIGGER IF EXISTS trigger_invoke_dispatcher_on_scheduled_insert ON public.memory_processing_status;
CREATE TRIGGER trigger_invoke_dispatcher_on_scheduled_insert
  AFTER INSERT ON public.memory_processing_status
  FOR EACH ROW
  WHEN (NEW.state = 'scheduled')
  EXECUTE FUNCTION invoke_memory_processing_dispatcher();

-- Step 6: Create trigger on UPDATE (when state transitions to 'scheduled')
DROP TRIGGER IF EXISTS trigger_invoke_dispatcher_on_scheduled_update ON public.memory_processing_status;
CREATE TRIGGER trigger_invoke_dispatcher_on_scheduled_update
  AFTER UPDATE ON public.memory_processing_status
  FOR EACH ROW
  WHEN (NEW.state = 'scheduled' AND (OLD.state IS DISTINCT FROM NEW.state))
  EXECUTE FUNCTION invoke_memory_processing_dispatcher();

-- Step 7: Add comments for documentation
COMMENT ON TABLE public.dispatcher_config IS 'Configuration table for dispatcher trigger. Stores Supabase URL for invoking dispatch-memory-processing edge function. Automatically configured during migration. Service role key is handled by the dispatcher function itself.';
COMMENT ON COLUMN public.dispatcher_config.supabase_url IS 'Full Supabase project URL (e.g., https://your-project.supabase.co)';
COMMENT ON FUNCTION invoke_memory_processing_dispatcher() IS 'Trigger function that invokes dispatch-memory-processing edge function when a scheduled job is inserted or state transitions to scheduled. Uses pg_net for async HTTP requests.';
COMMENT ON TRIGGER trigger_invoke_dispatcher_on_scheduled_insert ON public.memory_processing_status IS 'Fires after INSERT when state=scheduled to immediately invoke the dispatcher.';
COMMENT ON TRIGGER trigger_invoke_dispatcher_on_scheduled_update ON public.memory_processing_status IS 'Fires after UPDATE when state transitions to scheduled to immediately invoke the dispatcher.';

