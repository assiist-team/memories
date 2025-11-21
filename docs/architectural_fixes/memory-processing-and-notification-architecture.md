## Memory Processing & Notification Architecture (Unified, Offline-Aware)

### 1. Scope & Intent

- **Goal**: Define a **single, coherent architecture** for:
  - Kicking off memory processing (two-step LLM pipeline).
  - Tracking processing status in a way that is:
    - **Unified across all memory types** (moment, memento, story).
    - **Compatible with offline viewing & editing** (`offline-memory-viewing-editing` phases).
  - Surfacing processing and sync status in the UI (buttons, overlays, timeline badges).
- **Non-goal**: Rebuild the entire offline system. We assume the offline phases (1–6) are the source of truth for:
  - Queue semantics (`OfflineQueueService`, `OfflineStoryQueueService`).
  - Timeline model (`TimelineMoment`, `OfflineSyncStatus`, `isOfflineQueued`, `isPreviewOnly`, etc.).
  - Preview index and local caching rules.

This document **replaces** the earlier, over-complicated “memory-processing-pipeline-and-notification-architecture” design that introduced both `memory_processing_status` and `memory_processing_jobs`. We keep the **behavioural goals**, but simplify the data model and clearly align it with the offline architecture.

---

### 2. Design Problems Addressed

The previous processing spec had a few core issues:

- **Redundant state machines**:
  - `processing_status`, `processing_stage`, and `processing_job_status` all tried to describe the same lifecycle.
  - This created drift risk and made it unclear which field was the source of truth.
- **Over-generalized job table**:
  - `memory_processing_jobs` duplicated state already present in `memory_processing_status`, without any concrete need for multiple jobs per memory.
- **Naming that wasn’t self-evident**:
  - Three different enums with nearly identical labels but different responsibilities.

This doc fixes that by:

- Defining **one processing table** (`memory_processing_status`) as the single source of truth.
- Using **one state enum** to represent the full processing lifecycle.
- Treating the **offline sync state** (`OfflineSyncStatus`) as a separate concern from processing.

---

### 3. Core Principles

- **Single source of truth for processing**:
  - Exactly **one row per memory** in `memory_processing_status` (when processing is relevant).
  - The `state` field on that row is the **only** authoritative processing lifecycle indicator.
- **Separation of concerns**:
  - **Transport/sync** is represented by:
    - Offline queues (`QueuedMoment`, `QueuedStory`).
    - `OfflineSyncStatus` in `TimelineMoment` (`queued`, `syncing`, `failed`, `synced`).
  - **AI processing** is represented by:
    - `memory_processing_status.state` (`queued`, `running`, `title_generation`, `text_processing`, `complete`, `failed`).
- **Event-driven, low-latency processing**:
  - No cron as a primary driver; processing should normally start within ~1s of a memory reaching the server.
- **Asynchronous processing for all memory types**:
  - All memory types follow the same pattern:
    - Synchronous: validation, uploads, DB writes, queue management.
    - Asynchronous: LLM title + text/narrative processing.
- **Offline-aware by design**:
  - Offline capture and editing **never depend** on processing.
  - Processing only begins **after** queue sync succeeds and the memory exists on the server.

---

### 4. Data Model – Unified Processing Table

#### 4.1 Table: `memory_processing_status`

We keep the existing table name, but simplify and clarify its responsibilities.

```sql
CREATE TYPE memory_processing_state AS ENUM (
  'queued',       -- row exists; work not yet started
  'processing',   -- one or more LLM steps are in progress
  'complete',     -- all required processing finished successfully
  'failed'        -- processing failed after retries
);

CREATE TABLE memory_processing_status (
  memory_id UUID PRIMARY KEY REFERENCES memories(id) ON DELETE CASCADE,

  -- Single lifecycle state for AI processing.
  state memory_processing_state NOT NULL DEFAULT 'queued',

  -- Retry + error metadata.
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  last_error_at TIMESTAMPTZ,

  -- Timestamps.
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  last_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Optional UI/diagnostic payload (e.g., current stage messages, timing, LLM model info).
  metadata JSONB
);

CREATE INDEX idx_memory_processing_status_state
  ON memory_processing_status(state);

CREATE INDEX idx_memory_processing_status_created_at
  ON memory_processing_status(created_at);
```

**Key points:**

- **No separate “jobs” table**:
  - Workers claim and update work directly via `memory_processing_status`.
  - If we ever need a full job system, we can introduce a separate, generic `jobs` module—but today we don’t.
- **`state` encodes the high-level lifecycle only**:
  - `queued`: used for worker discovery, capacity planning, and “about to process” UI.
  - `processing`: covers any internal structure (sequential or parallel LLM calls).
  - `complete` / `failed`: terminal outcomes for the whole pipeline.
- **Fine-grained stages live in `metadata`**:
  - If needed, workers can record sub-stages in `metadata` (e.g., `{"title_done": true, "text_done": false}` or `"phase": "title_generation"`).
  - UI may optionally use that for richer copy, but it must always degrade gracefully to generic “Processing…” text.

#### 4.2 Optional: `memory_processing_audit_log` table (audit log)

If we need a historical trace for debugging, we add an **append-only** log table instead of a second live state machine:

```sql
CREATE TABLE memory_processing_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  memory_id UUID NOT NULL REFERENCES memories(id) ON DELETE CASCADE,

  old_state memory_processing_state,
  new_state memory_processing_state NOT NULL,
  error TEXT,
  metadata JSONB,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

Workers append here on each transition. The UI never depends on this table.

---

### 5. End-to-End Flow – Online vs Offline

#### 5.1 Online Save Flow (All Memory Types)

**Synchronous (UI-blocking, tracked by save button spinner):**

1. **Validate & prepare capture state**.
2. **Upload media** to Supabase Storage.
3. **Insert `memories` row** (and any type-specific tables, e.g. `story_fields`).
4. **Insert `memory_processing_status` row**:
   - `memory_id = memories.id`.
   - `state = 'queued'`.
   - `attempts = 0`.
   - `metadata` can include `{"memory_type": "story" | "moment" | "memento"}`.
5. **Commit transaction**.

**Asynchronous (background, tracked by overlay + timeline indicators):**

6. A **dispatcher** (Edge Function / worker) is triggered when a new `queued` row appears (e.g., via database notification or a Supabase function that is called after insert).
7. Dispatcher:
   - Picks a `queued` row using `SELECT ... FOR UPDATE SKIP LOCKED`.
   - Sets:
     - `state = 'running'`,
     - `started_at = NOW()`,
     - `last_updated_at = NOW()`.
   - Calls the appropriate edge function:
     - `process-moment`, `process-memento`, or `process-story`.
8. Edge function logic:
   - Loads the memory and any needed text/audio from the DB/Storage.
   - Sets `memory_processing_status.state = 'processing'` (if not already).
   - Runs one or more LLM calls (for example: title generation + text/narrative processing), in **any** internal structure:
     - sequential,
     - parallel,
     - or with retries / backoff.
   - Updates the memory record(s) with final title / processed text as those steps complete.
   - May record sub-stage information in `metadata` (e.g., `{"title_done": true, "text_done": false}`), but this is optional and best-effort.
   - **On overall success**:
     - `state = 'complete'`.
     - `completed_at = NOW()`.
     - `last_updated_at = NOW()`.
   - **On overall failure**:
     - `state = 'failed'`.
     - `attempts = attempts + 1`.
     - `last_error`, `last_error_at`, `metadata` (e.g., `{ "reason": "...", "phase": "narrative" }`).

**Retry policy** (dispatcher-level, not modeled as a separate table):

- If `state = 'failed'` and `attempts < MAX_ATTEMPTS`, dispatcher can:
  - Set `state = 'queued'` again,
  - Try again later (with backoff).

#### 5.2 Offline Capture & Sync Flow (Aligned with Offline Phases 1–5)

The offline system remains the source of truth for capturing and editing while offline.

**When capturing offline:**

1. `MemorySaveService.saveMemory(...)` detects no connectivity.
2. A `QueuedMoment` / `QueuedStory` is written to:
   - `OfflineQueueService` or `OfflineStoryQueueService`.
3. `TimelineMoment` is updated via `OfflineQueueToTimelineAdapter`:
   - `isOfflineQueued = true`.
   - `offlineSyncStatus = OfflineSyncStatus.queued`.
4. **No `memory_processing_status` row exists yet** (memory is not on the server).

**When sync runs and succeeds (Phase 5):**

1. `MemorySyncService` reads queued entries and writes them to Supabase:
   - Inserts into `memories` and any related tables.
2. **As part of that same transaction**, it inserts a `memory_processing_status` row:

   ```sql
   INSERT INTO memory_processing_status (memory_id, state, attempts, metadata)
   VALUES (:memory_id, 'queued', 0, jsonb_build_object('memory_type', :memory_type));
   ```

3. `MemorySyncService` emits a `SyncCompleteEvent` (already defined in Phase 5).
4. `UnifiedFeedController` removes the queued card (`isOfflineQueued`) from its in-memory list.
5. On the **next online refresh** (or via live queries), the server-backed memory appears:
   - In the RPC results.
   - In the preview index (`LocalMemoryPreview`), via upsert.
6. The dispatcher picks up the new `queued` processing row and runs the same async processing pipeline as for online saves.

**Resulting invariants:**

- A memory **never** has a `memory_processing_status` row until it exists in `memories`.
- Offline capture and editing are fully supported with only:
  - Queue + preview index + `OfflineSyncStatus`.
- The moment we leave “purely local” and land on the server, the processing system takes over using the same rules as an online save.

---

### 6. UI & Notification Model

We keep the **high-level UX** from the earlier doc (compact save button + overlay), but bind it to the simplified state model and offline semantics.

#### 6.1 Save Button States (Capture Screen)

- **Idle**:
  - Label: “Save”.
  - Enabled.
- **Saving (Online)**:
  - Spinner replaces label.
  - Disabled.
  - Covers: validation → uploads → DB write (including `memory_processing_status` insert).
- **Saving (Offline)**:
  - Spinner for the very brief queue write.
  - Disabled during queue persistence only.
- **Success (Online)**:
  - Brief checkmark animation.
  - Navigate away; processing continues in background.
- **Success (Offline)**:
  - Brief checkmark + subtle copy (“Queued for sync”).
  - Navigate away; user sees a queued card with “Pending sync” chip.

#### 6.2 Global Processing Overlay (Online Only)

The overlay is driven by `memory_processing_status.state` and appears only for **server-backed** memories.

**Behaviour:**

- Shown when:
  - A save just completed online **and** a new processing row exists, or
  - The app observes any `state IN ('queued', 'running', 'title_generation', 'text_processing')` for a memory the user recently interacted with.
- Hidden when:
  - `state = 'complete'` (after a brief success state), or
  - User dismisses it (until next app session or a new processing job starts).

**State → copy mapping (examples):**

- `queued`:
  - “Queued for processing…”
- `running`:
  - “Starting processing…”
- `title_generation`:
  - “Generating title…”
- `text_processing`:
  - Moments/Mementos: “Processing text…”
  - Stories: “Generating narrative…”
- `failed`:
  - “Processing failed. We’ll retry automatically.” (+ optional “Retry now” if exposed).

**Data source:**

- The client uses Supabase real-time or polling to watch `memory_processing_status` rows for:
  - Current user’s memories, or
  - Just the last N recent saves.

#### 6.3 Timeline & Detail Indicators (Aligned with Offline Docs)

We deliberately keep **two orthogonal axes**:

- **Sync axis** (from offline docs):
  - `TimelineMoment.offlineSyncStatus` = `queued`, `syncing`, `failed`, `synced`.
  - Used for:
    - “Pending sync” / “Syncing” / “Sync failed” badges.
    - Offline detail/edit availability for queued entries.
- **Processing axis** (from this doc):
  - `memory_processing_status.state`.
  - Projected into UI as:
    - “Processing…” indicator on detail view for server-backed memories.
    - Optional tiny badge or icon (e.g., gear) on cards while state is not `complete` or `failed`.

**Important separation:**

- A memory can be **synced but still processing**:
  - `offlineSyncStatus = synced`.
  - `state IN ('queued', 'running', 'title_generation', 'text_processing')`.
- A queued offline memory has **no processing state yet**:
  - `isOfflineQueued = true`.
  - `offlineSyncStatus != synced`.
  - No `memory_processing_status` row.

This prevents the earlier confusion where sync and processing states were intermingled.

---

### 7. Alignment Check with Offline Architecture

After reviewing `offline-memory-viewing-editing` (phases 1–6 + findings), the key alignment points are:

- **Conceptual separation is already present**:
  - Offline docs define `OfflineSyncStatus` and timeline flags purely for **transport/sync and caching**.
  - They treat processing as a separate concern, only briefly referencing `memory_processing_status` in the README.
- **No second processing/job table**:
  - Offline docs do **not** introduce their own processing-job concepts; they just expect:
    - A `memory_processing_status` row to exist after sync.
    - An event-driven processing pipeline to kick in quickly.
- **Flags are numerous but justified**:
  - `isOfflineQueued`, `isPreviewOnly`, `isDetailCachedLocally`, `offlineSyncStatus` each serve distinct, visible UX roles.
  - There is no obvious redundancy on the scale of “job table vs status table”; most flags are directly reflected in UI differences.

**Minor cleanups to consider (not blockers for this doc):**

- `isPreviewOnly` could, in theory, be derived from `!isOfflineQueued && !isDetailCachedLocally`, but keeping it explicit keeps call sites clearer.
- For brand-new implementations, we should:
  - Document these flags in one place with short, example-based definitions.
  - Ensure OfflineSyncStatus naming is consistent everywhere (`queued` / `syncing` / `failed` / `synced`).

Overall, the offline system **does not replicate** the same architectural mistakes as the old processing doc. Its complexity is largely driven by explicit product requirements (preview-only entries, queued editing) rather than speculative generalization.

---

### 8. Implementation Checklist

#### 8.1 Backend / Supabase

- [ ] Create or migrate to the unified `memory_processing_status` schema above.
- [ ] Remove any unused `memory_processing_jobs` or equivalent tables (if they were created).
- [ ] Update edge functions:
  - [ ] `process-moment`
  - [ ] `process-memento`
  - [ ] `process-story`
  - so they:
    - [ ] Drive `memory_processing_status.state` through the lifecycle.
    - [ ] Update `attempts` / `last_error` / `metadata` appropriately.
- [ ] Implement dispatcher:
  - [ ] Claims `queued` rows via `SELECT … FOR UPDATE SKIP LOCKED`.
  - [ ] Enforces a simple retry policy.
  - [ ] Ensures normal latency (~1s from row insert to job start).
- [ ] Ensure `MemorySyncService`:
  - [ ] Inserts `memory_processing_status` rows when queue entries sync.
  - [ ] Does **not** attempt any LLM work itself.

#### 8.2 Mobile App – Processing & Notifications

- [ ] Save button:
  - [ ] Compact spinner-only state during synchronous work.
  - [ ] Checkmark-on-success behavior for both online and offline paths.
- [ ] Global overlay:
  - [ ] Driven by `memory_processing_status.state`.
  - [ ] Shows clear, concise copy per state.
  - [ ] Persistent until `state = 'complete'` or user dismisses.
- [ ] Timeline + detail:
  - [ ] Use `OfflineSyncStatus` for sync-related badges and banners (as per offline docs).
  - [ ] Optionally add a subtle processing indicator when `state` is not `complete` or `failed`.
  - [ ] Never block offline viewing/editing on processing state.

---

### 9. Summary

- We now have **one processing table, one processing enum, and one set of clear responsibilities** for AI processing.
- Offline systems continue to handle capture/edit/sync using `OfflineSyncStatus` and queues, without any processing entanglement.
- The UI can confidently:
  - Show **sync status** (local vs server-backed).
  - Show **processing status** (LLM pipeline) when relevant.
  - Keep the capture experience fast and consistent across all memory types.

This architecture is intentionally conservative and self-evident, avoiding speculative “job system” overdesign while leaving room for a richer job/event system in the future if product requirements actually demand it.


