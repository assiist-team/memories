# Tasks: Search Functionality Full Text

## 1. Product & UX Definition
- Confirm final copy for search placeholder, empty states, recent searches, and load-more CTA.
- Define accessibility labels and focus handling for the persistent search bar and results list.
- Align with Unified Timeline spec owners on messaging that instructs users to use timeline filters for advanced filtering.

## 2. Database & Backend Foundations
- Design PostgreSQL search schema updates: decide between direct `tsvector` columns or materialized view per table.
- Write migrations to add weighted `tsvector` columns or materialized view plus GIN indexes for Stories, Moments, Mementos.
- Ensure triggers or edge functions refresh indexes/materialized views on insert/update/delete.
- Expose a secured RPC or REST endpoint in Supabase that accepts query text, pagination cursor, and user session, enforcing RLS.
- Unit test the SQL functions for correct weighting and pagination behavior.

## 3. Search API Layer
- Implement a backend service wrapper (Supabase client helper) that builds `plainto_tsquery`/`phraseto_tsquery` based on user input and validates syntax (quoted phrases, minus terms).
- Enforce the 20-result limit with cursor/offset handling and provide count of remaining rows to drive “Load more”.
- Log slow queries over 500ms and expose observability hooks for future tuning.
- Add endpoint contract documentation for frontend use (request/response schema, error formats).

## 4. Flutter UI: Global Search Entry
- Embed a persistent search field in the global header component, styled for light/dark modes and both orientations.
- Implement debounced text editing controller (≈250ms) and loading indicator beneath the field.
- Handle focus retention, keyboard dismissal, and “clear recent searches” link.
- Display recent searches list when field is focused and empty, with selectable chips.

## 5. Flutter UI: Results List & Pagination
- Build a reusable results list widget that sections hits by memory type with badges, highlighted snippets, and metadata rows.
- Integrate tap-through to existing detail screens using standard navigation helpers.
- Add the “Load more results” control with disabled/in-flight states and termination when no more data.
- Render empty states and validation errors inline beneath the search field.

## 6. Client-Side State & Data Management
- Create Riverpod providers for search query state, debounced results, pagination cursor, and loading/error flags.
- Cache last successful result set so returning to the view repopulates instantly without hitting the network.
- Persist last 5 distinct queries per user via Supabase or local secure storage synced with backend, ensuring immediate UI updates after clearing history.

## 7. Testing & Quality
- Write Flutter widget and integration tests covering instant search, pagination, empty states, and history interactions.
- Add backend tests verifying SQL search weighting, pagination, and RLS compliance.
- Perform manual QA on low-bandwidth profiles to confirm performance budget (<500ms server response, smooth UI).
- Update documentation/readme with feature overview, API usage, and any config steps.
