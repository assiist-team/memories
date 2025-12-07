# Story audio player placeholder showing incorrectly (Dec 6, 2025)

## Summary
- Story detail screens show the "Audio playback will be available soon" placeholder for **all stories**, even text-only stories that were never meant to have audio.
- The audio player widget is rendered unconditionally for any story type, regardless of whether `audio_path` exists in the database.
- This creates confusion when users see the placeholder on stories that don't have (and shouldn't have) audio.

## User impact
- Users see "Audio playback will be available soon" on text-only stories, creating false expectations that audio will be added later.
- The placeholder takes up UI space unnecessarily for stories that will never have audio.
- Confusion about which stories are voice stories vs text-only stories.

## Evidence

### Audio player shown for all stories
- The detail screen renders the audio player for any story type without checking if audio exists:
```
1057:1067:lib/screens/memory/memory_detail_screen.dart
if (isStory) ...[
  SliverPersistentHeader(
    pinned: true,
    delegate: _StickyAudioPlayerDelegate(
      child: _StoryAudioPlayer(
        audioPath: memory.audioPath,
        audioDuration: memory.audioDuration,
        storyId: memory.id,
      ),
    ),
  ),
],
```
- `_StoryAudioPlayer` then checks if `audioPath` is null and shows the placeholder, but the player widget itself is still rendered.

### Example: Text-only story showing placeholder
- **Memory ID:** `1cf4cdca-64a2-409a-8436-a4391ffa6fad`
- Database query shows:
  ```sql
  SELECT 
    m.id,
    m.memory_type,
    m.title,
    m.input_text,
    m.processed_text,
    sf.audio_path,
    sf.audio_duration,
    mps.state as processing_state
  FROM memories m
  LEFT JOIN story_fields sf ON sf.memory_id = m.id
  LEFT JOIN memory_processing_status mps ON mps.memory_id = m.id
  WHERE m.id = '1cf4cdca-64a2-409a-8436-a4391ffa6fad';
  -- Results:
  -- - audio_path = null
  -- - audio_duration = null
  -- - processed_text = null
  -- - processing_state = 'failed'
  ```
- This story was created as text-only (has `input_text` but no audio recording).
- Processing failed (no `processed_text` generated), and no audio was ever recorded.
- The UI incorrectly shows the audio player placeholder even though this story will never have audio.

## Root cause
The audio player is rendered for **all stories** (`if (isStory)`) without first checking if the story actually has audio data. The `_StoryAudioPlayer` widget handles the null case by showing a placeholder, but the widget shouldn't be rendered at all for stories without audio.

## Investigation steps

### 1. Check if story has audio data
```sql
SELECT 
  m.id,
  m.memory_type,
  sf.audio_path,
  sf.audio_duration
FROM memories m
LEFT JOIN story_fields sf ON sf.memory_id = m.id
WHERE m.id = '<memory_id>';
```

### 2. Check what get_memory_detail returns
The `get_memory_detail` function should return `audio_path` and `audio_duration` from `story_fields`:
- If `audio_path` is `null`, the story has no audio and shouldn't show the player.
- If `audio_path` is not `null`, the story has audio and should show the player.

### 3. Verify in UI
- Open the story detail screen.
- Check if the audio player is shown.
- If shown, check the logs for:
  ```
  [MemoryDetailScreen] Creating audio player for story id=... audioPath=... audioDuration=...
  ```
- If `audioPath` is `null` but the player is shown, this is the bug.

## Fix applied

### Change: Only render audio player when audio exists
Updated `memory_detail_screen.dart` to check for audio data before rendering the player:

```dart
// Before:
if (isStory) ...[
  // Always show audio player for stories
]

// After:
if (isStory && 
    memory.audioPath != null && 
    memory.audioPath!.isNotEmpty) ...[
  // Only show audio player when story has audio
]
```

### Code location
- File: `lib/screens/memory/memory_detail_screen.dart`
- Lines: ~1057-1077
- Change: Added conditional check for `memory.audioPath` before rendering `_StoryAudioPlayer`

## Verification

### Test case 1: Text-only story (no audio)
1. Create a story via text input (not voice recording).
2. Navigate to story detail screen.
3. **Expected:** No audio player widget should be visible.
4. **Before fix:** Audio player placeholder was shown.

### Test case 2: Voice story (with audio)
1. Create a story via voice recording.
2. Ensure audio uploads successfully (check `story_fields.audio_path` is not null).
3. Navigate to story detail screen.
4. **Expected:** Audio player should be visible with playback controls.
5. **Before fix:** Audio player was shown (correct behavior).

### Test case 3: Voice story with failed upload
1. Create a story via voice recording.
2. Simulate upload failure (e.g., network error).
3. Check that `story_fields.audio_path` is `null`.
4. Navigate to story detail screen.
5. **Expected:** No audio player widget should be visible (since no audio was saved).
6. **Before fix:** Audio player placeholder was shown (incorrect).

## Related issues

### Stories that should have audio but don't
If a story was created via voice recording but shows no audio player:

1. **Check database:**
   ```sql
   SELECT audio_path, audio_duration 
   FROM story_fields 
   WHERE memory_id = '<story_id>';
   ```

2. **If `audio_path` is null:**
   - Check if audio upload failed during capture (check app logs).
   - Check if the story was created before audio support was added.
   - Check if the story was edited/duplicated and audio wasn't preserved.

3. **If `audio_path` is not null but player doesn't show:**
   - Check if `get_memory_detail` is returning the audio fields correctly.
   - Check if signed URL generation is failing (check logs for errors).
   - Verify the audio file exists in Supabase Storage.

### Debug logging
The fix includes debug logging to help diagnose audio playback issues:

- `[MemoryDetailScreen] Creating audio player for story` - Shows when player is created and what values are passed.
- `[MemoryDetailScreen._StoryAudioPlayer]` - Shows the flow through the audio player widget.
- `[MemoryDetailScreen._StoryAudioPlayer] Error fetching audio signed URL` - Shows if signed URL generation fails.

## Implementation status

### ✅ UI behavior fixed (Dec 6, 2025)
- Audio player only renders when `memory.audioPath != null && memory.audioPath!.isNotEmpty`.
- Text-only stories no longer show the audio player placeholder.
- Debug logging added to help diagnose audio playback issues.

### ⚠️ Story processing currently not happening
- For **stories**, `processed_text` is currently **never** populated; the text-processing path for stories is effectively unimplemented / disabled as of Dec 6, 2025.
- For **story audio**, `story_fields.audio_path` and signed URLs are currently **never** generated for new stories, so audio playback does not work end-to-end even when users record audio.
- These pipeline-level gaps are **not** addressed by this UI fix and are tracked in more detail in `story-audio-and-title-processing-failures-2025-12-05.md`.

### Remaining work
- **Implement story text processing**: Design and ship the pipeline that takes story input and produces `processed_text` for stories, then backfill existing stories.
- **Implement story audio URL generation**: Implement and harden the code paths that upload story audio, write `story_fields.audio_path`, and generate signed URLs; add retries and better error logging.
- **User-facing indication for failed / missing audio**: Add a distinct UI state for stories that were intended to have audio but where upload or processing failed, separate from true text-only stories.
- **Ongoing monitoring and tooling**: Monitor logs and metrics for text/audio processing failures and signed URL errors; consider building an admin view to surface affected stories and their processing states.

## Notes
- This fix is complementary to the fixes in `story-audio-and-title-processing-failures-2025-12-05.md`.
- The previous document addressed the case where stories **with audio** weren't playing correctly.
- This document addresses the case where stories **without audio** were incorrectly showing the player.
- Both issues need to be fixed for proper audio playback UX, and pipeline reliability work is still in progress.
