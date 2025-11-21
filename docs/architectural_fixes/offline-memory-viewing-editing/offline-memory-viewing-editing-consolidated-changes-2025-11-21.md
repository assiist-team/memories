## Offline Memory Viewing & Editing – Consolidated Change Plan (2025-11-21)

### 1. Purpose

This document consolidates:

- Findings from `review-findings-2025-11-21.md`.
- The flag/enum review in `offline-flags-audit-and-cleanup-plan.md`.
- The original implementation plan in `offline-memory-viewing-editing/README.md` and Phase 1–6 docs.

It describes **recommended changes to the implementation**, not the high-level product goals. The intent is to:

- Close the gaps between the planning docs and the shipped code.
- Clarify how offline/preview flags should be used.
- Make media handling, feed refresh, and deletion of queued items behave predictably.

---

### 2. Media Source Handling (Fixing Issue 1)

#### 2.1 Problem Summary

Today:

- `PrimaryMedia` / `PhotoMedia` / `VideoMedia` assume `url` is a Supabase storage path.
- Timeline/detail widgets always try to obtain a signed URL (`Image.network` / remote video) even when `url` points at a local file path populated by the offline detail provider.
- As a result, offline memories with local media fail to render, even though files exist.

This conflicts with the README decision that the adapter will **mark local media** so the UI can bypass Supabase and fall back to placeholders if files disappear.

#### 2.2 Data Model Changes

- **Extend media models with an explicit source indicator**:
  - `enum MediaSource { supabaseStorage, localFile }`
  - In `PrimaryMedia`, `PhotoMedia`, and `VideoMedia`, add:
    - `final MediaSource source;`
    - A convenience getter: `bool get isLocal => source == MediaSource.localFile;`
  - Keep `url` as a single field, but interpret it based on `source`:
    - `MediaSource.supabaseStorage` → `url` is the Supabase storage key.
    - `MediaSource.localFile` → `url` is an absolute file-system path or `file://` URL.

**Naming rule**: use explicit, self-explanatory names (`MediaSource`, `isLocal`) rather than overloading `url` semantics.

#### 2.3 Adapter Responsibilities

- **Offline queue/detail adapters** (`OfflineQueueToTimelineAdapter`, `OfflineMemoryDetailNotifier`) must:
  - Set `source: MediaSource.localFile` for any media created from queue paths.
  - Optionally normalize paths to `file://` form for clarity.
  - Return `null` for media whose file is missing, so card/detail widgets can fall back to text-only treatments.

- **Server-backed adapters / mappers** (from Supabase rows or RPCs) must:
  - Set `source: MediaSource.supabaseStorage`.
  - Preserve existing behaviour for online media loading.

#### 2.4 Widget Behaviour

Update all widgets that render primary media to branch on media source:

- `MomentCard`, `StoryCard`, `MementoCard`, `MediaStrip`, `MediaPreview`:
  - When `media.isLocal`:
    - Use `File(media.urlOrPath)` existence checks (stripping `file://` if necessary).
    - If the file exists:
      - Use `Image.file` for photos.
      - Use `VideoPlayerController.file` (or equivalent) for videos.
    - If the file is missing:
      - Render the existing “broken image” / placeholder UI.
    - **Do not** call `TimelineImageCacheService` or any Supabase storage APIs.
  - When `!media.isLocal`:
    - Keep the current Supabase signed-URL path.

This keeps the UI logic simple and self-evident:

- “Local” media → file-based widgets.
- “Remote” media → signed Supabase URLs.

#### 2.5 Tests

- Add widget tests that:
  - Inject a queued memory whose `PhotoMedia` / `VideoMedia` use `MediaSource.localFile` and valid local paths.
  - Assert that **offline** rendering uses `Image.file` / file-based video.
  - Assert that missing local files fall back to placeholders without network calls.

---

### 3. Offline Flags & Semantics (Aligning With the Audit)

The flag inventory from `offline-flags-audit-and-cleanup-plan.md` is broadly correct. This section clarifies their **intended usage** and how new code should consume them.

#### 3.1 Canonical Timeline Flags

On `TimelineMoment`:

- `bool isOfflineQueued`  
  - True when the entry is backed by a **local queue item** that has not yet been fully synced.
  - Implies:
    - Full local detail/editing is available **today**.
    - `localId != null`.
    - `offlineSyncStatus != OfflineSyncStatus.synced`.
- `bool isPreviewOnly`  
  - True when the entry comes only from the **preview index**:
    - Card can be shown in the timeline.
    - Full detail is **not available offline** (Phase 1).
  - In Phase 1, this is effectively:
    - `!isOfflineQueued && !isDetailCachedLocally`.
- `bool isDetailCachedLocally`  
  - True when the app has full local detail for this memory.
  - Phase 1:
    - Only queued offline memories satisfy this.
  - Phase 2:
    - May include server-backed memories the user has explicitly cached.
- `String? localId`  
  - Local identifier for queued entries.
- `String? serverId`  
  - Supabase ID for synced entries.
- `OfflineSyncStatus offlineSyncStatus` (`queued`, `syncing`, `failed`, `synced`)  
  - Describes sync-to-server lifecycle only.
- Convenience getters:
  - `String get effectiveId => serverId ?? localId ?? id;`
  - `bool get isAvailableOffline => isOfflineQueued || isDetailCachedLocally;`

**Guidance for new code**:

- When asking **“can I open this offline?”**, use `isAvailableOffline`, not bespoke combinations.
- When asking **“is this queued?”**, use `isOfflineQueued`, not `offlineSyncStatus != synced` alone.
- When asking **“is this preview-only?”**, prefer `isPreviewOnly` and avoid re-deriving the condition ad hoc.

#### 3.2 No Changes to Flag Storage Yet

- Do **not** change storage shape or remove flags as part of this pass.
- The audit’s questions about deriving `isPreviewOnly` or renaming `OfflineSyncStatus` remain valid but are **future cleanup** concerns.
- For now, the main change is to **standardize consumption**:
  - New UI and services should respect the semantics above.

---

### 4. Unified Feed & Queue Change Propagation (Fixing Issue 2)

#### 4.1 Problem Summary

- Offline saves enqueue memories but **only** invalidate a queue-status chip.
- The unified feed is updated only on:
  - initial load, manual refresh, or
  - later sync-completion events.
- As a result:
  - After capturing offline, the user returns to the timeline and sees no new card until a full refresh.
  - Editing a queued memory also does not immediately update the feed.

#### 4.2 Design Options

We want feed updates to be **reactive to queue mutations**, without overcomplicating the data flow. Two viable patterns:

- **A. Dedicated queue-change notifier** (preferred for clarity):
  - `OfflineQueueService` and `OfflineStoryQueueService` expose a `Stream<QueueChangeEvent>` or similar.
  - `UnifiedFeedController` listens and reacts.
- **B. Direct provider invalidation**:
  - Call `ref.invalidate(unifiedFeedControllerProvider)` after any queue mutation.

Both can work; Option A keeps queue semantics self-contained and is easier to extend. This plan assumes Option A but allows Option B as a fallback.

#### 4.3 Queue Change Events

- Introduce a small, explicit event type:

  - `enum QueueChangeType { added, updated, removed }`
  - `class QueueChangeEvent { final String localId; final MemoryType memoryType; final QueueChangeType type; }`

- `OfflineQueueService` and `OfflineStoryQueueService`:
  - Publish events on:
    - `enqueue(...)` → `QueueChangeType.added`
    - `update(...)` → `QueueChangeType.updated`
    - `remove(...)` → `QueueChangeType.removed`

**Naming rule**: keep the event names self-explanatory (`QueueChangeEvent`, `QueueChangeType`) and scoped to queue semantics.

#### 4.4 Unified Feed Reaction

- `UnifiedFeedController` subscribes to queue change streams:
  - When offline:
    - On `added` or `updated`:
      - Re-run `fetchMergedFeed` with the existing cursor and `isOnline: false`.
      - Replace `state.memories` with the new result (preserving filters).
    - On `removed`:
      - Remove any `TimelineMoment` whose `isOfflineQueued` and `localId` match.
  - When online:
    - On `added`:
      - Optionally insert/merge the new queued moment into `state.memories` using the adapter, or simply re-run `fetchMergedFeed`.
    - On `updated`:
      - Replace the corresponding `TimelineMoment` in-place or re-run `fetchMergedFeed`.
    - On `removed`:
      - Remove matching queued entries, similar to sync-completion behaviour.

If this proves too complex initially, the minimal acceptable behaviour is:

- Always re-run `fetchMergedFeed` on **any** queue change.

#### 4.5 Capture & Save Flows

- Remove the assumption that the timeline will update “on its own”:
  - Ensure `OfflineQueueService.enqueue` / `update` / `remove` are the single source of truth and always emit queue-change events.
- From `CaptureScreen` and `MemorySaveService`:
  - Do not manually manipulate feed state.
  - Rely on the queue-change notifier to drive everything.

#### 4.6 Tests

- Add provider/widget tests for `UnifiedFeedController`:
  - When a queued memory is enqueued, the timeline reflects it without manual refresh.
  - When a queued memory is updated, the card fields (title/snippet, badges) update.
  - When a queued memory is removed, the card disappears.

---

### 5. Deleting Queued Memories (Fixing Issue 3)

#### 5.1 Problem Summary

- The detail screen’s delete FAB always goes through the **online** detail provider.
- For queued memories:
  - `memoryId` is the **local** UUID.
  - Supabase delete calls therefore fail, and the queue entry is untouched.
  - The card reappears on next launch, and the user cannot actually delete queued content.

This violates the intended offline flow: **queued memories should be removable entirely locally.**

#### 5.2 Detail Screen Behaviour

- Extend the `MemoryDetailScreen` constructor to include:
  - `final bool isOfflineQueued;`
- For queued offline memories (`isOfflineQueued == true`):
  - **Delete**:
    - Route through a new queue-deletion path:
      - Determine which queue to use based on `MemoryType`.
      - Call:
        - `OfflineQueueService.remove(localId)` for moments/mementos.
        - `OfflineStoryQueueService.remove(localId)` for stories.
      - After successful removal:
        - Invalidate or refresh the unified feed (via the queue-change notifier).
    - Only use `memoryDetailNotifierProvider.deleteMemory()` for **synced**/server-backed memories.
  - **Optional UX**:
    - Show a confirmation dialog clarifying that deleting a queued memory discards unsynced content forever.

#### 5.3 Unified Feed On Deletion

- Rely on the queue-change notifier:
  - Queue services emit a `QueueChangeType.removed` event.
  - `UnifiedFeedController` responds by removing any matching queued entry by `localId`.
  - No Supabase calls are made for queued-only items.
- For server-backed memories:
  - Continue to:
    - Call the online delete path.
    - Refresh the feed as it does today (and rely on preview-index updates for later offline sessions).

#### 5.4 Tests

- Add tests that:
  - Deleting a queued memory:
    - Removes the queue entry.
    - Removes the card from the unified feed.
    - Does not invoke Supabase delete operations.
  - Deleting a synced memory still uses the online provider and behaves as before.

---

### 6. Non-Goals & Deferred Cleanup

This consolidation **does not**:

- Change the Phase 1 vs Phase 2 product split:
  - Phase 1 remains “preview index + queued memories only”.
  - Full offline caching of arbitrary synced memories stays a future concern.
- Rework the entire flag taxonomy:
  - `isPreviewOnly`, `isDetailCachedLocally`, `OfflineSyncStatus`, etc. remain as specified.
  - The audit’s potential simplifications (e.g., deriving `isPreviewOnly`) are earmarked for a dedicated cleanup spec.

Instead, this plan focuses on:

- Making media rendering respect local vs remote sources.
- Ensuring the unified feed reacts promptly to queue mutations.
- Giving queued memories a clear, functional deletion path.

---

### 7. Summary of Concrete Changes

- **Media models**
  - Add `MediaSource` enum and `source` field to `PrimaryMedia`/`PhotoMedia`/`VideoMedia`.
  - Update adapters and widgets to branch on `source` (`isLocal` vs remote) and use `Image.file` / file-based video for local media.
- **Offline flags**
  - Reinforce canonical meanings of `isOfflineQueued`, `isPreviewOnly`, `isDetailCachedLocally`, `offlineSyncStatus`, `effectiveId`, and `isAvailableOffline`.
  - Standardize usage in new code; defer structural simplifications.
- **Unified feed & queues**
  - Introduce a queue-change notification mechanism (`QueueChangeEvent`) in `OfflineQueueService` / `OfflineStoryQueueService`.
  - Make `UnifiedFeedController` react to queue changes (added/updated/removed) by re-running `fetchMergedFeed` or updating entries in-place.
- **Deletion**
  - Route delete actions for queued memories through queue services, not Supabase.
  - Keep online delete behaviour for synced memories.
- **Tests**
  - Backfill tests around:
    - Local media rendering.
    - Queue-driven feed updates.
    - Offline delete flows for queued entries.

These changes bring the implementation back in line with the offline viewing/editing plan, while preserving the existing phase structure and product scope.


