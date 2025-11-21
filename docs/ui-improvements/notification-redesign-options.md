# Notification & Save Indicator Redesign Options

## Current Implementation Summary

**Processing Architecture (Verified in Code):**
- **All memory types** (`process-moment`, `process-memento`, `process-story`) perform **TWO separate LLM calls**:
  1. **First LLM call**: Title generation
     - All types: `generateTitleWithLLM(inputText)` → `title`
  2. **Second LLM call**: Text/Narrative processing
     - Moments/Mementos: `processTextWithLLM(inputText)` → `processed_text`
     - Stories: `generateNarrativeWithLLM(inputText)` → `processed_text`

- **Processing Timing**:
  - **Moments/Mementos**: Processing happens SYNCHRONOUSLY during save (save service awaits completion via `await _processingService.processMoment()`)
  - **Stories**: Processing happens ASYNCHRONOUSLY after save (fire-and-forget pattern via `_processingService.processStory().then(...)`)

**This document reflects the actual code implementation, not conditional assumptions.**

## Current Issues
1. **Save button expansion**: When saving, the button expands vertically showing spinner, message, and progress bar - creates a "fat pill container" that overlaps with bottom navigation
2. **Success toasts**: SnackBar toasts feel intrusive and don't match the app's aesthetic
3. **Upload progress**: Progress messages displayed inside the button make it too tall
4. **Inconsistent processing flows**: Stories process asynchronously after save completes, while moments/mementos process synchronously during save - creates inconsistent UX
5. **Slow perceived performance**: Users wait for LLM processing during save, making saves feel slow

## Design Goals
- Keep save button compact and fixed height
- Provide clear feedback without blocking UI
- Avoid overlapping with bottom navigation
- Modern, subtle notification system
- Better visual hierarchy
- **Consistent experience across all memory types** (moments, mementos, stories)
- **Normalize processing to async for all types** - faster perceived save time
- **Support offline saving** - queue works for all memory types
- **Show actual processing status** - helpful for debugging, no auto-dismiss

---

## Normalized Architecture: Synchronous vs Asynchronous Operations

### Proposed Normalization

**All memory types will follow the same pattern:**
- **Synchronous operations** (blocking, tracked by spinner/save button): Upload media, save to DB
- **Asynchronous operations** (non-blocking, tracked by overlay banner): Two-step LLM processing
  1. Title generation (first LLM call): `input_text` → `title`
  2. Text/Narrative processing (second LLM call): `input_text` → `processed_text`
  
**Current Implementation:**
- Each edge function (`process-moment`, `process-memento`, `process-story`) performs two sequential LLM calls
- Moments/Mementos: Processing happens synchronously during save (save service awaits)
- Stories: Processing happens asynchronously after save (fire-and-forget)

### Synchronous Operations (Spinner/Save Button Tracks)
1. **Uploading media** (photos, videos, audio)
   - Can be queued offline if no connectivity
   - Progress: "📤 Uploading photos... (2/5)"
2. **Saving to database**
   - Creates memory record with temporary title
   - Creates `memory_processing_status` row with status='processing' (online saves only — offline sync inserts later)
   - Can be queued offline if no connectivity
   - Progress: "💾 Saving memory..."

### Asynchronous Operations (Overlay Banner Tracks)

**All memory types follow the same two-step LLM processing pattern:**

1. **Title generation** (First LLM call)
   - Generates title from `input_text`
   - Happens server-side via edge functions
   - Updates `title` field when complete
   - Status: "⚙️ Generating title..."

2. **Text/Narrative processing** (Second LLM call)
   - **Moments/Mementos**: Processes `input_text` → `processed_text` (cleans and structures transcribed text)
   - **Stories**: Generates narrative from `input_text` → `processed_text` (transforms transcript into polished story)
   - Happens server-side via edge functions
   - Cannot happen offline (server-side only)
   - Status: "⚙️ Processing text..." (moments/mementos) or "⚙️ Generating narrative..." (stories)

**Current Implementation:**
- **Moments/Mementos**: Processing happens SYNCHRONOUSLY during save (save service awaits completion)
- **Stories**: Processing happens ASYNCHRONOUSLY after save (fire-and-forget pattern)

**Key Benefits:**
- **Faster perceived save time** - users don't wait for LLM processing
- **Consistent UX** - all memory types behave the same way
- **Better scalability** - LLM processing doesn't block saves
- **More resilient** - processing failures don't fail the save
- **Offline support** - saves can be queued, processing happens when online

### Processing Status Tracking

**New unified table**: `memory_processing_status`
- Consolidates processing status for all memory types
- Migrates processing fields from `story_fields` table
- Tracks: `processing_status` ('processing', 'complete', 'failed'), timestamps, retry count, errors
- Allows querying "all memories currently processing" efficiently

### Temporary Title Strategy

**Fallback title format**: First N characters of `input_text` + "..."
- Example: "This is a memory about my day at the beach..." (if N=50)
- More descriptive than "Untitled Moment" for multiple memories per day
- Clearly temporary (will be replaced when processing completes)
- If `input_text` is empty/null, use memory type + date/time as fallback

### Offline Flow

**Important**: Offline saves follow a different flow than online saves. See "Offline Save Flow" section below for details.

1. **User saves offline** → Memory queued to SharedPreferences
   - Overlay banner: "💾 Queuing memory..." → "✅ Queued for sync"
   - Timeline badge copy uses standardized **"Pending sync"** label from the `OfflineSyncStatus` enum (see `offline-memory-viewing-editing`), so overlay and timeline communicate the same state with consistent wording
   - **No `memory_processing_status` row created** (memory not in DB yet)
   - No upload (media stays local)
   - Temporary title stored in queue (from `input_text` snippet)

2. **When connectivity restored** → Sync service processes queue
   - Uploads media (if any)
   - Saves to database
   - **Creates `memory_processing_status` row** with status='processing'
   - Sets temporary title from `input_text` snippet

3. **Processing triggers** → Edge function called asynchronously (server-side)
   - Title generation (first LLM call)
   - Text/Narrative processing (second LLM call)

4. **Processing completes** → Updates `title`, `processed_text`, `processing_status='complete'`
   - Timeline updates to show final title
   - Processing indicator disappears

**Note**: Processing cannot happen offline (requires server-side LLM), but this is acceptable - the memory is saved and will be processed when online. **Processing status is only tracked after sync completes**, not during offline save.

### Offline Save Flow (Different from Online)

**When user saves while offline:**

**Synchronous operations** (Spinner/Save Button tracks):
- **Queuing**: "💾 Queuing memory..." (saves to SharedPreferences queue)
- No upload (media stays local)
- No database write
- **No processing status created** (memory not in DB yet)

**After connectivity restored** (Sync Service handles):
- Sync service processes queue
- Uploads media (if any)
- Saves to database
- Creates `memory_processing_status` row
- Triggers async processing

**Processing** (Overlay Banner tracks, after sync):
- Title generation
- Text/Narrative processing
- Updates `title`, `processed_text`, `processing_status='complete'`

**Key Difference**: Offline saves don't create `memory_processing_status` rows until after sync completes. Overlay banner shows "Queuing" → "Queued for sync" instead of processing status.

---

## Option 1: Compact Spinner in Save Button (Recommended)
**Concept**: Keep button fixed height, show only a spinner and disable button during save.

**Implementation**:
- Save button shows spinner icon instead of text when saving
- Button becomes disabled/opaque during save
- Progress shown in a subtle overlay above buttons (see Option 2 for overlay details)

**Pros**:
- Button stays compact, no overlap issues
- Clean, minimal design
- Clear visual feedback (spinner = in progress)
- No layout shifts

**Cons**:
- Less detailed progress information in button itself
- Need separate overlay for detailed progress

**Visual**:
```
[Cancel]  [🔄]  ← Spinner icon, button disabled
```

---

## Option 2: Overlay Banner Above Buttons
**Concept**: Fixed-height banner above Cancel/Save buttons showing progress status.

**Implementation**:
- Thin banner (40-48px height) above button row
- Shows: Icon + "Saving..." / "Uploading media..." / "Saving memory..."
- Optional: Thin progress bar at bottom of banner
- Remains visible (switches to background-processing state) until async processing reports `complete` or the user dismisses it
- Subtle background with slight elevation

**Pros**:
- Detailed progress messages visible
- Doesn't affect button layout
- Clear separation from action buttons
- Can show multiple states (saving → uploading → saving)

**Cons**:
- Takes up vertical space
- Might feel redundant if button also shows spinner

**Visual**:
```
┌─────────────────────────────────┐
│ 🔄 Uploading media...           │ ← Banner (40px)
│ ▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░ │ ← Progress bar
├─────────────────────────────────┤
│ [Cancel]        [Save]          │
└─────────────────────────────────┘
```

---

## Option 3: Inline Status Bar (Between Content and Buttons)
**Concept**: Status bar between main content and button row, similar to queue status chips.

**Implementation**:
- Fixed-height container (36-40px) between content area and buttons
- Shows icon + text: "🔄 Saving memory..." or "📤 Uploading media..."
- Optional progress indicator
- Subtle background, rounded corners
- Only appears during save/upload operations

**Pros**:
- Natural placement in layout flow
- Doesn't interfere with buttons
- Consistent with existing queue status chips pattern
- Easy to scan

**Cons**:
- Pushes buttons down slightly
- Might feel like it's part of content area

**Visual**:
```
[Main Content Area]
┌─────────────────────────────────┐
│ 🔄 Saving memory...             │ ← Status bar
└─────────────────────────────────┘
│ [Cancel]        [Save]          │
```

---

## Option 4: Floating Action Indicator (Top Right)
**Concept**: Small floating indicator in top-right corner of screen during operations.

**Implementation**:
- Small circular badge (48px) with spinner
- Positioned in top-right, above content
- Shows spinner + optional text tooltip on hover/tap
- Subtle shadow, semi-transparent background
- Auto-dismisses on completion

**Pros**:
- Doesn't affect layout at all
- Modern, iOS-style approach
- Out of the way but visible
- Can show percentage or status on tap

**Cons**:
- Less prominent, might be missed
- Requires interaction for details
- Might conflict with app bar

**Visual**:
```
┌─────────────────────────┐
│ [Title]            [🔄]│ ← Floating indicator
│                         │
│ [Content Area]          │
```

---

## Option 5: Button State with Overlay Combo (Hybrid)
**Concept**: Compact button state + optional overlay for detailed progress.

**Implementation**:
- Save button: Shows spinner icon, stays compact
- When detailed progress needed: Show Option 2 overlay banner
- Success: Subtle checkmark animation in button, then navigate
- No success toasts - rely on navigation/state change

**Pros**:
- Best of both worlds
- Button always compact
- Detailed info when needed
- No intrusive toasts

**Cons**:
- More complex implementation
- Two systems to maintain

---

## Option 6: Bottom Sheet Style Progress
**Concept**: Slide-up bottom sheet (like iOS share sheet) showing progress.

**Implementation**:
- Bottom sheet slides up from bottom (200px height)
- Shows progress with cancel option
- Dismisses automatically on completion
- Can be dismissed manually

**Pros**:
- Very clear, prominent feedback
- Can show detailed progress
- Familiar iOS pattern
- Doesn't affect main UI

**Cons**:
- More intrusive
- Requires dismissal interaction
- Might feel heavy for simple operations

---

## Success Notification Alternatives

### Current: SnackBar Toast
❌ Intrusive, blocks content, feels outdated

### Alternative A: Subtle Checkmark Animation
- Show checkmark icon in save button for 1 second
- Then navigate/close screen
- No separate toast needed

### Alternative B: Haptic Feedback Only
- Success haptic on completion
- Navigate immediately
- Trust that navigation = success

### Alternative C: Status Banner Success State
- Use Option 2/3 banner, show green checkmark + "Saved"
- Auto-dismiss after 1.5 seconds
- Then navigate

### Alternative D: No Success Feedback
- Just navigate on success
- User sees their memory in timeline = success confirmation
- Most minimal approach

---

## Recommended Combination

**Primary**: Option 1 (Compact Spinner) + Option 2 (Overlay Banner)
- Save button shows spinner, stays compact
- Overlay banner shows detailed progress messages
- Success: Subtle checkmark in button + navigate (no toast)

**Why**:
- Solves overlap issue (button stays fixed height)
- Provides detailed feedback when needed
- Clean, modern approach
- No intrusive toasts
- **Works consistently across all memory types** - same UI pattern for moments, mementos, and stories
- **Handles current processing differences**:
  - Moments/Mementos: Shows processing status during synchronous processing (save awaits completion)
  - Stories: Shows "Story saved! Processing in background..." message for asynchronous processing
- **After normalization**: All types will process asynchronously with consistent UX
- **User experience is consistent** - same visual feedback pattern regardless of memory type

---

## Implementation Notes

### Save Button States
1. **Idle**: "Save" text, enabled
2. **Saving (Online)**: Spinner icon, disabled, same height
   - Shows during: Upload → Save to DB → Processing (if synchronous)
3. **Saving (Offline)**: Spinner icon, disabled, same height
   - Shows during: Queue write (very brief)
   - Much faster than online save
4. **Success**: Checkmark icon (1s), then navigate
   - For offline: "✅ Queued for sync" message
   - For online: Navigate immediately after save completes (processing continues in background)

### Overlay Banner States (Normalized for All Memory Types)

**Online Save Flow**:
1. **Hidden**: Not shown initially
2. **Uploading**: "📤 Uploading photos... (2/5)" or "📤 Uploading videos... (1/3)" or "📤 Uploading audio..." (if media exists)
3. **Saving**: "💾 Saving memory..." (DB write)
4. **Generating Title** (First LLM call): "⚙️ Generating title..." (happens first, generates title from `input_text`) — driven entirely by the server dispatcher updating `processing_stage='title_generation'`
5. **Processing Text/Narrative** (Second LLM call): 
   - All memory types: "⚙️ Processing text..." (moments/mementos) or "⚙️ Generating narrative..." (stories) pulled from `processing_stage='text_processing'`. This happens asynchronously on the server after the DB write completes.
6. **Background Processing (Persistent)**: After the DB write returns, the overlay transitions to a compact sticky state that follows the user (even after navigation) and reflects the current `processing_stage` from `memory_processing_status`. Users can dismiss it, but it reappears if the stage is still `processing`.
7. **Complete**: When the async stage reports `complete`, the banner shows a success state for ~1.5s, the save button plays the checkmark animation, and then the banner gracefully fades.

**Offline Save Flow**:
1. **Hidden**: Not shown initially
2. **Queuing**: "💾 Queuing memory..." (saves to queue)
3. **Success**: "✅ Queued for sync" (brief, then navigate)
4. **After Sync** (when connectivity restored):
  - Sync service handles upload/save
  - Processing starts automatically
  - The global overlay re-attaches in its compact persistent form and mirrors the `processing_stage` (so users still see "Generating title..." or "Processing text..." while the job runs in the background)
  - Timeline shows "Pending sync" badge until sync completes
  - Timeline shows processing indicator if processing in progress

**Key Difference**: Offline saves don't show processing status (processing hasn't started yet). Processing status only appears after sync completes.

**Note**: All memory types use two separate LLM calls - first for title generation (from `input_text`), then for text/narrative processing (also from `input_text`). The difference is timing: moments/mementos process synchronously during save (save service awaits), while stories process asynchronously after save (fire-and-forget). After normalization, all types will process asynchronously.

**Key Points**:
- Overlay banner **persists** until processing actually completes (no auto-dismiss)
- Shows actual processing status - helpful for debugging
- Can be dismissed manually by user if desired
- Processing status also visible in timeline/detail view via `memory_processing_status` table
- If processing fails, banner shows error state with retry option

### Success Handling
- No SnackBar toast
- Brief checkmark animation in button
- Navigate to detail/timeline
- User sees their memory = confirmation

---

## Visual Mockup (Recommended)

```
┌─────────────────────────────────┐
│         [Memory Type]           │ ← AppBar
├─────────────────────────────────┤
│ [Queue Status Chips]            │
│                                 │
│ [Main Content Area]             │
│                                 │
│                                 │
├─────────────────────────────────┤
│ 🔄 Uploading media... (3/5)     │ ← Overlay Banner (when active)
│ ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░ │ ← Progress bar
├─────────────────────────────────┤
│ [Cancel]        [🔄]            │ ← Save button with spinner
└─────────────────────────────────┘
│ [Timeline] [Capture] [Settings]│ ← Bottom nav (no overlap!)
```

---

## Consistency Considerations

### Why Option 1 + Option 2 Works Best for Consistency

**Unified User Experience**:
- All memory types use the same visual pattern (compact spinner button + overlay banner)
- Users see consistent feedback regardless of memory type
- The overlay banner adapts its message based on memory type and processing stage
- **After normalization: All types process asynchronously** - consistent behavior across the board
- **Current state**: Moments/mementos process synchronously, stories process asynchronously (inconsistent)

**Current Processing Flow** (to be normalized):
- **Synchronous** (spinner tracks): Upload → Save to DB
- **Moments/Mementos**: Processing happens SYNCHRONOUSLY (two LLM calls: title generation → text processing)
- **Stories**: Processing happens ASYNCHRONOUSLY (two LLM calls: title generation → narrative generation)
- **Proposed Normalization**: Make all processing asynchronous - save completes immediately after DB write, processing continues in background
- Overlay persists until processing actually completes (no auto-dismiss)
- Processing status visible in timeline/detail view

**Benefits**:
- **Faster perceived save time** - users don't wait for LLM
- **Consistent UX** - same pattern for all memory types
- **Better debugging** - actual status shown, not auto-dismissed
- **Offline support** - saves queue, processing happens when online
- **More resilient** - processing failures don't fail saves

**Result**: Users get a consistent, predictable experience - same UI components, same interaction pattern, same processing flow, with messages that adapt to the specific processing stage.

---

## Implementation Plan

### Phase 1: Database & Backend Changes

1. **Create unified processing status table + stage enum**
   ```sql
   CREATE TYPE processing_status_enum AS ENUM ('processing', 'complete', 'failed');
   CREATE TYPE processing_stage_enum AS ENUM (
     'queued',
     'title_generation',
     'text_processing',
     'complete',
     'failed'
   );

   CREATE TABLE memory_processing_status (
     memory_id UUID PRIMARY KEY REFERENCES memories(id) ON DELETE CASCADE,
     processing_status processing_status_enum NOT NULL DEFAULT 'processing',
     processing_stage processing_stage_enum NOT NULL DEFAULT 'queued',
     stage_context JSONB, -- payload for UI (e.g., counts, retry metadata)
     processing_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
     processing_completed_at TIMESTAMPTZ,
     processing_error TEXT,
     retry_count INTEGER NOT NULL DEFAULT 0,
     last_retry_at TIMESTAMPTZ,
     processing_metadata JSONB -- For type-specific metadata
   );
   
   CREATE INDEX idx_memory_processing_status_status 
     ON memory_processing_status(processing_status);
   CREATE INDEX idx_memory_processing_status_stage 
     ON memory_processing_status(processing_stage);
   CREATE INDEX idx_memory_processing_status_started 
     ON memory_processing_status(processing_started_at);
   ```
   
   **Migration from story_fields**:
   - Migrate `story_status`, `processing_started_at`, `processing_completed_at`, `processing_error`, `retry_count`, `last_retry_at` from `story_fields` to `memory_processing_status`
   - Keep `story_fields` for story-specific fields (narrative_text, audio_path, etc.)
   - Create `memory_processing_status` rows for all existing stories with status
   - Populate `processing_stage` based on what was last completed (`complete` if narrative exists, `text_processing` if processing mid-flight, etc.)

   **Stage semantics**:
   - `queued`: memory has a status row but processing job not yet picked up. Overlay shows "Queued for processing..."
   - `title_generation`: Edge function is generating the title. Overlay shows "⚙️ Generating title..."
   - `text_processing`: Edge function is processing text/narrative. Overlay shows "⚙️ Processing text..." or "⚙️ Generating narrative..." depending on memory type.
   - `complete`: Both steps done. Overlay plays success animation and dismisses.
   - `failed`: Processing encountered an error. Overlay shows retry CTA and detail from `processing_error`.

2. **Add server-driven processing queue**
   ```sql
   CREATE TYPE processing_job_status_enum AS ENUM ('queued', 'running', 'failed', 'complete');

   CREATE TABLE memory_processing_jobs (
     job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
     memory_id UUID NOT NULL REFERENCES memories(id) ON DELETE CASCADE,
     memory_type memory_type_enum NOT NULL,
     status processing_job_status_enum NOT NULL DEFAULT 'queued',
     attempts INTEGER NOT NULL DEFAULT 0,
     last_error TEXT,
     created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
     updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
   );
   ```
   - Trigger: `AFTER INSERT` on `memory_processing_status` inserts/updates a job row (skipped for offline saves because the row is inserted later by the sync service).
   - Worker: new Supabase Edge Function `dispatch-memory-processing` runs on cron (e.g., every 15s) and:
     1. Claims the oldest `queued` job with `status='running'`.
     2. Calls the correct processing edge function (`process-moment`, `process-memento`, `process-story`) using the service role key.
     3. Updates `memory_processing_status.processing_stage` as each sub-step completes.
     4. Marks `memory_processing_jobs.status` as `complete` or `failed` with retries.
   - Because the trigger enqueues jobs inside the same transaction as the save, processing will still run even if the app is closed immediately afterward.

3. **Update edge functions**
   - `process-moment`, `process-memento`, and `process-story` no longer rely on client-side invocation; they read the `memory_processing_status` row that enqueued them.
   - Each function sets `processing_stage='title_generation'` before the first LLM call, `processing_stage='text_processing'` before the second, and `'complete'` plus timestamps when done.
   - On failure they set `processing_stage='failed'`, increment `retry_count`, persist `processing_error`, and let the dispatcher decide whether to retry.
   - The dispatcher records duration + last run metadata inside `processing_metadata`.

4. **Update fallback title logic**
   - Change `_getFallbackTitle()` to generate from `input_text`:
     ```dart
     String _getFallbackTitle(MemoryType memoryType, String? inputText) {
       if (inputText != null && inputText.trim().isNotEmpty) {
         const maxLength = 50; // Configurable
         final trimmed = inputText.trim();
         if (trimmed.length <= maxLength) {
           return trimmed;
         }
         return '${trimmed.substring(0, maxLength)}...';
       }
       // Fallback to type + date/time if no input_text
       final now = DateTime.now();
       final dateStr = DateFormat('MMM d, y').format(now);
       switch (memoryType) {
         case MemoryType.story:
           return 'Story - $dateStr';
         case MemoryType.memento:
           return 'Memento - $dateStr';
         case MemoryType.moment:
         default:
           return 'Moment - $dateStr';
       }
     }
     ```
   
   **Note**: This aligns with `OfflineMemoryAdapter` which should also use `input_text` snippet instead of "Untitled Moment" (see `offline-memory-viewing-editing/phase-1-data-model-adapter.md`).
   
   - **Online saves**: Use `input_text` snippet as temporary title
   - **Offline saves**: Queue stores `input_text`, adapter uses snippet for display
   - **After sync**: Temporary title replaced by LLM-generated title

### Phase 2: Save Service Normalization

1. **Normalize processing flow**
   - Remove *all* direct calls to `_processingService.processMoment/Memento/Story`.
   - After the memory row is persisted (online), immediately insert the `memory_processing_status` row with `processing_stage='queued'`. The database trigger handles enqueuing the background job in the same transaction.
   - The UI still shows synchronous progress for uploads + DB writes, but the moment the status row exists the overlay can subscribe to that row and keep showing background progress.
   - Set temporary title from the `input_text` snippet (see fallback section) so timeline UI has something to render until processing completes.
   - All memory types now share the same async pattern: save completes → DB trigger enqueues job → background dispatcher runs LLM calls.

2. **Update offline queue handling**
   - Ensure all memory types queue properly when offline
   - **Offline saves**: No `memory_processing_status` row created (memory not in DB yet)
   - **Sync service**: After sync completes, creates `memory_processing_status` row with `processing_stage='queued'`
   - **Processing triggers**: The same database trigger enqueues a job, so nothing special is needed on the client
   - Processing status tracked in `memory_processing_status` table (only after sync)

### Phase 3: UI Updates

1. **Save button states**
   - Idle: "Save" text, enabled
   - Saving: Spinner icon, disabled, same height
   - Success: Checkmark icon (1s), then navigate

2. **Overlay banner implementation**
   - Show during synchronous operations (upload, save)
   - **Persist during asynchronous operations** (processing) - no auto-dismiss
   - Use `processing_stage` from `memory_processing_status` to determine copy/icon ("Generating title...", "Processing text...", etc.)
   - Update status in real-time as processing progresses (polling or real-time subscriptions)
   - **Can persist across navigation** - if user navigates away, overlay can follow or show status in destination view
   - Allow manual dismissal by user (but show indicator in timeline/detail view if still processing)
   - Show error state with retry option if processing fails
   - Dismiss automatically only when `processing_status='complete'` or `'failed'` (with user action)

3. **Overlay persistence behavior**
   - **During save screen**: Overlay shows all status updates
   - **After navigation**: Overlay can persist as floating indicator OR show status in destination view
   - **Timeline view**: Show processing indicator badge on memory cards
   - **Detail view**: Show processing status banner if still processing
   - **Status updates**: Poll `memory_processing_status` table or use real-time subscriptions

3. **Remove SnackBar toasts**
   - Replace with overlay banner success state
   - Use checkmark animation in button
   - Navigate on success

### Phase 4: Status Visibility

1. **Timeline view**
   - Show processing indicator on memory cards (for synced memories)
   - Query `memory_processing_status` to show current state
   - **Coordinate with offline-first** (preview index + queues, per `offline-memory-viewing-editing`):
     - **Queued offline memories** (from the queues, `TimelineMoment.isOfflineQueued == true`) show a "Pending sync" / "Syncing" / "Sync failed" / "Synced" badge driven by the `OfflineSyncStatus` enum
     - **Preview-only memories** (from the preview index, `TimelineMoment.isPreviewOnly == true`) remain visible when offline but are greyed out and show a subtle "Not available offline" chip; they do not navigate to detail while offline
     - **Synced, processing memories** show the LLM processing indicator when `processing_status='processing'` in `memory_processing_status`
     - Badges from `OfflineSyncStatus` and processing indicators from `memory_processing_status` can coexist on the same card when appropriate (e.g., recently-synced but still processing)
   - Update cards when processing and/or sync completes (real-time or polling)

2. **Detail view**
   - Show processing status if still processing
   - Allow retry if processing failed
   - Show processing error details

### Phase 5: Testing & Refinement

1. Test consistency across all memory types
2. Test offline saving and sync
3. Test processing status updates
4. Test error handling and retry
5. Test on various screen sizes
6. Ensure no overlap with bottom navigation

---

## Next Steps
1. ✅ **Choose preferred option(s)**: Option 1 + Option 2 (Compact Spinner + Overlay Banner)
2. ✅ **Architecture decision**: Normalize all processing to async
3. ✅ **Database design**: Unified `memory_processing_status` table
4. ✅ **Title strategy**: Use `input_text` snippet as temporary title
5. ✅ **Overlay behavior**: Persist until processing completes (no auto-dismiss)
6. ✅ **Offline integration**: Coordinate with offline-first transition (see `notification-redesign-offline-integration.md`)
7. **Implement Phase 1**: Database & backend changes
8. **Implement Phase 2**: Save service normalization
9. **Implement Phase 3**: UI updates
10. **Implement Phase 4**: Status visibility
11. **Implement Phase 5**: Testing & refinement

## Related Documents

- `offline-memory-viewing-editing/README.md` - Offline-first implementation plan
- `offline-memory-viewing-editing/phase-1-data-model-adapter.md` - Temporary title strategy alignment

