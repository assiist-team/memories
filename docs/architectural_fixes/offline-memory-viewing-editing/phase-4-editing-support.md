## Phase 4: Editing Support (Queued Offline Memories)

### Objective

Allow users to **edit** memories that were **captured offline and are still queued** (text, tags, media, location), with all changes persisted to the queue and later synced to Supabase when connectivity returns.

In **Phase 1 offline support**:

- **Editing is limited to queued offline memories** (`isOfflineQueued == true`).
- Editing **pre-existing synced memories still requires connectivity**:
  - No new offline editing flow for server-backed memories.
  - No attempt to cache full detail for arbitrary synced memories (Phase 2 concern).

---

### Prerequisites

- Phase 1 completed (Data Model & Adapters)
  - `TimelineMoment` has offline/preview fields and identifiers.
  - Queue models and adapters (`QueuedMoment`, `QueuedStory`, `OfflineQueueToTimelineAdapter`).
- Phase 2 completed (Timeline Integration)
  - `UnifiedFeedRepository.fetchMergedFeed` provides preview index + queued entries when offline.
- Phase 3 completed (Detail View Support)
  - `OfflineMemoryDetailNotifier` loads queued offline memories into `MemoryDetail`.
  - `MemoryDetailScreen` routes queued entries through the offline provider.
- Existing:
  - `CaptureState` / `CaptureStateNotifier` (capture/edit pipeline).
  - `MemorySaveService` (saving/updating memories online).
  - `OfflineQueueService`, `OfflineStoryQueueService`.

---

## Implementation Steps

### Step 1: Extend `CaptureStateNotifier` for Offline Editing

**File**: `lib/providers/capture_state_provider.dart`

Add a minimal set of fields and methods to represent an **offline editing session** for a queued memory:

- Track the **local ID** of the queued memory being edited.
- Reuse existing capture state fields for text, tags, media, and location.
- Provide helpers to:
  - load queued data into the capture state,
  - determine whether the current session is an offline edit.

Example shape:

```dart
class CaptureStateNotifier extends StateNotifier<CaptureState> {
  CaptureStateNotifier(/* dependencies */) : super(CaptureState.initial());

  String? _editingOfflineLocalId;

  bool get isEditingOffline => _editingOfflineLocalId != null;
  String? get editingOfflineLocalId => _editingOfflineLocalId;

  Future<void> loadOfflineMemoryForEdit({
    required String localId,
    required MemoryType memoryType,
    required String? inputText,
    required List<String> tags,
    required List<String> existingPhotoPaths,
    required List<String> existingVideoPaths,
    double? latitude,
    double? longitude,
    String? locationStatus,
    DateTime? capturedAt,
  }) async {
    _editingOfflineLocalId = localId;

    state = state.copyWith(
      memoryType: memoryType,
      inputText: inputText,
      tags: tags,
      latitude: latitude,
      longitude: longitude,
      locationStatus: locationStatus,
      existingPhotoUrls: existingPhotoPaths.map((p) => 'file://$p').toList(),
      existingVideoUrls: existingVideoPaths.map((p) => 'file://$p').toList(),
      captureStartTime: capturedAt,
      editingMemoryId: null, // Do NOT treat this as an online edit.
    );
  }

  void clearOfflineEditing() {
    _editingOfflineLocalId = null;
  }
}
```

Key rule:

- `editingOfflineLocalId` is **never** used to call online update APIs; it only points to a queue entry that will be updated locally.

---

### Step 2: Load Capture State from Offline Detail View

**File**: `lib/screens/memory/memory_detail_screen.dart`

When viewing a queued offline memory (Phase 3), the user can tap “Edit” to move into the capture/edit flow. Wire that button so it:

1. Extracts the current `MemoryDetail` data (from the offline provider).  
2. Derives local media paths from `file://` URLs.  
3. Calls `CaptureStateNotifier.loadOfflineMemoryForEdit`.  
4. Navigates to the capture screen.

Example:

```dart
void _handleEditOffline(
  BuildContext context,
  WidgetRef ref,
  MemoryDetail detail,
) {
  final captureNotifier = ref.read(captureStateNotifierProvider.notifier);

  final photoPaths = detail.photos
      .map((p) => p.url.replaceFirst('file://', ''))
      .toList();
  final videoPaths = detail.videos
      .map((v) => v.url.replaceFirst('file://', ''))
      .toList();

  captureNotifier.loadOfflineMemoryForEdit(
    localId: detail.id,
    memoryType: detail.memoryType,
    inputText: detail.inputText,
    tags: detail.tags,
    existingPhotoPaths: photoPaths,
    existingVideoPaths: videoPaths,
    latitude: detail.locationData?.latitude,
    longitude: detail.locationData?.longitude,
    locationStatus: detail.locationData?.status,
    capturedAt: detail.capturedAt,
  );

  // Navigate to capture screen as usual.
  Navigator.of(context).pop();
  ref.read(mainNavigationTabNotifierProvider.notifier).switchToCapture();
}
```

Note:

- This path is **only used** when `MemoryDetailScreen` is showing a queued offline memory (`isOfflineQueued == true`).
- For synced memories, existing online edit behaviour remains unchanged and still requires connectivity.

---

### Step 3: Add `updateQueuedMemory` to `MemorySaveService`

**File**: `lib/services/memory_save_service.dart`

Add a method that:

- Updates a **queued** memory in the appropriate queue service, using the current `CaptureState`.
- Does **not** perform connectivity checks.
- Does **not** call any Supabase RPC or write to online tables.

```dart
class MemorySaveService {
  final OfflineQueueService _offlineQueueService;
  final OfflineStoryQueueService _offlineStoryQueueService;

  // ...

  Future<void> updateQueuedMemory({
    required String localId,
    required CaptureState state,
  }) async {
    if (state.memoryType == MemoryType.story) {
      await _updateQueuedStory(localId: localId, state: state);
    } else {
      await _updateQueuedMoment(localId: localId, state: state);
    }
  }

  Future<void> _updateQueuedMoment({
    required String localId,
    required CaptureState state,
  }) async {
    final existing = await _offlineQueueService.getByLocalId(localId);
    if (existing == null) {
      throw Exception('Queued memory not found: $localId');
    }

    final updated = existing.copyWithFromCaptureState(
      state: state,
      // Preserve sync metadata and timestamps.
      createdAt: existing.createdAt,
      retryCount: existing.retryCount,
      status: existing.status,
      serverMomentId: existing.serverMomentId,
    );

    await _offlineQueueService.update(updated);
  }

  Future<void> _updateQueuedStory({
    required String localId,
    required CaptureState state,
  }) async {
    final existing = await _offlineStoryQueueService.getByLocalId(localId);
    if (existing == null) {
      throw Exception('Queued story not found: $localId');
    }

    final updated = existing.copyWithFromCaptureState(
      state: state,
      createdAt: existing.createdAt,
      retryCount: existing.retryCount,
      status: existing.status,
      serverStoryId: existing.serverStoryId,
    );

    await _offlineStoryQueueService.update(updated);
  }
}
```

You can implement `copyWithFromCaptureState` either as:

- a constructor-like helper on `QueuedMoment` / `QueuedStory`, or  
- a dedicated factory `QueuedMoment.fromCaptureState(...)` that uses existing fields.

The key point is that **only the queue entry** is updated; online sync will happen later (Phase 5).

---

### Step 4: Update Capture Screen Save Logic

**File**: `lib/screens/capture/capture_screen.dart`

Update the save handler to distinguish between:

- **Offline edit of queued memory** → `updateQueuedMemory`.
- **Online edit of synced memory** → existing `updateMemory` logic.
- **New capture** → existing `saveMoment` / `saveStory` logic.

Example:

```dart
Future<void> _handleSave(BuildContext context, WidgetRef ref) async {
  final captureState = ref.read(captureStateNotifierProvider);
  final captureNotifier = ref.read(captureStateNotifierProvider.notifier);
  final saveService = ref.read(memorySaveServiceProvider);

  if (!captureState.canSave) {
    // show validation message...
    return;
  }

  try {
    if (captureNotifier.isEditingOffline) {
      final localId = captureNotifier.editingOfflineLocalId!;

      await saveService.updateQueuedMemory(
        localId: localId,
        state: captureState,
      );

      captureNotifier.clearOfflineEditing();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Changes saved. This memory will sync when you are online.'),
        ),
      );

      Navigator.of(context).pop(); // Back to timeline / detail.
      return;
    }

    if (captureState.isEditing) {
      // Existing online edit path (requires connectivity).
      await saveService.updateMemory(state: captureState);
    } else {
      // Existing new capture path.
      await saveService.saveMemory(state: captureState);
    }

    Navigator.of(context).pop();
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error saving memory: $e')),
    );
  }
}
```

Key rule:

- **Do not** treat offline editing as an error condition simply because connectivity is absent; queued edits should always be allowed and stored locally.

---

### Step 5: Verify/Adjust Queue Update Semantics

**Files**:

- `lib/services/offline_queue_service.dart`
- `lib/services/offline_story_queue_service.dart`

Confirm:

- `update(...)`:
  - Writes the entire queue entry atomically.
  - Persists correctly across app restarts.
  - Does not inadvertently reset sync metadata (status, retry count, server IDs).
- `getByLocalId(...)`:
  - Returns `null` when the entry doesn’t exist (handled by the caller).

Add tests where necessary to ensure editing updates the queue entry as expected.

---

### Step 6: Tests for Offline Editing Flow

**File**: `test/services/offline_memory_editing_test.dart` (new)

Suggested test cases:

- Given a queued moment:
  - When user edits text only → queue entry text is updated, other fields unchanged.
  - When user adds/removes tags → tags updated.
  - When user adds/removes media → media paths updated.
  - When user adjusts location → location fields updated.
- Given a queued story:
  - Editing text & tags updates queue entry without disturbing audio metadata.
- Editing synced (online) memories:
  - Still uses existing online update flow and **requires connectivity** (not covered by new offline-edit tests but should be regression-checked elsewhere).

Use fakes for:

- `OfflineQueueService`
- `OfflineStoryQueueService`
- `ConnectivityService` (if referenced)

so that tests stay focused on local editing logic.

---

## Files to Create/Modify

### Files to Modify

- `lib/providers/capture_state_provider.dart`
  - Add offline editing state and `loadOfflineMemoryForEdit`.
- `lib/screens/memory/memory_detail_screen.dart`
  - Wire offline “Edit” button to offline editing flow.
- `lib/screens/capture/capture_screen.dart`
  - Route offline edits to `MemorySaveService.updateQueuedMemory`.
- `lib/services/memory_save_service.dart`
  - Implement `updateQueuedMemory` and helper methods.
- `lib/services/offline_queue_service.dart`
  - Verify/adjust `update` behaviour if needed.
- `lib/services/offline_story_queue_service.dart`
  - Verify/adjust `update` behaviour if needed.

### Files to Create

- `test/services/offline_memory_editing_test.dart`

---

## Success Criteria

- **Editing capability**
  - [ ] Users can edit **queued offline memories** while offline (text, tags, media, location).
  - [ ] Edits persist in the queue and survive app restarts.
- **Scope boundaries**
  - [ ] Editing **pre-existing synced memories** still requires connectivity (no new offline edit path for them).
  - [ ] No implementation attempts full offline editing for all server-backed memories (Phase 2 responsibility if ever added).
- **Sync metadata continuity**
  - [ ] Edited queue entries keep their sync metadata (status, retry counts, server IDs) so Phase 5 can sync them as usual.
- **Tests**
  - [ ] New tests validate offline editing behaviours for moments and stories.
  - [ ] Existing online editing flows remain unchanged and pass.

When Phase 4 is complete, users can safely **capture, view, and refine** offline memories while offline; Phase 5 will focus on how these edited queue entries transition cleanly into synced, server-backed memories and the preview index.


