## Capture Screen Location Auto‑Detection and Display (2025‑12‑02)

### Summary

- **Problem**: When capturing a new memory, the app successfully obtains GPS coordinates and sets `location_status = "granted"`, but:
  - `captured_location` is stored as a raw point only.
  - `memory_location_data` (the human‑readable “where this happened” field) is not populated unless the user manually interacts with the location picker.
  - The capture UI shows **“Use current location”**, which implies a required user action instead of reflecting an automatic default.
- **Impact**: Most memories with successful GPS capture end up with **no visible location** in detail/timeline views unless the user manually sets a memory location. This contradicts the desired behavior that **current location should be used automatically when available**, and manual selection should only be a backup/override.

### Current Behavior (As Observed)

- **GeolocationService**
  - On capture screen load or save, `GeolocationService`:
    - Requests permission.
    - Obtains a valid position (lat/lng) when permitted.
    - Logs:
      - `Location services enabled: true`
      - `Current permission status: LocationPermission.whileInUse`
      - `Successfully obtained position: lat=..., lng=...`
      - `Final status: granted`
  - `CaptureStateNotifier.captureLocation()` then copies that into:
    - `state.latitude`
    - `state.longitude`
    - `state.locationStatus = "granted"` (or `"denied"` / `"unavailable"`).

- **Saving the memory**
  - `CaptureScreen` calls `notifier.captureLocation()` then passes the final `CaptureState` into `MemorySaveService.saveMemory`.
  - `MemorySaveService` persists:
    - `captured_location` from `state.latitude/longitude` as PostGIS `POINT(lng lat)`.
    - `location_status` from `state.locationStatus`.
  - `memory_location_data` is **only** sent when:
    - `captureNotifier.getMemoryLocationDataForSave()` returns a map; or
    - At least one of `state.memoryLocationLabel`, `state.memoryLocationLatitude`, `state.memoryLocationLongitude` is non‑null (fallback minimal map).
  - Those `memoryLocation*` fields are only set when the **location picker UI** is used (`setMemoryLocationLabel` / `setMemoryLocationFromData`), not from raw GPS capture.

- **Display in UI**
  - Timeline/detail cards render location using `memoryLocationData.formattedLocation`.
  - If `memory_location_data` is `NULL`, nothing is shown for location, even when:
    - GPS was captured successfully.
    - `captured_location` and `location_status = "granted"` are present in the DB.
  - The capture screen row text currently shows states such as:
    - `"Use current location"` when `locationStatus == "granted"` and no label is set.
    - `"Location unavailable (tap to set)"` for denied/unavailable/unknown.

### Desired Behavior

- **Default behavior**:
  - When GPS capture succeeds (`locationStatus == "granted"` and we have lat/lng), the app should:
    - **Automatically treat that as “use current location”**, without extra taps.
    - **Automatically populate `memory_location_data`** with a human‑readable name derived from those coordinates (via reverse geocoding), with an appropriate `source` (e.g., `'gps_auto'`).
  - Manual selection via the location picker should be:
    - A **backup/override** (e.g., “This actually happened at Grandma’s house”), not a requirement to see *any* location.

- **UI expectations**:
  - The user should typically see a concrete place name (e.g., **“Hilo, HI”**) or similar, not generic text like “Use current location”.
  - The location row should:
    - Show a **“Detecting location…”** state briefly after capture while reverse geocoding runs.
    - Then show the resolved human‑readable location as the row text.
    - Only prompt for explicit action when:
      - Location services are unavailable/denied, or
      - The user wants to correct/override the automatically detected location.

### Proposed Fix (High‑Level)

#### 1. Treat GPS as the default memory location

- **Principle**:
  - `captured_location` (raw GPS) and `memory_location_data` (display + structured info) should stay conceptually distinct, but:
    - When GPS capture succeeds, **`memory_location_data` should automatically derive from that GPS** unless/until the user overrides it manually.

- **Implementation direction**:
  - In `CaptureStateNotifier.captureLocation()`:
    - After successfully obtaining `position` and `status == "granted"`:
      - Set `state.latitude` / `state.longitude` / `state.locationStatus` as today.
      - Also set initial memory location coordinates, e.g. either:
        - `state.memoryLocationLatitude` / `state.memoryLocationLongitude`, or
        - Call `setMemoryLocationLabel(label: null, latitude: position.latitude, longitude: position.longitude)` to seed the memory‑location layer.

#### 2. Auto reverse‑geocode after GPS capture (when online)

- **Trigger**:
  - As soon as GPS capture succeeds and we know we are online, kick off a **non‑blocking** call to the `reverse-geocode-location` edge function.
  - This can be done either:
    - Directly inside `captureLocation()`; or
    - Via a follow‑up call like `reverseGeocodeMemoryLocation()` that is invoked immediately after capture.

- **Behavior**:
  - If online:
    - Call `reverseGeocodeMemoryLocation()` with the current `memoryLocationLatitude/Longitude`.
    - On success:
      - Call `setMemoryLocationFromData(result)`, which:
        - Sets `memoryLocationLabel` to `displayName`.
        - Updates `memoryLocationLatitude/Longitude`.
        - Stores the full `memoryLocationData` map (including city/state/country/provider/source).
    - On failure/timeout:
      - Swallow the error and continue; do not block saving.
  - If offline:
    - Skip reverse geocoding.
    - Optionally allow manual entry/edit as the only way to create `memory_location_data`.

- **Save behavior**:
  - On save, keep the current contract:
    - `MemorySaveService.saveMemory` receives `memoryLocationDataMap` if available.
    - If `memoryLocationDataMap` is not yet populated (e.g., user saved very quickly or we were offline), we either:
      - Save without `memory_location_data` (current behavior), or
      - Optionally construct a minimal fallback map from `memoryLocationLabel/Latitude/Longitude`.
  - The save operation should **never be blocked** by reverse geocoding; it uses whatever data is ready when save is tapped.

#### 3. UX text and state updates in the capture screen

- **Location row text**:
  - Replace the “Use current location” language with states that reflect auto behavior:
    - When GPS just succeeded and reverse geocoding is running:
      - Show: **“Detecting location…”** (with small activity indicator).
    - When reverse geocoding completes and `memoryLocationData.formattedLocation` is available:
      - Show that resolved value directly (e.g., “Hilo, HI” or a more detailed display name).
    - When location is denied/unavailable:
      - Show something like: **“Location unavailable (tap to set)”**.

- **Bottom sheet / picker**:
  - Reframe the primary action as **“Change location”** or “Edit location” instead of “Use current location”.
  - If we already have an auto‑detected location:
    - Show it prominently as the current setting.
    - Let the user:
      - Pick from search results; or
      - Enter a custom label.
    - On any manual change, call `setMemoryLocationLabel` / `setMemoryLocationFromData` and set `source: 'manual_update'`.

#### 4. Scope and out‑of‑scope

- **In scope**:
  - App‑side behavior:
    - Auto‑propagation from GPS (`captured_location`) to memory location fields.
    - Background reverse geocoding when online.
    - UI text + state for “detecting” and “resolved” location.
  - Data consistency for new memories going forward.

- **Explicitly out of scope (for now)**:
  - Backfilling existing test data:
    - No need to run a migration or background job to backfill `memory_location_data` for current memories; we only care about new behavior from now on.
  - Forcing save to wait on reverse geocode:
    - Save remains independent; reverse geocoding is best‑effort and non‑blocking.

### Open Questions / Follow‑Ups

- **Display preferences**:
  - Should we always prefer a rich `display_name` (from reverse geocoding) over city/state, or fall back to a shorter “City, State” for readability on smaller screens?
- **Source tagging semantics**:
  - Proposed `source` values: `'gps_auto'`, `'gps_backfill'`, `'manual_update'`.
  - Do we want to surface this anywhere in analytics or debugging UIs?


