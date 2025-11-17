import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

interface DeleteAccountRequest {
  userId: string;
}

interface DeleteAccountResponse {
  success: boolean;
  message?: string;
}

interface ErrorResponse {
  code: string;
  message: string;
  details?: unknown;
}

/**
 * Edge Function for secure account deletion
 * 
 * This function:
 * - Verifies the user's JWT token
 * - Ensures the user can only delete their own account
 * - Uses service role key to delete auth.users entry (cascades to profiles)
 * - Logs deletion event for audit purposes
 * 
 * Security:
 * - Service role key must be set in environment variables (never exposed to client)
 * - JWT verification required
 * - User can only delete their own account
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
    // Get authorization header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({
          code: "UNAUTHORIZED",
          message: "Missing authorization header",
        } as ErrorResponse),
        {
          status: 401,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Extract JWT token
    const token = authHeader.replace("Bearer ", "");
    if (!token) {
      return new Response(
        JSON.stringify({
          code: "UNAUTHORIZED",
          message: "Invalid authorization header format",
        } as ErrorResponse),
        {
          status: 401,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Create Supabase client with anon key to verify JWT
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    
    if (!supabaseUrl || !supabaseAnonKey) {
      console.error("Missing SUPABASE_URL or SUPABASE_ANON_KEY environment variables");
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

    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    // Verify JWT and get user
    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser(token);

    if (userError || !user) {
      return new Response(
        JSON.stringify({
          code: "UNAUTHORIZED",
          message: "Invalid or expired token",
        } as ErrorResponse),
        {
          status: 401,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Parse request body
    let requestBody: DeleteAccountRequest;
    try {
      requestBody = await req.json();
    } catch (e) {
      return new Response(
        JSON.stringify({
          code: "INVALID_REQUEST",
          message: "Invalid JSON in request body",
        } as ErrorResponse),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Verify user can only delete their own account
    if (requestBody.userId !== user.id) {
      return new Response(
        JSON.stringify({
          code: "FORBIDDEN",
          message: "You can only delete your own account",
        } as ErrorResponse),
        {
          status: 403,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Get service role key from environment
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseServiceKey) {
      console.error("Missing SUPABASE_SERVICE_ROLE_KEY environment variable");
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

    // Create admin client with service role key for deletion
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // Log deletion event for audit purposes
    const deletionTimestamp = new Date().toISOString();
    console.log(
      JSON.stringify({
        event: "account_deletion",
        userId: user.id,
        email: user.email,
        timestamp: deletionTimestamp,
        requestId: crypto.randomUUID(),
      }),
    );

    // Delete user account (this will cascade to profiles table via foreign key)
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(
      user.id,
    );

    if (deleteError) {
      console.error("Error deleting user:", deleteError);
      return new Response(
        JSON.stringify({
          code: "DELETION_FAILED",
          message: "Failed to delete account",
        } as ErrorResponse),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Return success response
    const response: DeleteAccountResponse = {
      success: true,
      message: "Account deleted successfully",
    };

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    // Log error for debugging (server-side only)
    console.error("Unexpected error in delete-account function:", error);

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

