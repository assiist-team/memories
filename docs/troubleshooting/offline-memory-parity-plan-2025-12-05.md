# Offline Memory Parity Plan — 2025-12-05

## Context
- Offline captures currently remain on the capture experience, only showing a toast.
- The timeline is unaware of the new queued entry unless it was already in a `ready`/`empty` state, so the newly queued memory is absent when the user manually navigates back.
- Expected behavior: immediate navigation to timeline plus an in-feed card with a pending/offline badge, matching the online save flow.

## Goals
1. Ensure offline save UX mirrors online saves (navigation + status indicator on the correct timeline position).
2. Guarantee the unified timeline always receives a deterministic signal to render the queued memory, even if it has not loaded yet.
3. Keep the implementation resilient to future queue expansions and minimize regressions through testing/telemetry.

## Recommended Changes

### 1. Align Capture-Screen Navigation Flow (`lib/screens/capture/capture_screen.dart`)
- After `_showOfflineQueueSuccess`, explicitly:
  - Unfocus input, `Navigator.pop` when possible, and call `mainNavigationTabNotifierProvider.switchToTimeline()` so the user lands on the timeline tab even when the capture sheet is the root.
  - Emit `MemoryTimelineEvent.created` with the queued memory’s `localId`. This mirrors the online path and avoids relying solely on queue listeners.
- Keep the success toast, but add haptics or brief confirm animation if desired for parity.

### 2. Broadcast Offline Creations to the Feed Bus (`lib/providers/memory_timeline_update_bus_provider.dart` consumers)
- For the offline branch inside `_handleSave`, call `bus.emitCreated(localId)` immediately after enqueueing the new `QueuedMemory`.
- For offline edits, continue emitting `emitUpdated` with the target server ID so cached cards refresh predictably.

### 3. Make Unified Feed React When Not Yet Ready (`lib/providers/unified_feed_provider.dart`)
- Update `_handleQueueChange` so `QueueChangeType.added/updated` events trigger a data load even if the controller is still in `initial/loading` states. Options:
  - If state is `initial`, call `loadInitial()`; otherwise, keep the current `_fetchPage` refresh.
  - Alternatively, always refresh but guard against concurrent loads with a flag.
- When handling the new `MemoryTimelineEvent.created` for queued IDs, short-circuit by constructing the `TimelineMemory` via `OfflineQueueToTimelineAdapter` so the UI updates without waiting for disk fetch.

### 4. Validation & Telemetry
- Add widget tests covering:
  - `CaptureScreen` offline save -> verifies navigation intent and bus emission (can spy on providers).
  - `UnifiedFeedController` reacting to queue events while in `initial` and `ready` states.
- Instrument debug logging (already present) to log the emitted local ID and whether the feed refresh ran; gate noisy logs behind debug flags.
- Manually verify on device/Flight:
  - Airplane mode -> create each memory type -> confirm immediate timeline navigation, queued chip, and offline status banner.
  - Return online -> ensure sync completion removes the queued entry.

### 5. Follow-Up Nice-to-Haves
- Surface the offline toast inside the timeline (e.g., inline banner near the new card) for better visibility.
- Consider precomputing the expected card position (based on `memoryDate`) before navigation to enable smooth auto-scroll once timeline loads.

## Status — 2025-12-06
- Capture flow now unfocuses, pops when possible, switches to the timeline tab, and emits `MemoryTimelineEvent.created` *after* navigation so the listener is active.
- Offline saves enqueue their `localId` and the unified feed short-circuits queued creations via `OfflineQueueToTimelineAdapter`, ensuring the card appears even if the controller was still `initial`/`loading`.
- Queue change listeners learned to trigger `loadInitial()` when necessary and replay once the first load completes to avoid missed events.
- Pending follow-up: stabilize/extend the widget tests called out below and record the manual device verification notes once QA signs off.

## Definition of Done Checklist
- [x] Capture screen navigates to timeline after offline save, regardless of navigation stack depth.
- [x] Memory timeline update bus receives and broadcasts created events for offline enqueue operations.
- [x] Unified feed reflects queued entries even when it was not yet initialized.
- [ ] Tests updated/passing; manual verification notes captured in troubleshooting doc.
