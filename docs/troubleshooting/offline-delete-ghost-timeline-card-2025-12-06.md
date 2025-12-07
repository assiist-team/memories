# Offline delete leaves ghost timeline card (Dec 6, 2025)

## Summary
- Deleting a queued offline memory removes it from the queue but the timeline card reappears almost immediately, leaving a “ghost” entry that cannot be opened.
- Recent UI-side changes (directly calling `UnifiedFeedController.removeMemory`) did not resolve the issue, which means the card is being re-hydrated by another data source after the optimistic removal.
- We need to identify which source (queue persistence, preview index cache, or pagination refresh) is resurrecting deleted cards while offline.

## User impact
- Offline users delete a queued moment/memento/story, see the success toast, but the timeline still shows the card — causing confusion about whether content was actually removed.
- Opening the ghost card fails (detail screen can’t load because the queue entry is gone), leaving the app in a broken UX state until the next full refresh.
- Leads to mistrust in offline capture/delete reliability and blocks parity work for Dec 2025 milestones.

## Reproduction steps
1. Go offline (Airplane Mode).
2. Capture a new moment (photo) so it lands in the offline queue and timeline.
3. Open the moment’s detail view (using `MemoryDetailScreen` with `isOfflineQueued=true`).
4. Delete the memory via the offline delete confirmation.
5. Observe: toast shows “Moment deleted”, but the timeline still displays the card after returning to the feed.
6. Tap the ghost card → detail screen errors because the queue entry no longer exists.

## Observations
- `OfflineMemoryQueueService.remove(localId)` succeeds and emits `QueueChangeType.removed`.
- `_handleDeleteQueuedMemory` now also calls `unifiedFeedController.removeMemory(localId)` (Dec 6 patch), so the card briefly disappears.
- Within ~1 s the card comes back while still offline, but the resurrected card continues to have `isOfflineQueued == true`, meaning it is being rehydrated from the last `_fetchPage()` call rather than the preview index.
- `_handleQueueChange` fires `_fetchPage()` for every `added/updated` event. Those fetches can still be running when the user later deletes the memory. There's no inflight cancellation or generation check, so when the stale `_fetchPage()` completes it blindly overwrites `state.memories` and restores the just-deleted entry.
- Preview index writes are derived only from online RPC rows (`serverId: m.serverId ?? m.id`). The offline delete path only calls `removePreviewByServerId` when `serverMemoryId` is known. For brand new offline captures (no server ID yet) the preview store is not involved at all—confirming the current repro is not a preview-cache problem.
- We still lack an offline “tombstone” list of deleted server IDs, so deleting a previously-synced memory while offline would be re-added via previews even after we fix the stale `_fetchPage()` race.

## Hypotheses
- **H1: Stale `_fetchPage()` response overwrites the optimistic removal** – The queue `added/updated` branch always launches a fresh `_fetchPage()`. If that response finishes after the subsequent delete, it rewrites controller state with the old queued item. We need either per-fetch generation tokens, cancellation, or a follow-up `_fetchPage()` after deletes so the latest write wins.
- **H2: Preview dedupe still lacks tombstones for server-backed deletes** – When the user deletes a memory that already has a `serverId`, offline refresh will continue to surface it from previews because we never persist a `deletedServerIds` / `deletedLocalIds` buffer. This is a separate problem we still need to solve for parity.
- (Retired) Prior preview-index hypotheses no longer match the logs for “brand-new offline capture gets deleted immediately.” Keeping the note here so nobody re-invests time in that branch unless telemetry shows `isPreviewOnly == true` on the ghost card.

## Next steps
1. Add fetch generation tokens (or cancelable futures) to `_fetchPage()` so only the latest invocation mutates controller state. Alternatively, replay a fresh `_fetchPage()` as soon as `QueueChangeType.removed` fires so the final write reflects the deletion.
2. Cut `_handleQueueChange` offline work: if we already emit `MemoryTimelineEvent.created` for queued saves, the `added/updated` branch doesn’t need to fire `_fetchPage()` while offline. Avoiding the redundant fetch removes the race entirely.
3. If we keep `_fetchPage()` on add/update, make it re-check queue membership immediately before committing to `state` (ignore entries whose `localId` is missing) and gate the state assignment on the generation ID.
4. Persist a `deletedServerIds` / `deletedLocalIds` tombstone set while offline. `fetchMergedFeed` should filter both preview and queue results against that set until we reconcile with the server.
5. Regression test coverage:
   - `unified_feed_provider_test`: deleting a queued memory keeps it removed even if a stale `_fetchPage()` completes afterwards.
   - `unified_feed_repository_offline_test`: preview merge honors tombstones for offline deletes of server-backed cards.

## Dec 7 update – stale `_fetchPage()` identified as primary ghost source
- Instrumentation shows the ghost card still carries `isOfflineQueued == true`. That means `_fetchPage()` is returning the deleted queue item, not a preview entry. The race happens because `_handleQueueChange` kicked off a fetch when the memory was added/updated, and that fetch commits after the delete.
- Preview-store purge logic is functioning (it never runs for new offline captures because they lack a `serverId`). We can stop chasing preview corruption for this specific repro.
- Action items:
  - Implement fetch-generation guards or cancellation to stop stale responses from mutating controller state.
  - Once the race is fixed, proceed with the tombstone plan so offline deletes of synced memories don’t reappear via previews.
  - Keep lightweight logging in `_fetchPage()` (localId + flags) until we verify in production that ghosts no longer have `isOfflineQueued == true`.

## Owners / status
- **Owner:** Timeline team (Benjamin)
- **Status:** Still open – Dec 7 purge attempt failed (ghost cards persist even after preview removal). Need deeper instrumentation of preview fetch + dedupe logic.
