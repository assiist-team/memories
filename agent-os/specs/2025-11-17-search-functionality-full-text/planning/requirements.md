# Spec Requirements: Search Functionality Full Text

## Initial Description
**Search Functionality** — Implement full-text search across all Stories, Moments, and Mementos using PostgreSQL text search; persistent search bar in app header with instant results.

## Requirements Discussion

### First Round Questions

**Q1:** I assume we’ll index titles, narrative text, descriptions, and transcript text across Stories, Moments, and Mementos with weighted relevance (titles > descriptions > transcripts). Is that correct, or should every field have equal weight?
**Answer:** Not sure which weighting is best, so proceed with whatever weighting strategy you think is best.

**Q2:** I’m thinking the search bar should live persistently in the global app header with instant, debounced results appearing below the bar as the user types. Should we instead require an explicit submit action before showing results to conserve queries?
**Answer:** Go with the persistent header search plus instant results approach.

**Q3:** For result presentation, I plan to group hits by memory type with badges (Story/Moment/Memento), show a snippet with highlighted terms, and allow tapping through to detail views. Do we also need inline actions such as quick edit/delete or secondary metadata (e.g., date, linked memories)?
**Answer:** That layout sounds good; no inline actions are needed right now.

**Q4:** To keep queries fast on mobile, I’m assuming we’ll maintain PostgreSQL materialized views or GIN indexes and limit each request to about 20 results with “load more.” Would you prefer full infinite scroll without pagination caps even if it costs more queries?
**Answer:** Limiting to ~20 results with “load more” is fine.

**Q5:** Should we support scoped filtering from the search UI (e.g., tabs or chips for All/Stories/Moments/Mementos plus “has media” filters), or is the expectation that global filters from the timeline feed remain separate from search?
**Answer:** Filtering already lives in the Unified Timeline feature; we can leave it there unless we decide consolidating filters into search is clearly better (and update the other spec accordingly).

**Q6:** For query language, I’m assuming simple keyword search with basic operators (quoted phrases, minus terms) is enough. Do we need advanced features like stemming, typo tolerance, or synonym dictionaries in this first release?
**Answer:** Simple keyword search with basic operators is sufficient for now.

**Q7:** I’m planning to log the last few recent searches per user for quick recall. Is that in scope, or should we avoid storing any search history for now?
**Answer:** Logging recent searches per user is fine.

**Q8:** Are there any explicit exclusions or constraints I should be aware of (e.g., no cross-user search, no backend aggregation for analytics, defer voice-search entry, etc.)?
**Answer:** No additional exclusions or constraints identified.

### Existing Code to Reference
No similar existing features identified for reference.

### Follow-up Questions
No follow-up questions were required.

## Visual Assets

### Files Provided:
No visual assets provided.

## Requirements Summary

### Functional Requirements
- Persistent global search bar with instant, debounced query results.
- Unified search index spanning titles, descriptions, narratives, and transcripts across all memory types with designer-determined weighting.
- Result list grouped by memory type with badges, snippets, highlighted matches, and tap-through to detail views.
- Pagination via ~20 initial results plus “load more”.
- Simple keyword query language supporting quoted phrases and minus terms.
- Optional recent-search history stored per user for quick recall.

### Reusability Opportunities
- Potential to align search filters with the Unified Timeline filtering UI if we later decide to consolidate filtering behavior.

### Scope Boundaries
**In Scope:**
- Full-text indexing and search API over Stories, Moments, and Mementos.
- Persistent search UI, result grouping, and pagination mechanics.
- Lightweight per-user recent search history.

**Out of Scope:**
- Inline result actions (edit/delete) or advanced filters unless future decision moves them from the Unified Timeline spec.
- Advanced linguistic search features (stemming, typo tolerance, synonyms) for this release.

### Technical Considerations
- Use PostgreSQL full-text search with GIN indexes or materialized views to maintain fast queries.
- Ensure mobile-friendly, debounced requests to minimize load.
- Coordinate with Unified Timeline feature owners if filtering responsibilities shift to search.
