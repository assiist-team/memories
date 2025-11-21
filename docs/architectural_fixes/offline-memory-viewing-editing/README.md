# Offline Memory Viewing & Editing Implementation Plan

## Objective

Enable users to view and edit memories that were captured offline **before** they are synced to the server, and ensure the unified timeline remains coherent and useful when the device is offline. Currently, offline memories are queued but invisible in the timeline and cannot be edited until connectivity is restored and sync completes.

## Current State

### Offline Capture Flow
- When offline, `MemorySaveService.saveMoment()` throws `OfflineException`
- Memory is queued locally in SharedPreferences via `OfflineQueueService` or `OfflineStoryQueueService`
- Queued memories are stored as `QueuedMoment` or `QueuedStory` objects
- Queue contains all memory data: text, tags, media paths, location, etc.

### Timeline Display
- Timeline only queries database via `get_unified_timeline_feed` RPC
- Requires connectivity - throws exception if offline
- Only shows memories that exist in the `memories` table
- **Queued offline memories are NOT visible**

### Editing Capabilities
- `MemorySaveService.updateMemory()` requires connectivity
- Memory detail screen disables edit button when offline
- **Offline memories cannot be edited**

## Target State

### Offline Memory Visibility (Product Phase 1 – Preview-First)
- Timeline **always** displays:
  - Memories from database (synced memories) as lightweight **preview cards**
  - Queued offline memories (not yet synced) as fully interactive cards
- When the user goes offline:
  - The **same memories** remain visible in roughly the same order
  - Previously-synced memories are rendered from a **local preview index** (minimal metadata), not removed
  - Previously-synced memories that do **not** have full local detail/media cached are:
    - visually de-emphasized (e.g., greyed)
    - **not tappable** (or show a clear “Not available offline” message)
  - Queued offline memories remain fully tappable and editable
- The local preview index stores only what is needed to render cards:
  - Memory ID
  - Memory type (story / moment / memento)
  - Title or first-line text snippet
  - Captured date/time
  - Lightweight flags (e.g., `isOfflineQueued`, `isDetailCachedLocally`)

### Offline Memory Editing
- Users can edit **queued offline memories**:
  - Modify `input_text`
  - Add/remove tags
  - Add/remove photos/videos
  - Update location
- Edits are stored locally in the queue (or its replacement inside the local store)
- When connectivity returns, edited version syncs to server

### Full Offline Caching (Product Phase 2 – Opt-In)
- Users can opt in to **full offline caching** beyond previews:
  - Cache detail text and additional metadata for a larger window of memories (e.g., recent months) and/or
  - Explicitly mark specific memories or collections as “Available offline”
  - Optionally pre-download media (photos/audio/video) within reasonable storage limits
- When fully cached, previously-synced memories become **tappable offline**:
  - Detail screen loads from local cache first
  - Supabase is only required to refresh or sync changes
- Phase 2 builds on the same local store and preview index introduced in Phase 1; it **expands caching policy** rather than replacing it.

### Sync Behavior
- When sync completes, offline memory transitions from queue to database
- Timeline updates to show synced version (removes queue entry)
- No duplicate entries during transition

## Backward Compatibility Stance

- This initiative intentionally **drops backward compatibility** with the pre-offline timeline model.
- The new `TimelineMoment` contract, preview index, and queue adapters ship together; there is **no legacy fallback path**.
- Older app versions are expected to upgrade before these changes reach production. We will not maintain dual data shapes or shims to support legacy clients.
- Server-side RPCs and mobile consumers will move in lockstep. Any migrations should favor the new schema even if that means breaking the previous contract.

## Implementation Requirements

> The sections below describe the **technical phases** (1–6) for implementing **Product Phase 1 (preview-first offline)**. Product Phase 2 (full offline caching) will extend the same local store and models with broader caching policies.

### 1. Extend Timeline Data Model

**File**: `lib/models/timeline_moment.dart`

**Changes**:
- Add `isOffline` boolean field to indicate if memory is from queue
- Add `localId` field for offline memories (null for synced memories)
- Ensure model can represent both synced and queued memories

**New Fields**:
```dart
class TimelineMoment {
  // ... existing fields ...
  
  /// Whether this memory is queued offline (not yet synced)
  final bool isOffline;
  
  /// Local ID for offline memories (null for synced memories)
  final String? localId;
  
  /// Server ID (null for offline memories, set after sync)
  final String? serverId;
}
```

### 2. Create Offline Memory Adapter

**File**: `lib/services/offline_memory_adapter.dart`

**Purpose**: Convert `QueuedMoment`/`QueuedStory` to `TimelineMoment` format

**Key Methods**:
- `TimelineMoment fromQueuedMoment(QueuedMoment queued)` - Convert queued moment to timeline format
- `TimelineMoment fromQueuedStory(QueuedStory queued)` - Convert queued story to timeline format
- Handle media paths (convert local paths to displayable format)
- Generate appropriate title/display text for offline memories

**Considerations**:
- Offline memories won't have `processed_text` (LLM hasn't run)
- Use `input_text` for display
- Generate fallback title if needed
- Handle missing media gracefully (files may not exist if deleted)

### 3. Extend Unified Feed Repository

**File**: `lib/services/unified_feed_repository.dart`

**Changes**:
- Add method to fetch queued offline memories
- Add method to fetch locally cached **preview entries** for previously-synced memories
- Merge queued memories with preview entries (and live RPC results when online)
- Sort combined results chronologically

**High-Level Methods**:
- `Future<List<TimelineMoment>> fetchQueuedMemories({ Set<MemoryType>? filters })`
- `Future<List<TimelineMoment>> fetchPreviewIndexMemories({ Set<MemoryType>? filters })`
- `Future<UnifiedFeedPageResult> fetchMergedFeed({ UnifiedFeedCursor? cursor, Set<MemoryType>? filters, int batchSize = 20, required bool isOnline })`

**Offline Behavior (Repository Level)**:
- When **offline**:
  - Read from **local preview index** + queued memories only (no RPC)
  - Return a page of `TimelineMoment` objects where:
    - queued offline memories are fully interactive
    - previously-synced memories are treated as preview-only (UI decides tap behaviour)
- When **online**:
  - Fetch from database via `get_unified_timeline_feed`
  - Continuously update the local preview index from live results
  - Merge queued memories, preview index entries, and RPC results as needed

### 4. Update Unified Feed Provider

**File**: `lib/providers/unified_feed_provider.dart`

**Changes**:
- Support offline mode (show queued memories + preview entries when offline)
- Merge queued memories with database results when online
- Handle transition when offline memory syncs

**Key Updates**:
- `_fetchPage()` - Merge queued memories and preview entries with database results
- `loadInitial()` - When offline, show queued memories + preview entries (no RPC)
- Add listener for sync completion to update timeline

**Offline Behavior (UI Level)**:
- When offline:
  - Timeline items from **queue** are fully interactive (detail + editing)
  - Timeline items from **preview index only**:
    - render greyed out (visual “Not available offline” state)
    - either have `onTap` disabled or show a one-line explanation
- When online: Show merged view (database + queued), with previews kept in sync in the background.

### 5. Create Offline Memory Detail Provider

**File**: `lib/providers/offline_memory_detail_provider.dart`

**Purpose**: Provide memory detail view for offline queued memories

**Key Features**:
- Load memory data from queue (not database)
- Support editing queued memories
- Update queue entry when edited
- Convert `QueuedMoment`/`QueuedStory` to `MemoryDetail` format

**Methods**:
```dart
@riverpod
class OfflineMemoryDetailNotifier extends _$OfflineMemoryDetailNotifier {
  Future<MemoryDetail> build(String localId) async {
    // Load from appropriate queue
    // Convert to MemoryDetail format
  }
  
  Future<void> updateMemory(CaptureState updatedState) async {
    // Update queue entry with new data
    // Trigger UI refresh
  }
}
```

### 6. Update Memory Detail Screen

**File**: `lib/screens/memory/memory_detail_screen.dart`

**Changes**:
- Detect if memory is offline (check for `localId` or `isOffline` flag)
- Use `OfflineMemoryDetailProvider` for offline memories
- Enable editing for offline memories (no connectivity check)
- Show "Pending sync" indicator for offline memories
- For preview-only cards (previously-synced memories with no local detail), when offline:
  - either do **not** navigate to detail at all, or
  - navigate to a lightweight screen that explains the memory is not available offline.

**Key Updates**:
- Edit button enabled for offline memories
- Different provider based on memory type (synced vs offline)
- Visual indicator showing sync status

### 7. Update Capture State for Offline Editing

**File**: `lib/providers/capture_state_provider.dart`

**Changes**:
- Support loading offline memory for editing
- Update queue entry instead of database when editing offline memory

**New Methods**:
```dart
/// Load offline memory for editing
Future<void> loadOfflineMemoryForEdit({
  required String localId,
  required MemoryType memoryType,
  // ... other fields from QueuedMoment/QueuedStory
}) async {
  // Load from queue
  // Populate CaptureState
  // Set editingMemoryId to localId (not server ID)
}

/// Save edited offline memory
Future<void> saveEditedOfflineMemory() async {
  // Update queue entry instead of calling updateMemory()
  // Use OfflineQueueService.update() or OfflineStoryQueueService.update()
}
```

### 8. Update Memory Save Service

**File**: `lib/services/memory_save_service.dart`

**Changes**:
- Add method to update queued memory (for offline editing)
- Ensure sync service picks up edited queue entries

**New Method**:
```dart
/// Update a queued offline memory
/// 
/// This updates the queue entry directly without requiring connectivity.
/// The updated entry will sync when connectivity is restored.
Future<void> updateQueuedMemory({
  required String localId,
  required CaptureState state,
}) async {
  // Load appropriate queue service
  // Update queue entry with new state
  // No connectivity check needed
}
```

### 9. Update Queue Services

**Files**: 
- `lib/services/offline_queue_service.dart`
- `lib/services/offline_story_queue_service.dart`

**Changes**:
- Ensure `update()` method properly handles all fields
- Add method to get memory by localId (if not exists)
- Emit notifications when queue entries change (for UI updates)

**Key Updates**:
- `update()` - Update existing queue entry
- `getByLocalId()` - Already exists, verify it works correctly
- Add stream/notifier for queue changes (optional, for reactive UI)

### 10. Handle Sync Transition

**File**: `lib/services/memory_sync_service.dart`

**Changes**:
- When sync completes, notify timeline to refresh
- Remove offline memory from timeline (it's now in database)
- Ensure smooth transition (no duplicate entries)

**Key Updates**:
- After successful sync, emit event/notification
- Timeline provider listens and updates accordingly
- Remove queued memory from display, add synced version

### 11. Visual Indicators

**Files**:
- `lib/widgets/memory_card.dart`
- `lib/screens/memory/memory_detail_screen.dart`

**Changes**:
- Add "Pending sync" badge/indicator for offline memories
- Show sync status (queued, syncing, failed)
- Different styling for offline vs synced memories
- Visually distinguish:
  - fully available offline memories (queued, or fully cached in future)
  - preview-only memories that are not available offline

**UI Elements**:
- Badge on memory card: "Pending sync" or "Syncing..."
- Status indicator in detail view
- Disable share for offline memories (until synced)
- Greyed, non-tappable cards (or explicit “Not available offline” state) for preview-only entries when offline

## Implementation Steps

### Phase 1: Data Model & Adapter (Foundation)
1. Extend `TimelineMoment` model with offline fields
2. Create `OfflineMemoryAdapter` service
3. Add tests for adapter conversion

### Phase 2: Timeline Integration
4. Extend `UnifiedFeedRepository` to fetch queued memories and preview index entries
5. Update `UnifiedFeedProvider` to merge results and respect online/offline state
6. Test offline timeline display (queued + preview-only cards)

### Phase 3: Detail View Support
7. Create `OfflineMemoryDetailProvider`
8. Update `MemoryDetailScreen` to handle offline memories
9. Test offline memory detail view

### Phase 4: Editing Support
10. Update `CaptureStateProvider` for offline editing
11. Add `updateQueuedMemory()` to `MemorySaveService`
12. Update queue services if needed
13. Test offline memory editing

### Phase 5: Sync Integration
14. Update sync service to notify on completion
15. Handle transition from queue to database
16. Test sync transition

### Phase 6: UI Polish
17. Add visual indicators for offline status
18. Update memory card styling (including greyed non-tappable preview-only cards when offline)
19. Add sync status indicators
20. Test complete offline → online flow

## Files to Create/Modify

### New Files
- `lib/services/offline_memory_adapter.dart`
- `lib/providers/offline_memory_detail_provider.dart`
- `lib/providers/offline_memory_detail_provider.g.dart` (generated)
- `test/services/offline_memory_adapter_test.dart`
- `test/providers/offline_memory_detail_provider_test.dart`

### Files to Modify
- `lib/models/timeline_moment.dart` - Add offline fields
- `lib/services/unified_feed_repository.dart` - Add queued memory + preview index fetching
- `lib/providers/unified_feed_provider.dart` - Merge queued memories + previews
- `lib/screens/memory/memory_detail_screen.dart` - Support offline memories and preview-only states
- `lib/providers/capture_state_provider.dart` - Offline editing support
- `lib/services/memory_save_service.dart` - Add `updateQueuedMemory()`
- `lib/services/offline_queue_service.dart` - Verify update methods
- `lib/services/offline_story_queue_service.dart` - Verify update methods
- `lib/services/memory_sync_service.dart` - Notify on sync completion
- `lib/widgets/memory_card.dart` - Add offline and preview-only indicators

## Dependencies

- **Requires**: `OfflineQueueService` (exists)
- **Requires**: `OfflineStoryQueueService` (exists)
- **Requires**: `QueuedMoment` model (exists)
- **Requires**: `QueuedStory` model (exists)
- **Requires**: `MemorySaveService` (exists)
- **Requires**: `ConnectivityService` (exists)
- **Related**: Works with existing sync service

## Success Criteria

- [ ] Offline memories visible in timeline with "Pending sync" indicator
- [ ] Previously-synced memories remain visible as preview cards when offline (not silently removed)
- [ ] Users can open offline memory detail view for queued memories
- [ ] Users can edit offline memory text, tags, and media (queued)
- [ ] Edits persist in queue (survive app restart)
- [ ] When connectivity returns, edited version syncs to server
- [ ] Timeline updates smoothly when sync completes (no duplicates)
- [ ] Visual indicators clearly show offline vs synced vs preview-only status
- [ ] All tests pass
- [ ] No regressions in existing functionality

## Edge Cases & Considerations

### Media File Handling
- **Problem**: Local media files may be deleted or moved
- **Solution**: Validate file existence before display, show placeholder if missing
- **Consideration**: Large media files may consume significant local storage

### Queue Size Limits
- **Problem**: Queue could grow very large if user stays offline
- **Solution**: Consider pagination for queue display, or limit visible items
- **Consideration**: May need queue size limits or cleanup strategy

### Sync Conflicts
- **Problem**: User edits offline memory, then syncs, then edits again before sync completes
- **Solution**: Last edit wins, or merge strategy
- **Consideration**: Queue updates should be atomic

### Memory Type Handling
- **Problem**: Stories have different structure (audio) than moments/mementos
- **Solution**: Adapter handles both types appropriately
- **Consideration**: Ensure story editing works correctly

### Performance
- **Problem**: Merging preview index, queued memories, and database results could be slow
- **Solution**: Efficient sorting/merging, consider caching and pagination
- **Consideration**: May need preview index pagination separate from RPC pagination

## Testing Strategy

### Unit Tests
- `OfflineMemoryAdapter` - Conversion logic
- `OfflineMemoryDetailProvider` - Detail view loading
- Queue service update methods

### Integration Tests
- Offline capture → timeline display (queued + preview-only cards)
- Offline editing → queue update
- Sync completion → timeline update
- Offline → online transition (including preview-only cards becoming fully interactive once cached in future phases)

### Manual Testing
- Capture memory offline
- View in timeline
- Verify previously-synced memories still appear as preview cards when offline
- Edit memory offline
- Add/remove media offline
- Go online and verify sync
- Verify edited version syncs correctly

## Decisions on Previous Open Questions

1. **Queue pagination strategy**  
   Merge queued memories with the database page *before* applying pagination. `UnifiedFeedRepository.fetchMergedFeed` will pull the next RPC page, append `OfflineMemoryAdapter` output from both queues, then sort by `capturedAt DESC` and trim to the requested batch size. This keeps the timeline chronological without teaching the UI about two separate cursors. The same strategy applies when merging with the local preview index.

2. **Sync priority for edited offline items**  
   Stick with FIFO ordering (earliest `createdAt` first) regardless of edit count. Edited items stay in the same queue position; the `offlineSyncStatus` badge communicates progress. This matches today’s `OfflineQueueService` retry policy and avoids starvation for older captures when a user continually tweaks a newer one.

3. **Local media storage location**  
   Do **not** duplicate files. The queue already records absolute paths; the adapter now marks the resulting `PrimaryMedia` as `isLocal` so UI widgets can gate loading logic (placeholders, retries) without copying bytes. If a file is missing, the adapter simply returns `null` and `MomentCard`/`StoryCard` fall back to the existing text-only treatment.

4. **Conflict resolution when editing repeatedly offline**  
   “Last edit wins.” `OfflineMemoryDetailProvider.updateMemory` will call `OfflineQueueService.update(localId, …)` which replaces the stored `QueuedMoment/QueuedStory` in place. Because queue mutations happen on a single isolate and we never fork drafts, this remains atomic and easy to reason about once sync eventually runs.

5. **Visual indicator direction**  
   Reuse the visual language from `QueueStatusChips` and add a lightweight `PendingSyncBadge` on `MemoryCard`/`StoryCard` plus a status banner inside `MemoryDetailScreen`. Colors/icons match the existing chip palette (orange for queued, blue for syncing, red for failed). For preview-only memories that are not available offline, use a subdued grey treatment with clear copy like “Not available offline”.

## Related Documents

- `story-sync-service-todo.md` - Story sync service implementation
- `lib/services/memory_sync_service.dart` - Existing sync service
- `lib/services/offline_queue_service.dart` - Queue service
- `lib/models/queued_moment.dart` - Queued memory model
- `agent-os/specs/2025-11-16-moment-list-timeline-view/implementation/cache-offline-strategy.md` - Offline strategy spec


