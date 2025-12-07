# Planning Prompt: Simplified Phase 1 Offline Support

Create a brief implementation plan for simplifying Phase 1 offline support with text-only caching.

## Current State

- Phase 1 currently caches only lightweight preview metadata (title, first line, date) for synced memories
- Full text detail is only cached when a user explicitly views a memory detail screen online
- Users can tap on preview-only memories offline and get errors because detail isn't cached
- Navigation guards exist but don't properly prevent accessing uncached memories
- Three boolean flags track state: `isOfflineQueued`, `isPreviewOnly`, `isDetailCachedLocally`

## Goal

Simplify Phase 1 by:
1. **Always cache full text** (input_text, processed_text, generated_title, tags, location metadata) for **previously-synced memories** when fetching timeline feed online
2. **Never cache media** (photos, videos, audio files) for synced memories - keep media URLs but don't download files
3. **Add clear visual indicators** on timeline cards showing:
   - ✅ Text available offline (can open detail view)
   - ⚠️ Media not available offline (will show placeholders)
   - 🚫 Not available offline (preview-only, shouldn't happen anymore)
4. **Fix navigation guards** to prevent tapping memories that aren't cached
5. **Update detail screen** to gracefully handle missing media with clear placeholders and "Media not available offline" messages

**Important distinction:**
- **Memories created offline** (queued memories) already have full text AND media files stored locally - they remain fully cached and editable offline. This text-only caching approach does NOT apply to them.
- **Previously-synced memories** (from server) will get text cached but media will remain online-only, requiring connectivity to view media.

## Constraints

- Text-only caching applies ONLY to previously-synced memories (not queued offline memories)
- Queued offline memories continue to have full text + media cached locally (no change)
- Must work with existing `TimelineMemory` model and flags
- Must maintain backward compatibility with queued offline memories
- Should reduce complexity, not add new edge cases
- Keep existing `LocalMemoryPreviewStore` but extend it to store full text fields

## Key Questions to Address

1. How to extend `LocalMemoryPreview` model to include full text fields without breaking existing preview-only entries?
2. When to cache text: on every timeline fetch, or only when viewing detail? (Applies only to synced memories, not queued)
3. How to update `isDetailCachedLocally` flag to reflect text-only caching? (Should it be true for text-only cached synced memories, or only for queued memories with full media?)
4. What visual indicators to use on timeline cards (badges, icons, styling) to distinguish:
   - Queued memories (full text + media available)
   - Text-cached synced memories (text available, media requires online)
   - Uncached memories (shouldn't exist after this change)
5. How to handle media placeholders in detail view when offline for text-cached synced memories?
6. Should we keep `isPreviewOnly` flag or can it be removed/deprecated? (Since all synced memories will have text cached)

## Deliverables

Brief plan covering:
- Data model changes (what fields to add/change)
- Caching strategy (when and how to cache text)
- UI indicators (where and how to show availability)
- Navigation guard fixes (how to prevent errors)
- Detail screen updates (how to handle missing media)
- Migration strategy (how to update existing preview entries)

Keep it concise, actionable, and focused on text-only caching with proper indicators.
