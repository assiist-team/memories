### Long audio story testing: uploading a local audio file to Supabase Storage

This document is written **for a model that has access to the Supabase MCP tools and the local workspace**. The goal is to **take a local audio file (within this project workspace), upload it once to Supabase Storage**, and then provide a **stable Storage path** that can be reused by other testing flows (for example, the instructions in `long-audio-story-testing-with-existing-storage-file.md`).

You **must** use the Supabase MCP tools for Supabase metadata and database operations. For the actual file upload, you will typically use a shell command (`curl`) against the Supabase Storage REST API.

---

### 1. Collect required inputs

You will need:

- **`local_audio_path`**: absolute or project-relative path to the local audio file.
  - Example: `test_data/audio/long-story-test.m4a` (relative to the project root).
- **`bucket_name`**: the Supabase Storage bucket that should hold story audio.
  - For consistency, prefer a dedicated bucket name like `story-audio`.
- **`storage_object_path`**: path within the bucket (no leading slash) where you will store the audio file.
  - Example: `dev-long-audio-tests/2025-12-07-long-story-test.m4a`.

These three values should either be:
- Provided explicitly in the user prompt, or
- Derived as described below.

---

### 2. Determine project URL and API key for Storage

Use Supabase MCP tools to get connection details that can be used with the Storage REST API.

1. **Get the project URL** via MCP:

   - Call `user-supabase-get_project_url`.
   - Record the result as `project_url`. It should look like `https://YOUR_PROJECT_ID.supabase.co`.

2. **Get a publishable key** via MCP:

   - Call `user-supabase-get_publishable_keys`.
   - Choose a **non-disabled key** suitable for client-side operations (e.g. `anon` or `sb_publishable_...`).
   - Record it as `anon_key`.

> **Important**: Use the **same `anon_key`** for both `apikey` and `Authorization: Bearer` headers when calling the Storage REST API, unless the human has specifically provided a different key for this purpose.

---

### 3. Ensure the Storage bucket exists

If the bucket for story audio does not already exist, **ask the human to create it via the Supabase Dashboard** (models generally cannot manage Storage buckets via the MCP tools in this setup).

- Recommended name: **`story-audio`**.
- Ensure the bucket is configured so that uploads with the `anon_key` are permitted for testing.

Once the bucket exists:
- Record: `bucket_name = 'story-audio'` (or the name specified by the human).

---

### 4. Compute the object path from the local file name

If the user has not specified a `storage_object_path`, derive one from `local_audio_path`.

Given:
- `local_audio_path = <local path in workspace>`,
- Extract the **file name** (e.g. `long-story-test.m4a`).

Construct a path such as:

- `storage_object_path = 'dev-long-audio-tests/' || <file_name>`
  - Example: `dev-long-audio-tests/long-story-test.m4a`.

This keeps all test audio files under a clear prefix inside the bucket.

---

### 5. Upload the local audio file via `curl`

Use the Shell tool to run a `curl` command that uploads the binary file to Supabase Storage.

#### 5.1. Build the upload URL

The Storage upload endpoint is:

```text
{project_url}/storage/v1/object/{bucket_name}/{storage_object_path}
```

Example:

```text
https://YOUR_PROJECT_ID.supabase.co/storage/v1/object/story-audio/dev-long-audio-tests/long-story-test.m4a
```

#### 5.2. Run the upload command using Shell

1. Use the Shell tool (with network access) to execute a command of this form:

```bash
curl \
  -X POST \
  "${PROJECT_URL}/storage/v1/object/${BUCKET_NAME}/${STORAGE_OBJECT_PATH}" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: audio/m4a" \
  --data-binary @"${LOCAL_AUDIO_PATH}"
```

Where you substitute:
- `PROJECT_URL` with `project_url` from `user-supabase-get_project_url`.
- `BUCKET_NAME` with `bucket_name` (e.g. `story-audio`).
- `STORAGE_OBJECT_PATH` with the computed `storage_object_path`.
- `ANON_KEY` with the selected `anon_key` from `user-supabase-get_publishable_keys`.
- `LOCAL_AUDIO_PATH` with the actual local audio file path in the workspace.

2. Check the `curl` response:
   - HTTP `200` or `201` indicates success.
   - If you get `403` or `401`, you likely have a bucket policy or key issue. In that case, **ask the human to adjust bucket permissions or provide a different key**.

---

### 6. Derive the Storage path for later use

After a successful upload, the **Storage path** you will use for testing is:

```text
<BUCKET_NAME>/<STORAGE_OBJECT_PATH>
```

For example:

```text
story-audio/dev-long-audio-tests/long-story-test.m4a
```

This is the value that should be:
- Stored in `story_fields.audio_path`, and
- Passed as `test_audio_path` to the instructions in `long-audio-story-testing-with-existing-storage-file.md`.

Record for the human and future models:

- **`test_audio_storage_path`**: `story-audio/dev-long-audio-tests/long-story-test.m4a`

---

### 7. (Optional) Verify from the database side

If you have any tables that reference Storage paths (e.g. `story_fields.audio_path`), you can confirm that the new path is not yet used (or that it is used as expected):

```sql
SELECT memory_id, audio_path
FROM public.story_fields
WHERE audio_path = :test_audio_storage_path;
```

Use `user-supabase-execute_sql` to run this check.

---

### 8. Summary for the model

- **Use Supabase MCP** to obtain `project_url` and `anon_key`.
- **Use Shell + `curl`** to upload the local audio file to the Storage REST API.
- **Store the resulting Storage path** (`bucket_name/storage_object_path`) and surface it to the human or other flows as `test_audio_storage_path`.
- That `test_audio_storage_path` can then be reused to create many test memories without re-uploading the audio file.
