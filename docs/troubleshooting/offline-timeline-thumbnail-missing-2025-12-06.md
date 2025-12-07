# Offline timeline thumbnail missing after offline edit (Dec 6, 2025)

## Summary
- Adding new photos/videos to an **offline-queued memory** updates the detail screen immediately but timeline preview cards (`MomentCard` / `MementoCard`) keep showing the text-only placeholder.
- The offline edit emits a `MemoryTimelineEvent.updated`, yet the feed either rebuilds from stale data or never sees the queued media paths, so `primaryMedia` stays `null`.
- Yesterday’s fix that rebuilt the card from `OfflineQueueToTimelineAdapter` did not change runtime behaviour; thumbnails still fail to appear.

## User impact
- Offline users think their edit failed because the timeline card never shows the newly added media (even though detail view proves the file exists).
- The only workaround is going online and forcing a full refresh, defeating the purpose of offline capture/edit parity.
- Breaks parity milestone for Dec 2025 and erodes trust in offline editing.

## Reproduction steps
1. Go offline.
2. Capture a new memory (photo) so it lands in the offline queue/timeline.
3. From the timeline, open that memory and edit it to add *another* photo (still offline).
4. Save; the detail screen shows both photos.
5. Return to the timeline → the card still displays the fallback badge (no thumbnail).

## Observations
- Detail screen renders the new photo via `MediaPreview` because `offlineMemoryDetailNotifier` exposes the fresh `PhotoMedia` list coming from the queue snapshot.
- Timeline cards rely on `TimelineMemory.primaryMedia`. Even after the offline edit, `primaryMedia` remains `null`/stale in the feed state, so `_buildThumbnail` takes the text-only path.
- Update handler attempts to rebuild from the queue:

```312:364:lib/providers/unified_feed_provider.dart
      case MemoryTimelineEventType.updated:
        final queueService = ref.read(offlineMemoryQueueServiceProvider);
        final queuedMemory =
            await queueService.getByLocalId(event.memoryId);
        if (queuedMemory != null) {
          final timelineMemory =
              OfflineQueueToTimelineAdapter.fromQueuedMemory(queuedMemory);
          // …
```

  but in repro logs `queuedMemory` returns `null`, so we fall through to the “offline refresh” branch which reloads cached preview data and keeps the old `primaryMedia`.
- The edit bus emits `emitUpdated(serverId)` even for offline queued edits, so `event.memoryId` rarely matches `localId`. That mismatch means we never reach the adapter branch.

## Hypotheses
1. **ID mismatch:** Offline edit path calls `emitUpdated(editingMemoryId)` using the *server* ID (which is null/unknown). The queue lookup requires `localId`, so it fails and we never rebuild from the queue snapshot.
2. **Queue snapshot timing:** Even if IDs matched, `_saveQueuedEdit` may not flush new `photoPaths` before the bus fires, so the adapter still reads the old media list.
3. **Preview store override:** `_fetchPage` invoked while offline may merge in stale preview entries that lack `primaryMedia`, overriding the freshly rebuilt card.

## Next steps
1. Instrument `CaptureScreen` / edit flow to confirm which ID is emitted for offline edits; ensure it emits the `localId` when `isOfflineQueued == true`.
2. Add an integration test in `unified_feed_provider_test.dart` covering “offline queued memory edit adds photo → card shows `isLocal` thumbnail”.
3. Ensure `_saveQueuedEdit` flushes updated `photoPaths` before notifying listeners / firing bus events.
4. Consider forcing `_fetchPage` to prefer matching queue entries by `serverId` **or** `localId` so preview-store merges cannot overwrite them.

## Owners / status
- **Owner:** Timeline & Offline Capture
- **Status:** Open – regression reproduced Dec 6 (post patch). Needs ID fix + instrumentation before next attempt.
