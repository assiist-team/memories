## New Memory Shows Twice on Timeline & “Processing” Never Finishes

**Date:** 2025-11-25  
**Status:** 🟢 Resolved – duplicate entries fixed, UI badges implemented, backend dispatcher configuration pending  

This doc tracks an issue where creating a new memory results in:

- **Issue A:** A **duplicate timeline entry** for the same memory (“Test” and “Untitled Moment”) that briefly appear at the same time.  
- **Issue B:** The remaining entry shows a **“Processing” indicator that never completes**, even though processing should be fast.

These two symptoms share the same underlying context: the new unified memory-processing pipeline plus the unified timeline feed.

---

## Issue A — Duplicate Timeline Entries for a New Memory

### Problem Description

When saving a new memory from the capture flow while online:

- After returning to the **Unified Timeline**, the user sees **two entries** for what is clearly the **same memory**:
  - One entry titled **“Test”** (matching the raw input text).
  - One entry titled **“Untitled Moment”**.
- After a manual refresh, the **“Test”** entry disappears and only **“Untitled Moment”** remains.

From the user’s perspective, this looks like a corrupted or duplicated save.

### What the Data Shows

From Supabase, we see **only one row** for this memory in `memories`:

- `id`: `1ac87759-3b46-4601-8426-bd7f4ecdc99a`  
- `user_id`: `5aeed2a7-26f9-40ac-a700-3a6da123f3b5`  
- `title`: `"Untitled Moment"`  
- `input_text`: `"test"`  
- `memory_type`: `"moment"`  

And exactly **one row** in `memory_processing_status` for that `memory_id`.

**Conclusion:** the duplicate cards are **not** two different server memories; they are **two different client representations of the same logical memory**.

### Likely Root Cause

On the client side:

- The unified feed (`UnifiedFeedController` + `UnifiedTimelineScreen`) loads **server-backed memories** via the `get_unified_timeline_feed` RPC and maps them to `TimelineMemory` (`TimelineMemory.fromJson(...)`).  
- The offline system adds **queued offline entries** into the same feed via `OfflineQueueToTimelineAdapter` (not shown in this snippet but documented in the offline architecture).

The observed behaviour strongly suggests that, **after a successful online save**:

- The app is **showing an “optimistic” or queued-style entry** built from the capture state (with title derived from `"test"`), **and**  
- Also showing the **server-backed entry** with the fallback title `"Untitled Moment"` once the feed reloads.

Because both representations are in the feed at the same time, the user sees **two cards for one memory** until the next refresh clears the optimistic one.

### Desired Behaviour

- There should **never be two timeline items** for the same logical memory ID at the same time.
- For **online saves**:
  - The timeline should either:
    - **Skip** any local/optimistic card entirely and rely solely on the server-backed entry, **or**
    - Ensure the optimistic entry is **immediately replaced in-place** when the server-backed entry arrives (same effective ID, no visual duplication).
- The **only legitimate “duplicate-like” scenario** is:
  - A queued **offline** card (explicitly marked with a “Pending sync” badge), and  
  - Its server-backed sibling **after** sync, **but never simultaneously**; the queued one must be removed when sync completes.

### Current Mitigation (What to Fix in Code)

At the time of this incident:

- `UnifiedFeedController` removes queued entries when sync completes:

```168:183:lib/providers/unified_feed_provider.dart
  void _removeQueuedEntry(String localId) {
    final updated = state.memories
        .where((m) => !(m.isOfflineQueued && m.localId == localId))
        .toList();

    state = state.copyWith(memories: updated);
  }

  /// Handle queue change event - remove queued entry by localId
  void _removeQueuedEntryByLocalId(String localId) {
    final updated = state.memories
        .where((m) => !(m.isOfflineQueued && m.localId == localId))
        .toList();

    state = state.copyWith(memories: updated);
  }
```

However, for **online saves** that never go through the offline queue, we likely still:

- Add a temporary/optimistic entry to the feed, and  
- Then later fetch the server-backed entry with a different `id`/`serverId`, causing a visual duplicate.

**Action items (✅ IMPLEMENTED):**

- ✅ **Deduplication by serverId**: Added `_deduplicateByServerId` method in `UnifiedFeedRepository` that ensures at most one `TimelineMemory` per `serverId` when merging online and queued memories.
- ✅ **Deduplication on append**: Added `_deduplicateMemories` method in `UnifiedFeedController` that prevents duplicate entries when appending paginated results.
- ✅ **Preference logic**: When duplicates exist, the system prefers:
  - Server-backed entries over queued entries
  - Queued entries with full detail over preview-only entries
  - First-seen entry when characteristics are equal

---

## Issue B — “Processing” Indicator Never Completes

### Problem Description

For the same newly created memory:

- The timeline card shows a **“Processing” chip** (spinner + label).
- Even after waiting ~1 minute and refreshing the timeline, the badge:
  - **Never disappears**.
  - There is **no user-facing error state**.

From the user’s perspective, it looks like processing is frozen.

### What the Data Shows

Supabase query for the new memory’s processing status:

- Table: `memory_processing_status`
- Row for `memory_id = 1ac87759-3b46-4601-8426-bd7f4ecdc99a`:
  - `state = 'scheduled'`
  - `attempts = 0`
  - `started_at = null`
  - `completed_at = null`
  - `last_error = null`

Aggregate check:

- `select state, count(*) from public.memory_processing_status group by state;`
  - Returns **only**: `state = 'scheduled', count = 1`.

**Conclusion:**  
No processing job has ever:

- Claimed this row,  
- Transitioned it to `processing`, or  
- Marked it `complete`/`failed`.

### Relevant Backend Implementation

- `MemorySaveService` creates the `memory_processing_status` row:

```324:339:lib/services/memory_save_service.dart
      // Step 4: Insert memory_processing_status row if we have input_text to process
      // Processing will happen asynchronously via dispatcher
      final hasInputText = state.inputText?.trim().isNotEmpty == true;
      String? generatedTitle;

      if (hasInputText) {
        // Insert processing status row - dispatcher will pick this up
        try {
          await _supabase.from('memory_processing_status').insert({
            'memory_id': memoryId,
            'state': 'scheduled',
            'attempts': 0,
            'metadata': {
              'memory_type': state.memoryType.apiValue,
            },
          });
        } catch (e) {
          // Log but don't fail - processing status insert is best-effort
          // The dispatcher can still process the memory
          print('Warning: Failed to insert memory_processing_status: $e');
        }
      }
```

- Dispatcher Edge Function:

```22:75:supabase/functions/dispatch-memory-processing/index.ts
Deno.serve(async (req: Request): Promise<Response> => {
  ...
  // Claim scheduled jobs using SELECT ... FOR UPDATE SKIP LOCKED
  // This ensures only one dispatcher processes each job
  const { data: scheduledJobs, error: selectError } = await supabaseClient
    .rpc("claim_scheduled_processing_jobs", { batch_size: MAX_BATCH_SIZE });
  ...
});
```

Edge Function logs for this project show **no invocations** of `dispatch-memory-processing` at the time of the incident; only unrelated `search-places` 404s.

### UI Logic for the “Processing” Badge

On the timeline card (`MomentCard`), the processing chip is driven by `MemoryProcessingStatus.isInProgress`:

```141:144:lib/widgets/moment_card.dart
    // Show processing indicator for server-backed memories that are still processing
    if (!isQueuedOffline && moment.serverId != null) {
      badges.add(_buildProcessingIndicator(context));
    }
```

```158:175:lib/widgets/moment_card.dart
  Widget _buildProcessingIndicator(BuildContext context) {
    // Only show for server-backed memories
    if (moment.serverId == null) return const SizedBox.shrink();

    return Consumer(
      builder: (context, ref, child) {
        final statusAsync = ref.watch(
          memoryProcessingStatusStreamProvider(moment.serverId!),
        );

        return statusAsync.when(
          data: (status) {
            // Only show if processing is in progress
            if (status == null || !status.isInProgress) {
              return const SizedBox.shrink();
            }

            // Show a subtle processing indicator
            return Container(
              ...
              child: Text(
                'Processing',
                ...
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }
```

The model marks both `scheduled` **and** `processing` as “in progress”:

```101:111:lib/models/memory_processing_status.dart
  /// Check if processing is in progress
  bool get isInProgress {
    return state == MemoryProcessingState.scheduled ||
        state == MemoryProcessingState.processing;
  }
```

So any memory that has a `memory_processing_status` row in `state = 'scheduled'` will show the **same “Processing” badge** as one that is truly being worked on.

### Root Cause

This incident is a combination of:

- **Backend**: The **dispatcher function is not running at all** in this environment:
  - No `dispatch-memory-processing` calls in Supabase Edge Function logs.
  - No rows ever transition from `scheduled` → `processing`/`complete`/`failed`.
- **UI**: The app **treats `scheduled` as “in progress”**, so:
  - Merely inserting the row immediately shows “Processing”.
  - When the dispatcher is down, it **never turns off**.

### Resolution Plan

#### 1. Backend — Ensure Dispatcher Actually Runs

**Goal:** `dispatch-memory-processing` should be invoked automatically whenever there are `scheduled` jobs, or at a short interval (e.g. every 30–60 seconds).

Checklist:

- In **Supabase Dashboard → Edge Functions**:
  - Confirm that `dispatch-memory-processing` is **deployed** and has a recent deployment.
  - Confirm that a **scheduled invocation** or **hook** exists:
    - Either a **cron schedule** (Supabase Scheduled Functions) targeting `dispatch-memory-processing`, or
    - A **post-insert trigger** or RPC that calls the function when a new `memory_processing_status` row is inserted.
- In **Edge Function logs**:
  - Verify that `POST /functions/v1/dispatch-memory-processing` is being called regularly.
  - If not present, add/repair the scheduler configuration and redeploy.

Until this is fixed, all new memories will stay stuck in `state = 'scheduled'` and appear “forever processing” in the UI.

#### 2. UI — Different Badges for `scheduled` vs `processing` ✅ IMPLEMENTED

**Goal:** Make it clear when work is merely scheduled vs actively running, without hiding the fact that it's queued.

**Status:** ✅ Complete - The UI now renders **two distinct badges** on the timeline card:

- **`scheduled`** → badge text: **"Scheduled for processing"**  
- **`processing`** → badge text: **"Processing"**

Implementation (card-level mapping - already in place):

```158:203:lib/widgets/moment_card.dart
  Widget _buildProcessingIndicator(BuildContext context) {
    // Only show for server-backed memories
    if (moment.serverId == null) return const SizedBox.shrink();

    return Consumer(
      builder: (context, ref, child) {
        final statusAsync = ref.watch(
          memoryProcessingStatusStreamProvider(moment.serverId!),
        );

        return statusAsync.when(
          data: (status) {
            if (status == null) {
              return const SizedBox.shrink();
            }

            // Map processing state to user-facing badge label.
            String? label;
            switch (status.state) {
              case MemoryProcessingState.scheduled:
                label = 'Scheduled for processing';
                break;
              case MemoryProcessingState.processing:
                label = 'Processing';
                break;
              case MemoryProcessingState.complete:
              case MemoryProcessingState.failed:
                // No badge for completed/failed on the timeline card today.
                label = null;
                break;
            }

            if (label == null) {
              return const SizedBox.shrink();
            }

            // Show a subtle processing/scheduled indicator
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade800,
                          fontSize: 10,
                        ),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
    );
  }
```

Combined with the updated model, this gives us:

- **`scheduled`**: “Scheduled for processing” badge.  
- **`processing`**: “Processing” badge.  
- **`complete` / `failed`**: no badge on the card (detail banner still conveys richer status).

---

## Quick Triage Checklist for This Issue

When you see:

- A new memory shows **both “Test” and “Untitled Moment”**, and  
- The remaining entry’s **“Processing” badge never turns off**,

perform these checks:

1. **Database state**
   - `select * from memories order by created_at desc limit 5;`
   - `select * from memory_processing_status order by created_at desc limit 5;`
   - Confirm only **one** memory row exists for that logical memory and that its processing status is `scheduled` with `attempts = 0`.
2. **Edge Function logs**
   - In Supabase Dashboard, check logs for `dispatch-memory-processing` and `process-moment` / `process-story` / `process-memento`.
   - If there are **no entries**, the worker isn’t being invoked.
3. **Scheduler configuration**
   - Confirm that a Supabase **Scheduled Function** or other trigger is calling `dispatch-memory-processing`.
4. **UI expectations** ✅ VERIFIED
   - ✅ `MemoryProcessingStatus.isInProgress` returns `true` **only** for `processing` (not `scheduled`).
   - ✅ Timeline cards never show duplicate entries for the same `serverId` (deduplication implemented in `fetchMergedFeed` and `_fetchPage`).

Once the dispatcher is running and the UI change is deployed, this symptom should disappear:

- New memories will show at most **one** timeline card.  
- The “Processing” badge will appear briefly **only while actual processing is running**, and then clear when the job completes.


