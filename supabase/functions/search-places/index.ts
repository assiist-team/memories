import "jsr:@supabase/functions-js/edge-runtime.d.ts";

interface SearchPlacesRequest {
  query: string;
  limit?: number;
  user_location?: {
    latitude: number;
    longitude: number;
  };
}

interface PlaceResult {
  display_name: string;
  city?: string;
  state?: string;
  country?: string;
  latitude: number;
  longitude: number;
  provider: string;
}

interface SearchPlacesResponse {
  results: PlaceResult[];
}

interface ErrorResponse {
  code: string;
  message: string;
  details?: unknown;
}

/**
 * Forward geocodes a text query using Nominatim (OpenStreetMap)
 * This is a free service that doesn't require an API key
 */
async function forwardGeocodeWithNominatim(
  query: string,
  limit: number = 5,
  userLocation?: { latitude: number; longitude: number },
): Promise<PlaceResult[]> {
  // Build Nominatim search URL
  const encodedQuery = encodeURIComponent(query);
  let url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodedQuery}&limit=${limit}&addressdetails=1`;
  
  // Add user location bias if provided (helps prioritize nearby results)
  if (userLocation) {
    url += `&lat=${userLocation.latitude}&lon=${userLocation.longitude}`;
  }

  try {
    const response = await fetch(url, {
      headers: {
        "User-Agent": "Memories App (contact: support@memories.app)", // Required by Nominatim ToS
      },
    });

    if (!response.ok) {
      console.error(JSON.stringify({
        event: "nominatim_forward_geocode_error",
        status: response.status,
        statusText: response.statusText,
        query: query.substring(0, 50), // Log partial query for debugging
      }));
      return [];
    }

    const data = await response.json();
    
    if (!Array.isArray(data) || data.length === 0) {
      return [];
    }

    // Map Nominatim results to our standard format
    return data.map((item: any) => {
      const address = item.address || {};
      
      const city = address.city || address.town || address.village || address.municipality || null;
      const state = address.state || address.region || null;
      const country = address.country || null;
      const displayName = item.display_name || null;

      // Build a shorter display name if we have city and state
      let shortDisplayName = displayName;
      if (city && state) {
        shortDisplayName = `${city}, ${state}`;
        if (country) {
          shortDisplayName = `${city}, ${state}, ${country}`;
        }
      } else if (city) {
        shortDisplayName = city;
        if (country) {
          shortDisplayName = `${city}, ${country}`;
        }
      } else if (state) {
        shortDisplayName = state;
        if (country) {
          shortDisplayName = `${state}, ${country}`;
        }
      }

      return {
        display_name: shortDisplayName || displayName || query,
        city: city || undefined,
        state: state || undefined,
        country: country || undefined,
        latitude: parseFloat(item.lat),
        longitude: parseFloat(item.lon),
        provider: "nominatim",
      };
    });
  } catch (error) {
    console.error(JSON.stringify({
      event: "nominatim_forward_geocode_exception",
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
      query: query.substring(0, 50),
    }));
    return [];
  }
}

/**
 * Edge Function for forward geocoding / place search
 * 
 * This function:
 * - Accepts a text query and optional user location for biasing results
 * - Returns a list of candidate places with coordinates and structured location data
 * - Uses Nominatim (OpenStreetMap) as the geocoding provider
 * - Enforces query length and limit constraints
 */
Deno.serve(async (req: Request): Promise<Response> => {
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
    let requestBody: SearchPlacesRequest;
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
    if (typeof requestBody.query !== "string" || requestBody.query.trim().length === 0) {
      return new Response(
        JSON.stringify({
          code: "INVALID_REQUEST",
          message: "query is required and must be a non-empty string",
        } as ErrorResponse),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Reject very short queries to avoid noisy calls
    const trimmedQuery = requestBody.query.trim();
    if (trimmedQuery.length < 2) {
      return new Response(
        JSON.stringify({
          code: "INVALID_REQUEST",
          message: "Query must be at least 2 characters long",
        } as ErrorResponse),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Validate and enforce limit
    const limit = Math.min(requestBody.limit || 5, 10); // Max 10 results
    if (limit < 1 || limit > 10) {
      return new Response(
        JSON.stringify({
          code: "INVALID_REQUEST",
          message: "limit must be between 1 and 10",
        } as ErrorResponse),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Validate user_location if provided
    if (requestBody.user_location) {
      const { latitude, longitude } = requestBody.user_location;
      if (
        typeof latitude !== "number" ||
        typeof longitude !== "number" ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180
      ) {
        return new Response(
          JSON.stringify({
            code: "INVALID_REQUEST",
            message: "Invalid user_location coordinates",
          } as ErrorResponse),
          {
            status: 400,
            headers: { "Content-Type": "application/json" },
          },
        );
      }
    }

    // Perform forward geocoding
    const results = await forwardGeocodeWithNominatim(
      trimmedQuery,
      limit,
      requestBody.user_location,
    );

    // Log successful search (without exposing full query)
    console.log(JSON.stringify({
      event: "forward_geocode_success",
      provider: "nominatim",
      resultCount: results.length,
      queryLength: trimmedQuery.length,
      hasUserLocation: !!requestBody.user_location,
    }));

    return new Response(
      JSON.stringify({
        results: results,
      } as SearchPlacesResponse),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error("Unexpected error in search-places function:", error);

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

