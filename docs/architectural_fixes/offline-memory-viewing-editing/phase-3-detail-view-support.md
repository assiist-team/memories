## Phase 3: Detail View Support (Queued Offline Memories Only)

### Objective

Enable **full detail views** for **queued offline memories** (captured while offline and stored in local queues), while keeping **preview-only memories**:

- visible in the unified timeline when offline (via preview index), but  
- **not openable offline** in Phase 1.

This phase is explicitly constrained to **Phase 1 offline support**:

- Only **queued offline memories** (`isOfflineQueued == true`) are fully available offline.
- Previously-synced memories represented by `isPreviewOnly == true` remain:
  - greyed out, and
  - **non-tappable** or show a very lightweight “Not available offline” explanation.
- We **do not** implement full offline detail for all synced memories (that is **Phase 2 – Full Offline Caching**).

---

### Prerequisites

- Phase 1 completed (Data Model & Adapters):
  - `TimelineMoment` with:
    - `isOfflineQueued`
    - `isPreviewOnly`
    - `isDetailCachedLocally`
    - `localId`, `serverId`
  - Queue and preview adapters:
    - `OfflineQueueToTimelineAdapter`
    - `PreviewIndexToTimelineAdapter`
- Phase 2 completed (Timeline Integration):
  - `UnifiedFeedRepository.fetchMergedFeed` using preview index + queue.
  - `UnifiedFeedProvider` exposing `isOffline` and a merged list of `TimelineMoment`s.
- Existing:
  - `MemoryDetail` model
  - `MemoryDetailScreen`
  - `OfflineQueueService`, `OfflineStoryQueueService`

---

## Implementation Steps

### Step 1: Create `OfflineMemoryDetailProvider` for Queued Items

**File**: `lib/providers/offline_memory_detail_provider.dart`

Purpose: load **only queued offline memories** into a `MemoryDetail` representation suitable for the detail screen and editing flows.

Key behaviours:

- Accepts a **local ID** (from `TimelineMoment.localId` / `effectiveId`).
- Searches:
  - main queue (`OfflineQueueService`) for moments/mementos, then
  - story queue (`OfflineStoryQueueService`) for stories.
- Throws an error if the local ID does not exist in any queue.
- Does **not** load or attempt to cache remote details for preview-only entries.

Example shape:

```dart
@riverpod
class OfflineMemoryDetailNotifier extends _$OfflineMemoryDetailNotifier {
  @override
  Future<MemoryDetail> build(String localId) async {
    final queueService = ref.read(offlineQueueServiceProvider);
    final storyQueueService = ref.read(offlineStoryQueueServiceProvider);

    final queuedMoment = await queueService.getByLocalId(localId);
    if (queuedMoment != null) {
      return _toDetailFromQueuedMoment(queuedMoment);
    }

    final queuedStory = await storyQueueService.getByLocalId(localId);
    if (queuedStory != null) {
      return _toDetailFromQueuedStory(queuedStory);
    }

    throw Exception('Offline queued memory not found: $localId');
  }

  // _toDetailFromQueuedMoment / _toDetailFromQueuedStory map queue models
  // to MemoryDetail without any remote fetch.
}
```

Implementation notes:

- Use whatever **local paths** exist in the queue for media.
- If a local file path is missing, show a placeholder at the UI layer; do not attempt to fetch from Supabase in Phase 1.
- `userId`, `publicShareToken`, relationships, etc. can remain empty or defaulted until sync.

---

### Step 2: Update `MemoryDetailScreen` to Route Offline vs Online

**File**: `lib/screens/memory/memory_detail_screen.dart`

Update the detail screen so it:

- Uses `OfflineMemoryDetailNotifier` **only** for queued offline memories.
- Uses the existing online detail provider for synced memories.
- Explicitly avoids attempting detail loads for preview-only memories when offline.

#### 2.1 Constructor / navigation parameters

Expose:

- `memoryId` — can be `serverId` or `localId` depending on entry.
- `isOfflineQueued` — whether this memory is a queued offline item.

```dart
class MemoryDetailScreen extends ConsumerWidget {
  final String memoryId;
  final bool isOfflineQueued;

  const MemoryDetailScreen({
    required this.memoryId,
    required this.isOfflineQueued,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = isOfflineQueued
        ? ref.watch(offlineMemoryDetailNotifierProvider(memoryId))
        : ref.watch(memoryDetailNotifierProvider(memoryId)); // existing online provider

    // Build UI from AsyncValue<MemoryDetail> as before...
  }
}
```

#### 2.2 Handling preview-only entries when offline

Do **not** navigate into this screen when:

- `TimelineMoment.isPreviewOnly == true`, and
- the app is offline (`UnifiedFeedViewState.isOffline == true`).

That rule is enforced at the card level (see Phase 6), but you may also add a defensive guard:

```dart
if (!isOfflineQueued && !isOnline) {
  // Optionally show a very lightweight explanation instead of full detail.
  return _NotAvailableOfflineScaffold();
}
```

This keeps Phase 1 scoped: only queued memories get detail views offline.

---

### Step 3: Wire Memory Cards to the Correct Detail Flow

**File**: `lib/widgets/memory_card.dart` (and any type-specific card widgets)

Each card has access to:

- `TimelineMoment` (with offline/preview flags).
- `UnifiedFeedViewState.isOffline` (can be read via `ConsumerWidget` or passed down).

Update tap handling:

```dart
class MemoryCard extends ConsumerWidget {
  final TimelineMoment memory;

  const MemoryCard({required this.memory, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(unifiedFeedControllerProvider());
    final isOffline = feedState.isOffline;

    final canOpenDetailOffline = memory.isOfflineQueued || memory.isDetailCachedLocally;
    final isPreviewOnlyOffline = isOffline && memory.isPreviewOnly && !canOpenDetailOffline;

    return Card(
      child: InkWell(
        onTap: isPreviewOnlyOffline
            ? () => _showNotAvailableOfflineMessage(context)
            : () => _openDetail(context, isOffline),
        child: _buildContent(context, isPreviewOnlyOffline),
      ),
    );
  }

  void _openDetail(BuildContext context, bool isOffline) {
    final isQueued = memory.isOfflineQueued;
    final id = isQueued ? (memory.localId ?? memory.effectiveId) : (memory.serverId ?? memory.effectiveId);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemoryDetailScreen(
          memoryId: id,
          isOfflineQueued: isQueued,
        ),
      ),
    );
  }

  void _showNotAvailableOfflineMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This memory is not available offline yet.')),
    );
  }
}
```

Behaviour:

- **Queued offline memories**:
  - Are always tappable.
  - Route to `OfflineMemoryDetailNotifier`.
- **Preview-only memories when offline**:
  - Are not tappable, or show a small explanatory snackbar.
- **Synced memories when online**:
  - Behave as they do today, using the online detail provider.

---

### Step 4: Tests for Offline Detail View (Queued Only)

**File**: `test/providers/offline_memory_detail_provider_test.dart`

Add tests for:

- `OfflineMemoryDetailNotifier`:
  - Loads a queued moment by `localId`.
  - Loads a queued story by `localId`.
  - Throws when `localId` does not exist in any queue.
- Card → detail flow:
  - When `TimelineMoment.isOfflineQueued == true` and `isOffline == true`, tapping card navigates to offline detail.
  - When `TimelineMoment.isPreviewOnly == true` and `isOffline == true`, tapping card **does not** open full detail (shows message instead).

Use fakes for queue services to keep tests local and deterministic.

---

## Files to Create/Modify

### Files to Create

- `lib/providers/offline_memory_detail_provider.dart`
- `lib/providers/offline_memory_detail_provider.g.dart` (generated)
- `test/providers/offline_memory_detail_provider_test.dart`

### Files to Modify

- `lib/screens/memory/memory_detail_screen.dart`
  - Route queued offline memories through `OfflineMemoryDetailNotifier`.
  - Optionally guard against opening preview-only entries when offline.
- `lib/widgets/memory_card.dart` (and related card widgets)
  - Use `TimelineMoment` offline/preview flags to decide tap behaviour.

---

## Success Criteria

- **Offline detail support (queued only)**
  - [ ] Users can open **queued offline memories** from the timeline while offline.
  - [ ] Queued offline memories show full detail (text, tags, media paths, location) from the queue.
- **Preview-only behaviour**
  - [ ] Previously-synced, preview-only memories remain visible in the timeline when offline but:
    - are greyed or visually de-emphasized (Phase 6),
    - are **not openable** as full detail in Phase 1.
  - [ ] Attempting to tap a preview-only memory while offline either does nothing or shows a clear “Not available offline” message.
- **Scope alignment**
  - [ ] No code path attempts to fetch remote detail or media for preview-only entries while offline.
  - [ ] No behaviour implies full offline caching of all synced memories (that remains a Phase 2 concern).
- **Tests**
  - [ ] Unit/integration tests validate that offline detail is restricted to queued memories.
  - [ ] Card tap behaviour is correct for queued vs preview-only vs online-synced memories.

With this phase complete, Phase 4 can safely add **offline editing** on top of queued detail views, while preview-only items remain view-only (and non-openable) when offline.


