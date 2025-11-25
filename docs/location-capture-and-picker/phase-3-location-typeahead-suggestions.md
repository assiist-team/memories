# Phase 3 – Location Typeahead Suggestions

**Status**: Not started  
**Owner**: TBD  
**Depends on**: Phase 1 (location picker UI), Phase 2 (reverse geocoding service & data shape)  

---

## 1. Goal

Enhance the **memory location picker** with **typeahead suggestions** so that:

- As users type into the location field, they see relevant place suggestions.
- Selecting a suggestion sets both:
  - A high‑quality `displayName` (e.g. “Brooklyn Museum”).
  - Underlying coordinates and structured components (`city`, `state`, `country`).
- When the device is offline, the picker gracefully falls back to **manual text only** (no suggestions).

---

## 2. Scope

Included:

- New Supabase Edge Function (or an extension of the Phase 2 function) for **forward geocoding memory locations**:
  - Input: partial text query (and possibly user’s approximate location).
  - Output: list of candidate places with coordinates and labels.
- App integration into the existing Phase 1 location picker:
  - Online: show suggestions as the user types.
  - Offline: show no suggestions.
- UX adjustments:
  - Clear differentiation between “Use this text” vs. “Use suggested place”.

Not included:

- Caching of suggestions beyond per‑session caching.
- Complex spatial search features (“memories near X”).

---

## 3. API & Data Design

### 3.1 Edge Function: `search-places`

**Request payload (JSON)**:

```json
{
  "query": "brooklyn",
  "limit": 5,
  "user_location": {
    "latitude": 40.6782,
    "longitude": -73.9442
  }
}
```

**Response payload (JSON)**:

```json
{
  "results": [
    {
      "display_name": "Brooklyn, New York, United States",
      "city": "Brooklyn",
      "state": "New York",
      "country": "United States",
      "latitude": 40.6782,
      "longitude": -73.9442,
      "provider": "example-geocoder"
    }
  ]
}
```

Notes:

- `user_location` is optional; when present, it can be used to bias results.
- `limit` keeps the response small and predictable.
- The data shape should align with Phase 2’s reverse geocoding output.

### 3.2 App‑Side Structures

Define a lightweight model for a memory‑location suggestion, e.g. `LocationSuggestion`:

- `displayName: String`
- `city: String?`
- `state: String?`
- `country: String?`
- `latitude: double`
- `longitude: double`
- `provider: String?`

This should convert cleanly into the memory‑location model (`MemoryLocation` / `LocationData`) when a suggestion is chosen.

---

## 4. Picker UX Behavior

### 4.1 Online (Suggestions Available)

Behavior:

- As the user types into the search field:
  - Debounce input (e.g. 250–400 ms).
  - Call `search-places` with `query` and, if available, approximate `user_location`.
  - Render a list of suggestions under the input.

Selecting a suggestion:

- Updates:
  - `displayName` to the suggestion’s `display_name`.
  - `latitude`/`longitude`, `city`, `state`, `country` in `LocationData`.
- Closes the picker and updates the capture or detail UI row.

Using manual text:

- If the user ignores suggestions and taps **“Use this text”**:
  - Store the raw input string as `displayName`.
  - Optionally:
    - Attempt a one‑shot geocode in the background, but do not block on it.
    - Do not override the manual `displayName` with provider labels.

### 4.2 Offline (No Suggestions)

Behavior:

- Do not call `search-places`.
- Show a small hint text under the field:
  - “Offline: suggestions not available”
- Only show:
  - Manual “Use this text” action.
  - Optional “Use current location” chip if GPS coordinates are available.

---

## 5. Frontend Integration

### 5.1 Service Layer

Introduce a small service, e.g. `LocationSuggestionService`, that:

- Wraps Supabase calls to `search-places`.
- Applies:
  - Debouncing at the caller level (or exposes a method suitable for debounced calls).
  - Simple error handling:
    - On error, log and return an empty list.

### 5.2 Picker Widget Changes

Tasks:

- Add a suggestions list under the search field:
  - Each row shows `displayName` and a secondary line (e.g. `city, country`).
- Ensure keyboard and focus behavior is friendly:
  - Scrolling suggestions does not hide the input.
  - Tapping a suggestion commits the value and dismisses the sheet.
- Keep the “Use this text” action clearly visible and distinct from suggestions.

---

## 6. Junior‑Friendly Task Breakdown

### Task Group A – Edge Function

1. **Create `search-places` Edge Function**
   - Define request/response schemas.
   - Call the geocoding API’s “search” or “forward geocoding” endpoint.
   - Map responses into the standard suggestion shape.
2. **Implement basic constraints**
   - Enforce max `limit`.
   - Reject very short queries (e.g. < 2–3 characters) to avoid noisy calls.

### Task Group B – App Service

1. **Implement `LocationSuggestionService`**
   - Single method, e.g. `Future<List<LocationSuggestion>> search(String query, {Location? bias})`.
   - Handles mapping from raw JSON into the `LocationSuggestion` model.
2. **Wire into the picker**
   - Add debounced calls tied to the text field’s `onChanged`.
   - Update suggestions list reactively.

### Task Group C – UI & Offline Handling

1. **Render suggestions list**
   - Show an empty state when there are no suggestions and no query.
   - Show an error or subtle state when suggestions fail (optional).
2. **Offline behavior**
   - Short‑circuit suggestion calls when offline (based on existing connectivity state).
   - Show the “Offline: suggestions not available” hint.

---

## 7. Acceptance Criteria

- When online and typing into the location picker:
  - Suggestions appear under the input after a short delay.
  - Selecting a suggestion sets a high‑quality label and structured location fields.
- When offline:
  - No suggestion calls are made.
  - The user is clearly informed suggestions are unavailable, but can still type and save text.
- Manual labels:
  - Users can always choose to “Use this text” instead of a suggestion.
  - Manual labels remain primary display text unless the user explicitly chooses a different place.


