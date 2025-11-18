# Story Sync Service Implementation TODO

## Objective

Implement a sync service for Stories (`StorySyncService`) that handles syncing queued stories from `OfflineStoryQueueService` to the server, similar to how `MemorySyncService` (formerly `MomentSyncService`) handles moments and mementos.

## Current State

- **Stories Queue**: `OfflineStoryQueueService` exists and manages `QueuedStory` objects
- **Story Model**: `QueuedStory` model exists with proper serialization
- **Story Save**: Stories are queued in `capture_screen.dart` but not synced
- **No Sync Service**: Stories remain queued indefinitely, no automatic sync

## Target State

- **Sync Service**: `StorySyncService` in `lib/services/story_sync_service.dart`
- **Provider**: `storySyncServiceProvider` (generated)
- **Auto Sync**: Automatically syncs queued stories when connectivity is restored
- **Retry Logic**: Exponential backoff retry for failed syncs
- **Integration**: Integrated with `SyncServiceInitializer` or separate initializer

## Implementation Requirements

### 1. Create StorySyncService

**File**: `lib/services/story_sync_service.dart`

**Features**:
- Similar structure to `MemorySyncService`
- Uses `OfflineStoryQueueService` instead of `OfflineQueueService`
- Uses `MemorySaveService` to save stories (or create `StorySaveService` if needed)
- Handles audio file uploads for stories
- Retry logic with exponential backoff
- Connectivity monitoring

**Key Methods**:
- `startAutoSync()` - Start automatic syncing when connectivity is restored
- `stopAutoSync()` - Stop automatic syncing
- `syncQueuedStories()` - Sync all queued stories
- `syncStory(String localId)` - Sync a specific story by local ID

### 2. Story Save Integration

**Decision Needed**: 
- Does `MemorySaveService.saveMoment()` handle stories correctly?
- Or do we need a separate `saveStory()` method?
- Check if story creation (including `story_fields` table insert) is handled properly

**Current Code Reference**:
```dart
// lib/screens/capture/capture_screen.dart:193-200
if (finalState.memoryType == MemoryType.story) {
  // For Stories, queue for offline sync (story save service will be implemented in task 8)
  // Check connectivity to determine if we should queue
  final connectivityService = ref.read(connectivityServiceProvider);
  final isOnline = await connectivityService.isOnline();
  
  try {
    // Queue story (will be synced when story save service is available in task 8)
```

### 3. Audio Upload Handling

**Requirements**:
- Stories include audio recordings that need to be uploaded to Supabase Storage
- Audio path is stored in `QueuedStory.audioPath`
- Audio should be uploaded before creating the story record
- Handle upload failures gracefully

**Reference**: See `MemorySaveService` for how audio uploads are handled for stories:
```dart
// lib/services/memory_save_service.dart:244-279
if (state.memoryType == MemoryType.story) {
  // Upload audio if available
  String? audioPath;
  if (state.audioPath != null) {
    // ... audio upload logic
  }
  // Create story_fields row
}
```

### 4. Integration with Sync Initializer

**Options**:
- **Option A**: Extend `SyncServiceInitializer` to also initialize `StorySyncService`
- **Option B**: Create separate `StorySyncServiceInitializer` widget
- **Option C**: Create unified `MemorySyncServiceInitializer` that handles both

**Recommendation**: Option A - extend existing initializer to handle both services

### 5. Error Handling

**Requirements**:
- Handle network failures gracefully
- Retry with exponential backoff (max 3 retries)
- Update `QueuedStory` status: `queued` → `syncing` → `completed` or `failed`
- Store error messages in `QueuedStory.errorMessage`
- Preserve audio files even if sync fails (for retry)

### 6. Testing

**Test Files to Create**:
- `test/services/story_sync_service_test.dart`
- Integration tests for offline → online sync flow
- Tests for audio upload handling
- Tests for retry logic

## Implementation Steps

1. **Analyze Story Save Flow**
   - Verify `MemorySaveService.saveMoment()` handles stories correctly
   - Check if `story_fields` table insert is handled
   - Verify audio upload logic works for queued stories

2. **Create StorySyncService**
   - Create `lib/services/story_sync_service.dart`
   - Implement service class with auto-sync functionality
   - Add retry logic with exponential backoff
   - Handle audio uploads

3. **Update Sync Initializer**
   - Update `SyncServiceInitializer` to also initialize `StorySyncService`
   - Or create unified initializer

4. **Update Queue Status Provider**
   - Verify `QueueStatusProvider` includes story sync status
   - Update UI to show story sync status

5. **Add Tests**
   - Unit tests for `StorySyncService`
   - Integration tests for story sync flow
   - Tests for audio upload handling

6. **Update Documentation**
   - Update architecture docs
   - Update capture screen comments (remove "task 8" TODO)

## Files to Create/Modify

**New Files**:
- `lib/services/story_sync_service.dart`
- `lib/services/story_sync_service.g.dart` (generated)
- `test/services/story_sync_service_test.dart`

**Files to Modify**:
- `lib/widgets/sync_service_initializer.dart` (or create unified initializer)
- `lib/screens/capture/capture_screen.dart` (remove TODO comment)
- `lib/providers/queue_status_provider.dart` (verify story status is included)

## Dependencies

- **Requires**: `OfflineStoryQueueService` (exists)
- **Requires**: `QueuedStory` model (exists)
- **Requires**: `MemorySaveService` (exists, verify story support)
- **Requires**: `ConnectivityService` (exists)
- **Related**: Should be done after Phase 8 (MemorySyncService rename) for consistency

## Success Criteria

- [ ] `StorySyncService` created and functional
- [ ] Stories sync automatically when connectivity is restored
- [ ] Audio files upload correctly
- [ ] Retry logic works with exponential backoff
- [ ] Failed syncs are marked appropriately
- [ ] Sync status visible in UI
- [ ] All tests pass
- [ ] No regressions in existing functionality

## Open Questions

1. **Save Method**: Does `MemorySaveService.saveMoment()` handle stories correctly, or do we need a separate method?
2. **Initializer**: Should we extend `SyncServiceInitializer` or create a unified initializer?
3. **Audio Handling**: Should audio upload failures block story creation, or should story be created without audio?
4. **Priority**: Should story syncs have different priority than moment/memento syncs?

## Related Documents

- `phase-8-sync-service-renaming.md` - Renaming MomentSyncService to MemorySyncService
- `lib/services/moment_sync_service.dart` - Reference implementation
- `lib/services/offline_story_queue_service.dart` - Story queue service
- `lib/models/queued_story.dart` - QueuedStory model

