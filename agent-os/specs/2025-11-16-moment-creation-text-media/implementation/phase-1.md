# Phase 1 Implementation Status — Moment Creation (Text + Media)

## Summary
Phase 1 covers the back-end architecture work: schema extensions, title-generation edge function, and storage cleanup automation. The Supabase project already reflects all required schema changes, and both edge functions live under `supabase/functions`. However, none of the database changes are represented as migrations in the repo, and the cleanup hook still lacks documented scheduling/enqueue wiring. This document records the current state and what remains.

## What’s Done
- **Moments schema extended (applied directly in Supabase)**
  - Columns present: `raw_transcript`, `generated_title`, `title_generated_at`, `tags text[]`, `captured_location geography(Point,4326)`, `location_status text`, `capture_type capture_type`.
  - Enum `capture_type` includes `moment | story | memento`.
  - Indexes observed via Supabase MCP:
    - `idx_moments_tags` (GIN on `tags`).
    - `idx_moments_capture_type`.
    - `idx_moments_title_generated_at` (partial).
    - `idx_moments_location` (GiST on `captured_location`).
- **Title generation edge function (`supabase/functions/generate-title/index.ts`)**
  - Validates JWTs, trims transcripts, calls OpenAI (configurable), truncates to ≤60 characters, and falls back to “Untitled {type}”.
  - Logs request metadata (`durationMs`, `requestId`, etc.) for observability.
- **Storage cleanup automation (`supabase/functions/cleanup-media/index.ts`)**
  - Processes `media_cleanup_queue` in batches, deletes Supabase Storage files with service role credentials, retries up to three times, and records status/error metadata.
  - Supporting table `media_cleanup_queue` exists in Supabase with the columns expected by the function.

## Gaps & Follow-Ups
- **Missing migrations + generated types**
  - The repo lacks SQL migrations for the `moments` table updates, `capture_type` enum, indexes, and `media_cleanup_queue`. Add migrations so other environments stay in sync, then regenerate Dart/TypeScript types.
- **Client integration**
  - Flutter services/models still reference the old `moments` shape. Update the data layer to read/write the new fields (e.g., `capture_type`, `raw_transcript`, `tags`).
- **Cleanup scheduling & enqueue docs**
  - Document or automate how orphaned media get enqueued. Add a Supabase cron schedule (or other trigger) for `cleanup-media` and describe the workflow in `docs/` or the spec.
- **Telemetry & monitoring**
  - Define dashboards/alerts for the new edge functions (success vs fallback rate, cleanup failures) so ops can detect regressions.

## Verification Commands
Use the Supabase MCP tools to inspect the live project:
- List tables: `mcp_supabase_list_tables`.
- Inspect moments indexes: `mcp_supabase_execute_sql` with `SELECT indexname, indexdef FROM pg_indexes WHERE tablename='moments';`.
- Check enum values: `SELECT enumlabel FROM pg_enum ... WHERE typname='capture_type';`.

These were run on 2025-11-17 to confirm the status above; re-run them after adding migrations to ensure parity between source control and the hosted database.

