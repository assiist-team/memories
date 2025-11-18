# Phase 7: Story Fields Extension & Title Nullability

One focused plan to:

- Fix the `title` column contract on the unified `memories` table (make it optional and honest).
- Move story-specific processing fields out of the core `memories` table into a dedicated `story_fields` extension table.

There is **no production data to preserve**, so we can assume a clean slate and apply non‑backwards‑compatible schema changes.

---

## 1. Problem Statement

- **Title is incorrectly required at the DB level**
  - `supabase/migrations/20250115000000_create_moments_table.sql` defines `title TEXT NOT NULL` and comments it as “required”.
  - Actual behavior: the app inserts a memory first, then generates or falls back to a title asynchronously.
  - Impact: the schema lies about what’s required and artificially couples insert flows to title generation.

- **Story‑specific fields live in the core memories table**
  - Migrations like `20251117130200_extend_stories_table_for_voice_processing.sql` add story‑only fields (e.g. `story_status`, `narrative_text`, `audio_path`, retry metadata) directly to `public.moments` / `public.memories`.
  - This bloats the base table with columns that are NULL or meaningless for non‑story memories.
  - It also makes constraints and documentation harder: you can’t accurately express which fields are only valid for stories without a mess of nullable columns.

- **Raw transcript is legacy**
  - Earlier migrations added `raw_transcript` and used it for title/narrative generation.
  - Phase 1/2 architectural docs and the current implementation agree that `input_text` is the canonical text field and `raw_transcript` should not be part of the long‑term model.

---

## 2. Goals & Non‑Goals

- **Goals**
  - Make the database contract for `title` match the app and spec:
    - `title` is **optional on insert** and often generated.
    - Comments clearly describe that `generated_title` is the last suggestion and `title` is the user‑visible field.
  - Cleanly separate **shared memory fields** from **story‑specific processing fields**.
    - Core table: `public.memories` with fields that apply to all memory types.
    - Extension table: `public.story_fields` with fields that only make sense for stories.
  - Remove `raw_transcript` from the long‑term model wherever feasible.

- **Non‑Goals**
  - No change to high‑level capture UX or memory types (`moment`, `story`, `memento`).
  - No change to timeline/feed business logic other than adapting queries to the new schema.
  - No attempt to support live, in‑place migration of large legacy datasets (we currently have none).

---

## 3. Target Schema Design

### 3.1 Core `memories` Table (Shared Fields)

The core table should remain the single source of truth for all memory types, and hold only **shared** fields:

- **Identity & ownership**
  - `id UUID PRIMARY KEY`
  - `user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`
  - `memory_type memory_type_enum NOT NULL DEFAULT 'moment'`

- **Text model**
  - `title TEXT` — optional, current display title.
  - `generated_title TEXT` — last LLM‑generated title suggestion.
  - `title_generated_at TIMESTAMPTZ` — when `generated_title` was created.
  - `input_text TEXT` — canonical raw user text from dictation or typing.
  - `processed_text TEXT` — LLM‑processed version of `input_text` (narrative for stories, cleaned description for others).

- **Media & tags**
  - Photo/video URL or path arrays as already defined.
  - `tags TEXT[]` (or equivalent) for search and organization.

- **Timestamps & metadata**
  - `created_at`, `updated_at`, any shared location columns, etc.

**Important:** the core table should **not** contain story processing fields like `story_status`, `narrative_text`, `audio_path`, `retry_count`, etc.

### 3.2 Story Extension Table: `story_fields`

Introduce a dedicated story extension table that “extends” `memories` in a 1‑to‑1 fashion:

- **Table name**
  - `public.story_fields`
  - Rationale: clearly scoped to story‑specific fields; pairs naturally with the core `memories` table.

- **Columns**
  - `memory_id UUID PRIMARY KEY REFERENCES public.memories(id) ON DELETE CASCADE`
    - Represents “this story’s extra data”; one row per story memory.
  - `story_status story_status` (ENUM) — processing status (`processing`, `complete`, `failed`).
  - `processing_started_at TIMESTAMPTZ`
  - `processing_completed_at TIMESTAMPTZ`
  - `narrative_generated_at TIMESTAMPTZ`
  - `narrative_text TEXT` — story narrative produced by LLM (aligned with `processed_text` semantics).
  - `audio_path TEXT` — Supabase Storage path for the story’s audio.
  - `retry_count INTEGER NOT NULL DEFAULT 0`
  - `last_retry_at TIMESTAMPTZ`
  - `processing_error TEXT`

- **Indexes**
  - Indexes equivalent to the existing story‑specific ones, but on `story_fields`:
    - `idx_story_fields_story_status` on `story_status` (for processing queues).
    - `idx_story_fields_processing_started_at`, `idx_story_fields_processing_completed_at`, `idx_story_fields_narrative_generated_at`.
    - `idx_story_fields_retry_count` on `retry_count`.

- **Invariants**
  - `story_fields` rows exist **only** for `memories.memory_type = 'story'`.
  - The app/processing pipeline must ensure a row is created when a new story memory is inserted.

---

## 4. Migration Plan (No Existing Data)

Because we have no real data to preserve, we can choose a **simple, destructive‑friendly path**.

### 4.1 Make `title` Optional

1. **Drop NOT NULL on `title`**
   - For the current table name (`memories`):
     - `ALTER TABLE public.memories ALTER COLUMN title DROP NOT NULL;`
   - Optionally include a safety check to only run if `title` exists.

2. **Update comments**
   - Replace “required” language with an accurate description:
     - `title`: “Current display title. May be NULL on insert; often generated from input_text.”
     - `generated_title`: “Last auto‑generated title suggestion from LLM/title service.”
     - `title_generated_at`: “Timestamp when generated_title was created.”

3. **Confirm app behavior**
   - Validate that `MemorySaveService` can insert memories without a `title` and later update it with generated or fallback titles.

### 4.2 Introduce `story_fields` Table

1. **Create `story_status` enum (if not already present)**
   - `CREATE TYPE story_status AS ENUM ('processing', 'complete', 'failed');`

2. **Create `story_fields` table**
   - Define `memory_id` as `PRIMARY KEY` and `REFERENCES public.memories(id) ON DELETE CASCADE`.
   - Add story‑specific columns and comments as described in §3.2.

3. **Add indexes**
   - Create the indexes that mirror the existing story‑specific indexes on `moments`/`memories`.

4. **Wire up insertion**
   - Update:
     - Story creation flows (RPCs / services) to insert into `story_fields` whenever a story memory is created.
     - Background processing / edge functions to read/write from `story_fields` instead of story columns on `memories`.

### 4.3 Remove Story Fields From Core Table

Once the codebase has been updated to use `story_fields`:

1. **Drop story‑specific columns from `memories`**
   - `story_status`
   - `processing_started_at`
   - `processing_completed_at`
   - `narrative_generated_at`
   - `narrative_text`
   - `audio_path`
   - `retry_count`
   - `last_retry_at`
   - `processing_error`

2. **Drop any story‑specific indexes on `memories`**
   - e.g. `idx_memories_story_status`, `idx_memories_processing_started_at`, etc., if present.

3. **Update comments**
   - Ensure the `memories` table comments no longer refer to story‑specific semantics.

---

## 5. Code & API Changes

High‑level areas to touch once the schema is changed:

- **Backend / Edge Functions**
  - Title generation:
    - Continue writing `title` / `generated_title` updates to `memories`.
  - Story narrative processing:
    - Read story inputs from `memories` (`input_text` / audio path).
    - Write status, timestamps, narrative, and errors to `story_fields`.

- **Supabase RPC / SQL Functions**
  - Any functions that currently join against story processing columns on `memories` should be updated to join `story_fields` instead.

- **Timeline / Detail Views**
  - For story details: join `story_fields` for narrative/status fields.
  - For unified timeline feeds: rely on `memories` and search vectors; only join `story_fields` when necessary for story‑specific UI.

---

## 6. Testing & Verification

- **Schema verification**
  - Confirm `title` is nullable in `public.memories`.
  - Confirm `story_fields` exists with correct FKs and indexes.
  - Confirm `memories` no longer contains story‑specific columns once cleanup is done.

- **Behavioral checks**
  - Create:
    - A moment with only text or media (no title in payload).
    - A memento with only media.
    - A story with audio; verify a `memories` row and a `story_fields` row are both created.
  - Ensure title generation still works and `title`/`generated_title` are correctly updated.
  - Verify story processing reads/writes to `story_fields` and that status transitions behave as expected.

---

## 7. Rollout Notes

- With no existing data, we can:
  - Apply migrations in a dev/staging environment.
  - Regenerate Supabase types.
  - Update code to use the new schema.
  - Run the test suite and manual smoke tests for capture → save → processing.
- Once everything passes, apply the same migrations to production without needing data backfills.


