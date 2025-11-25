# Location Capture & Picker – Master Plan

**Last Updated**: 2025-11-25  
**Owner**: Core team  

---

## 1. Status

- **Overall Feature**: Planned
- **Phase 1 – Location row + picker UI, manual labels only**: Not started
- **Phase 2 – Reverse geocoding for current location**: Not started
- **Phase 3 – Location typeahead suggestions**: Not started

We will track high‑level status here; detailed implementation notes and task breakdowns live in the phase‑specific docs in this folder.

---

## 2. Objectives

- **Model the right thing**: Introduce a clear **memory location** concept that represents **where the memory actually happened**, distinct from **capture location** (where the phone was when we recorded it).
- **Human‑readable locations**: Show meaningful place names (e.g. “Brooklyn, NY”, “Grandma’s house”) for the memory location instead of raw coordinates.
- **Capture parity with date**: Add a **location row + picker** to the capture screen that behaves similarly to the **date picker**:
  - Always visible as a tappable metadata row.
  - Prefills from current context (GPS where possible) as a suggestion, not as the only truth.
  - Allows explicit user editing of the **memory location**.
- **Offline‑first**: Work gracefully when:
  - Location permission is denied.
  - GPS is disabled/unavailable.
  - Network is offline (no reverse geocoding / suggestions).
- **Future‑proof but simple**: Start with **one JSONB field for memory location metadata** plus the existing `captured_location`:
  - Later background enrichment (reverse geocode existing coordinates) is possible.
  - Future spatial querying on **memory location** can be added with a single new geography field if/when we actually need it.

---

## 3. High‑Level Architecture

- **Capture layer (existing)**:
  - Uses `GeolocationService` + `CaptureState.latitude/longitude/locationStatus` to track **capture location** (where the phone is).
  - Called on save via `CaptureStateNotifier.captureLocation()` in `capture_screen.dart`.

- **New layers to add (for memory location)**:
  - **Location Picker UI** (capture + detail screens)
    - Capture: full‑width “Location” row mirroring the existing **date row** semantics.
    - Detail: editable location row in metadata section, similar to the **date edit** behavior.
  - **Memory location data model**
    - A single **memory location metadata** object that contains a label and optional coordinates.
    - Stored in a **JSONB field on `memories`** named `memory_location`, not in multiple columns.
  - **Reverse Geocoding Service**
    - **Phase 1**: UX + manual labels only (no external calls).
    - **Phase 2**: Supabase Edge Function for reverse geocoding (lat/long → `city/state/display_name`).
    - **Phase 3**: Typeahead suggestions (text → suggested places with coords).

- **Data model (app side)**
  - Extend existing `LocationData` (or introduce a `MemoryLocation` type) with:
    - **`displayName` / `label`**: what we actually show in UI (“Brooklyn, NY”, “Grandma’s house”).
    - Optional `latitude` / `longitude` for **memory location** (distinct from capture coordinates).
    - Optional **`source` enum** (e.g. `gps_suggestion`, `manual_text_only`, `manual_with_suggestion`).

---

## 4. UX Summary

### 4.1 Capture Screen Location Row

- **Placement**
  - Below the media/tags container.
  - Above the swipeable input container, parallel to the date row.
- **Row content**
  - Label: `Location`.
  - Value: varies by state (detecting, unavailable, manual label, reverse‑geocoded label).
  - Affordance: Chevron or edit icon consistent with the capture screen date picker row.

**Key states:**

- Detecting: `Location: Detecting current location…`
- GPS + reverse geocode success: `Location: Brooklyn, NY`
- GPS success, reverse geocode pending/failed: `Location: Current location`
- Permission denied / services disabled: `Location: Unavailable (tap to set)`
- Manually set: `Location: Grandma’s house`

Tapping always opens the **location picker modal/bottom sheet**.

### 4.2 Location Picker Modal / Bottom Sheet

Core elements:

- **Search/input field** (always present)
  - Placeholder: “Search for a place or type one in…”
  - Allows arbitrary manual text at all times.
- **Current location section** (when we have `latitude/longitude`)
  - Online + reverse geocoded: `Use current location — Brooklyn, NY`
  - Offline / geocode failed: `Use current location — coordinates only`
- **Suggestions list (online only, Phase 3)**
  - Typeahead based on user text.
  - Selecting a suggestion writes the suggestion label into the text field and sets coordinates and optional components.
- **Manual entry confirmation**
  - Primary action: **“Save location”**.
  - Whatever text is currently in the input (typed by the user or filled from a suggestion) is saved as the `displayName`, even if no coordinates are resolved.

Offline behavior:

- GPS works but offline:
  - Show “Use current location (no network for place name)” option.
  - No suggestions; show an inline “Offline: suggestions not available” hint.
- GPS fails and offline:
  - No current location option.
  - Picker is purely a free‑text form with a single confirm action (**“Save location”**) that saves the current input as the label.

### 4.3 Memory Detail Screen

- **Display**
  - Show a location row when either:
    - `displayName` is present, or
    - `formattedLocation` from `city/state` is present.
  - Priority:
    - Prefer `displayName` when set.
    - Fall back to `formattedLocation` otherwise (e.g. “Brooklyn, NY”).

- **Editing**
  - Tapping opens the same location picker as the capture screen.
  - Mirrors the date editing pattern in the detail screen:
    - Shows loading state when updating.
    - Validates connectivity and handles offline errors cleanly.

---

## 5. Data & API Summary

### 5.1 App‑Side Model

- **Capture location** (existing):
  - Tracked via `CaptureState.latitude`, `CaptureState.longitude`, and `locationStatus`.
  - Represents where the phone is when capturing the memory.

- **Memory location** (new):
  - Represented by a `MemoryLocation` / `LocationData` object with:
    - `displayName: String?` – the string to show in UI (“Brooklyn, NY”, “Grandma’s house”).
    - `latitude: double?` / `longitude: double?` – coordinates for where the memory happened (optional).
    - Optional `city`, `state`, `country` if the provider returns them.
    - Optional `source: String?` – e.g. `gps_suggestion`, `manual_text_only`, `manual_with_suggestion`.

In the UI, **memory location** is what is rendered in the metadata section and edited via the picker.

### 5.2 Backend Schema / RPC

- Keep existing (capture metadata):
  - `captured_location` (geography) on `memories` – where capture occurred.
  - `location_status` on `memories` – permission / availability status for capture.

- Add one simple JSONB field for **memory location**:
  - `memory_location JSONB` on `memories`, containing:
    - `display_name`, `latitude`, `longitude`, and optional `city`, `state`, `country`, `source`, `provider`.

`get_memory_detail`:

- Should return **memory location** separately from capture metadata, e.g.:
  - `memory_location` JSON with:
    - `display_name`, `latitude`, `longitude`, optional `city`, `state`, `country`, `source`.
  - Optionally still include capture metadata if needed for debugging/analytics.

### 5.3 Edge Functions

- **Reverse geocoding (Phase 2)**
  - Input: `{ latitude, longitude }` for a memory location candidate.
  - Output: `{ city, state, country, display_name }`.
  - Calls an external geocoding provider, with optional coordinate rounding for privacy.

- **Forward geocoding / suggestions (Phase 3)**
  - Input: `{ query, limit, maybe userLocation }`.
  - Output: `[{ display_name, latitude, longitude, city, state, country }, …]`.
  - Used by the picker for typeahead suggestions to populate the **memory location** field.

---

## 6. Behavior & Edge Cases

- **Permissions**
  - If location permission is denied:
    - Set `locationStatus = 'denied'`.
    - Do not re‑request automatically.
    - Still allow manual text entry in the picker.

- **Offline**
  - GPS capture is best‑effort and may work offline.
  - No reverse geocoding or suggestions:
    - Still capture `latitude/longitude` and `locationStatus`.
    - Expose “current coordinates” options where appropriate.
    - Rely on manual labels for user‑visible text.

- **Manual vs auto labels**
  - When a user explicitly types a label and saves it:
    - Never overwrite it automatically with geocoded labels.
    - We may enrich `city/state`/coords behind the scenes if missing, but `displayName` remains user‑provided until the user chooses something else.

---

## 7. Phased Implementation

Implementation details and junior‑friendly task breakdowns live in separate docs:

- **Phase 1 – Location row + picker UI, manual labels only**
  - See: `phase-1-location-picker-ui-and-manual-labels.md`
- **Phase 2 – Reverse geocoding for current location**
  - See: `phase-2-reverse-geocoding-edge-function.md`
- **Phase 3 – Location typeahead suggestions**
  - See: `phase-3-location-typeahead-suggestions.md`

This master document should stay relatively high‑level and status‑focused, with deep technical details in each phase doc.

---

## 8. Future Considerations: On‑Device Reverse Geocoding

We’ve intentionally chosen a **Supabase Edge Function + third‑party geocoder** approach as the primary path for reverse geocoding (Phase 2), but an **on‑device reverse geocoding** strategy remains an attractive future option:

- **Why it’s interesting**
  - **Privacy**: Coordinates never leave the device; no third‑party API sees user locations.
  - **Latency & resilience**: Local lookups could be faster and more predictable, especially on poor networks.
  - **Offline behavior**: With the right data or platform APIs, we might still resolve basic place names even when the user is offline.

- **Challenges & tradeoffs**
  - **Platform differences**: iOS and Android expose different geocoding APIs and quality; we’d likely need a plugin wrapper and platform‑specific behavior.
  - **Data freshness & coverage**: Relying solely on system geocoders may lead to inconsistent results across devices and OS versions.
  - **Complexity**: Adds another code path to test and maintain (on‑device vs. Edge Function), including potential divergence in results.

- **How we might combine both in the future**
  - Use **on‑device geocoding as a first attempt**:
    - Fast, private lookup for a basic label (e.g. “Brooklyn, NY”).
  - Fall back to **Edge Function** when:
    - The device geocoder fails or times out.
    - We want richer metadata (e.g. stable IDs, categories) that the on‑device API doesn’t provide.
  - Continue to treat **user‑entered labels as authoritative**, regardless of where the underlying place data comes from.

For now, we will **not** implement on‑device reverse geocoding and will focus on the Edge Function path, but this section documents it as a viable future enhancement if we want stronger privacy, better offline behavior, or reduced dependency on external APIs.


