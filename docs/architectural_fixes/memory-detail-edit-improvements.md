# Memory Detail Edit Improvements

## Overview

This document captures the problems identified with the memory detail screen's edit functionality. These issues need to be addressed after completing the moment-to-memory naming refactor.

## Problems Identified

### 1. Media Loading When Editing

**Problem**: When a user clicks edit on a memory, the existing media (photos and videos) are not loaded into the capture screen. The `loadMemoryForEdit()` method in `CaptureStateProvider` only loads text, tags, and location data, but not the existing media URLs.

**Current Behavior**:
- User clicks edit on a memory with photos/videos
- Capture screen opens with text, tags, and location loaded
- Media tray shows empty (no existing media visible)
- User can add new media, but cannot see or manage existing media

**Expected Behavior**:
- User clicks edit on a memory with photos/videos
- Capture screen opens with all data loaded including existing media URLs
- Media tray displays existing media (as read-only or removable thumbnails)
- User can see existing media, add new media, and remove existing media if desired

**Technical Details**:
- `MemoryDetail` model has `photos` and `videos` lists containing URLs from Supabase Storage
- `CaptureState` has `photoPaths` and `videoPaths` lists containing local file paths
- Need to bridge this gap: download existing media URLs or display them differently
- Consider: Should existing media be editable (removable) or just viewable?

**Implementation Requirements**:
1. Extend `loadMemoryForEdit()` to accept existing media URLs
2. Add new fields to `CaptureState` to track existing media URLs separately from new media paths
3. Update `MediaTray` widget to display both existing media (from URLs) and new media (from local paths)
4. Handle media removal: Track which existing media should be deleted
5. On save: Update memory with new media + remaining existing media - deleted media

**Files to Modify**:
- `lib/models/capture_state.dart` - Add fields for existing media URLs
- `lib/providers/capture_state_provider.dart` - Update `loadMemoryForEdit()` method
- `lib/widgets/media_tray.dart` - Display existing media URLs alongside new media
- `lib/services/memory_save_service.dart` - Handle media updates (not just creation)

### 2. Navigation Back After Editing

**Problem**: After editing a memory and saving, the user is not navigated back to the memory detail screen. Instead, the capture screen either stays open or navigates to a new detail screen (for new memories), leaving the user lost.

**Current Behavior**:
- User clicks edit → navigates to capture screen
- User makes changes and saves
- Capture screen saves memory (or creates new one if update endpoint doesn't exist)
- User is left on capture screen or navigated to detail screen for a "new" memory
- Original detail screen is lost in navigation stack

**Expected Behavior**:
- User clicks edit → navigates to capture screen (with edit mode tracked)
- User makes changes and saves
- Capture screen updates existing memory
- User is navigated back to the memory detail screen
- Detail screen shows updated content

**Technical Details**:
- Need to track edit mode in `CaptureState` (e.g., `editingMemoryId` field)
- Need to distinguish between creating new memory vs. updating existing memory
- Need update endpoint in `MemorySaveService` (currently only has `saveMemory()` which creates new)
- After successful update, navigate back to detail screen instead of creating new detail screen

**Implementation Requirements**:
1. Add `editingMemoryId` field to `CaptureState` to track when editing
2. Update `loadMemoryForEdit()` to set `editingMemoryId` in capture state
3. Create `updateMemory()` method in `MemorySaveService` (or modify `saveMemory()` to handle updates)
4. Update capture screen save logic to check if editing and call update vs. create
5. After successful update, navigate back to detail screen (pop capture screen)
6. Refresh detail screen to show updated content

**Files to Modify**:
- `lib/models/capture_state.dart` - Add `editingMemoryId` field
- `lib/providers/capture_state_provider.dart` - Set `editingMemoryId` in `loadMemoryForEdit()`
- `lib/services/memory_save_service.dart` - Add `updateMemory()` method
- `lib/screens/capture/capture_screen.dart` - Handle edit mode in save logic and navigation
- `lib/screens/memory/memory_detail_screen.dart` - Ensure refresh after edit

**Database/API Requirements**:
- May need new RPC function or update existing one to handle memory updates
- Need to handle media updates (add new, remove existing)
- Need to handle partial updates (only update changed fields)

### 3. Deletion Handling

**Problem**: The delete button placement and behavior needs clarification. Currently it's a floating action button, but we need to confirm this is the desired UX.

**Current Behavior**:
- Delete button is a floating action button at bottom right
- Edit button was moved to AppBar (recent change)
- Delete button requires online connection
- Shows confirmation bottom sheet before deletion

**Question**: Should delete button remain as FAB or be moved to AppBar?

**Recommendation**: Keep delete as FAB since:
- It's a destructive action that should be visually separated from primary actions
- FAB placement makes it less likely to be accidentally tapped
- Common pattern: Edit in AppBar, Delete as FAB

**If Moving to AppBar**:
- Place delete button after edit button in AppBar actions
- Use error color (red) for delete icon to indicate destructive action
- Keep confirmation dialog before deletion

**Implementation Requirements** (if keeping as FAB):
- No changes needed - current implementation is acceptable
- Ensure proper offline handling (already implemented)
- Ensure proper confirmation flow (already implemented)

**Files to Modify** (if moving to AppBar):
- `lib/screens/memory/memory_detail_screen.dart` - Move delete button to AppBar actions
- Remove `_buildFloatingActions()` method or simplify to only handle delete if needed

## Implementation Priority

1. **High Priority**: Navigation back after editing (blocks user workflow)
2. **High Priority**: Media loading when editing (core functionality missing)
3. **Low Priority**: Deletion handling (UX polish - current implementation acceptable)

## Dependencies

- Must complete moment-to-memory naming refactor first
- Database/API may need updates for memory update endpoint
- Media handling may require new storage operations (delete existing media)

## Testing Considerations

- Test editing memory with existing media
- Test editing memory without media
- Test adding new media to existing memory
- Test removing existing media from memory
- Test navigation flow: edit → save → back to detail
- Test offline editing (should be disabled or queued)
- Test error handling: what if update fails?

## Related Files

- `lib/screens/memory/memory_detail_screen.dart` - Edit button handler
- `lib/screens/capture/capture_screen.dart` - Save logic and navigation
- `lib/providers/capture_state_provider.dart` - Edit state loading
- `lib/services/memory_save_service.dart` - Save/update operations
- `lib/models/capture_state.dart` - State model
- `lib/widgets/media_tray.dart` - Media display

