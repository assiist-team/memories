# Spec Requirements: Moment List & Timeline View

## Initial Description
**Moment List & Timeline View** — Display all user's Moments in reverse chronological feed with date grouping headers; show thumbnails for media-rich moments and text preview for text-only moments.

## Requirements Discussion

### First Round Questions

**Q1:** Preferred loading model: should the list stream via infinite scroll, load in pages, or follow another approach? How many Moments per batch?
**Answer:** Streamed infinite scroll is preferred. We still want optional hierarchical context so batches can align with the timeline sections (e.g., load a season or month at a time) but the user experience should remain continuous.

**Q2:** How should date groupings work—strict calendar days or higher-level aggregation like years, seasons, and months?
**Answer:** Use hierarchical grouping: Year → Season → Month. Each section should keep context visible while scrolling.

**Q3:** How should cards render for mixed-media Moments?
**Answer:** Always show a single primary thumbnail, even if multiple assets exist. Choose the best candidate (e.g., first photo, hero frame from video) and keep layout consistent.

**Q4:** Do we need inline filters or search in v1?
**Answer:** Include a search bar. Ideally it performs full-text search across all memory content (titles, descriptions, transcripts across Moments/Stories/Mementos). If that’s unexpectedly hard we can fall back to title-only, but expectation is full-text.

**Q5:** What happens when a Moment card is tapped?
**Answer:** Always deep-link to the Moment detail view. No inline expansion is required for v1.

### Existing Code to Reference
- None identified yet; treat as net-new but align with existing navigation patterns and feed components if discovered later.

### Follow-up Questions

**Follow-up 1:** Should the search bar target just Moment titles or every textual field across memory types?
**Answer:** Prefer full-text search across everything. Only narrow to titles if full-text adds significant complexity (unlikely).

## Visual Assets
_No visual assets provided._

## Requirements Summary
- Infinite-scroll timeline that can still surface hierarchical headers (Year → Season → Month) to maintain orientation.
- Moment cards show reverse chronological order with a consistent primary thumbnail, title, snippet, and metadata.
- Built-in search bar performing full-text queries across all memory content; design for future expansion even if initial data source is limited.
- Tapping a card always navigates to the detailed Moment view; no inline quick actions needed for v1.
- Plan batching/pagination to balance perceived performance while respecting hierarchical sections (e.g., load a season/month at a time under the hood).
