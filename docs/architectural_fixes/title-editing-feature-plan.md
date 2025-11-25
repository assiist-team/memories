# Title Editing Feature Plan

## Overview

Enable users to edit memory titles directly in the memory detail screen, similar to how date and location editing currently work. This will allow inline editing without navigating to the capture screen.

## Current State Analysis

### Display Logic
- Title is displayed as read-only text in `memory_detail_screen.dart` (lines 718-723)
- `MemoryDetail.displayTitle` getter prefers `generatedTitle`, then `title`, then falls back to "Untitled Story/Memento/Moment"
- Title editing currently requires navigating to capture screen via the Edit button

### Existing Patterns
- **Date Editing**: `_handleEditDate()` method shows date/time picker, calls `updateMemoryDate()` in provider/service
- **Location Editing**: `_handleEditLocation()` shows bottom sheet, updates `CaptureState` (Phase 1 implementation)
- Both follow similar patterns: check online status, show UI, update via service, refresh detail view

### Database Schema
- `memories` table has both `title` (TEXT, nullable) and `generated_title` (TEXT, nullable)
- `title` is the user-editable display title
- `generated_title` is the last auto-generated title from LLM/processing
- When user edits title, we should update `title` field, not `generated_title`

### Service Layer
- `MemoryDetailService` has `updateMemoryDate()` method as reference pattern
- Updates clear cache after successful update
- Provider layer (`MemoryDetailNotifier`) has corresponding `updateMemoryDate()` method

## Requirements

### Functional Requirements
1. **Inline Title Editing**: User can tap on title in detail screen to edit it
2. **Edit Mode**: Title becomes editable text field when tapped
3. **Save/Cancel**: User can save changes or cancel editing
4. **Online Requirement**: Title editing requires internet connection (like date editing)
5. **Title Field Update**: When user edits, update `title` field in database (not `generated_title`)
6. **Display Update**: After save, detail screen refreshes to show updated title
7. **Timeline Sync**: Updated title should appear in timeline feed (via update bus or refresh)

### Technical Requirements
1. **Service Method**: Add `updateMemoryTitle()` to `MemoryDetailService`
2. **Provider Method**: Add `updateMemoryTitle()` to `MemoryDetailNotifier`
3. **UI Component**: Make title editable in detail screen (similar to date editing pattern)
4. **Validation**: Ensure title is not empty (or allow empty to fall back to "Untitled...")
5. **Error Handling**: Show appropriate error messages if update fails
6. **Loading State**: Show loading indicator while saving
7. **Cache Invalidation**: Clear cache after successful update (already handled in service pattern)

## Implementation Plan

### Phase 1: Backend Service Layer

**File**: `lib/services/memory_detail_service.dart`

Add new method:
```dart
/// Update title for a memory
///
/// [memoryId] is the UUID of the memory to update
/// [title] is the new title (null to clear it, which will use generated_title or fallback)
///
/// Throws an exception if the memory is not found or user doesn't have permission
Future<void> updateMemoryTitle(String memoryId, String? title) async {
  // Similar pattern to updateMemoryDate:
  // 1. Build updateData map with title and updated_at
  // 2. Update via Supabase .from('memories').update()
  // 3. Clear cache
  // 4. Handle errors
}
```

**Key Points**:
- Update `title` field (not `generated_title`)
- Allow null/empty title (will fall back to `generated_title` or "Untitled..." in display)
- Clear cache after update
- Follow same error handling pattern as `updateMemoryDate`

### Phase 2: Provider Layer

**File**: `lib/providers/memory_detail_provider.dart`

Add new method:
```dart
/// Update memory title
///
/// [title] is the new title (null to clear it)
/// Refreshes the memory detail after update
Future<void> updateMemoryTitle(String? title) async {
  // Similar pattern to updateMemoryDate:
  // 1. Call service.updateMemoryTitle()
  // 2. Refresh memory detail to get updated data
  // 3. Handle errors (rethrow for UI to handle)
}
```

**Key Points**:
- Call service method
- Refresh detail view after update
- Rethrow errors for UI layer to handle

### Phase 3: UI Layer - Title Editing Component

**File**: `lib/screens/memory/memory_detail_screen.dart`

**Approach Options**:

#### Option A: Inline TextField (Recommended)
- Replace read-only `Text` widget with `TextField` that becomes editable on tap
- Show save/cancel buttons when editing
- Similar to how many note-taking apps handle title editing

#### Option B: Bottom Sheet Dialog
- Tap title opens bottom sheet with text field
- Similar to date/location editing pattern
- More consistent with existing editing patterns

**Recommendation**: **Option A** for better UX (faster, more intuitive), but **Option B** for consistency with existing patterns.

**Implementation Steps**:

1. **Add State Management**:
   - Track if title is being edited (`_isEditingTitle`)
   - Track edited title value (`_editedTitle`)
   - Add `TextEditingController` for title field

2. **Add Edit Handler**:
   ```dart
   Future<void> _handleEditTitle(
     BuildContext context,
     WidgetRef ref,
     MemoryDetail memory,
   ) async {
     // 1. Check online status
     // 2. Enter edit mode (set _isEditingTitle = true)
     // 3. Initialize _editedTitle with current displayTitle
     // 4. Focus text field
   }
   ```

3. **Add Save Handler**:
   ```dart
   Future<void> _handleSaveTitle(
     BuildContext context,
     WidgetRef ref,
     MemoryDetail memory,
     String newTitle,
   ) async {
     // 1. Show loading indicator
     // 2. Call notifier.updateMemoryTitle(newTitle.trim())
     // 3. Exit edit mode
     // 4. Show success/error message
     // 5. Refresh detail view (automatic via provider refresh)
   }
   ```

4. **Update Title Display Widget**:
   - Replace static `Text` widget with conditional widget:
     - If editing: Show `TextField` with save/cancel buttons
     - If not editing: Show `Text` with tap handler to enter edit mode

5. **Add Cancel Handler**:
   - Reset `_editedTitle` to original value
   - Exit edit mode

### Phase 4: Timeline Feed Update

**File**: `lib/providers/unified_feed_provider.dart` or `lib/providers/memory_timeline_update_bus_provider.dart`

**Options**:
1. **Via Update Bus**: Emit title update event to timeline update bus
2. **Via Refresh**: Timeline will refresh when user navigates back (simpler, but less immediate)
3. **Optimistic Update**: Update timeline state optimistically before server confirms

**Recommendation**: Start with **Option 2** (refresh on navigation), add **Option 1** (update bus) if needed for better UX.

### Phase 5: Edge Cases & Validation

1. **Empty Title**: Allow empty title (will use `generated_title` or fallback in `displayTitle`)
2. **Very Long Title**: Consider max length validation (e.g., 200 characters)
3. **Offline State**: Disable editing when offline (show tooltip like date editing)
4. **Processing State**: If memory is still processing, allow title edit (title is independent of processing)
5. **Concurrent Edits**: Handle case where user edits title while memory is being updated elsewhere

## File Changes Summary

### Files to Modify

1. **`lib/services/memory_detail_service.dart`**
   - Add `updateMemoryTitle()` method

2. **`lib/providers/memory_detail_provider.dart`**
   - Add `updateMemoryTitle()` method

3. **`lib/screens/memory/memory_detail_screen.dart`**
   - Add state variables for title editing
   - Add `_handleEditTitle()` method
   - Add `_handleSaveTitle()` method
   - Add `_handleCancelTitleEdit()` method
   - Replace title display widget with editable version
   - Add `TextEditingController` for title

### Files to Consider (Optional)

4. **`lib/providers/memory_timeline_update_bus_provider.dart`**
   - Add `emitTitleUpdated()` method if using update bus approach

5. **`lib/providers/unified_feed_provider.dart`**
   - Handle title update events if using update bus approach

## Testing Considerations

1. **Unit Tests**:
   - Test `updateMemoryTitle()` in service (success, error cases)
   - Test provider method calls service correctly
   - Test title validation (empty, max length)

2. **Integration Tests**:
   - Test title editing flow end-to-end
   - Test offline state handling
   - Test error handling (network failure, permission denied)

3. **UI Tests**:
   - Test tap to edit title
   - Test save/cancel buttons
   - Test loading state display
   - Test error message display

## User Experience Flow

1. **User views memory detail screen**
   - Title is displayed as read-only text

2. **User taps on title**
   - Title becomes editable text field
   - Save/Cancel buttons appear (or inline save icon)
   - Keyboard appears (if on mobile)

3. **User edits title**
   - Text field updates as user types
   - Validation happens (if any)

4. **User saves**
   - Loading indicator shows
   - Title updates in UI
   - Success message appears briefly
   - Edit mode exits

5. **User cancels**
   - Title reverts to original value
   - Edit mode exits
   - No changes saved

## Success Criteria

- ✅ User can tap title to edit it inline
- ✅ User can save or cancel title edits
- ✅ Title updates persist to database
- ✅ Updated title appears in detail screen immediately
- ✅ Updated title appears in timeline feed (on refresh or via update bus)
- ✅ Editing requires online connection (with appropriate offline message)
- ✅ Error handling works correctly (network failures, etc.)
- ✅ Loading states are shown appropriately
- ✅ Empty titles fall back to `generated_title` or "Untitled..." correctly

## Future Enhancements (Out of Scope)

1. **Bulk Title Editing**: Edit multiple memories at once
2. **Title Suggestions**: Show AI-generated title suggestions while editing
3. **Title History**: Track title change history
4. **Undo/Redo**: Undo title changes
5. **Title Templates**: Pre-defined title templates for different memory types

## Notes

- Title editing should be independent of memory processing status
- When user edits title, `title` field becomes the source of truth (not `generated_title`)
- Consider adding analytics tracking for title edits (similar to other edit actions)
- Title editing should work for all memory types (story, memento, moment)

