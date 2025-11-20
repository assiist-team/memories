# Memory Detail Edit Improvements

## Overview

This document captures the problems identified with the memory detail screen's edit functionality. These issues need to be addressed after completing the moment-to-memory naming refactor.

## Solution Recommendation

After analyzing the problems, **Option C (Clear State Intent + Edit Mode Tracking)** is recommended:

### Why This Approach Works Best

1. **Solves State Pollution**: By always clearing state when entering capture screen for new memories (unless in edit mode), we prevent old edit data from polluting new memory creation.

2. **Solves Cancel Navigation**: By tracking edit mode explicitly and providing a cancel button when there are unsaved changes, users can easily exit edit mode or cancel draft work and return appropriately.

3. **Maintains Unified Approach**: Keeps the single capture screen for both creating and editing, avoiding code duplication.

4. **Clear User Experience**: Users understand when they're editing vs. creating new, and can easily cancel edits or cancel drafts. Cancel button is always visible (disabled when no changes), providing a predictable and safe way to abandon work. The disabled state provides clear visual feedback about when cancellation is available.

5. **Prevents Accidental Data Loss**: By showing confirmation dialogs when canceling unsaved changes (whether editing or creating), we prevent users from accidentally losing their work.

### Key Implementation Strategy

1. **Edit Mode Tracking**: Add `editingMemoryId` to `CaptureState` - when set, we're in edit mode; when null, we're creating new.

2. **State Clearing Logic**: 
   - When entering edit mode: Set `editingMemoryId` and load edit data
   - After saving edit: Clear state completely (including `editingMemoryId`)
   - After canceling edit: Clear state completely (including `editingMemoryId`)
   - No need to clear on capture screen init - state is already clean after edit operations

3. **Cancel Button**: Always visible in AppBar, but disabled when `hasUnsavedChanges` is false. When enabled (unsaved changes exist), handles confirmation dialog, then clears state.
   - **When editing**: Cancel navigates back to detail screen
   - **When creating**: Cancel clears state and stays on capture screen (or navigates back if screen was pushed)
   - **Benefits**: Consistent UI placement, discoverable option, visual feedback via disabled state

4. **Back Button Handling**: When `hasUnsavedChanges` is true, intercept back button and show confirmation dialog (same behavior as cancel button).

### Why Not Separate Edit Screen?

While a separate edit screen would solve these problems, it has downsides:
- Code duplication (capture screen logic would need to be duplicated)
- More maintenance burden (two screens to keep in sync)
- Diverges from the unified capture approach
- Doesn't solve the fundamental issue (just avoids it)

The recommended approach solves the problems while maintaining the unified architecture.

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

### 2. Cancel/Back Navigation When Editing

**Problem**: When a user clicks edit on a memory, they navigate to the capture screen with preloaded data. If they decide they don't want to make edits, they cannot easily go back to the detail screen. They're stuck in the capture screen with preloaded edit data.

**Current Behavior**:
- User clicks edit → navigates to capture screen with data preloaded
- User changes their mind and wants to cancel
- No clear way to cancel and go back to detail screen
- User is stuck with preloaded data in capture screen

**Expected Behavior**:
- User clicks edit → navigates to capture screen with data preloaded (edit mode)
- User can click "Cancel" button to discard changes and go back to detail screen
- Cancel should clear the edit state and navigate back cleanly
- **Also applies to creating new memories**: If user starts creating and wants to cancel, same cancel button should appear

**Technical Details**:
- Need to track edit mode in `CaptureState` (e.g., `editingMemoryId` field)
- `CaptureState` already has `hasUnsavedChanges` field - use this to enable/disable cancel button
- Need "Cancel" button always visible in AppBar, but disabled when `hasUnsavedChanges` is false
- Cancel button should:
  - Be enabled when `hasUnsavedChanges` is true (works for both editing and creating)
  - Show confirmation dialog when clicked (only enabled when there are unsaved changes)
  - Clear capture state (including `editingMemoryId` if editing)
  - Navigate back appropriately (to detail screen if editing, stay/pop if creating)
- Back button should intercept and show same confirmation when `hasUnsavedChanges` is true

**Implementation Requirements**:
1. Add `editingMemoryId` field to `CaptureState` to track when editing
2. Update `loadMemoryForEdit()` to set `editingMemoryId` in capture state
3. Add "Cancel" button to capture screen AppBar (always visible)
4. Cancel button should:
   - Be disabled when `hasUnsavedChanges` is false
   - Be enabled when `hasUnsavedChanges` is true
   - Show confirmation dialog when clicked (only possible when enabled)
   - Clear capture state (including `editingMemoryId` if editing)
   - Navigate back to detail screen if editing, or stay/pop if creating
5. Handle back button press: Use `PopScope` or `WillPopScope` to intercept when `hasUnsavedChanges` is true, show confirmation, then clear state and allow pop

**Files to Modify**:
- `lib/models/capture_state.dart` - Add `editingMemoryId` field (already has `hasUnsavedChanges`)
- `lib/providers/capture_state_provider.dart` - Set `editingMemoryId` in `loadMemoryForEdit()`, add cancel method
- `lib/screens/capture/capture_screen.dart` - Add cancel button when `hasUnsavedChanges` is true, handle back button with `PopScope`/`WillPopScope`
- `lib/screens/memory/memory_detail_screen.dart` - Ensure proper navigation when entering edit mode

### 3. Cancel/Discard When Creating New Memories

**Problem**: When a user starts creating a new memory and enters data (text, media, tags), they may want to cancel their work and start over. Currently, there's no explicit way to cancel unsaved work when creating - users must rely on the back button, which may not provide clear feedback about losing unsaved changes.

**Current Behavior**:
- User navigates to capture screen to create new memory
- User enters data (text, media, tags, etc.)
- User wants to cancel and start over
- No explicit "Cancel" button - must use back button
- Back button may not warn about unsaved changes
- State persists if user navigates away, causing confusion later

**Expected Behavior**:
- User starts creating new memory and enters data
- "Cancel" button is always visible in AppBar, becomes enabled when there are unsaved changes
- User can click "Cancel" (when enabled) to clear all data and start fresh
- Confirmation dialog appears when canceling (only possible when button is enabled)
- After canceling, state is cleared and user can start new memory
- Back button should also show confirmation when there are unsaved changes

**Why This Matters**:
- **Consistency**: Same cancel pattern whether editing or creating
- **Prevents State Pollution**: Explicit cancel clears state, preventing old draft data from persisting
- **Clear Intent**: User knows they can abandon work with explicit action
- **Prevents Accidental Loss**: Confirmation dialog prevents accidental data loss
- **Better UX**: More predictable than relying solely on back button
- **Discoverability**: Button always visible (disabled when no changes) - users know the option exists
- **Visual Feedback**: Disabled state clearly communicates when there's nothing to cancel

**Technical Details**:
- `CaptureState` already has `hasUnsavedChanges` field - use this to enable/disable cancel button
- Show "Cancel" button always in AppBar, enabled when `hasUnsavedChanges` is true (works for both editing and creating)
- Cancel button should show confirmation dialog before clearing state (only clickable when enabled)
- Back button should intercept and show same confirmation when `hasUnsavedChanges` is true

**Implementation Requirements**:
1. Show "Cancel" button always in AppBar (always visible)
2. Cancel button should:
   - Be disabled when `hasUnsavedChanges` is false
   - Be enabled when `hasUnsavedChanges` is true (works for both creating and editing)
   - Show confirmation dialog when clicked (only possible when enabled)
   - Clear capture state completely (including `editingMemoryId` if editing)
   - Navigate appropriately (stay on screen if creating, go back if editing)
3. Handle back button with `PopScope`/`WillPopScope` to intercept when `hasUnsavedChanges` is true

**Files to Modify**:
- `lib/screens/capture/capture_screen.dart` - Add cancel button logic, handle back button interception
- `lib/providers/capture_state_provider.dart` - Ensure `hasUnsavedChanges` is properly tracked

### 4. State Pollution When Creating New Memories

**Problem**: If someone edits a memory (which preloads data into capture state), then later wants to capture a new memory, the capture screen still has all the old edit data preloaded. They have to manually clear all that data before they can create a new memory, which is a significant design problem.

**Current Behavior**:
- User edits memory → capture screen has preloaded data
- User saves or cancels edit
- Later, user wants to create new memory
- Capture screen still has old edit data (text, tags, location, etc.)
- User must manually clear everything before creating new memory
- This is confusing and error-prone

**Expected Behavior**:
- After saving or canceling an edit, state should be completely cleared
- User is immediately ready to create a new memory without any old data
- No need to navigate away and back - state is clean after edit operations complete

**Technical Details**:
- Capture screen is part of main navigation shell (IndexedStack) - it's always present, just hidden/shown
- After edit operations (save or cancel), clear state completely including `editingMemoryId`
- This ensures that when user is done editing, they have a clean slate for new memories
- No special "clear on entry" logic needed - just clear on "exit" from edit mode

**Implementation Requirements**:
1. Track edit mode via `editingMemoryId` field in `CaptureState`
2. When saving edit: After successful save, clear state completely (including `editingMemoryId`)
3. When canceling edit: Clear state completely (including `editingMemoryId`)
4. After state is cleared, user is immediately ready to create new memory
5. No need to clear state on capture screen init - it's already clean after edit operations

**Files to Modify**:
- `lib/models/capture_state.dart` - Add `editingMemoryId` field
- `lib/providers/capture_state_provider.dart` - Ensure clear() resets `editingMemoryId`, clear after save/cancel
- `lib/screens/capture/capture_screen.dart` - Clear state after successful save or cancel
- `lib/screens/memory/memory_detail_screen.dart` - Set edit mode before navigating to capture

**Alternative Solutions Considered**:

**Option A: Separate Edit Screen**
- Create dedicated `MemoryEditScreen` separate from `CaptureScreen`
- Pros: Clear separation, no state pollution, easy to cancel
- Cons: Code duplication, more screens to maintain, diverges from unified capture approach

**Option B: Modal Edit Overlay**
- Edit opens as modal/overlay on top of detail screen
- Pros: Easy to cancel (just dismiss), no navigation issues, no state pollution
- Cons: Different UX pattern, might be cramped on smaller screens, requires overlay management

**Option C: Clear State After Edit Operations** (Recommended)
- Track edit mode explicitly with `editingMemoryId`
- After saving or canceling edit, clear state completely (including `editingMemoryId`)
- User is immediately ready for new memory without navigating away
- Pros: Reuses capture screen, solves both problems, maintains unified approach, simple implementation
- Cons: Requires ensuring state is cleared after all edit operations

**Recommendation**: Option C (Clear State After Edit Operations) is the best approach because:
- Maintains the unified capture screen approach
- Solves both problems (cancel navigation and state pollution)
- Simple implementation - just clear state after save/cancel
- No need to navigate away and back - state is clean immediately after edit
- Clear user experience - edit → save/cancel → ready for new memory

### 5. Delete Button Placement

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

### 6. Navigation After Saving Edit

**Problem**: After editing a memory and saving, the user should be navigated back to the memory detail screen to see the updated content.

**Current Behavior**:
- User edits memory and saves
- Capture screen saves memory (or creates new one if update endpoint doesn't exist)
- User is left on capture screen or navigated to detail screen for a "new" memory
- Original detail screen is lost in navigation stack

**Expected Behavior**:
- User edits memory and saves
- Capture screen updates existing memory
- User is navigated back to the memory detail screen
- Detail screen shows updated content

**Technical Details**:
- Need update endpoint in `MemorySaveService` (currently only has `saveMemory()` which creates new)
- After successful update, navigate back to detail screen (pop capture screen)
- Refresh detail screen to show updated content

**Implementation Requirements**:
1. Create `updateMemory()` method in `MemorySaveService` (or modify `saveMemory()` to handle updates)
2. Update capture screen save logic to check if editing and call update vs. create
3. After successful update, navigate back to detail screen (pop capture screen)
4. Refresh detail screen to show updated content

**Files to Modify**:
- `lib/services/memory_save_service.dart` - Add `updateMemory()` method
- `lib/screens/capture/capture_screen.dart` - Handle edit mode in save logic and navigation
- `lib/screens/memory/memory_detail_screen.dart` - Ensure refresh after edit

**Database/API Requirements**:
- May need new RPC function or update existing one to handle memory updates
- Need to handle media updates (add new, remove existing)
- Need to handle partial updates (only update changed fields)

## Implementation Priority

1. **Critical Priority**: Cancel navigation when editing or creating (blocks user workflow, prevents state pollution)
2. **Critical Priority**: State pollution when creating new memories (blocks core workflow)
3. **High Priority**: Media loading when editing (core functionality missing)
4. **High Priority**: Navigation after saving edit (completes edit workflow)
5. **Low Priority**: Deletion handling (UX polish - current implementation acceptable)

## Dependencies

- Must complete moment-to-memory naming refactor first
- Database/API may need updates for memory update endpoint
- Media handling may require new storage operations (delete existing media)

## Testing Considerations

### State Pollution Tests
- Test: Edit memory, save → state should be cleared, ready for new memory
- Test: Edit memory, cancel → state should be cleared, ready for new memory
- Test: After edit save/cancel, create new memory → no old data present, clean state
- Test: User stays on capture screen after edit → can immediately create new memory

### Cancel Navigation Tests
- Test: Cancel button is always visible in AppBar
- Test: Cancel button is disabled when `hasUnsavedChanges` is false
- Test: Cancel button is enabled when `hasUnsavedChanges` is true
- Test: Click edit, then cancel → should navigate back to detail screen
- Test: Click edit, make changes, then cancel → should show confirmation, then navigate back
- Test: Click edit, then press back button → should behave same as cancel
- Test: Cancel should clear all edit state
- Test: Start creating new memory, make changes, then cancel → should show confirmation, clear state, stay on capture screen
- Test: Start creating new memory, make changes, then press back button → should show confirmation, clear state, allow navigation
- Test: Cancel button works consistently whether editing or creating
- Test: After canceling, button becomes disabled again (no unsaved changes)

### Media Loading Tests
- Test editing memory with existing media
- Test editing memory without media
- Test adding new media to existing memory
- Test removing existing media from memory

### Save Navigation Tests
- Test navigation flow: edit → save → back to detail
- Test offline editing (should be disabled or queued)
- Test error handling: what if update fails?
- Test: Save edit should refresh detail screen with updated content

## Related Files

- `lib/screens/memory/memory_detail_screen.dart` - Edit button handler
- `lib/screens/capture/capture_screen.dart` - Save logic and navigation
- `lib/providers/capture_state_provider.dart` - Edit state loading
- `lib/services/memory_save_service.dart` - Save/update operations
- `lib/models/capture_state.dart` - State model
- `lib/widgets/media_tray.dart` - Media display

