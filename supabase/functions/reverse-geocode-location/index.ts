import "jsr:@supabase/functions-js/edge-runtime.d.ts";

interface ReverseGeocodeRequest {
  latitude: number;
  longitude: number;
}

interface ReverseGeocodeResponse {
  city?: string;
  state?: string;
  country?: string;
  display_name: string;
  provider: string;
  raw?: Record<string, unknown>;
}

interface ErrorResponse {
  code: string;
  message: string;
  details?: unknown;
}

/**
 * Rounds coordinates to 4 decimal places (~11 meters precision) for privacy
 * This reduces the precision of location data sent to third-party geocoding services
 */
function roundCoordinates(lat: number, lng: number): { lat: number; lng: number } {
  return {
    lat: Math.round(lat * 10000) / 10000,
    lng: Math.round(lng * 10000) / 10000,
  };
}

/**
 * Reverse geocodes coordinates using Nominatim (OpenStreetMap)
 * This is a free service that doesn't require an API key
 */
async function reverseGeocodeWithNominatim(
  latitude: number,
  longitude: number,
): Promise<ReverseGeocodeResponse | null> {
  const rounded = roundCoordinates(latitude, longitude);
  
  // Nominatim API endpoint
  const url = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${rounded.lat}&lon=${rounded.lng}&addressdetails=1&zoom=18`;
  
  try {
    const response = await fetch(url, {
      headers: {
        "User-Agent": "Memories App (contact: support@memories.app)", // Required by Nominatim ToS
      },
    });

    if (!response.ok) {
      console.error(JSON.stringify({
        event: "nominatim_reverse_geocode_error",
        status: response.status,
        statusText: response.statusText,
      }));
      return null;
    }

    const data = await response.json();
    
    if (!data || !data.address) {
      console.warn(JSON.stringify({
        event: "nominatim_reverse_geocode_empty_response",
        data: data,
      }));
      return null;
    }

    const address = data.address;
    
    // Extract location components
    const city = address.city || address.town || address.village || address.municipality || null;
    const state = address.state || address.region || null;
    const country = address.country || null;
    const displayName = data.display_name || null;

    if (!displayName) {
      console.warn(JSON.stringify({
        event: "nominatim_reverse_geocode_no_display_name",
        address: address,
      }));
      return null;
    }

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
      city: city || undefined,
      state: state || undefined,
      country: country || undefined,
      display_name: shortDisplayName,
      provider: "nominatim",
      raw: data, // Store raw response for future enrichment
    };
  } catch (error) {
    console.error(JSON.stringify({
      event: "nominatim_reverse_geocode_exception",
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    }));
    return null;
  }
}

/**
 * Edge Function for reverse geocoding coordinates to place information
 * 
 * This function:
 * - Accepts latitude and longitude coordinates
 * - Returns structured place information (city, state, country, display_name)
 * - Uses Nominatim (OpenStreetMap) as the geocoding provider
 * - Rounds coordinates for privacy before sending to third-party service
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
    let requestBody: ReverseGeocodeRequest;
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
    if (
      typeof requestBody.latitude !== "number" ||
      typeof requestBody.longitude !== "number"
    ) {
      return new Response(
        JSON.stringify({
          code: "INVALID_REQUEST",
          message: "latitude and longitude are required and must be numbers",
        } as ErrorResponse),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Validate coordinate ranges
    if (
      requestBody.latitude < -90 ||
      requestBody.latitude > 90 ||
      requestBody.longitude < -180 ||
      requestBody.longitude > 180
    ) {
      return new Response(
        JSON.stringify({
          code: "INVALID_REQUEST",
          message: "Invalid coordinate values. Latitude must be between -90 and 90, longitude between -180 and 180",
        } as ErrorResponse),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Perform reverse geocoding
    const result = await reverseGeocodeWithNominatim(
      requestBody.latitude,
      requestBody.longitude,
    );

    if (!result) {
      return new Response(
        JSON.stringify({
          code: "GEOCODING_FAILED",
          message: "Failed to reverse geocode coordinates",
        } as ErrorResponse),
        {
          status: 500,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    // Log successful geocoding (without exposing coordinates)
    console.log(JSON.stringify({
      event: "reverse_geocode_success",
      provider: result.provider,
      hasCity: !!result.city,
      hasState: !!result.state,
      hasCountry: !!result.country,
      displayNameLength: result.display_name.length,
    }));

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Unexpected error in reverse-geocode-location function:", error);

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

