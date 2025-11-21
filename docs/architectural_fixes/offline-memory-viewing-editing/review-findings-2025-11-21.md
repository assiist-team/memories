# Offline Memory Viewing & Editing — Review Findings (2025-11-21)

## Summary
- Local media from queued memories is still routed through Supabase signing/streaming, so offline photo/video viewing fails despite the files existing on-device.
- The unified timeline never hears about queue mutations, meaning queued captures/edits are invisible until users manually refresh or the provider rebuilds.
- The delete affordance on queued memories always calls the online detail provider and never touches the queue, so offline items cannot actually be removed.
- None of the above flows have UI/automation coverage, so regressions slip in silently.

---

## Issue 1 – Local media still treated as Supabase objects (Severe)

### Expectation vs. implementation
The plan explicitly calls for adapters to mark local media so the UI can skip Supabase and fall back to placeholders if files vanish:

```455:462:docs/architectural_fixes/offline-memory-viewing-editing/README.md
3. **Local media storage location**  
   Do **not** duplicate files. The queue already records absolute paths; the adapter now marks the resulting `PrimaryMedia` as `isLocal` so UI widgets can gate loading logic (placeholders, retries) without copying bytes. If a file is missing, the adapter simply returns `null` and `MomentCard`/`StoryCard` fall back to the existing text-only treatment.
```

However:

```262:291:lib/models/timeline_moment.dart
class PrimaryMedia {
  final String type; // 'photo' or 'video'
  final String url; // Supabase Storage path
  final int index;
  ...
  bool get isPhoto => type == 'photo';
  bool get isVideo => type == 'video';
}
```

`PrimaryMedia`, `PhotoMedia`, and `VideoMedia` all assume their URLs live in Supabase. The timeline/detail widgets therefore request signed URLs even for `file://` or absolute filesystem paths that come from the queues:

```218:285:lib/widgets/moment_card.dart
final media = moment.primaryMedia!;
final bucket = media.isPhoto ? 'moments-photos' : 'moments-videos';
final signedUrl = imageCache.getSignedUrl(
  supabase,
  bucket,
  media.url,
);
return FutureBuilder<String>(
  future: signedUrl,
  builder: ...
      child: Image.network(
        snapshot.data!,
        ...
```

```123:161:lib/widgets/media_preview.dart
return FutureBuilder<String>(
  future: imageCache.getSignedUrlForDetailView(
    supabase,
    'moments-photos',
    photo.url,
  ),
  builder: (context, snapshot) {
    if (snapshot.hasError || !snapshot.hasData) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: Icon(
            Icons.broken_image,
            color: Colors.grey,
            size: 64,
          ),
        ),
      );
    }
    return ClipRRect(
      ...
      child: Image.network(snapshot.data!)
```

Yet the offline detail provider feeds those widgets raw local paths:

```18:95:lib/providers/offline_memory_detail_provider.dart
final photos = queued.photoPaths.asMap().entries.map((entry) {
  return PhotoMedia(
    url: entry.value, // Local file path
    index: entry.key,
    caption: null,
  );
}).toList();
...
return MemoryDetail(
  id: queued.localId,
  ...
  photos: photos,
  videos: videos,
);
```

### Impact
- Offline detail and timeline screens display broken images/videos (“failed to load thumbnail”) even though files are present locally.
- Video playback tries to stream via HTTPS, so it never starts while offline.
- The UX violates the Phase-3/4 acceptance criteria (“queued offline memories show full detail and media offline”).

### Remediation
1. Extend `PrimaryMedia`, `PhotoMedia`, and `VideoMedia` with an `isLocal` (or `source`) flag and/or normalize URLs to `file://` when they are local.
2. Update adapters (`OfflineQueueToTimelineAdapter`, offline detail provider) to set that flag.
3. In `MomentCard`, `StoryCard`, `MementoCard`, `MediaStrip`, and `MediaPreview`, branch on `isLocal`/`file://`:
   - Use `File(...)` existence checks plus `Image.file` / `VideoPlayerController.file`.
   - Fall back to the existing placeholder chips if the file is missing.
   - Never call `TimelineImageCacheService`/Supabase for local files.
4. For local video posters, allow optional thumbnails but don’t require Supabase.

### Test coverage
- Add a widget test that injects a queued memory with local photo/video paths and asserts that `Image.file` renders when the app is offline.
- Add a golden/integration test for `MemoryDetailScreen` offline mode to ensure tapping “Edit” still works after the refactor.

---

## Issue 2 – Unified feed never hears about queue mutations (Severe)

Offline saves enqueue items but only invalidate the queue-status chip; the feed controller isn’t told to reload:

```414:442:lib/screens/capture/capture_screen.dart
final queuedMoment = QueuedMoment.fromCaptureState(...);
await queueService.enqueue(queuedMoment);

// Invalidate queue status to refresh UI
ref.invalidate(queueStatusProvider);
...
if (Navigator.of(context).canPop()) {
  Navigator.of(context).pop();
}
return;
```

The `UnifiedFeedController` only removes entries when sync completes, via a listener on `memorySyncService`:

```122:139:lib/providers/unified_feed_provider.dart
_syncSub = syncService.syncCompleteStream.listen((event) {
  _removeQueuedEntry(event.localId);
});

void _removeQueuedEntry(String localId) {
  final updated = state.memories
      .where((m) => !(m.isOfflineQueued && m.localId == localId))
      .toList();
  state = state.copyWith(memories: updated);
}
```

New or edited queued items only appear after `loadInitial`/`loadMore` runs again inside `_fetchPage`:

```260:305:lib/providers/unified_feed_provider.dart
final result = await repository.fetchMergedFeed(
  cursor: cursor,
  filters: _memoryTypeFilters,
  batchSize: _batchSize,
  isOnline: isOnline,
);
state = state.copyWith(
  memories:
      append ? [...state.memories, ...result.memories] : result.memories,
  ...
);
```

### Impact
- After capturing offline, the user returns to the timeline and sees nothing new; the card only appears after a full pull-to-refresh or app restart.
- Editing an offline memory doesn’t update the timeline until manual refresh, so users can’t verify their change “stuck.”
- Violates the success criteria “Offline memories visible in timeline with Pending Sync indicator.”

### Remediation
1. Introduce a queue-change notifier (e.g., `OfflineQueueService` emits a `Stream<void>` or Riverpod `Provider` invalidation) that fires on `enqueue`, `update`, and `remove`.
2. `UnifiedFeedController` should listen to that stream and:
   - Re-run `fetchMergedFeed` (cheap because it’s local only) when offline.
   - Add/update the affected `TimelineMoment` in-place when online.
3. Alternatively, invalidate `unifiedFeedControllerProvider` right after queue mutations in `CaptureScreen`/`MemorySaveService`.
4. Ensure `_removeQueuedEntry` still runs after sync to avoid duplicates when the server version arrives.

### Test coverage
- Add an integration/widget test that:
  1. Enqueues a queued moment via `OfflineQueueService`.
  2. Pumps `UnifiedTimelineScreen`.
  3. Asserts the new card appears without manual refresh.
- Add a regression test for editing: mutate an existing queued entry and verify the timeline reflects the newest title/snippet.

---

## Issue 3 – Delete action for queued memories hits the online provider (Severe)

The offline detail screen always wires the delete FAB to the online `memoryDetailNotifierProvider` even when `isOfflineQueued` is true:

```938:1016:lib/screens/memory/memory_detail_screen.dart
final notifier =
    ref.read(memoryDetailNotifierProvider(widget.memoryId).notifier);
...
// Optimistically remove from unified feed
unifiedFeedController.removeMemory(memory.id);

// Delete from backend
final success = await notifier.deleteMemory();
```

- `widget.memoryId` holds the **local** UUID for queued entries, so `deleteMemory()` just calls Supabase with an ID that does not exist and always throws.
- We never touch `OfflineQueueService` / `OfflineStoryQueueService`, so the queued item stays in storage and reappears on next launch.
- Even if the server call succeeded (for synced memories), we refresh the entire feed but never re-run queue merges, so the local card can reappear until sync completes.

### Impact
- Users cannot delete queued memories; the button silently fails and the card reappears.
- Depending on error handling, the detail screen may show misleading snackbars (“Failed to delete memory”) even though we really needed a queue removal.

### Remediation
1. When `widget.isOfflineQueued` is true, hide the delete FAB or route it through a dedicated queue deletion path:
   - Call `OfflineQueueService.remove(localId)` / `OfflineStoryQueueService.remove(localId)`.
   - Invalidate both `queueStatusProvider` and `unifiedFeedControllerProvider`.
2. Only call `memoryDetailNotifierProvider.deleteMemory()` for synced memories.
3. Consider confirming with the user that deleting a queued memory discards unsynced content.

### Test coverage
- Add a provider/widget test covering the offline delete path, asserting that:
  - The queue entry is removed.
  - The feed no longer contains the local card.
  - No Supabase call is attempted.

---

## Next Steps
1. **Design update**: Align on the new media source flag and deletion UX for queued entries.
2. **Implementation**: Execute the remediation steps above, touching adapters, UI widgets, queue services, and feed providers.
3. **Testing**: Backfill the outlined widget/integration tests to lock in the offline behaviors.
4. **Docs**: Update the project README/phase documents with the chosen naming (`isLocal`, queue refresh strategy, deletion behavior) once implemented.


