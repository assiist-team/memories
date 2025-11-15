## API standards with Supabase and Edge Functions

- **Prefer Supabase over bespoke APIs**: Use Supabase client queries (PostgREST) for CRUD, filtering, sorting, and pagination. Don’t duplicate endpoints that PostgREST already provides.
- **Business logic close to data**: For server-side logic, prefer Postgres RPC (SQL functions exposed via Supabase) where appropriate.
- **Use Edge Functions selectively**: Add Edge Functions for third-party integrations, privileged workflows not expressible with RLS alone, or multi-step operations requiring orchestration.
- **Authentication and authorization**:
  - Require and validate the Supabase JWT in Edge Functions; return `401/403` when missing/invalid/unauthorized.
  - Forward the user’s JWT when calling Supabase from functions so RLS policies enforce access automatically.
  - Never expose or use service-role keys in client apps.
- **Function API conventions**:
  - Keep endpoints REST-shaped with plural, resource-oriented paths; exchange JSON (`Content-Type: application/json`).
  - Return consistent error payloads with `code`, `message`, and optional `details`.
  - Version via URL (e.g., `/v1/...`) when introducing breaking changes.
  - Prefer query parameters for filters/sorts/pagination instead of extra endpoints.
- **Observability**: Log structured JSON with request IDs and user IDs where available. Capture exceptions and performance signals in Sentry.
- **Rate limiting**: Apply platform-level throttling (Supabase API settings, Cloudflare) where needed; respond with `429 Too Many Requests` when applicable. Configure Supabase rate limits under Settings > API.
