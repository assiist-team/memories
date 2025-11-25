## Memory Edit Creates New “Untitled” Entry & Timeline Ignores Edits

**Date:** 2025-11-25  
**Status:** 🔴 Open – active regression after timeline update bus refactorR  

This doc tracks an issue where **editing an existing memory** (e.g., “Spring Cleaning”) results in:

- **Issue A:** After saving and returning to the **Unified Timeline**, the edited memory’s **thumbnail and metadata do not update** (still shows old placeholder image / missing media).  
- **Issue B:** After performing a **manual refresh**, a **new “Untitled” memory with no location** appears in the timeline, showing the **new image**, while the original entry remains.

From the user’s perspective:

- Edits feel like they “don’t stick” until a manual refresh.  
- Even after refresh, the presence of a new untitled entry with missing location looks like **data corruption / duplicate saves**.

---

## Update – 2025-11-25 (Investigation of Failed Fix)

**Status:** 🔴 Issue Persists

Attempted to fix by changing `CaptureStateNotifier` to `keepAlive: true` and regenerating providers.
The issue **persists even after hot restart** and verifying the `.g.dart` file change.

**Symptoms:**
- A new "Untitled" memory is still generated instead of updating the existing one.
- This implies `editingMemoryId` is still being cleared or lost *before* the save operation completes, or the logic in `_handleSave` is incorrectly falling through to the create path.

**Action Item:**
- Further investigation stopped per user request.
- This remains a high-priority regression.

---

## Update – 2025-11-25 (Root Cause Identified: Offline Queue Short-Circuit)

**Status:** 🔴 Confirmed regression inside capture save flow

### What We Found

- `_handleSave` now enqueues **every** capture (including edits) into the offline queue **before** it reaches the real `saveMemory` / `updateMemory` branch. When the widget is still mounted (normal case), this block shows the success checkmark, clears state, pops the screen, and returns early, so the update path is never executed.

```286:327:lib/screens/capture/capture_screen.dart
      // Step 3: Queue for offline sync if needed
      // MemorySyncService will automatically sync when connectivity is restored
      // This queues whenever uploads cannot proceed (offline or when upload service unavailable)
      try {
        final queueService = ref.read(offlineMemoryQueueServiceProvider);
        ...
        await queueService.enqueue(queuedMemory);

        if (mounted) {
          ...
          await notifier.clear(keepAudioIfQueued: true);
          ...
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
        return;
      }
```

- The queued payload does **not** retain `editingMemoryId`/`originalEditingMemoryId`, and `MemorySyncService` always processes entries by calling `saveService.saveMemory(...)` (create-only). This means every edit is replayed as a brand-new memory row once the sync service runs.

```134:158:lib/services/memory_sync_service.dart
        // Convert to CaptureState and save
        final state = queuedMemory.toCaptureState();
        final result = await _saveService.saveMemory(state: state);

        // Mark as completed and remove from queue
        await _queueService.update(
          queuedMemory.copyWith(
            status: 'completed',
            serverMemoryId: result.memoryId,
          ),
        );
        await _queueService.remove(queuedMemory.localId);
```

### Why This Explains Both Symptoms

- **Issue A (timeline never updates):** Because the actual `updateMemory` branch never runs, we never emit `MemoryTimelineUpdateBus.emitUpdated(...)`. The existing timeline card keeps stale media/location until the user manually refreshes.
- **Issue B (new “Untitled” entry):** The queued edit syncs as a fresh insert via `saveMemory`. `QueuedMemory.fromCaptureState` only stores bare `latitude/longitude` fields and never propagates the `_memoryLocationDataMap`, so the insert lacks `memory_location_data` and gets the fallback `Untitled Moment` title—exactly what we see in Supabase.
- **Danger:** Editing repeatedly will create one new row per attempt while the original row is never touched, so deleting the “extra” card risks wiping the user’s only copy with media.

### Immediate Actions

1. **Remove / gate** the unconditional queue block. Only enqueue when we truly cannot upload (e.g., `OfflineException`) and skip it entirely for server-backed edits.
2. Re-test the normal save path to ensure `_handleSave` reaches `saveService.updateMemory` and emits the update bus event.
3. (Follow-up) Decide how edits should behave when offline—currently there is no schema for queued edits, so we should block edits while offline rather than silently queuing creates.

Until that fix lands, advise users not to edit memories: every edit will silently create a duplicate untitled row and leave the original untouched.

---

## Update – 2025-11-26 (User Acceptance Requirement Clarified & Current Regression State)

**Status:** 🟡 Partial fix – duplicate creation resolved, new title regression discovered

### New Requirement (from user validation)

- When a user edits a memory **while offline**, the edited content must still appear in the timeline immediately. In other words, queueing an offline edit is acceptable, but the UI must reflect the changes locally right away (e.g., by updating/remapping the timeline entry that corresponds to the pending edit).

### Latest Test (2025-11-26)

- Scenario: Edit an existing memory with a custom title while online, then return to the timeline.
- Observed behaviour:
  - ✅ No duplicate “Untitled” entry appeared. The edit flowed through the update path and the timeline reflected the new media immediately.
  - ❌ The original memory’s title was wiped and replaced with **“Untitled Moment.”** The change also synchronized to the timeline right away, so the user saw the incorrect title immediately.
  - ⚠️ Subjective performance regression: saving now takes noticeably longer than before (though still completes). This is expected with the current guard because `_handleSave` now waits for the full Supabase upload/update call to complete whenever connectivity exists. Previously, every save short-circuited into the offline queue, so the UI dismissed immediately. We should call out that latency difference in future UX work, but no code change was made for it in this iteration.

-### Why the title regressed
-
- `MemorySaveService.updateMemory` unconditionally resets the `title` field to the fallback “Untitled {Type}” whenever the incoming `CaptureState` does not contain fresh text.
- For edits where the user already had a curated title but is only attaching media (no new text), `state.inputText` is still `null`, so the fallback overwrites the existing title every time.
- This was masked before because the update branch rarely executed (thanks to the queue short-circuit). Now that edits truly run through `updateMemory`, the fallback logic fires consistently.
- **Updated requirement:** If a memory already has a non-fallback title (anything other than “Untitled Moment/Memento/Story”), editing must preserve that title. Ordinary edits (media, tags, etc.) must never replace an existing curated title with the fallback unless we introduce a future explicit “regenerate title” action.

### Why saves feel slower now

- Because the unconditional queue block has been removed, `_handleSave` no longer “fire-and-forgets” into the offline queue when the device **is actually online**.
- The UI now waits for:
  1. `MemorySaveService` to upload any new media to Supabase Storage.
  2. The `memories` table update RPC to finish (including location JSON, media arrays, etc.).
- Media uploads dominate this latency, especially for multi-photo edits. Previously the save returned immediately regardless of media size because nothing was uploaded until the background sync ran.
- Net effect: the operation now reflects real network work, which is good for correctness but explains the slower perceived save.

---

## Resolution – 2025-11-25 (ATTEMPTED / FAILED)

### Previous Attempted Fix

1.  **Duplicate "Untitled" Entry (State Reset):**
    -   The `CaptureStateNotifier` was using the default `autoDispose` behavior.
    -   When navigating between tabs (Detail -> Capture), the notifier could be disposed and recreated if the Capture screen wasn't immediately watching it.
    -   This caused `editingMemoryId` to be lost. When saving, the system saw no ID and created a **new memory** ("Untitled") instead of updating the existing one.
    -   **Crucial Fix Step:** The initial attempt to fix this by adding `@Riverpod(keepAlive: true)` failed because the **code generation step (`build_runner`) was not run**. The generated `.g.dart` file still contained `AutoDisposeNotifierProvider`, so the fix was not active at runtime. Running `dart run build_runner build` updated the provider to `NotifierProvider` (persistent), resolving the issue.

2.  **Missing Location Data:**
    -   `CaptureStateNotifier` maintains a private `_memoryLocationDataMap` for full location details (city, state, country, source).
    -   Any manual updates to the location *label* (e.g., picking a suggestion) did not sync back to this map.
    -   When saving, the system prioritized this stale map, leading to data inconsistencies.
    -   **Fix:** Updated `setMemoryLocationLabel` and `getMemoryLocationDataForSave` to synchronize the map with the current state, ensuring saved data is consistent.

### Fix Implemented

1.  **State Persistence:**
    -   Changed `CaptureStateNotifier` to use `@Riverpod(keepAlive: true)`.
    -   ran `dart run build_runner build` to regenerate the provider definition as a persistent `NotifierProvider`.

2.  **Location Data Integrity:**
    -   Updated `setMemoryLocationLabel` to synchronously update `_memoryLocationDataMap`.
    -   Updated `getMemoryLocationDataForSave` to merge current state values into the map before returning.

### Verification

-   **Persistence:** `lib/providers/capture_state_provider.g.dart` now correctly defines `captureStateNotifierProvider` as a `NotifierProvider` (not `AutoDisposeNotifierProvider`).
-   **Behavior:** Editing a memory now correctly persists the `editingMemoryId` across navigation, resulting in an `update` operation rather than a `create` operation. The location data is also correctly preserved.

---

## Context – Recent Structural Change

This regression appeared immediately after implementing the **Memory Timeline Update Bus**:

- New provider: `memory_timeline_update_bus_provider.dart`:

```1:73:lib/providers/memory_timeline_update_bus_provider.dart
/// Provider for the memory timeline update bus
///
/// Kept alive so all parts of the app (timeline, capture, detail) share
/// a single global bus instance. This prevents events from being missed
/// due to provider disposal or separate instances per scope.
@Riverpod(keepAlive: true)
MemoryTimelineUpdateBus memoryTimelineUpdateBus(MemoryTimelineUpdateBusRef ref) {
  final bus = MemoryTimelineUpdateBus();
  ref.onDispose(() {
    bus.dispose();
  });
  return bus;
}
```

- `CaptureScreen` now **emits an updated event** instead of directly reaching into the unified feed:

```379:485:lib/screens/capture/capture_screen.dart
      // Step 3: Save or update memory with progress updates (or queue if offline)
      final saveService = ref.read(memorySaveServiceProvider);
      MemorySaveResult? result;
      final isEditing = finalState.isEditing;
      final editingMemoryId = finalState.editingMemoryId;
      ...
      if (isEditing && editingMemoryId != null) {
        // Update existing memory
        result = await saveService.updateMemory(
          memoryId: editingMemoryId,
          state: finalState,
          memoryLocationDataMap: memoryLocationDataMap,
        );
      } else {
        // Create new memory
        result = await saveService.saveMemory(
          state: finalState,
          memoryLocationDataMap: memoryLocationDataMap,
        );
      }
      ...
      if (mounted) {
        ...
        if (isEditing && editingMemoryId != null) {
          final memoryIdToRemove = editingMemoryId;

          // When editing, emit updated event so timeline can refresh with updated data
          final bus = ref.read(memoryTimelineUpdateBusProvider);
          bus.emitUpdated(memoryIdToRemove);

          // When editing, navigate back to detail screen
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          // Refresh detail screen to show updated content
          ref
              .read(memoryDetailNotifierProvider(memoryIdToRemove).notifier)
              .refresh();
        }
```

- `UnifiedFeedController` subscribes to the bus and currently:
  - On **updated**: removes the memory and reloads page 1.  
  - On **deleted**: removes the memory only.

```112:178:lib/providers/unified_feed_provider.dart
  StreamSubscription<MemoryTimelineEvent>? _timelineUpdateSub;
  ...
  @override
  UnifiedFeedViewState build([Set<MemoryType>? memoryTypeFilters]) {
    ...
    _setupTimelineUpdateBusListener();
    ref.onDispose(() {
      ...
      _timelineUpdateSub?.cancel();
      ...
    });
    return const UnifiedFeedViewState(state: UnifiedFeedState.initial);
  }
  ...
  void _setupTimelineUpdateBusListener() {
    final bus = ref.read(memoryTimelineUpdateBusProvider);

    _timelineUpdateSub?.cancel();
    _timelineUpdateSub = bus.stream.listen((event) {
      _handleTimelineUpdateEvent(event);
    });
  }

  Future<void> _handleTimelineUpdateEvent(MemoryTimelineEvent event) async {
    switch (event.type) {
      case MemoryTimelineEventType.updated:
        debugPrint(
            '[UnifiedFeedController] Handling updated event for memory: ${event.memoryId}');
        removeMemory(event.memoryId);
        // Attempt to refresh first page so edits are reflected immediately
        try {
          final connectivityService = ref.read(connectivityServiceProvider);
          final isOnline = await connectivityService.isOnline();
          if (isOnline &&
              (state.state == UnifiedFeedState.ready ||
                  state.state == UnifiedFeedState.empty)) {
            await _fetchPage(
              cursor: null,
              append: false,
              pageNumber: 1,
            );
          }
        } catch (e) {
          debugPrint(
              '[UnifiedFeedController] Error refreshing feed after update event: $e');
        }
        break;
      case MemoryTimelineEventType.deleted:
        debugPrint(
            '[UnifiedFeedController] Handling deleted event for memory: ${event.memoryId}');
        removeMemory(event.memoryId);
        break;
    }
  }
```

---

## Issue A – Edit Appears Ignored Until Manual Refresh

### Symptom

1. Open an existing memory (e.g. “Spring Cleaning”).  
2. Edit it in the capture flow (e.g. add a photo).  
3. Save, then navigate back to the **Unified Timeline**.

Observed behaviour:

- The card for that memory **still shows the old placeholder thumbnail / no media**.  
- Only after a **manual pull-to-refresh** does the new thumbnail appear.

### Likely Contributing Factors

- The edit path calls `updateMemory(...)` correctly, but the **timeline data is stale** until `_fetchPage(...)` runs.
- `_handleTimelineUpdateEvent` currently reloads **only the first page** with `cursor: null`:
  - If the edited memory is **not on page 1** under the current sort/cursor, the reload will not affect it.
  - If the current state is not `ready` / `empty` (e.g. `loading` or `paginationError`), the refresh block is skipped.
- Realtime subscription (`_handleMemoryUpdate`) also **removes** the old entry and relies on future pagination/refresh, which interacts with the bus behaviour in non-obvious ways.

**Net effect:** for some combinations of scroll position / filter state:

- The **bus event is processed**, but
- The **refetch does not include the edited memory**, so the user sees no visible change until they explicitly pull-to-refresh.

---

## Issue B – New “Untitled” Memory With No Location After Refresh

### Symptom

Continuing from Issue A:

1. After editing and returning to timeline, user sees **no visible change**.  
2. User performs a **manual refresh** of the feed.  
3. After refresh:
   - A **new “Untitled Moment/Memento/Story”** appears in the feed.  
   - That **new entry shows the newly added image**, but **has no location** set.  
   - The **original entry also remains**, leading to two visually related but distinct items.

### What the Database Shows Right Now (Confirmed)

Direct query of the `memories` table for the affected titles:

```1:40:db-snapshot
select id, title, input_text, memory_type, photo_urls, memory_location_data,
       created_at, updated_at
from public.memories
where title in ('Spring Cleaning', 'Untitled Moment')
order by updated_at desc;
```

Current result:

- `id = 383cc79e-83cb-4c44-ac9c-5bf0915ba3ac`  
  - `title = 'Untitled Moment'`  
  - `photo_urls = ['https://cgppebaekutbacvuaioa.supabase.co/storage/v1/object/public/memories-photos/5aeed2a7-26f9-40ac-a700-3a6da123f3b5/1764041555892_0.jpg']`  
  - `memory_location_data = null`  
  - `created_at = 2025-11-25 03:32:38.316208+00`  
  - `updated_at = 2025-11-25 03:32:38.59763+00`

- `id = cc9de90e-98d2-4cdc-bc63-8c5bb77f8ea9`  
  - `title = 'Spring Cleaning'`  
  - `photo_urls = []`  
  - `memory_location_data = { city: 'Seattle', state: 'WA', country: 'USA', source: 'manual_text_only', display_name: 'Seattle, WA' }`  
  - `created_at = 2025-03-22 13:00:00+00`  
  - `updated_at = 2025-11-25 02:36:50.763425+00`

**Conclusion from DB:**

- The edit flow **created a completely new memory row** (`Untitled Moment`) that owns the new `photo_urls`.  
- The original `Spring Cleaning` row still exists, with its **location intact but no photos**.  
- Deleting what looks like the “extra” card in the UI can therefore be dangerous: depending on which ID the delete path hits, it may:
  - Delete the **new Untitled row** (losing the photo), or  
  - Delete the **original Spring Cleaning row**, leaving only the Untitled + photo row.

This confirms the bug is not just a client-side duplication; it is causing **real data divergence** in `memories`.

### Hypotheses (Updated)

1. **Edit falling back to “create” path (confirmed by DB snapshot):**
   - In the edit flow, the ID we use to decide between `saveMemory(...)` and `updateMemory(...)` can still end up `null` or mismatched, causing the **create path** to run:

   ```379:410:lib/screens/capture/capture_screen.dart
   // Step 3: Save or update memory with progress updates (or queue if offline)
   final saveService = ref.read(memorySaveServiceProvider);
   MemorySaveResult? result;
   // Use originalEditingMemoryId as a safety net so that edits never
   // silently fall back to creating a new memory row.
   final effectiveEditingMemoryId =
       finalState.editingMemoryId ?? finalState.originalEditingMemoryId;
   final isEditing = effectiveEditingMemoryId != null;
   ...
   if (isEditing) {
     // Update existing memory
     result = await saveService.updateMemory(
       memoryId: effectiveEditingMemoryId!,
       state: finalState,
       memoryLocationDataMap: memoryLocationDataMap,
     );
   } else {
     // Create new memory
     result = await saveService.saveMemory(
       state: finalState,
       memoryLocationDataMap: memoryLocationDataMap,
     );
   }
   ```

   - Despite the `originalEditingMemoryId` safety net, real data shows we are **still entering the create branch** in at least some flows, producing:
     - A new row with `title = 'Untitled Moment'`.  
     - `photo_urls` set only on that new row.  
     - No `memory_location_data` on the new row.

2. **Location data not round-tripping on edit:**
   - `CaptureStateNotifier.loadMemoryForEdit(...)` is responsible for seeding location fields when editing:

   ```652:683:lib/providers/capture_state_provider.dart
   void loadMemoryForEdit({
     required String memoryId,
     required String captureType,
     String? inputText,
     List<String>? tags,
     double? latitude,
     double? longitude,
     String? locationStatus,
     List<String>? existingPhotoUrls,
     List<String>? existingVideoUrls,
     DateTime? memoryDate,
   }) {
     ...
     state = state.copyWith(
       editingMemoryId: memoryId,
       memoryType: memoryType,
       inputText: inputText,
       tags: tags ?? [],
       latitude: latitude,
       longitude: longitude,
       locationStatus: locationStatus,
       existingPhotoUrls: existingPhotoUrls ?? [],
       existingVideoUrls: existingVideoUrls ?? [],
       memoryDate: memoryDate,
       deletedPhotoUrls: const [],
       deletedVideoUrls: const [],
       hasUnsavedChanges: false,
     );
   }
   ```

   - Any path that **reloads or clears** capture state (e.g. calling `clear()` or failing to preserve `editingMemoryId`) before save will:
     - Lose location fields.  
     - Lose `editingMemoryId` → causing a **new memory with missing location** to be created.

3. **Timeline deduplication by `serverId` hides the relationship between the two rows:**
   - `TimelineMemory` distinguishes `id` vs `serverId`:

   ```11:83:lib/models/timeline_memory.dart
   final String id;
   ...
   final String? serverId;
   ...
   /// Effective ID for this memory - prefers serverId, falls back to localId, then id
   String get effectiveId => serverId ?? localId ?? id;
   ```

   - If the “edited” and “new untitled” rows share logic (e.g. same date/nearby timestamps) but have different IDs, they will appear as **distinct timeline memories**, with no UI cue that they’re really “versions” of the same conceptual event.

---

## Current Understanding & Risk

**What we know:**

- The **bus refactor** introduced a new code path for edit/delete invalidation.  
- The bus was initially **auto-disposed**, causing some events to never reach the feed; this has been fixed by making it a keep-alive provider.  
- Even with the global bus, the user can still hit the sequence:
  - Edit memory → no visible change on timeline → manual refresh → see new untitled entry with image + original entry.

**Risk:**

- High user confusion and distrust in data integrity:
  - It *looks* like editing creates a **second memory** instead of updating the existing one.  
  - Missing location on the new entry further suggests **data loss**.  
- Potential for **real data duplication** in `memories` if the edit path is indeed falling back to `saveMemory(...)`.

---

## Triage Checklist for This Issue

When this bug is observed (edit ignored until refresh, then new untitled entry appears), run:

### 1. Database: Check for Actual Duplicate Rows

Use Supabase (via MCP tools or SQL console) to inspect the affected memory:

- Identify both timeline entries by UI:
  - Original title (e.g. “Spring Cleaning”).  
  - New untitled entry with the same approximate date and new image.

- Query recent memories:

```sql
select id, user_id, title, input_text, memory_type, memory_date, captured_at,
       memory_location_data, created_at, updated_at
from public.memories
where user_id = '<current_user_id>'
order by created_at desc
limit 10;
```

Questions:

- Do we see **two distinct rows** that both plausibly correspond to “Spring Cleaning”?  
- Does the **newer row** have:
  - `title` = `Untitled ...`  
  - `memory_location_data` = `null` or missing fields?  

If yes → confirms the edit path sometimes **creates a new row** instead of updating.

### 2. CaptureState at Time of Save

Add temporary logging (if needed) around `_handleSave()` to dump:

- `finalState.isEditing`  
- `finalState.editingMemoryId`  
- `finalState.memoryDate`  
- `finalState.memoryLocationLabel` / coordinates  

Confirm:

- When user believes they are editing, is `isEditing == true` and `editingMemoryId != null` at save time?  
- After navigating from detail → capture → back → capture (or similar flows), does anything silently clear `editingMemoryId`?

### 3. Timeline Behaviour After Bus Event

Verify that the bus event is actually seen by `UnifiedFeedController`:

- Look for logs:

```text
[MemoryTimelineUpdateBus] Emitting updated event for memory: <id>
[UnifiedFeedController] Handling updated event for memory: <id>
```

If the first appears but the second does not, the bus wiring is still incorrect.  
If both appear, but the timeline card doesn’t change until manual refresh, focus on:

- Whether `_fetchPage(cursor: null, append: false, pageNumber: 1)` actually returns the edited memory under the current filters/cursor.  
- Whether the edited memory’s `primaryMedia` and location fields are correct in the RPC response.

---

## Next Steps / Fix Plan (High Level)

1. **Stop accidental “create instead of update” on edit:**
   - Add defensive checks in `_handleSave()`:
     - If capture was launched in edit mode (from `MemoryDetailScreen`), but `isEditing == false` at save time, **abort save** and surface an error instead of silently creating a new memory.
   - Ensure navigation flows never clear `editingMemoryId` before the user actually cancels or completes the edit.

2. **Make timeline refresh deterministic for edits:**
   - For `MemoryTimelineEventType.updated`, consider:
     - A targeted RPC `get_memory_by_id(memory_id)` to update that single entry in-place, **or**
     - A refresh strategy that guarantees the edited memory is included (e.g. by re-fetching around its `captured_at`).

3. **Location preservation:**
   - Ensure `loadMemoryForEdit` and `getMemoryLocationDataForSave` always:
     - Seed memory location fields from the detail model.  
     - Keep them intact through the entire edit session.
   - Add a regression test: editing a memory without touching location must **not** clear `memory_location_data`.

4. **Offline-edit timeline parity:**
   - When an edit is queued because the device is offline, immediately reflect that pending edit in the timeline (same requirement reiterated above). Either mutate the existing `TimelineMemory` in-place or layer a temporary “pending edit” version so users can confirm their change without reconnecting.

5. **Preserve curated titles during edits:**
   - Update `MemorySaveService.updateMemory` so it **only** writes the fallback “Untitled {Type}” when a memory truly lacks any user-facing title.
   - If the existing title is already non-fallback, leave it untouched regardless of other edit operations, unless we later add an explicit regenerate-title flow.

Until these are implemented and verified, treat this as a **known regression** and avoid heavy use of edit for production data.