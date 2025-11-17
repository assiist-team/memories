import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

interface CleanupQueueItem {
  id: string;
  media_url: string;
  bucket_name: string;
  file_path: string;
  moment_id: string | null;
  retry_count: number;
}

interface ErrorResponse {
  code: string;
  message: string;
  details?: unknown;
}

const MAX_RETRIES = 3;
const BATCH_SIZE = 10;

/**
 * Edge Function for cleaning up orphaned media files from Supabase Storage
 * 
 * This function:
 * - Processes pending items from media_cleanup_queue
 * - Deletes files from Supabase Storage using service role key
 * - Updates queue status and handles retries
 * - Can be called manually or via scheduled job
 */
Deno.serve(async (req: Request): Promise<Response> => {
  // Only allow POST requests
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({
        code: "METHOD_NOT_ALLOWED",
        message: "Only POST requests are allowed",
      } as ErrorResponse),
      {
        status: 405,
        headers: { "Content-Type": "application/json" },
      },
    );
  }

  try {
    // Get service role key from environment (required for storage operations)
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variables");
      return new Response(
        JSON.stringify({
          code: "INTERNAL_ERROR",
          message: "Server configuration error",
        } as ErrorResponse),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Create admin client with service role key (bypasses RLS)
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // Get pending cleanup items (limit to batch size)
    const { data: queueItems, error: fetchError } = await supabaseAdmin
      .from("media_cleanup_queue")
      .select("*")
      .in("status", ["pending", "failed"])
      .lte("retry_count", MAX_RETRIES)
      .order("created_at", { ascending: true })
      .limit(BATCH_SIZE);

    if (fetchError) {
      console.error("Error fetching cleanup queue:", fetchError);
      return new Response(
        JSON.stringify({
          code: "FETCH_ERROR",
          message: "Failed to fetch cleanup queue",
        } as ErrorResponse),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    if (!queueItems || queueItems.length === 0) {
      return new Response(
        JSON.stringify({
          message: "No items to process",
          processed: 0,
        }),
        {
          status: 200,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    const results = {
      processed: 0,
      succeeded: 0,
      failed: 0,
      errors: [] as string[],
    };

    // Process each item
    for (const item of queueItems as CleanupQueueItem[]) {
      try {
        // Mark as processing
        await supabaseAdmin
          .from("media_cleanup_queue")
          .update({
            status: "processing",
            processed_at: new Date().toISOString(),
          })
          .eq("id", item.id);

        // Delete file from storage
        const { error: deleteError } = await supabaseAdmin.storage
          .from(item.bucket_name)
          .remove([item.file_path]);

        if (deleteError) {
          // File might already be deleted, or path is invalid
          // Log but don't fail - update status accordingly
          console.warn(
            `Failed to delete ${item.bucket_name}/${item.file_path}:`,
            deleteError.message,
          );

          // Check if error is "not found" - file already deleted, mark as completed
          if (deleteError.message.includes("not found") || deleteError.message.includes("404")) {
            await supabaseAdmin
              .from("media_cleanup_queue")
              .update({
                status: "completed",
                processed_at: new Date().toISOString(),
              })
              .eq("id", item.id);
            results.succeeded++;
          } else {
            // Other error - increment retry count
            const newRetryCount = item.retry_count + 1;
            await supabaseAdmin
              .from("media_cleanup_queue")
              .update({
                status: newRetryCount >= MAX_RETRIES ? "failed" : "pending",
                retry_count: newRetryCount,
                error_message: deleteError.message,
              })
              .eq("id", item.id);
            results.failed++;
            results.errors.push(`${item.file_path}: ${deleteError.message}`);
          }
        } else {
          // Success - mark as completed
          await supabaseAdmin
            .from("media_cleanup_queue")
            .update({
              status: "completed",
              processed_at: new Date().toISOString(),
            })
            .eq("id", item.id);
          results.succeeded++;
        }

        results.processed++;
      } catch (error) {
        console.error(`Error processing cleanup item ${item.id}:`, error);
        const newRetryCount = item.retry_count + 1;
        await supabaseAdmin
          .from("media_cleanup_queue")
          .update({
            status: newRetryCount >= MAX_RETRIES ? "failed" : "pending",
            retry_count: newRetryCount,
            error_message: error instanceof Error ? error.message : String(error),
          })
          .eq("id", item.id);
        results.failed++;
        results.errors.push(`${item.file_path}: ${error instanceof Error ? error.message : String(error)}`);
      }
    }

    // Log processing results
    console.log(
      JSON.stringify({
        event: "media_cleanup_processed",
        processed: results.processed,
        succeeded: results.succeeded,
        failed: results.failed,
        timestamp: new Date().toISOString(),
      }),
    );

    return new Response(
      JSON.stringify({
        message: "Cleanup processing completed",
        ...results,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    // Log error for debugging (server-side only)
    console.error("Unexpected error in cleanup-media function:", error);

    // Return generic error to client (don't leak stack traces)
    return new Response(
      JSON.stringify({
        code: "INTERNAL_ERROR",
        message: "An unexpected error occurred",
      } as ErrorResponse),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      },
    );
  }
});

