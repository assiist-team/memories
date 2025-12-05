# Capture Screen First-Tap Delay Fix - Logging Reduction

**Date:** 2025-12-04
**Status:** 🟡 Partially Applied / In Progress

## Problem
The user reported a ~3 second delay on the first tap in the capture screen text input container. Logs showed a massive volume of `TimelineImageCacheService` and `MediaCarousel` errors (404 Object Not Found) occurring right before and during the interaction.

## Analysis
1.  **Log Volume:** The logs were flooded with "Failed to generate signed URL" and "Photo slide error" messages.
2.  **Main Thread Blocking:** While the network requests were successfully offloaded to a worker isolate (using `compute`), the *results* (specifically exceptions) were being marshalled back to the main thread.
3.  **Synchronous Logging:** The `catchError` blocks on the main thread were executing multiple `debugPrint` and `developer.log` calls for *each* failure. On iOS/Android, heavy logging to the console can be synchronous or fill buffers, causing the UI thread to stutter or freeze.
4.  **Timing:** The freeze (gap in logs between `scheduling ensureVisible` and `executing ensureVisible`) coincided with the period of heavy log activity.
5.  **Root Cause of 404s:** The 404 errors themselves were caused by `TimelineImageCacheService` generating signed URLs in a background isolate *without* the user's authentication token. The `memories-photos` bucket is private (RLS enabled), so unauthenticated requests were correctly rejected by Supabase.

## Fix 1: Reduce Logging (Applied)
Reduced logging verbosity in:
1.  `lib/services/timeline_image_cache_service.dart`:
    - Commented out success logs.
    - Commented out verbose error logs, especially for 404 errors.
    - Commented out "Extracted storage path" logs.
2.  `lib/widgets/media_carousel.dart`:
    - Commented out verbose error logs in `_PhotoSlide`.

## Fix 2: Authenticate Image Cache Requests (Applied)
Updated the image caching architecture to pass the user's `accessToken` to the background isolate:
1.  **`lib/services/timeline_image_cache_service.dart`**:
    *   Updated `getSignedUrl` and `getSignedUrlForDetailView` to accept an optional `accessToken`.
    *   Updated the background isolate logic to initialize the `SupabaseClient` with the `Authorization` header if a token is provided.
2.  **Widget Updates**:
    *   Updated `MomentCard`, `MementoCard`, `MediaPreview`, and `MediaCarousel` to retrieve the `accessToken` from the `SupabaseClient` (via Riverpod) and pass it to the cache service.

## Outcome
The massive volume of 404 errors in the logs has been resolved, as the requests are now properly authenticated. **However, the 2-second delay on the first tap persists.**

## Next Steps
Since eliminating the log spam and fixing the 404 errors did not resolve the UI freeze, the root cause lies elsewhere.
-   **Geolocation Service:** The logs showed a `TimeoutException` for geolocation right around the time of the interaction. This needs further investigation.
-   **Focus Handling:** The delay happens specifically when tapping the text field (`onTap` -> `ensureVisible`). We need to profile what happens during focus acquisition and the `ensureVisible` scroll calculation.
-   **Widget Build Cost:** Profiling the build cost of the Capture Screen, particularly the quote widget and input container.

## Note on Geolocation
A `GeolocationService` timeout was also observed (`TimeoutException after 10s`). This appears to be handled asynchronously and shouldn't block the UI, but if the issue persists, this service should be investigated next to ensure it's not implicitly blocking the main thread.
