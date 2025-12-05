# Offline queued memories fail to open (Dec 5, 2025)

## Summary
- Offline timelines can still show queued memories that were already removed from local storage. Opening one yields `Offline queued memory not found` and leaves the user stuck on the detail screen.
- Offline edits/failed retries never appear in the timeline because the queue-to-timeline adapter filters out every entry with a `serverId`, even though updates carry that field.
- The offline detail error view retries the *online* provider and offers no escape hatch, so users have to force-close or background the app.

## User impact
- Encountering a "pending sync" card that has already synced or failed now traps the user on an error screen because the queue entry is gone.
- Offline edits cannot be reviewed in the feed, causing confusion about whether the change saved at all.
- Background sync churn keeps recreating ghost cards, so the issue can repeat indefinitely until the app is relaunched.

## Evidence
- Logcat shows the offline detail provider throwing `Exception: Offline queued memory not found: 29407acc-...` and the UI looping on retries.
- Stack traces confirm the detail screen re-invokes `memoryDetailNotifierProvider` rather than the offline provider when the user taps Retry.
- Unified feed update logs (`[UnifiedFeedController] Handling updated event...`) demonstrate that queue events were processed, yet the stale card stayed visible until tapped.

## Root causes
1. **Stale queue snapshot is committed after removal events**  
   `_fetchPage` assigns the merged feed straight into state without re-validating queued entries, so a queued item removed during the fetch reappears when the fetch finishes. (`lib/providers/unified_feed_provider.dart` lines 632-681)
2. **Navigation assumes every offline card still exists in storage**  
   `_navigateToDetail` routes to the offline detail screen solely based on `memory.isOfflineQueued` and never re-checks the queue. (`lib/screens/timeline/unified_timeline_screen.dart` lines 232-264)
3. **Offline edits filtered out of the feed**  
   `fetchQueuedMemories` throws away any queue row with a `serverId`, which removes every offline edit/failed retry from the merged feed. (`lib/services/unified_feed_repository.dart` lines 243-265)
4. **Offline detail error view retries the wrong provider**  
   `_buildErrorState` always calls `memoryDetailNotifierProvider(...).refresh()` and never offers a way to pop when the offline provider fails. (`lib/screens/memory/memory_detail_screen.dart` lines 600-694)

## Remediation plan
1. **Validate queue membership before committing fetch results**  
   - After `_fetchPage` returns, re-query `offlineMemoryQueueService` and drop any queued entry whose `localId` is missing before calling `state = state.copyWith(...)`.  
   - Add a regression test that simulates `QueueChangeType.removed` firing while `_fetchPage` awaits the RPC, ensuring the stale entry is not reintroduced.
2. **Guard navigation with the queue service**  
   - In `_navigateToDetail`, if `memory.isOfflineQueued` is true, call `offlineMemoryQueueService.getByLocalId(memoryId)` and bail out with a snackbar if it returns null.  
   - As a fallback, if we know the `serverId`, redirect to the online detail screen instead of pushing the offline route.
3. **Stop filtering queued updates**  
   - Remove `results.where((m) => m.serverId == null)` or replace it with a `status == 'completed'` check so offline edits remain visible until the queue actually drops them.  
   - Extend unit coverage to ensure queued updates appear in the merged feed while offline.
4. **Improve offline detail error handling**  
   - When `offlineMemoryDetailNotifier` throws `Offline queued memory not found`, show inline guidance (“This memory already synced. Refresh the timeline.”) with a primary button that pops the route.  
   - The Retry button should invoke the offline provider again or, if connectivity is available and the server id is known, switch to the online provider.

## Verification
1. Queue a memory, force removal (by syncing) while the feed is loading, and confirm the card disappears without reappearing post-fetch.
2. Attempt to open a queued card after it synced; the app should refuse navigation or fall back to the server detail without getting stuck.
3. Capture a memory, go offline, edit it, and confirm the edit card stays visible in the feed.
4. Trigger the "offline queued memory not found" path and verify the new error UI lets the user leave gracefully.
