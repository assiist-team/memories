## Offline Memory Viewing & Editing – Code-Level Implementation Checklist (2025-11-21)

This checklist ties the consolidated change plan directly to the current Dart implementation. It is scoped to **Phase 1 offline support** and assumes the existing data model and queue/sync services.

---

### 1. Media Source Handling (Local vs Supabase)

**Goal**: Stop signing local file paths; route local photos/videos through `File`-based widgets.

#### 1.1 Extend media models with a source field

- **File**: `lib/models/timeline_moment.dart`
- **Current**:

```261:291:lib/models/timeline_moment.dart
class PrimaryMedia {
  final String type; // 'photo' or 'video'
  final String url; // Supabase Storage path
  final int index;
  ...
  bool get isPhoto => type == 'photo';
  bool get isVideo => type == 'video';
}
```

- **Required changes**:
  - Introduce:
    - `enum MediaSource { supabaseStorage, localFile }`
  - Extend `PrimaryMedia`:
    - Add `final MediaSource source;`
    - Add `bool get isLocal => source == MediaSource.localFile;`
  - Update:
    - `PrimaryMedia.fromJson(...)` to read a `source` string and default to `MediaSource.supabaseStorage` when missing.
    - `PrimaryMedia.toJson()` to write a `source` string.
  - **Server-backed paths** (`TimelineMoment.fromJson`) should always produce `MediaSource.supabaseStorage`.

> Follow-up (Phase 1+): mirror `MediaSource` into `PhotoMedia` / `VideoMedia` in `memory_detail.dart` so detail view logic can branch the same way as card thumbnails.

#### 1.2 Mark offline media as local in the offline detail provider

- **File**: `lib/providers/offline_memory_detail_provider.dart`
- **Current**:

```38:53:lib/providers/offline_memory_detail_provider.dart
final photos = queued.photoPaths.asMap().entries.map((entry) {
  return PhotoMedia(
    url: entry.value, // Local file path
    index: entry.key,
    caption: null,
  );
}).toList();
...
final videos = queued.videoPaths.asMap().entries.map((entry) {
  return VideoMedia(
    url: entry.value, // Local file path
    index: entry.key,
    duration: null,
    posterUrl: null,
    caption: null,
  );
}).toList();
```

- **Required changes**:
  - Extend `PhotoMedia` / `VideoMedia` with a `MediaSource` (or equivalent) field and `isLocal` getter.
  - In `_toDetailFromQueuedMoment` and `_toDetailFromQueuedStory`:
    - Normalize paths to `file://` form if desired for clarity.
    - Set `source: MediaSource.localFile` for all media created from queue paths.
    - Optionally, drop entries whose file no longer exists to avoid thrashing network code.

#### 1.3 Branch card thumbnails on `isLocal`

- **File**: `lib/widgets/moment_card.dart`
- **Current** (always uses signed URLs):

```218:248:lib/widgets/moment_card.dart
final media = moment.primaryMedia!;
final bucket = media.isPhoto ? 'moments-photos' : 'moments-videos';

// Get signed URL from cache or generate new one
final signedUrl = imageCache.getSignedUrl(
  supabase,
  bucket,
  media.url,
);
...
Image.network(
  snapshot.data!,
  width: thumbnailSize,
  height: thumbnailSize,
  fit: BoxFit.cover,
)
```

- **Required changes**:
  - Before requesting a signed URL:
    - If `media.isLocal`:
      - Interpret `media.url` as a local path (strip `file://` if present).
      - If `File(path).exists()`:
        - Use `Image.file(File(path), ...)` for photos.
        - Use a basic file-backed video thumbnail strategy for videos (e.g., static frame, generic “VIDEO” chip).
      - If file is missing:
        - Render the existing “broken image” / text-only placeholder.
      - **Skip** `imageCache.getSignedUrl` entirely.
    - Else:
      - Preserve current Supabase signing behaviour.

> Apply the same pattern to any other card components that render `PrimaryMedia` (`StoryCard`, `MementoCard`, etc.) when they are added.

#### 1.4 Branch detail previews on `isLocal`

- **File**: `lib/widgets/media_preview.dart`
- **Current** (always Supabase):

```123:128:lib/widgets/media_preview.dart
future: imageCache.getSignedUrlForDetailView(
  supabase,
  'moments-photos',
  photo.url,
),
```

```198:205:lib/widgets/media_preview.dart
final videoUrl = await imageCache.getSignedUrlForDetailView(
  supabase,
  'moments-videos',
  widget.video.url,
);
_controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
```

- **Required changes**:
  - For `_PhotoPreview` and `_LightboxPhotoSlide`:
    - If `photo.isLocal`:
      - Use `Image.file(File(localPath))`, with a “broken image” fallback when the file is gone.
    - Else:
      - Keep the signed URL + `Image.network` flow.
  - For `_VideoPreview` and `_LightboxVideoSlide`:
    - If `video.isLocal`:
      - Use `VideoPlayerController.file(File(localPath))`.
      - If the file is missing, show a simple “missing media” placeholder instead of an endless spinner.
    - Else:
      - Keep the existing Supabase-backed controller.

---

### 2. Queue Change Propagation to Unified Feed

**Goal**: When the offline queues change (enqueue, update, remove), the unified timeline should update without manual refresh.

#### 2.1 Add queue-change events to queue services

- **Files**:
  - `lib/services/offline_queue_service.dart`
  - `lib/services/offline_story_queue_service.dart`

- **Current**: Only SharedPreferences persistence; no reactive notifications.

```39:79:lib/services/offline_queue_service.dart
Future<void> enqueue(QueuedMoment moment) async { ... }
Future<void> update(QueuedMoment moment) async { await enqueue(moment); }
Future<void> remove(String localId) async { ... }
```

- **Required changes**:
  - Define a small event model:

    ```dart
    enum QueueChangeType { added, updated, removed }

    class QueueChangeEvent {
      final String localId;
      final String memoryType; // or MemoryType
      final QueueChangeType type;

      QueueChangeEvent({
        required this.localId,
        required this.memoryType,
        required this.type,
      });
    }
    ```

  - In each queue service:
    - Add a `StreamController<QueueChangeEvent>.broadcast()` and:
      - `Stream<QueueChangeEvent> get changeStream => _controller.stream;`
    - After `enqueue`, `update`, and `remove`, emit a `QueueChangeEvent` with clear, self-explanatory fields.

#### 2.2 Make `UnifiedFeedController` listen and refresh

- **File**: `lib/providers/unified_feed_provider.dart`

- **Current**: Only listens to `MemorySyncService.syncCompleteStream` to remove queued entries on successful sync.

```122:131:lib/providers/unified_feed_provider.dart
_syncSub = syncService.syncCompleteStream.listen((event) {
  _removeQueuedEntry(event.localId);
});
```

- **Required changes**:
  - Wire in the queue services (or a combined `OfflineQueueChangeService`) in the provider setup.
  - Add subscriptions to `OfflineQueueService.changeStream` and `OfflineStoryQueueService.changeStream`.
  - For an initial, simple implementation:
    - On any `QueueChangeEvent`:

      ```dart
      await _fetchPage(
        cursor: null,
        append: false,
        pageNumber: 1,
      );
      ```

    - This re-runs `UnifiedFeedRepository.fetchMergedFeed` with the latest queue + preview index data.
  - Later optimization (optional):
    - For `added` / `updated`, use `OfflineQueueToTimelineAdapter` to insert/update individual items in `state.memories`.
    - For `removed`, reuse `_removeQueuedEntry(localId)` to drop the queued card immediately.

#### 2.3 Keep capture flows dumb and reactive

- **File**: `lib/screens/capture/capture_screen.dart`

- **Current**: After enqueueing, only the queue-status chip is invalidated.

```414:425:lib/screens/capture/capture_screen.dart
final queuedMoment = QueuedMoment.fromCaptureState(...);
await queueService.enqueue(queuedMoment);

// Invalidate queue status to refresh UI
ref.invalidate(queueStatusProvider);
```

- **Required changes**:
  - Leave this code as-is for queue status display.
  - Rely on the new queue-change events to drive `UnifiedFeedController` so that:
    - After saving offline, the user immediately sees a new queued card.
    - After editing a queued memory, the card updates without a full pull-to-refresh.

---

### 3. Delete Path for Queued vs Synced Memories

**Goal**: Deleting queued memories should operate entirely locally on the queues; only synced memories should call Supabase.

#### 3.1 Branch delete FAB on `isOfflineQueued`

- **File**: `lib/screens/memory/memory_detail_screen.dart`

- **Current**: Delete FAB is always guarded by online connectivity and always calls the online delete path.

```703:741:lib/screens/memory/memory_detail_screen.dart
onPressed: isOnline
    ? () => _showDeleteConfirmation(context, ref, memory)
    : () => _showOfflineTooltip(context, 'Delete requires internet connection'),
```

- **Required changes**:
  - For offline queued details (`widget.isOfflineQueued == true` / `_buildOfflineDetailScreen` path):
    - Use a separate confirmation and delete handler for queued items.
    - Do **not** block queued deletes on `isOnline`; they are local operations.

#### 3.2 Implement a dedicated queue-delete handler

- **File**: `lib/screens/memory/memory_detail_screen.dart`

- **Current**: `_handleDelete` always goes through `memoryDetailNotifierProvider(...).deleteMemory()` and removes from the unified feed by `memory.id`:

```939:970:lib/screens/memory/memory_detail_screen.dart
final notifier = ref.read(memoryDetailNotifierProvider(widget.memoryId).notifier);
...
// Optimistically remove from unified feed
unifiedFeedController.removeMemory(memory.id);

// Delete from backend
final success = await notifier.deleteMemory();
```

- **Required changes**:
  - Introduce `_handleDeleteQueuedMemory(BuildContext, WidgetRef, MemoryDetail detail)`:
    - Decide queue service based on `detail.memoryType`:
      - Moments/mementos → `OfflineQueueService.remove(detail.id)`.
      - Stories → `OfflineStoryQueueService.remove(detail.id)`.
    - Let the queue-change event for `QueueChangeType.removed` drive the unified feed update.
  - Wire `_handleDeleteQueuedMemory` from the offline detail path instead of `_handleDelete`.
  - Keep `_handleDelete` for server-backed memories only.

---

### 4. Optional Consistency Cleanups

These are not blocking, but will reduce surprises and duplication over time:

- **Connectivity checks**:
  - `UnifiedFeedController.loadInitial` and `_fetchPage` both consult `ConnectivityService`.
  - Consider capturing `isOnline` once at the caller and passing it into `_fetchPage` to keep the source of truth obvious.

- **Offline sync status**:
  - `TimelineMoment.offlineSyncStatus` and queue `status` strings both model sync state.
  - The offline banner currently re-derives `OfflineSyncStatus` by reading the queue again.
  - Longer-term, consider passing a `TimelineMoment` (or at least its `offlineSyncStatus`) into `MemoryDetailScreen` when navigating for queued items so the UI doesn’t need to map the queue string a second time.

---

### 5. Test Coverage Pointers

For each area above, add lightweight tests to catch regressions:

- **Media source handling**:
  - Widget tests injecting queued memories with local paths and verifying:
    - `Image.file` / `VideoPlayerController.file` are used when offline.
    - Missing files fall back to placeholders without Supabase calls.
- **Queue change propagation**:
  - Provider tests for `UnifiedFeedController` with fake queue services that emit `QueueChangeEvent`s and assert:
    - Enqueue → new card appears.
    - Update → card content refreshes.
    - Remove → card disappears.
- **Queue delete path**:
  - Tests for the offline delete handler ensuring:
    - The queue entry is removed.
    - The unified feed no longer contains the local card.
    - No Supabase delete operation is invoked for queued-only items.

This checklist should be treated as the “what to change in which file” companion to `offline-memory-viewing-editing-consolidated-changes-2025-11-21.md` and the Phase 1–6 docs.


