import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

interface GenerateTitleRequest {
  transcript: string;
  memoryType: "moment" | "story" | "memento";
}

interface GenerateTitleResponse {
  title: string;
  status: "success" | "fallback";
  generatedAt: string;
}

interface ErrorResponse {
  code: string;
  message: string;
  details?: unknown;
}

const MAX_TITLE_LENGTH = 60;
const FALLBACK_TITLES = {
  moment: "Untitled Moment",
  story: "Untitled Story",
  memento: "Untitled Memento",
};

/**
 * Truncates a string to a maximum length, ensuring it doesn't break words
 */
function truncateTitle(title: string, maxLength: number): string {
  if (title.length <= maxLength) {
    return title;
  }
  
  // Truncate to max length, then find the last space before that point
  const truncated = title.substring(0, maxLength);
  const lastSpace = truncated.lastIndexOf(" ");
  
  // If we found a space and it's not too close to the start, use it
  if (lastSpace > maxLength * 0.5) {
    return truncated.substring(0, lastSpace) + "...";
  }
  
  // Otherwise, just truncate and add ellipsis
  return truncated + "...";
}

/**
 * Generates a title from transcript using LLM
 */
async function generateTitleWithLLM(
  transcript: string,
  memoryType: string,
): Promise<string | null> {
  const openaiApiKey = Deno.env.get("OPENAI_API_KEY");
  
  if (!openaiApiKey) {
    console.warn("OPENAI_API_KEY not configured, falling back to default title");
    return null;
  }

  const openaiUrl = Deno.env.get("OPENAI_API_URL") || 
    "https://api.openai.com/v1/chat/completions";

  // Build prompt based on memory type
  const memoryTypeContext = {
    moment: "a brief moment or memory",
    story: "a longer narrative story",
    memento: "a special memento or keepsake",
  }[memoryType] || "a memory";

  const prompt = `Generate a concise, engaging title (maximum ${MAX_TITLE_LENGTH} characters) for ${memoryTypeContext} based on this transcript. The title should be descriptive but brief, capturing the essence of what happened. Return only the title text, nothing else.

Transcript: ${transcript.substring(0, 1000)}`;

  try {
    const response = await fetch(openaiUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${openaiApiKey}`,
      },
      body: JSON.stringify({
        model: Deno.env.get("OPENAI_MODEL") || "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: "You are a helpful assistant that generates concise, engaging titles for personal memories.",
          },
          {
            role: "user",
            content: prompt,
          },
        ],
        max_tokens: 50,
        temperature: 0.7,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error("OpenAI API error:", response.status, errorText);
      return null;
    }

    const data = await response.json();
    const generatedTitle = data.choices?.[0]?.message?.content?.trim();

    if (!generatedTitle) {
      console.warn("No title generated from LLM response");
      return null;
    }

    // Clean and truncate the title
    const cleanedTitle = generatedTitle
      .replace(/^["']|["']$/g, "") // Remove surrounding quotes
      .trim();
    
    return truncateTitle(cleanedTitle, MAX_TITLE_LENGTH);
  } catch (error) {
    console.error("Error calling LLM API:", error);
    return null;
  }
}

/**
 * Edge Function for generating titles from transcripts
 * 
 * This function:
 * - Verifies the user's JWT token
 * - Calls LLM API to generate a title from transcript
 * - Truncates title to ≤60 characters
 * - Falls back to "Untitled [Type]" if LLM fails
 * - Logs generation for analytics
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
    let requestBody: GenerateTitleRequest;
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

    // Validate request body
    if (!requestBody.transcript || typeof requestBody.transcript !== "string") {
      return new Response(
        JSON.stringify({
          code: "INVALID_REQUEST",
          message: "transcript is required and must be a string",
        } as ErrorResponse),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    if (!requestBody.memoryType || !["moment", "story", "memento"].includes(requestBody.memoryType)) {
      return new Response(
        JSON.stringify({
          code: "INVALID_REQUEST",
          message: "memoryType must be one of: moment, story, memento",
        } as ErrorResponse),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Trim transcript
    const trimmedTranscript = requestBody.transcript.trim();
    
    if (trimmedTranscript.length === 0) {
      return new Response(
        JSON.stringify({
          code: "INVALID_REQUEST",
          message: "transcript cannot be empty",
        } as ErrorResponse),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Generate title using LLM
    const startTime = Date.now();
    const generatedTitle = await generateTitleWithLLM(
      trimmedTranscript,
      requestBody.memoryType,
    );
    const duration = Date.now() - startTime;

    // Determine final title and status
    const finalTitle = generatedTitle || FALLBACK_TITLES[requestBody.memoryType];
    const status: "success" | "fallback" = generatedTitle ? "success" : "fallback";

    // Log generation event
    const requestId = crypto.randomUUID();
    console.log(
      JSON.stringify({
        event: "title_generation",
        userId: user.id,
        memoryType: requestBody.memoryType,
        status: status,
        titleLength: finalTitle.length,
        transcriptLength: trimmedTranscript.length,
        durationMs: duration,
        requestId: requestId,
        timestamp: new Date().toISOString(),
      }),
    );

    // Return success response
    const response: GenerateTitleResponse = {
      title: finalTitle,
      status: status,
      generatedAt: new Date().toISOString(),
    };

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    // Log error for debugging (server-side only)
    console.error("Unexpected error in generate-title function:", error);

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

