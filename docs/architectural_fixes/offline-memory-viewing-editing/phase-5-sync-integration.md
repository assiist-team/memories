## Phase 5: Sync Integration (Queues → Server + Preview Index)

### Objective

Ensure a smooth, **non-duplicating** transition when **queued offline memories** sync to Supabase, in a world where:

- The unified timeline is powered by:
  - **Online RPC results** (when available),
  - the **local preview index**, and
  - **offline queues**.
- Phase 1 offline support remains:
  - **Preview-first** for previously-synced memories, and
  - **detail/edit-first** for queued offline memories only.

This phase:

- Keeps the preview index **up to date after sync**, and
- Removes queue entries from the timeline at the right time,

without introducing any **Phase 2 – Full Offline Caching** behaviours such as broad media pre-download.

---

### Prerequisites

- Phase 1–4 completed:
  - Offline-aware `TimelineMoment`.
  - `OfflineQueueToTimelineAdapter` and `PreviewIndexToTimelineAdapter`.
  - `LocalMemoryPreviewStore`.
  - `UnifiedFeedRepository.fetchMergedFeed` (preview index + queues).
  - `OfflineMemoryDetailNotifier` and offline editing support for queued entries.
- Existing:
  - `MemorySyncService` (responsible for syncing queues to Supabase).
  - `UnifiedFeedProvider` (`UnifiedFeedController`).
  - `OfflineQueueService` / `OfflineStoryQueueService`.

---

## Implementation Steps

### Step 1: Emit Sync Completion Events

**File**: `lib/services/memory_sync_service.dart`

Extend the sync service to emit a **lightweight event** when a queued memory successfully syncs:

- Contains both `localId` (queue) and `serverId` (Supabase).
- Contains `MemoryType` to help any downstream logic, if needed.

```dart
class SyncCompleteEvent {
  final String localId;
  final String serverId;
  final MemoryType memoryType;

  SyncCompleteEvent({
    required this.localId,
    required this.serverId,
    required this.memoryType,
  });
}

class MemorySyncService {
  final _syncCompleteController = StreamController<SyncCompleteEvent>.broadcast();

  Stream<SyncCompleteEvent> get syncCompleteStream =>
      _syncCompleteController.stream;

  Future<void> _syncQueuedMomentsAndMementos() async {
    final queued = await _offlineQueueService.getByStatus('queued');

    for (final item in queued) {
      try {
        // ...existing status updates, save to Supabase, etc...
        final result = await _saveService.saveMoment(state: item.toCaptureState());

        await _offlineQueueService.markCompleted(
          item.copyWith(
            status: 'completed',
            serverMomentId: result.memoryId,
          ),
        );

        _syncCompleteController.add(
          SyncCompleteEvent(
            localId: item.localId,
            serverId: result.memoryId,
            memoryType: item.memoryType,
          ),
        );

        await _offlineQueueService.remove(item.localId);
      } catch (e) {
        // existing failure / retry logic
      }
    }
  }

  // Similar logic for stories via _offlineStoryQueueService...
}
```

Phase 1 rule:

- Sync completion **does not** attempt to pre-cache detail/media for the synced memory.  
  It only:
  - writes to Supabase, and
  - notifies the app that the queue entry can disappear.

---

### Step 2: Make Unified Feed React to Sync Completion

**File**: `lib/providers/unified_feed_provider.dart`

`UnifiedFeedController` should:

- Subscribe to `syncCompleteStream`.
- Remove the corresponding **queued** entry from the current in-memory timeline.
- Optionally refresh the feed later to pick up the server-backed version (from RPC / preview index).

Example:

```dart
@riverpod
class UnifiedFeedController extends _$UnifiedFeedController {
  StreamSubscription<SyncCompleteEvent>? _syncSub;

  @override
  UnifiedFeedViewState build([Set<MemoryType>? memoryTypeFilters]) {
    _memoryTypeFilters = memoryTypeFilters ??
        {MemoryType.story, MemoryType.moment, MemoryType.memento};

    _setupSyncListener();
    return const UnifiedFeedViewState(state: UnifiedFeedState.initial);
  }

  void _setupSyncListener() {
    final syncService = ref.read(memorySyncServiceProvider);

    _syncSub?.cancel();
    _syncSub = syncService.syncCompleteStream.listen((event) {
      _removeQueuedEntry(event.localId);
      // We do NOT immediately re-fetch the feed here; the server-backed
      // version will naturally appear on next pagination/refresh.
    });
  }

  void _removeQueuedEntry(String localId) {
    final updated = state.memories
        .where((m) => !(m.isOfflineQueued && m.localId == localId))
        .toList();

    state = state.copyWith(memories: updated);
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }
}
```

Behaviour:

- While syncing:
  - Cards show “Syncing” (Phase 6).
- Once a sync succeeds:
  - The queued card is removed from the in-memory list.
  - On the next online fetch:
    - The server-backed memory appears via RPC, and
    - A preview row is upserted for offline visibility.

---

### Step 3: Keep Preview Index in Sync (Conceptual)

**Files**:

- `lib/services/unified_feed_repository.dart`
- `lib/services/local_memory_preview_store.dart`

The **primary mechanism** for updating the preview index is already in Phase 2:

- Whenever an online page is fetched from Supabase:
  - The repository derives `LocalMemoryPreview` rows from the server results.
  - It calls `LocalMemoryPreviewStore.upsertPreviews(...)`.

For Phase 1, this is sufficient:

- After sync completes:
  - There will soon be an online fetch (either user-initiated or automatic).
  - That fetch will upsert the new server-backed entry into the preview index.

Optional (Phase 1-friendly) enhancement:

- If you want slightly faster preview-index updates after sync, `MemorySyncService` can:

  ```dart
  final previewStore = ref.read(localMemoryPreviewStoreProvider);
  await previewStore.upsertPreviews([
    LocalMemoryPreview(
      serverId: event.serverId,
      memoryType: event.memoryType,
      titleOrFirstLine: /* derive from capture state or queue entry */,
      capturedAt: /* same capturedAt as queue state */,
    ),
  ]);
  ```

- This is still **preview-level only** (no full detail/media), consistent with Phase 1.

Do **not**:

- Download full detail/media at sync-time,
- Introduce storage/eviction policies in this phase.

Those choices belong to Phase 2.

---

### Step 4: Avoid Duplicates in Repository Logic

**File**: `lib/services/unified_feed_repository.dart`

Even with `UnifiedFeedController._removeQueuedEntry`, it is good defensive practice for the repository to avoid returning entries that:

- represent a queue item that has already been synced (i.e., it has a `serverId`).

In `fetchQueuedMemories(...)`:

```dart
Future<List<TimelineMoment>> fetchQueuedMemories({
  Set<MemoryType>? filters,
}) async {
  final base = /* existing logic using OfflineQueueToTimelineAdapter */;

  // Phase 1 de-duplication rule:
  // If a queued item has a serverId, it is considered synced and should not
  // appear as an "offline queued" entry in the merged feed.
  return base.where((m) => m.serverId == null).toList();
}
```

This, combined with:

- `UnifiedFeedController._removeQueuedEntry(localId)` after sync, and  
- online fetches that bring in the server-backed version,

keeps the timeline free of duplicates during sync transitions.

---

### Step 5: Tests for Sync Transition Behaviour

**Files**:

- `test/services/memory_sync_service_test.dart`
- `test/providers/unified_feed_provider_sync_test.dart` (new or folded into existing feed tests)

Suggested test cases:

1. **Sync emits completion event**
   - Given a queued memory that syncs successfully,
   - Then `MemorySyncService.syncCompleteStream` emits a `SyncCompleteEvent` with the correct `localId`, `serverId`, and `memoryType`.

2. **Feed removes queued entry on sync**
   - Given a `UnifiedFeedViewState` containing a `TimelineMoment` with `isOfflineQueued == true` and matching `localId`,
   - When a `SyncCompleteEvent` is emitted,
   - Then the queued entry is removed from `state.memories`.

3. **No duplicate entries after sync**
   - Given a queued entry that syncs and then an online page is fetched,
   - Then the merged list:
     - contains a single entry for that memory (the server-backed one),
     - and no queued copy with the same content.

4. **Preview index updated via online fetch (or optional sync-time upsert)**
   - Ensure `LocalMemoryPreviewStore.upsertPreviews` is called with new `serverId`s either:
     - from `fetchPage` (online fetch), or
     - from an optional sync-time upsert.

Use fakes for:

- Queue services,
- `LocalMemoryPreviewStore`,
- `SupabaseClient` / repository,

so the tests remain fast and deterministic.

---

## Files to Create/Modify

### Files to Modify

- `lib/services/memory_sync_service.dart`
  - Emit `SyncCompleteEvent`s after successful syncs.
  - Ensure queue entries are removed and statuses updated.
- `lib/providers/unified_feed_provider.dart`
  - Subscribe to `syncCompleteStream`.
  - Remove queued entries from `state.memories` by `localId`.
- `lib/services/unified_feed_repository.dart`
  - Filter out `TimelineMoment`s representing already-synced queued entries (`serverId != null`).

### Files to Create

- `test/providers/unified_feed_provider_sync_test.dart` (or equivalent)
  - Focused tests for sync → timeline behaviour.

---

## Success Criteria

- **Queue → server transition**
  - [ ] When a queued memory syncs, its queue entry is removed from the timeline without leaving duplicates.
  - [ ] On the next online fetch, the synced version appears as a normal, server-backed memory.
- **Preview index alignment**
  - [ ] Newly synced memories eventually appear in the preview index (via online fetch or optional sync-time upsert).
  - [ ] Offline users later see these memories as preview-only cards when offline.
- **No Phase 2 behaviour**
  - [ ] No code path attempts full offline caching of all details/media during sync.
  - [ ] Preview index stays lightweight and focused on card-level metadata.
- **Tests**
  - [ ] Sync completion events are emitted and consumed correctly.
  - [ ] Unified feed stays free of duplicates during sync transitions.

With Phase 5 complete, queued offline memories cleanly “graduate” into normal, synced memories while maintaining a consistent offline experience through the preview index.


