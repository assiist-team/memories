# Phase 1 – Location Picker UI & Manual Labels (No External Geocoder)

**Status**: Not started  
**Owner**: TBD  
**Depends on**: Existing date picker UX in capture + memory detail screens  

---

## 1. Goal

Introduce a **memory location row and picker** on the capture and memory detail screens that:

- Mirrors the interaction pattern of the **date picker**.
- Uses existing GPS capture (`GeolocationService`) as a **convenience suggestion only**.
- Allows users to **manually enter or edit** the **memory location** (where the event happened).
- Stores a clear, user‑facing `displayName` for the memory location, even without any reverse geocoding.

No external geocoding APIs or Supabase Edge Functions are used in this phase.

---

## 2. Scope

Included:

- Capture screen:
  - New **location metadata row** (parallel to the existing date row).
  - New **location picker** modal/bottom sheet.
  - Integration with `CaptureState` so that chosen labels + coordinates are persisted.
- Memory detail screen:
  - Location row display (using stored label when available).
  - Tapping into the same picker to edit the location.
- Data model:
  - Introduce a user‑visible `displayName` / `label` field for location on the app side.

Not included:

- Reverse geocoding.
- Typeahead suggestions / autocomplete.
- Backend schema changes and Edge Functions (planned in later phases).

---

## 3. UX Details

### 3.1 Capture Screen – Memory Location Row

**Reference**: Use the existing **date picker row in the capture screen** as a model for:

- Placement (full‑width row above the swipeable input container).
- Visual style (icon, label text, value text, chevron/edit icon).
- Interaction (tap opens picker; row reflects current selection).

**States & copy suggestions (for memory location)**:

- **Initial / detecting**:
  - Label: `Location`
  - Value: `Detecting current location…` (or similar).
- **GPS success, but no memory location label yet**:
  - Value: `Use current location` or similar (tap to confirm or edit into a more precise memory location).
- **Permission denied / services disabled**:
  - Value: `Unavailable (tap to set)`.
- **User‑selected/edited**:
  - Value: the stored `displayName` (e.g. `Grandma’s house`, `Brooklyn, NY`).

Implementation tip for juniors:

- Start by **copying the date row widget pattern** (without reusing code).
- Replace date‑specific text and icons with location equivalents.
- Connect the row’s displayed value to a new field in `CaptureState` (see Section 4).

### 3.2 Memory Location Picker Modal / Bottom Sheet

Initial (Phase 1) behavior:

- **Search / input field** (for memory location):
  - Always present, labeled “Search for a place or type one in…”.
  - In Phase 1, it behaves as a **plain text field** (no suggestions yet).
- **Current location section** (optional, as a suggestion):
  - If we have `latitude`/`longitude` from GPS:
    - Show a row: `Use current location` (possibly with a small “from GPS” note).
    - Selecting this sets a default label (e.g. `Current location`) and keeps coords.
- **Manual entry confirmation**:
  - Primary action label: **“Save location”**.
  - Whatever text is currently in the input field (typed by the user or filled from GPS defaults) becomes the location label.
  - If there is no GPS data or the user doesn’t choose “Use current location”:
    - We still store the manual label; coordinates may or may not be present from GPS capture.

Dismissal:

- “Cancel” or tapping outside the sheet should discard changes.
- “Save location” should update `CaptureState` and close the sheet.

### 3.3 Memory Detail Screen

**Reference**: Use the **date field in `MemoryDetail`** as a model:

- Show a row in `MemoryMetadataSection` when a location label exists.
- Use the same pattern for:
  - Left icon (location pin).
  - Label text.
  - Value text.
  - Tap target and semantics.

Behavior:

- If a `displayName` exists, show it.
- If we only have coordinates (no label), Phase 1 can:
  - Either hide the row, or
  - Show a generic `Current location` label that can be edited.
- Tapping the row opens the same location picker as the capture screen, but:
  - Uses a service such as `MemoryDetailService` to persist the updated value.

---

## 4. Data Model Changes (App Side Only)

### 4.1 Memory Location Model (App Side)

Define or extend a model to represent **memory location** (separate from capture location), e.g. using `LocationData`:

- `displayName: String?`
  - The user‑visible label used in UI (e.g. `"Grandma's house"`, `"Brooklyn, NY"`).
- `latitude: double?` / `longitude: double?`
  - Optional coordinates for where the memory happened (may come from GPS suggestion or manual choice later).

In Phase 1, **`displayName` is the primary way to render memory location in UI**; coordinates are optional.

### 4.2 Capture State and Save Flow

- **CaptureState**
  - Introduce a new field such as `memoryLocationLabel: String?` (name can be finalized when implementing).
  - Ensure `copyWith` and serialization preserve it.

- **CaptureStateNotifier**
  - Add methods like:
    - `setMemoryLocationLabel(String? label)`
  - Wire these to:
    - The memory location picker’s save actions.
    - Any GPS‑based defaulting (e.g. prefill a label based on capture location if desired).

- **MemorySaveService**
  - For Phase 1, keep things simple:
    - Continue writing only `captured_location` and `location_status` as today (capture metadata).
    - Keep **memory location** (label + optional coords) as **client‑side only** for now.
  - Persisting memory location to the DB is deferred to Phase 2 when the schema is updated with a single `memory_location JSONB` field.

---

## 5. Junior‑Friendly Task Breakdown

### Task Group A – Capture Screen UI

1. **Add location row to capture screen**
   - Clone the date row pattern (layout + tap behavior).
   - Hard‑code text values initially, then wire to state.
2. **Connect row to `CaptureState`**
   - Add a new field for the location label.
   - Show different strings depending on label and GPS status.

### Task Group B – Location Picker UI

1. **Create location picker bottom sheet**
   - Reuse modal patterns already used by the date picker entry.
   - Add a text field with placeholder.
2. **Hook picker up to `CaptureStateNotifier`**
   - On save, call methods to update location label (and possibly coordinates).
   - On cancel, discard changes.

### Task Group C – Memory Detail Integration

1. **Display location in `MemoryMetadataSection`**
   - Add a new row with an icon and text, similar to the date row.
   - Hide the row when there is no label.
2. **Enable editing from detail view**
   - Wire tap to open the same location picker.
   - On save, call a new `MemoryDetailService` method (e.g. `updateMemoryLocation`).
   - Handle loading and error states similarly to `updateMemoryDate`.

---

## 6. Acceptance Criteria

- Capture screen shows a location row above the input area.
- Tapping the row opens a picker where:
  - The user can type a location label.
  - The user can choose to keep or clear the label.
- When saving a memory:
  - The location label is stored in app state and appears in memory detail.
  - GPS coordinates and `locationStatus` continue to be captured as before.
- Memory detail:
  - Shows the location label when present.
  - Allows editing via the same picker, with changes persisted correctly.


