## Location not showing on memory cards and detail (online + offline)

### Summary

- **Symptom**: Location is correctly detected on the capture screen but **does not show** on:
  - Timeline memory cards (Story/Moment/Memento)
  - Memory detail screen metadata section
- **Scope**:
  - Affects **online detail when served from cache** and
  - **offline/queued memories** in both the timeline and detail.
- **Data integrity**: `memories.memory_location_data` in Postgres is **populated and correct** (e.g. memory `4814b636-994d-463a-bf4d-bf521af6d99f` shows a full JSON payload with `display_name`, `city`, `state`, `country`, `latitude`, `longitude`, `provider`, `source`).
- **Root cause**: We drop `memory_location_data` in several client‑side layers (caching and offline adapters), so the UI models never see it and the location row is skipped.

---

### Symptoms

- **Capture screen**
  - GPS auto‑detection works, reverse geocoding resolves a place name (e.g. "Kailua, Hawaii, United States").
  - Location chips / labels appear as expected while capturing.

- **Timeline cards (online)**
  - For some memories, cards show no location row under the date, even though DB rows clearly have `memory_location_data.display_name`.
  - This affects supposedly "online" usage, but is tightly coupled to whether the card’s backing model came from the **online RPC**, the **preview index**, or the **offline queue**.

- **Memory detail screen**
  - The timestamp row renders, but the location row in `MemoryMetadataSection` is missing.
  - Reproducible for IDs like `4814b636-994d-463a-bf4d-bf521af6d99f` even though that row’s `memory_location_data` is populated in Postgres.

---

### Architecture overview (relevant pieces)

- **DB / RPCs**
  - Table: `public.memories`
    - Column: `memory_location_data JSONB` (event location; distinct from `captured_location`).
  - RPC: `get_unified_timeline_feed` (timeline feed)
    - Returns column `memory_location_data JSONB` which is mapped into `TimelineMemory.memoryLocationData`.
  - RPC: `get_memory_detail` (detail view)
    - Returns column `memory_location_data JSONB` which is mapped into `MemoryDetail.memoryLocationData`.

- **Flutter models**
  - `TimelineMemory.memoryLocationData : MemoryLocationData?`
  - `MemoryDetail.memoryLocationData : MemoryLocationData?`
  - `MemoryLocationData.formattedLocation` prefers `display_name`, falling back to `city/state`.

- **UI components**
  - `StoryCard` / `MomentCard` / `MementoCard`
    - Show location row only when `memory.memoryLocationData?.formattedLocation != null`.
  - `MemoryMetadataSection`
    - Shows location row when either:
      - `memoryLocationLabel` (from `CaptureState` while editing) is non‑null, or
      - `memory.memoryLocationData?.formattedLocation` is non‑null.

---

### Data path from capture to DB

- **Capture**
  - `CaptureStateNotifier.captureLocation()` sets `latitude`/`longitude` and, if unset, `memoryLocationLatitude`/`memoryLocationLongitude`.
  - `CaptureStateNotifier.setMemoryLocationFromData(MemoryLocationData)` populates:
    - `state.memoryLocationLabel`, `state.memoryLocationLatitude`, `state.memoryLocationLongitude`, and
    - internal `_memoryLocationDataMap` used when saving.

- **Save / update**
  - `CaptureScreen` builds `memoryLocationDataMap` via:
    - `captureNotifier.getMemoryLocationDataForSave()`.
  - `MemorySaveService.saveMemory(...)` and `updateMemory(...)` write that map into `memories.memory_location_data`:
    - If `memoryLocationDataMap` is provided, it is used directly.
    - Otherwise, a minimal map is constructed from `memoryLocationLabel`/lat/lng.

- **Database state**
  - Verified via Supabase SQL:
    - Example row `4814b636-994d-463a-bf4d-bf521af6d99f` contains a full `memory_location_data` object with `display_name` and coordinates.

**Conclusion**: Capture and persistence are correct; the bug is entirely on how we hydrate and cache the Flutter models.

---

### Root causes (by code path)

#### 1. Online memory detail served from cache drops `memory_location_data`

- **Where**: `MemoryDetailService` (`lib/services/memory_detail_service.dart`)

- **Network path (correct)**
  - `getMemoryDetail(id, preferCache: false)`:
    - Calls `get_memory_detail` RPC.
    - `MemoryDetail.fromJson` maps `json['memory_location_data']` into `MemoryDetail.memoryLocationData`.
    - `MemoryMetadataSection` then sees a non‑null `memoryLocationData` and can show the location row.

- **Cache path (broken)**
  - `_cacheMemoryDetail(String memoryId, MemoryDetail memory)` serializes a subset of fields into SharedPreferences.
  - **The serialized JSON includes `location_data` but does not include `memory_location_data`.**
  - On a later call where we:
    - Are offline (`isOnline == false`), or
    - Hit a network error and fall back to cache,
    - `_getCachedMemoryDetail` reads the JSON and passes it into `MemoryDetail.fromJson(...)`, but since the JSON has no `memory_location_data` key, `MemoryDetail.memoryLocationData` is `null`.
  - `MemoryMetadataSection` then evaluates:

    - `hasLocation = memoryLocationLabel != null || memory.memoryLocationData?.formattedLocation != null;`

    and finds **no location**, so it omits the location row entirely.

- **Impact**
  - Any time detail is served from the **SharedPreferences cache** (offline, or after a transient RPC failure), the event‑location vanishes from the detail screen, even though the DB row is correct.
  - This is why a fully online memory like `4814b636-994d-463a-bf4d-bf521af6d99f` can appear to "have no location" in the UI if the app happened to use cached detail instead of fresh RPC data.

#### 2. Offline queued memories never propagate `memoryLocationData` into timeline models

- **Where**:
  - `QueuedMemory` (`lib/models/queued_memory.dart`)
  - `OfflineQueueToTimelineAdapter` (`lib/services/offline_queue_to_timeline_adapter.dart`)

- **Queued data (correct)**
  - `QueuedMemory.fromCaptureState(...)` stores `memoryLocationData` from capture:
    - Field: `QueuedMemory.memoryLocationData : Map<String, dynamic>?`.

- **Adapter to timeline (broken)**
  - `OfflineQueueToTimelineAdapter.fromQueuedMemory(QueuedMemory queued)` builds a `TimelineMemory` but **never sets `memoryLocationData`**:

    - It fills `title`, `snippetText`, `primaryMedia`, `capturedAt`, etc.
    - All offline queued cards thus end up with `TimelineMemory.memoryLocationData == null`.

- **Impact**
  - For queued memories rendered in the unified timeline while offline:
    - `StoryCard` / `MomentCard` / `MementoCard` see `memory.memoryLocationData == null` and skip the location row.
  - The data is present in `QueuedMemory`, but never exposed in the card model.

#### 3. Offline detail for queued memories does not map `memoryLocationData` into `MemoryDetail`

- **Where**:
  - `OfflineMemoryDetailNotifier` (`lib/providers/offline_memory_detail_provider.dart`)

- **Current behavior**
  - `_toDetailFromQueuedMemory(QueuedMemory queued)` builds:
    - `LocationData` from `queued.latitude/longitude/locationStatus` and assigns it to `MemoryDetail.locationData` (captured GPS location).
    - **It never maps `queued.memoryLocationData` into `MemoryDetail.memoryLocationData`.**
  - `MemoryMetadataSection` ignores `locationData` and only uses:
    - `memoryLocationLabel` (when editing) or
    - `memory.memoryLocationData?.formattedLocation`.

- **Impact**
  - The offline detail view for queued memories also lacks an event‑location row, even though `QueuedMemory.memoryLocationData` holds it.

---

### Why this shows up "in online mode"

- The app decides whether to **prefer cache** based on `ConnectivityService.isOnline()`.
- If `isOnline` is false (or flaky), or if the RPC throws an error, `MemoryDetailService.getMemoryDetail` will fall back to:
  - `_getCachedMemoryDetail` (SharedPreferences path), or
  - `_getMemoryDetailFromPreviewStore` (text‑only preview path).
- Both these fallback paths currently **omit** `memory_location_data` from the serialized JSON, so `MemoryDetail.memoryLocationData` ends up null, and the UI hides location.
- From the user’s perspective, this is indistinguishable from a normal online session; they just see "no location" even though the DB row is correct.

---

### Fix sketch (not implemented here)

> Note: This section is a design outline only; actual code changes are out of scope for this troubleshooting doc.

- **Fix 1: Include `memory_location_data` in the detail cache**
  - In `_cacheMemoryDetail`, add `memory.memoryLocationData?.toJson()` under a `memory_location_data` key.
  - In `_getCachedMemoryDetail`, ensure that JSON is passed through so `MemoryDetail.fromJson` can hydrate `memoryLocationData` correctly.

- **Fix 2: Propagate `memoryLocationData` from `QueuedMemory` into `TimelineMemory`**
  - In `OfflineQueueToTimelineAdapter.fromQueuedMemory`, map `queued.memoryLocationData` into `TimelineMemory.memoryLocationData` (via `MemoryLocationData.fromJson`) so cards can display a location row offline.

- **Fix 3: Map queued `memoryLocationData` into offline `MemoryDetail`**
  - In `_toDetailFromQueuedMemory`, construct a `MemoryLocationData` from `queued.memoryLocationData` and assign it to `MemoryDetail.memoryLocationData`, so `MemoryMetadataSection` can render the event‑location row even in offline detail.

---

### Quick sanity checks when debugging this again

- **DB sanity**
  - Run a Supabase SQL query to verify the row:
    - `select id, memory_type, memory_location_data from public.memories order by created_at desc limit 10;`
  - Confirm `memory_location_data.display_name` is non‑null for the test ID.

- **Model sanity (online)**
  - Add temporary logging in `MemoryDetail.fromJson` and `TimelineMemory.fromJson` to print `memoryLocationData?.formattedLocation` for a known ID.
  - If this is non‑null, the bug is in **caching/adapters/UI**; if null, the bug is either in the RPC or the save pipeline.

- **Model sanity (offline / queued)**
  - Log `QueuedMemory.memoryLocationData` when enqueuing and when adapting to `TimelineMemory` and `MemoryDetail`.
  - If it’s present on the queue object but absent on `TimelineMemory`/`MemoryDetail`, you’ve reproduced the adapter mapping bug described above.
