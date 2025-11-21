## Phase 2: Timeline Integration (Preview Index + Offline Queues)

### Objective

Integrate the **preview index** and **offline queues** into the unified timeline so that:

- When **online**, the app:
  - Reads from Supabase (via existing RPC / queries),
  - Updates the **local preview index**, and
  - Merges in queued offline memories.
- When **offline**, the app:
  - Renders the **full previously-synced timeline** from the **preview index**, **plus**
  - All **queued offline memories**.

Phase 2 remains strictly within **Phase 1 offline support**:

- Previously-synced memories are often **preview-only** when offline (greyed, not tappable).
- Only **queued offline memories** have full offline detail/editing.
- We **do not** implement any Phase 2 “Full Offline Caching” behaviour (no broad media pre-download, no deep caching of all details).

---

### Prerequisites

- Phase 1 completed (Data Model & Adapters):
  - `TimelineMoment` supports:
    - `isOfflineQueued`
    - `isPreviewOnly`
    - `isDetailCachedLocally`
    - `localId`, `serverId`, `offlineSyncStatus`
  - `OfflineQueueToTimelineAdapter`
  - `PreviewIndexToTimelineAdapter`
  - `LocalMemoryPreview` model
  - `LocalMemoryPreviewStore` abstraction
- Existing:
  - `UnifiedFeedRepository`
  - `UnifiedFeedProvider` (or `UnifiedFeedController`)
  - `OfflineQueueService` / `OfflineStoryQueueService`
  - `ConnectivityService`

---

## Implementation Steps

### Step 1: Extend `UnifiedFeedRepository` to Use Preview Index

**File**: `lib/services/unified_feed_repository.dart`

#### 1.1 Inject `LocalMemoryPreviewStore`

Add a dependency on the preview index store:

```dart
class UnifiedFeedRepository {
  final SupabaseClient _supabase;
  final OfflineQueueService _offlineQueueService;
  final OfflineStoryQueueService _offlineStoryQueueService;
  final LocalMemoryPreviewStore _localPreviewStore;

  UnifiedFeedRepository(
    this._supabase,
    this._offlineQueueService,
    this._offlineStoryQueueService,
    this._localPreviewStore,
  );
}
```

#### 1.2 Fetch queued memories as timeline items

Reuse the queue adapter to express queued items in the unified model:

```dart
Future<List<TimelineMoment>> fetchQueuedMemories({
  Set<MemoryType>? filters,
}) async {
  final effectiveFilters = filters ?? {
    MemoryType.story,
    MemoryType.moment,
    MemoryType.memento,
  };

  final results = <TimelineMoment>[];

  // Moments + mementos
  if (effectiveFilters.contains(MemoryType.moment) ||
      effectiveFilters.contains(MemoryType.memento)) {
    final queued = await _offlineQueueService.getAllQueued();
    for (final item in queued) {
      final type = item.memoryType;
      if (effectiveFilters.contains(type)) {
        results.add(OfflineQueueToTimelineAdapter.fromQueuedMoment(item));
      }
    }
  }

  // Stories
  if (effectiveFilters.contains(MemoryType.story)) {
    final queuedStories = await _offlineStoryQueueService.getAllQueued();
    for (final story in queuedStories) {
      results.add(OfflineQueueToTimelineAdapter.fromQueuedStory(story));
    }
  }

  // Phase 1: filter out already-synced queue entries (if any)
  return results.where((m) => m.serverId == null).toList();
}
```

#### 1.3 Fetch preview-index memories as timeline items

Add a method to read stored previews and adapt them:

```dart
Future<List<TimelineMoment>> fetchPreviewIndexMemories({
  Set<MemoryType>? filters,
  int limit = 200,
}) async {
  final previews = await _localPreviewStore.fetchPreviews(
    filters: filters,
    limit: limit,
  );

  return previews
      .map(PreviewIndexToTimelineAdapter.fromPreview)
      .toList();
}
```

#### 1.4 Update online fetch to upsert preview index

Whenever an online page is fetched from Supabase, upsert preview entries:

```dart
Future<UnifiedFeedPageResult> _fetchOnlinePage({
  UnifiedFeedCursor? cursor,
  Set<MemoryType>? filters,
  int batchSize = _defaultBatchSize,
}) async {
  final result = await fetchPage(
    cursor: cursor,
    filters: filters,
    batchSize: batchSize,
  );

  // Derive preview rows from online results.
  final previews = result.memories.map((m) {
    return LocalMemoryPreview(
      serverId: m.serverId ?? m.id,
      memoryType: m.memoryType,
      titleOrFirstLine: m.titleOrFirstLine,
      capturedAt: m.capturedAt,
      // In Phase 1, RPC results are not considered “locally cached details”.
      isDetailCachedLocally: false,
    );
  }).toList();

  await _localPreviewStore.upsertPreviews(previews);

  return result;
}
```

> Phase 1: the preview index is populated **opportunistically** whenever we’re online. We don’t design eviction or deep caching policies here—that belongs to Phase 2.

---

### Step 2: Implement `fetchMergedFeed` (online + offline branches)

**File**: `lib/services/unified_feed_repository.dart`

Implement a single entry point that:

- merges **online RPC** + **queue** + **preview index** when online, and  
- merges **queue** + **preview index** when offline.

```dart
Future<UnifiedFeedPageResult> fetchMergedFeed({
  UnifiedFeedCursor? cursor,
  Set<MemoryType>? filters,
  int batchSize = _defaultBatchSize,
  required bool isOnline,
}) async {
  if (!isOnline) {
    // OFFLINE: use preview index + queue only.
    final queued = await fetchQueuedMemories(filters: filters);
    final previews = await fetchPreviewIndexMemories(
      filters: filters,
      // keep a sane upper bound; pagination handled after merge
      limit: batchSize * 3,
    );

    final merged = [...queued, ...previews]
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));

    final page = merged.take(batchSize).toList();

    return UnifiedFeedPageResult(
      memories: page,
      nextCursor: null, // simple offline pagination (optional to implement)
      hasMore: merged.length > batchSize,
    );
  }

  // ONLINE: fetch from Supabase, then merge in queued + preview index as needed.
  final onlineResult = await _fetchOnlinePage(
    cursor: cursor,
    filters: filters,
    batchSize: batchSize,
  );

  final queued = await fetchQueuedMemories(filters: filters);

  // For Phase 1, it is acceptable to:
  // - show online results + queued; preview index is updated but not required for online rendering.
  final merged = [...onlineResult.memories, ...queued]
    ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));

  // Re-derive pagination over merged list.
  final startIndex = 0; // keep simple; cursor-based merging can be refined later.
  final page = merged.skip(startIndex).take(batchSize).toList();

  return UnifiedFeedPageResult(
    memories: page,
    nextCursor: onlineResult.nextCursor,
    hasMore: onlineResult.hasMore || merged.length > page.length,
  );
}
```

Key behaviours:

- **Offline**:
  - The unified timeline still shows **all previously-synced memories** (via preview index).
  - Queued offline memories are interleaved chronologically with previews.
  - Preview-only entries will be rendered greyed and non-tappable offline (handled in Phase 6).
- **Online**:
  - The preview index is **kept fresh** from RPC results.
  - Queued memories appear inline with server data.

---

### Step 3: Update `UnifiedFeedProvider` to Use `fetchMergedFeed`

**File**: `lib/providers/unified_feed_provider.dart`

Update the controller/provider to:

- Detect online vs offline via `ConnectivityService`,
- Call `fetchMergedFeed` instead of `fetchPage`,
- Expose an `isOffline` flag to the UI so cards can adjust behaviour.

```dart
@riverpod
class UnifiedFeedController extends _$UnifiedFeedController {
  static const _batchSize = 20;

  Set<MemoryType> _memoryTypeFilters = {
    MemoryType.story,
    MemoryType.moment,
    MemoryType.memento,
  };

  @override
  UnifiedFeedViewState build([Set<MemoryType>? memoryTypeFilters]) {
    _memoryTypeFilters = memoryTypeFilters ?? _memoryTypeFilters;
    return const UnifiedFeedViewState(state: UnifiedFeedState.initial);
  }

  Future<void> loadInitial() async {
    state = state.copyWith(state: UnifiedFeedState.loading);
    await _fetchPage(append: false, pageNumber: 1, cursor: null);
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.state == UnifiedFeedState.loadingMore) return;
    state = state.copyWith(state: UnifiedFeedState.loadingMore);
    await _fetchPage(
      append: true,
      pageNumber: state.pageNumber + 1,
      cursor: state.nextCursor,
    );
  }

  Future<void> _fetchPage({
    required bool append,
    required int pageNumber,
    UnifiedFeedCursor? cursor,
  }) async {
    final repository = ref.read(unifiedFeedRepositoryProvider);
    final connectivity = ref.read(connectivityServiceProvider);

    final isOnline = await connectivity.isOnline();

    final result = await repository.fetchMergedFeed(
      cursor: cursor,
      filters: _memoryTypeFilters,
      batchSize: _batchSize,
      isOnline: isOnline,
    );

    final mergedMemories = append
        ? [...state.memories, ...result.memories]
        : result.memories;

    state = state.copyWith(
      state: mergedMemories.isEmpty && !append
          ? UnifiedFeedState.empty
          : UnifiedFeedState.ready,
      memories: mergedMemories,
      nextCursor: result.nextCursor,
      hasMore: result.hasMore,
      pageNumber: pageNumber,
      isOffline: !isOnline,
      errorMessage: null,
    );
  }
}
```

Provider wiring for repository:

```dart
@riverpod
UnifiedFeedRepository unifiedFeedRepository(UnifiedFeedRepositoryRef ref) {
  final supabase = ref.read(supabaseClientProvider);
  final offlineQueueService = ref.read(offlineQueueServiceProvider);
  final offlineStoryQueueService = ref.read(offlineStoryQueueServiceProvider);
  final localPreviewStore = ref.read(localMemoryPreviewStoreProvider);

  return UnifiedFeedRepository(
    supabase,
    offlineQueueService,
    offlineStoryQueueService,
    localPreviewStore,
  );
}
```

---

### Step 4: Ensure No “Offline = Queued-Only” Logic Remains

Search for and remove/replace any logic that implies:

- “When offline, return only queued memories”  
- “If offline, timeline is empty unless there are queued items”

Instead, the contract must be:

- **Offline = preview index + queue**
  - Preview index keeps previously-synced cards visible.
  - Queued offline memories are fully available offline.

Examples to adjust:

- Old (to remove/replace):

```dart
if (!isOnline) {
  final queued = await fetchQueuedMemories(filters: filters);
  // return only queued items
}
```

- New (already shown above):

```dart
if (!isOnline) {
  final queued = await fetchQueuedMemories(filters: filters);
  final previews = await fetchPreviewIndexMemories(filters: filters);
  // merge + sort
}
```

---

### Step 5: Tests for Offline Timeline Integration

**File**: `test/providers/unified_feed_provider_test.dart` (or new)

Add tests that assert Phase 1 behaviour:

- **Offline timeline includes preview index + queue**:
  - Given:
    - preview index has 10 memories,
    - offline queue has 2 queued moments,
    - connectivity reports `isOnline == false`,
  - When `loadInitial()` is called,
  - Then:
    - `state.memories.length == 12` (subject to `batchSize`),
    - all preview items have `isPreviewOnly == true`,
    - queued items have `isOfflineQueued == true` and `isDetailCachedLocally == true`.
- **Online timeline merges online + queue, keeps preview index updated**:
  - Ensure `LocalMemoryPreviewStore.upsertPreviews` is called with online results.
- **Filters still work**:
  - Filtering to `MemoryType.story` respects both preview index and queue.

Use fakes for:

- `ConnectivityService`
- `LocalMemoryPreviewStore`
- Queue services

so tests remain fast and deterministic.

---

## Files to Create/Modify

### Files to Modify

- `lib/services/unified_feed_repository.dart`
  - Inject `LocalMemoryPreviewStore`.
  - Add `fetchQueuedMemories`, `fetchPreviewIndexMemories`, and `fetchMergedFeed`.
  - Ensure online fetch upserts preview index.
- `lib/providers/unified_feed_provider.dart`
  - Use `fetchMergedFeed`.
  - Track `isOffline` for UI.

### Files to Create

- `test/providers/unified_feed_provider_test.dart` (if not present) — tests for merged offline/online behaviour.

---

## Success Criteria

- **Offline behaviour**
  - [ ] When offline, the unified timeline still shows **previously-synced memories** (via preview index) **and** queued offline memories.
  - [ ] Preview-only entries are clearly marked via `TimelineMoment` flags (`isPreviewOnly`, `isAvailableOffline == false`).
- **Online behaviour**
  - [ ] When online, the repository fetches from Supabase and upserts **preview index** entries.
  - [ ] Queued offline memories are merged with online results without duplicates.
- **API & tests**
  - [ ] `UnifiedFeedRepository.fetchMergedFeed` is the single entry point used by the provider.
  - [ ] `UnifiedFeedProvider` exposes `isOffline` so Phase 6 can grey out preview-only cards.
  - [ ] Tests cover online/offline branches and confirm the timeline does **not** collapse to “queued only” when offline.

This phase ensures the **MVP offline behaviour**: a full, meaningful timeline when offline, powered by a **preview index + queues**, ready for Phase 3 (detail view support for queued memories) and later Phase 2 (full offline caching) work.


