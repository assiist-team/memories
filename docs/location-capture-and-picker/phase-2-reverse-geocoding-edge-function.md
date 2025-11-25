# Phase 2 – Reverse Geocoding via Supabase Edge Function

**Status**: Not started  
**Owner**: TBD  
**Depends on**: Phase 1 (location picker UI + manual labels), existing `memories` schema  

---

## 1. Goal

- Add reverse geocoding so that, when we have candidate GPS coordinates for a **memory location** (where the event happened, not just where we captured it):

- We can resolve them into human‑readable place information (e.g. `city`, `state`, `country`, `display_name`).
- We can store that information in a **simple JSONB field** on the `memories` table (named `memory_location`) and expose it via `get_memory_detail`.
- The capture and detail UIs show more meaningful labels by default, while still preserving any explicit manual labels the user sets.

---

## 2. Scope

Included:

- New Supabase Edge Function for **reverse geocoding** memory locations:
  - Input: latitude/longitude.
  - Output: structured place info.
- Backend schema change to store resolved **memory location** information:
  - Add a single `memory_location_data JSONB` field to `public.memories`.
- Frontend integration:
  - Call Edge Function on capture/edit when online and we have candidate memory‑location coordinates.
  - Populate the app’s memory‑location model with provider results.

Not included:

- Forward geocoding / search suggestions (Phase 3).
- Spatial queries (e.g. “nearby memories”).

---

## 3. API & Data Design

### 3.1 Edge Function: `reverse-geocode-location`

**Request payload (JSON)**:

```json
{
  "latitude": 40.6782,
  "longitude": -73.9442
}
```

**Response payload (JSON)**:

```json
{
  "city": "Brooklyn",
  "state": "New York",
  "country": "United States",
  "display_name": "Brooklyn, New York, United States",
  "provider": "example-geocoder",
  "raw": { "..." : "..." }
}
```

Notes:

- `provider` identifies which geocoding service we’re using (useful for debugging).
- `raw` can store the raw provider response for future enrichment, or be omitted if not needed.
- We may want to **round coordinates** before sending them to the third‑party API for privacy.

### 3.2 Database Schema Updates

Simple, single‑field design:

- Add to `public.memories`:
  - `memory_location_data JSONB`
    - Holds:
      - `display_name`
      - `latitude`, `longitude`
      - Optional `city`, `state`, `country`
      - Optional `source`, `provider`

Notes:

- This keeps **all memory location metadata in one place**, without cluttering the table with many extra columns.
- If we ever need heavy querying on specific fields (e.g. by country), we can add JSONB indexes or promote individual fields later, but that is explicitly **out of scope** for this phase.

### 3.3 `get_memory_detail` Changes

Ensure `get_memory_detail` returns **memory location** distinctly:

- New:
  - `memory_location_data` JSON with:
    - `display_name`, `latitude`, `longitude`
    - Optional `city`, `state`, `country`, `source`

Priority rules:

- If `memory_location_data.display_name` is present, that is the primary string for UI.
- `city`/`state`/`country` are used only to:
  - Derive default display names when no explicit display name exists.
  - Support future filtering/search if we decide to add indexes later.

---

## 4. Frontend Integration

### 4.1 Calling Reverse Geocoding

When to call the Edge Function:

- On **capture**:
  - After `captureLocation()` has set coordinates, and before or after save:
    - If online and we have `latitude` and `longitude`:
      - Call `reverse-geocode-location`.
      - Store the results in `LocationData` and send them with the save request.
    - If offline or the call fails:
      - Fall back to Phase 1 behavior (manual labels only).

- On **edit**:
  - If an older memory has coordinates but no place info:
    - Optionally call reverse geocoding when the user edits the location.
    - Do not override a user’s existing manual `displayName` unless they explicitly choose a new place.

### 4.2 UI Behavior

After reverse geocoding:

- Capture & detail screens:
  - Prefer showing `display_name` from the Edge Function (e.g. `Brooklyn, New York, United States`).
  - Alternatively derive `"City, State"` from `city` + `state` for a shorter label.

Manual labels:

- If the user types a label and saves it:
  - Keep that label as primary.
  - We can still store provider data in the background; `displayName` stays manual.

---

## 5. Junior‑Friendly Task Breakdown

### Task Group A – Edge Function

1. **Create `reverse-geocode-location` Edge Function**
   - Define input schema (Latitude/Longitude).
   - Call a geocoding provider (mock or real, depending on environment).
   - Map provider response into `{ city, state, country, display_name, provider }`.
2. **Add basic error handling**
   - Network or provider failure should return a 4xx/5xx with a clear error message.
   - The app will treat this as “no place info available” and fall back gracefully.

### Task Group B – Database Schema & RPC

1. **Add new location fields**
   - Either columns or JSONB fields, named self‑evidently.
   - Provide a migration file with comments documenting purpose.
2. **Update `get_memory_detail`**
   - Include new fields in the `location_data` JSON returned to the app.
   - Update comments to mention the new fields.

### Task Group C – App Integration

1. **Update `LocationData` model**
   - Add fields for `displayName`, `city`, `state`, `country`, `provider`.
   - Ensure `fromJson` and any caching logic are updated.
2. **Call Edge Function from the app**
   - Implement a small `LocationLookupService` or similar that wraps the Supabase call.
   - Integrate into the capture flow:
     - Only when online and we have coordinates.
     - With timeouts and non‑blocking error handling.

---

## 6. Acceptance Criteria

- The Edge Function accepts `latitude`/`longitude` and returns structured place info.
- The database can store and retrieve `display_name`, `city`, `state`, `country` for a memory.
- `get_memory_detail` includes these fields in `location_data`.
- The app:
  - Calls the Edge Function when appropriate.
  - Populates `LocationData` with provider results.
  - Shows meaningful place names by default (e.g. “Brooklyn, NY”).
  - Continues to respect explicit manual labels as primary display text.


