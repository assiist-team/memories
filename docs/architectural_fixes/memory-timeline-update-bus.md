## Memory Timeline Update Bus – Decoupling Capture from Timeline

**Last Updated:** 2025-11-25  
**Status:** Draft – not yet implemented

### Problem

Right now, the capture screen (`CaptureScreen`) knows too much about the unified timeline:

- It imports `unified_feed_provider` and `unified_feed_tab_provider`.  
- After an **edit** succeeds, it directly calls `removeMemory(editingMemoryId)` on the `UnifiedFeedController`.

This works, but:

- Couples capture to a specific feed implementation.  
- Makes it hard to evolve the feed (e.g., multiple feeds, different views).  
- Sprinkles “timeline invalidation” logic inside a screen that should really only care about saving memories.

### Goal

**Single responsibility for timeline updates**:

- Capture / detail / delete flows should **emit simple events** like “memory X was updated” or “memory X was deleted”.  
- The **timeline layer** should decide how to react (remove, refresh, merge, etc.).

We get:

- Cleaner boundaries between capture/detail and feed.  
- Easier future changes (multiple feeds, background refresh, etc.).  
- Fewer places that need to know about `unifiedFeedControllerProvider`.

---

## Design – `MemoryTimelineUpdateBus`

### High-Level Concept

Introduce a tiny, app-wide **event bus** for memory timeline updates:

- A Riverpod provider that exposes a simple API:
  - `emitUpdated(String memoryId)`
  - `emitDeleted(String memoryId)`
- Backed by a `StreamController<MemoryTimelineEvent>` or a `StateNotifier<List<...>>` depending on what fits best with existing patterns.

**Event type**:

```startLine:endLine:lib/providers/(planned)_memory_timeline_update_bus.dart
enum MemoryTimelineEventType { updated, deleted }

class MemoryTimelineEvent {
  final MemoryTimelineEventType type;
  final String memoryId;

  MemoryTimelineEvent.updated(this.memoryId) : type = MemoryTimelineEventType.updated;
  MemoryTimelineEvent.deleted(this.memoryId) : type = MemoryTimelineEventType.deleted;
}
```

(Exact file and provider naming to be finalized when implementing; above is conceptual.)

---

## Data Flow After Refactor

### 1. Capture / Detail / Delete Emit Events

Places that currently “reach into” the feed:

- `CaptureScreen` after a successful **online edit**.  
- Any delete flows that remove a memory from Supabase.

Instead of:

- Importing `unified_feed_provider` / `unified_feed_tab_provider`.  
- Calling `removeMemory(editingMemoryId)` directly.

They will:

- Read the bus provider and emit an event:

```startLine:endLine:lib/screens/capture/capture_screen.dart
// Pseudocode for success path after updateMemory()
final bus = ref.read(memoryTimelineUpdateBusProvider);
bus.emitUpdated(editingMemoryId);
```

### 2. Unified Feed Listens and Reacts

`UnifiedFeedController` subscribes to the bus in `build()`:

- On `MemoryTimelineEventType.updated`:
  - For now, call `removeMemory(memoryId)` and rely on the next fetch/refresh to pull updated server data.
  - Later, we could add a “refresh single memory” path if we have a cheap `get_memory_by_id` RPC.
- On `MemoryTimelineEventType.deleted`:
  - Call `removeMemory(memoryId)` and **do not** expect it to reappear from the server.

This keeps the logic:

- “What does it mean to update/delete a memory in the timeline?”  
inside the **feed controller**, not the capture UI.

---

## Implementation Plan

### Step 1 – Create the Bus Provider

- New file (suggested): `lib/providers/memory_timeline_update_bus_provider.dart`
- Responsibilities:
  - Hold a `StreamController<MemoryTimelineEvent>` (broadcast).  
  - Expose:
    - `Stream<MemoryTimelineEvent> get stream`  
    - `void emitUpdated(String memoryId)`  
    - `void emitDeleted(String memoryId)`

### Step 2 – Wire Capture / Delete Flows to Emit

- **CaptureScreen**:
  - In the **online edit** success path (after `updateMemory`), replace direct calls to `removeMemory` with:
    - `emitUpdated(editingMemoryId)`.
- **Delete flows** (e.g., in `memory_detail_screen` / `memory_detail_service` consumers):
  - After a successful delete RPC, call:
    - `emitDeleted(memoryId)`.

### Step 3 – Subscribe in `UnifiedFeedController`

- In `build()` of `UnifiedFeedController`:
  - Read the bus provider, subscribe to `stream`.
  - On dispose, cancel the subscription.
- Handler logic:
  - `updated(memoryId)` → `removeMemory(memoryId)` (current simple behaviour).
  - `deleted(memoryId)` → `removeMemory(memoryId)` and optionally log analytics.

### Step 4 – Remove Direct Timeline Dependencies from Capture

- Remove imports of:
  - `unified_feed_provider.dart`
  - `unified_feed_tab_provider.dart`
- Remove direct calls to `removeMemory` in `CaptureScreen`.
- Keep navigation and detail refresh logic in `CaptureScreen` (that’s still its responsibility).

---

## Offline & Caching Considerations

This refactor is **deliberately conservative** with respect to offline behaviour:

- **Offline queued memories**:
  - Still come from `fetchQueuedMemories` using `OfflineQueueToTimelineAdapter`.
  - The bus is only used for **online edits / deletes**; offline queue updates continue to flow via:
    - `MemorySaveService.updateQueuedMemory`.
    - `MemorySyncService` + existing `SyncCompleteEvent` stream.
- **Preview index**:
  - Unchanged. We still:
    - Upsert previews in `_fetchOnlinePage`.
    - Use them when offline (`fetchPreviewIndexMemories`).
- The bus exists **only to route “this memory changed on the server”** into the unified feed without having capture screens know timeline internals.

---

## Risks & Future Extensions

**Risks (low):**

- Event bus not subscribed:
  - Symptoms: edits & deletes succeed, but timeline doesn’t immediately reflect them until a manual refresh.
  - Mitigation: unit test or integration test verifying that an `emitUpdated` causes `removeMemory` in `UnifiedFeedController`.

**Future extensions:**

- Add a `MemoryTimelineEventType.refreshed` that triggers:
  - A targeted fetch of a single memory if we introduce a cheap RPC (`get_memory_by_id`), enabling true in-place updates.
- Use the same bus for:
  - Background sync notifications.
  - Cross-tab or cross-screen invalidation (e.g., detail screen edits causing other views to refresh).

---

## Summary

This “timeline update bus” is a small structural change that:

- Removes direct dependencies from `CaptureScreen` to the unified feed controller.  
- Keeps **offline caching and queue semantics exactly as they are today**.  
- Centralizes “what to do when a memory changes” in the timeline layer, where it belongs.


