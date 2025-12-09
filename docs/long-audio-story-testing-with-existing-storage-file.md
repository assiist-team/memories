### Long audio story testing with an existing Storage file

This document is written **for a model that has access to the Supabase MCP tools for this project**. The goal is to **create a new `story` memory that reuses an existing long audio file in Supabase Storage**, and then **kick off processing via the existing dispatcher pipeline**.

The steps below assume:
- There is **one test user** in `profiles` and `auth.users` (local/dev scenario).
- The long audio file is **already uploaded to Supabase Storage**.
- The audio file will be referenced via a **Storage path** (e.g. `story-audio/test/long-audio.m4a`).

You **must** use the Supabase MCP tools (e.g. `user-supabase-execute_sql`) for all database operations.

---

### 1. Collect required inputs

You will need:

- **`test_audio_path`**: Supabase Storage path for the existing long audio file.
  - This is **not** a full URL, just the bucket/path value used in the `story_fields.audio_path` column.
  - Example placeholder: `story-audio/USER_ID/2025-12-07-long-test.m4a`.
- **`test_user_id`**: UUID of the test user who owns the memory.

#### 1.1. Get the test user id from `profiles`

1. Call `user-supabase-execute_sql` with this query to inspect the existing profiles:

```sql
SELECT id, name, created_at
FROM public.profiles
ORDER BY created_at ASC
LIMIT 5;
```

2. **Pick the single existing profile row** (for local dev there is typically only one). Use its `id` as **`test_user_id`**.

Record:
- `test_user_id = <profiles.id>`
- `test_audio_path = <STORAGE_PATH_FOR_LONG_AUDIO>` (filled in by the human beforehand in this doc or given in the prompt).

---

### 2. Create a new `memories` row for the story

Create a new memory row with `memory_type = 'story'`. Use `now()` for timestamps for testing.

1. Call `user-supabase-execute_sql` with a parameterized INSERT like this (you may inline the literal values when running via MCP):

```sql
INSERT INTO public.memories (
  user_id,
  memory_type,
  memory_date,
  device_timestamp,
  title,
  input_text,
  processed_text,
  tags,
  photo_urls,
  video_urls,
  video_poster_urls,
  metadata_version
) VALUES (
  :test_user_id::uuid,
  'story'::memory_type_enum,
  now(),                -- memory_date: for testing, use now()
  now(),                -- device_timestamp: for testing, use now()
  NULL,                 -- title (will be filled by processing)
  NULL,                 -- input_text (we are driving from audio only)
  NULL,                 -- processed_text (to be generated)
  ARRAY[]::text[],      -- tags
  ARRAY[]::text[],      -- photo_urls
  ARRAY[]::text[],      -- video_urls
  ARRAY[]::text[],      -- video_poster_urls
  1                     -- metadata_version
)
RETURNING id;
```

2. Capture the returned `id` as **`new_memory_id`**.

---

### 3. Attach the existing audio file via `story_fields`

Create the corresponding `story_fields` row that points to the same `new_memory_id` and references the existing audio path.

1. Call `user-supabase-execute_sql` with:

```sql
INSERT INTO public.story_fields (
  memory_id,
  audio_path,
  audio_duration,
  narrative_generated_at
) VALUES (
  :new_memory_id::uuid,
  :test_audio_path::text,
  NULL,                 -- audio_duration (optional; let pipeline fill it in if needed)
  NULL                  -- narrative_generated_at (set when processed_text is generated)
);
```

2. Verify the row:

```sql
SELECT memory_id, audio_path, audio_duration
FROM public.story_fields
WHERE memory_id = :new_memory_id::uuid;
```

---

### 4. Schedule processing via `memory_processing_status`

To reuse the existing dispatcher pipeline, insert a `memory_processing_status` row in the `scheduled` state. Existing database triggers and the dispatcher Edge Function are responsible for picking up this job.

1. Call `user-supabase-execute_sql` with:

```sql
INSERT INTO public.memory_processing_status (
  memory_id,
  state,
  attempts,
  last_error,
  last_error_at,
  created_at,
  started_at,
  completed_at,
  last_updated_at,
  metadata
) VALUES (
  :new_memory_id::uuid,
  'scheduled'::memory_processing_state,
  0,
  NULL,
  NULL,
  now(),
  NULL,
  NULL,
  now(),
  jsonb_build_object(
    'memory_type', 'story',
    'source', 'long_audio_test',
    'audio_path', :test_audio_path::text
  )
);
```

2. Confirm the status row:

```sql
SELECT memory_id, state, attempts, metadata, created_at
FROM public.memory_processing_status
WHERE memory_id = :new_memory_id::uuid;
```

> **Important**: Do **not** modify the dispatcher function from this flow. The system is designed so that inserting a `memory_processing_status` row in `scheduled` state is enough to queue the job. Existing triggers / cron will handle dispatch.

---

### 5. Monitor processing progress

Use the MCP SQL tool to monitor progress for the new memory.

#### 5.1. Check processing status

```sql
SELECT state,
       attempts,
       last_error,
       last_error_at,
       started_at,
       completed_at,
       metadata
FROM public.memory_processing_status
WHERE memory_id = :new_memory_id::uuid;
```

#### 5.2. Check generated outputs on the memory

```sql
SELECT title,
       generated_title,
       title_generated_at,
       input_text,
       processed_text
FROM public.memories
WHERE id = :new_memory_id::uuid;
```

#### 5.3. Check story-specific fields

```sql
SELECT narrative_generated_at,
       audio_path,
       audio_duration
FROM public.story_fields
WHERE memory_id = :new_memory_id::uuid;
```

When `state = 'complete'` and `processed_text` + `generated_title` are populated, the long audio test memory has successfully passed through the full pipeline.

---

### 6. Summary for the model

- **Always use** `user-supabase-execute_sql` for DB reads/writes.
- **Inputs required**: `test_user_id` (from `profiles`) and `test_audio_path` (existing Storage path).
- **Flow**:
  1. Insert a `story`-type row into `public.memories` and capture `new_memory_id`.
  2. Insert a `public.story_fields` row for `new_memory_id` with `audio_path = test_audio_path`.
  3. Insert a `public.memory_processing_status` row for `new_memory_id` in `state = 'scheduled'`.
  4. Poll `memory_processing_status`, `memories`, and `story_fields` until processing is `complete` or `failed`.
