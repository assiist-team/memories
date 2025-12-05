# Story audio + title processing failures (Dec 5, 2025)

## Summary
- Story detail screens always render the "audio playback will be available soon" placeholder even when an audio file exists, because the player requires both a signed URL and a non-null duration but we never persist `audio_duration` in `story_fields`.
- The `process-story` edge function aborts the entire processing job when OpenAI returns an empty/`length`-truncated title response, so successful narratives still end up saved as "Untitled Story" and the memory stays in `failed` state.

## User impact
- Voice stories cannot be replayed at all; the UI suggests audio is "coming soon" despite the recording having uploaded successfully.
- Stories remain stuck in the failed state and keep their fallback title even though narrative text was generated, so the timeline shows confusing duplicates titled "Untitled Story" until someone manually retries processing.

## Evidence
### Audio playback stuck on the placeholder
- `StickyAudioPlayer` short-circuits to the placeholder if either the URL or duration is null:
```
39:76:lib/widgets/sticky_audio_player.dart
if (widget.audioUrl == null || widget.duration == null) {
  return Semantics(
    label: 'Audio player placeholder - audio playback will be available soon',
    child: Container(
      ...
```
- We only ever store `audio_path` when inserting the story_fields row; `audio_duration` is never populated and therefore comes back as `null` from `get_memory_detail`:
```
288:323:lib/services/memory_save_service.dart
if (state.memoryType == MemoryType.story) {
  ...
  await _supabase.from('story_fields').insert({
    'memory_id': memoryId,
    'audio_path': audioPath,
  });
}
```
- Because of those two constraints, every story detail request returns `audio_path != null` but `audio_duration == null`, so the player always shows the placeholder.

### Title processing fails when the LLM stops early
- The OpenAI logs pasted from the edge function show `finishReason":"length"` for the title request while the narrative request succeeds; this matches the code path where `generateTitleWithLLM` returns `null` whenever the completion is empty:
```
228:241:supabase/functions/process-story/index.ts
const generatedTitle = data.choices?.[0]?.message?.content?.trim();
if (!generatedTitle) {
  console.warn(JSON.stringify({
    event: "openai_title_generation_empty_response",
    finishReason: data.choices?.[0]?.finish_reason,
    usage: data.usage,
    fullResponse: JSON.stringify(data),
  }));
  return null;
}
```
- Instead of falling back to the transcript, we throw and mark the run as failed, which leaves `title` untouched and keeps the processing status stuck at `failed`:
```
489:503:supabase/functions/process-story/index.ts
const [narrativeResult, titleResult] = await Promise.all([
  generateNarrativeWithLLM(inputText),
  generateTitleWithLLM(inputText),
]);
...
if (!titleResult) {
  throw new Error("Failed to generate title");
}
```
- On the client we already expect the first 60 characters to be the "primary" fallback when the title is missing:
```
757:774:lib/services/memory_save_service.dart
if (text != null && text.trim().isNotEmpty) {
  final trimmed = text.trim();
  if (trimmed.length <= 60) {
    return trimmed;
  }
  return '${trimmed.substring(0, 60)}...';
}
switch (memoryType) {
  case MemoryType.story:
    return 'Untitled Story';
```
  That code only runs during capture; once processing fails we never retry the fallback, so the story stays "Untitled" indefinitely.

## Root causes
1. **Audio metadata never stored** – We upload the audio file and persist `audio_path`, but we do not extract or save `audio_duration`, so the player logic always fails its `duration` guard and keeps rendering the placeholder block.
2. **Title generation errors abort the whole pipeline** – `process-story` treats a missing title as a fatal error even if the narrative succeeded. GPT-5 mini frequently exhausts its 100-token budget on reasoning tokens, returns an empty string with `finish_reason = length`, and our job bails before writing either the narrative or the fallback title.

## Remediation plan
1. **Wire up real audio playback metadata**
   - Capture the audio duration during recording (e.g., via `FlutterSoundRecorder.stopRecorder()` metadata) and include it when inserting/updating the `story_fields` row.
   - Relax `StickyAudioPlayer` so it can initialize when `audioUrl` is present but `duration` is missing—load the duration from the audio engine once the stream starts instead of blocking on a DB field.
   - After metadata is reliable, replace the placeholder with a real audio engine (e.g., `just_audio`) and wire `_togglePlayPause`, the slider, and playback-speed menu to actual playback state.

2. **Make title generation resilient**
   - In `process-story`, treat a missing title as a recoverable condition: fall back to `truncateTitle(narrativeResult ?? inputText)` and continue updating the memory and `story_fields` even when OpenAI returns nothing. Only mark the run as failed if *both* narrative and title fail.
   - Increase `max_completion_tokens` (or switch to `response_format={type:'text'}` with higher limits) so GPT-5 mini can emit short titles without hitting the reasoning budget ceiling.
   - Record a structured warning (e.g., `metadata.error = 'title_generation_empty_response'`) instead of throwing so operations can monitor when fallbacks fire.
   - Add regression tests (or mocked edge-function unit tests) to ensure we set `processed_text`, `title`, and `memory_processing_status.state = 'complete'` even when the title step falls back.

## Verification
1. Capture a new voice story, confirm that `story_fields.audio_duration` is non-null and the sticky player renders real controls with functional playback.
2. Retry a previously failed story; the edge function should now save the narrative + fallback title, mark processing `complete`, and the timeline should show the first 60 characters instead of "Untitled Story".
3. Force OpenAI to return an empty title (e.g., by temporarily reducing `max_completion_tokens`) and verify the run still succeeds while logging a fallback warning.

## Implementation status (Dec 5, 2025)

This section documents what is **already implemented in code** so future changes can focus on the remaining gaps.

### Audio pipeline (recorder → DB → detail UI)

- **Recorder populates audio duration**
  - The dictation plugin now returns a `DictationAudioFile` with duration and other metadata. `DictationService.stop()` converts this into seconds and exposes it via `DictationStopResult.metadata['duration']`.
  - `CaptureStateNotifier.stopDictation()` reads that metadata and sets both `audioPath` and `audioDuration` on `CaptureState`, so voice stories captured with the new plugin carry real duration data.
- **Story save path persists `audio_duration`**
  - `MemorySaveService.saveMemory()` now inserts both `audio_path` and `audio_duration` into `story_fields` when `memoryType == story`, wiring the recorder metadata into the database.
- **Detail models surface audio fields**
  - `MemoryDetail.fromJson` reads `audio_path` and `audio_duration` from the `memory_detail` view.
  - `OfflineMemoryDetailNotifier._toDetailFromQueuedMemory` passes through `QueuedMemory.audioPath` and `QueuedMemory.audioDuration` so queued offline stories also have audio metadata in `MemoryDetail`.
  - `QueuedMemory.fromCaptureState` and `QueuedMemory.toCaptureState` include `audioPath` and `audioDuration`, so offline edit/queue flows preserve story audio metadata end-to-end.
- **Detail screen passes audio data into the player**
  - `MemoryDetailScreen`’s story layout passes `memory.audioPath` and `memory.audioDuration` into `_StoryAudioPlayer`, which:
    - Returns a placeholder `StickyAudioPlayer` when there is **no** `audioPath`.
    - Passes a local `file://` path directly as `audioUrl` for offline stories.
    - Resolves a signed URL from Supabase Storage for remote stories and feeds it into `StickyAudioPlayer`.
- **Sticky player no longer blocks on duration**
  - `StickyAudioPlayer` now:
    - Shows the **placeholder only when `audioUrl == null`**.
    - Uses `_loadedDuration ?? widget.duration` as the effective duration, so it can render controls even when duration is missing.
    - Disables the slider and shows `?:??` until a future audio engine sets `_loadedDuration`.
  - This removes the original “audio_duration is null so we always show the placeholder” bug: any story with a valid URL now gets the full player UI.

### Title + processing pipeline

- **Client-side fallback titles at save time**
  - `MemorySaveService._getFallbackTitle` still implements “first 60 characters of text or `Untitled X` by type”.
  - `saveMemory()` now:
    - Inserts the memory with a `null` title initially.
    - Immediately computes a fallback title from `input_text` and **updates `memories.title`**, so stories always have a reasonable title even before processing or when processing later fails.
  - `updateMemory()` preserves curated user titles:
    - It recomputes the fallback for comparison.
    - Only overwrites `title` when the existing value is empty or already looks like a fallback; otherwise it leaves curated titles untouched.
- **Resilient title generation in `process-story`**
  - `generateTitleWithLLM`:
    - Uses `max_completion_tokens` high enough to avoid frequent `finish_reason = length` truncation for short titles.
    - Logs structured errors and returns `null` on empty or truncated responses instead of throwing.
  - The main `process-story` handler:
    - Calls `generateNarrativeWithLLM` and `generateTitleWithLLM` in parallel.
    - Only treats the run as a hard failure when **both** narrative and title generation return `null`.
    - Uses `narrativeResult ?? inputText` as `processed_text`.
    - Uses `titleResult ?? truncateTitle(narrative, MAX_TITLE_LENGTH)` as the final `title`.
    - Writes `processed_text`, `title`, and `title_generated_at` into `memories`, and `narrative_generated_at` into `story_fields`.
    - Marks `memory_processing_status.state = 'complete'` on success, and includes structured metadata when a title fallback was used (e.g., `error: 'title_generation_empty_response', title_fallback_used: true`).
- **Models and UI respect generated + fallback titles**
  - Both `MemoryDetail.displayTitle` and `TimelineMemory.displayTitle` use the same priority:
    1. `generated_title`
    2. `title`
    3. First 60 characters of `displayText` (which prefers `processed_text` over `input_text`)
    4. `"Untitled Story"/"Untitled Moment"/"Untitled Memento"` by type
  - This ensures:
    - LLM-generated titles are preferred when available.
    - Fallback titles from `MemorySaveService` or the `process-story` truncation behave consistently across detail and timeline views.
    - Stories no longer remain indefinitely as `"Untitled Story"` after a successful narrative generation.

### Offline queue + story audio

- **Queued stories preserve audio metadata**
  - `QueuedMemory` stores `audioPath` and `audioDuration` for stories and serializes them in the local queue.
  - `OfflineMemoryDetailNotifier` maps `QueuedMemory` into `MemoryDetail`, including audio fields, so offline story detail screens can show the same sticky player.
- **Detail navigation handles queued vs. synced stories**
  - `UnifiedTimelineScreen._navigateToDetail`:
    - Routes to `MemoryDetailScreen` with `isOfflineQueued = true` when tapping an offline queued story.
    - If the queued entry has been removed but a `serverId` is present, it transparently redirects to the online detail screen using the server ID.
  - `MemoryDetailScreen`’s offline/online branches both share the same `_buildLoadedState`, so story audio behavior is consistent regardless of sync status.

## Remaining work to reach production readiness

The following items are **not yet implemented** but are required to make this flow robust in production.

### 1. Audio engine + UX polish

- Integrate a real audio engine (e.g., `just_audio`) into `StickyAudioPlayer`:
  - Implement `_togglePlayPause` to control actual playback.
  - Wire the slider to seek within the current track.
  - Honor `_playbackSpeed` changes by configuring the engine’s playback rate.
  - Populate `_loadedDuration` from the engine once the stream is ready, so recordings without `audio_duration` from the backend still show a correct duration.
- Add error handling for audio load/playback failures:
  - Surface a user-friendly error message in the player.
  - Optionally log structured errors for monitoring (e.g., bucket/path problems, HLS issues).

### 2. Dictation plugin rollout and feature flag

- Confirm that the **new dictation plugin path is enabled in production**:
  - The recorder only sets `CaptureState.audioDuration` when `useNewDictationPluginSyncProvider` resolves to `true`.
  - If production is still using the old plugin, new stories will continue to lack duration metadata even though the rest of the pipeline is wired.
- Once the new plugin is stable:
  - Consider removing the flag and old path to reduce complexity.
  - Document expected plugin versions and platform requirements.

### 3. Processing status UX alignment

- Align `memory_processing_status.metadata.phase` with the UI banner:
  - The edge function currently uses values like `"narrative_generation"`.
  - The banner logic in `MemoryDetailScreen` expects phases such as `"title"`, `"title_generation"`, `"text_processing"`, and `"narrative"`.
- Either:
  - Normalize the phases written by `process-story` to match the existing UI cases, **or**
  - Update the banner’s switch/case to handle the new phase names.
- Goal: during processing, the banner should show specific copy such as “Generating narrative…” or “Generating title…” instead of the generic “Processing memory…”.

### 4. Testing and observability

- **Automated tests**
  - Add unit and/or integration tests around `process-story` to cover:
    - Successful narrative + title generation.
    - Title-only failure (empty/length-truncated) with narrative success → verify:
      - `processed_text` is set.
      - `title` falls back to a truncated narrative.
      - `memory_processing_status.state` is `complete` and metadata marks `title_fallback_used`.
    - Complete failure where both narrative and title fail → verify:
      - `memory_processing_status.state` is `failed`.
      - `attempts` increments, `last_error` is populated.
  - Add client-side tests (widget or integration) for:
    - `StickyAudioPlayer` rendering placeholder vs. full controls based solely on `audioUrl`.
    - `MemoryDetail.displayTitle` / `TimelineMemory.displayTitle` behavior for:
      - Generated title present.
      - Only fallback title present.
      - No title but `processed_text` or `input_text` present.
      - Completely empty text.
- **Logging and monitoring**
  - Ensure logs for:
    - `openai_title_generation_empty_response`.
    - `title_generation_fallback_used`.
    - `story_processing_failed`.
  - are wired into whatever observability stack is used (e.g., Logflare, DataDog, etc.).
  - Define basic alerts when:
    - The rate of `title_generation_empty_response` spikes.
    - `story_processing_failed` rates cross an agreed threshold.

### 5. Operational runbook

- Runbook for on-call / support:
  - **Identify stuck stories** – Query Supabase (`select memory_id, state, attempts, last_error from memory_processing_status where state = 'failed' order by last_error_at desc`) and capture sample IDs before rerunning.
  - **Retry processing** – Use `supabase functions invoke process-story --env-file .env --data '{"memoryId":"<uuid>"}'` or requeue via the dispatcher so we log a fresh attempt; note new `metadata.phase` strings (`title_generation`, `narrative`, `text_processing`).
  - **Verify audio artifacts** – Check `story_fields` (`select audio_path, audio_duration from story_fields where memory_id = '<uuid>'`) and ensure the referenced file exists in the `stories-audio` bucket; regenerate signed URLs via `supabase storage get-url`.
  - **Interpret logs/metadata** – `title_generation_fallback_used` / `title_fallback_source` now indicate when the LLM skipped the explicit title, while `error: title_generation_empty_response` helps differentiate OpenAI regressions from Supabase failures.
  - **Escalate when both LLM steps fail** – If `memory_processing_status.metadata.error` contains the thrown message “Failed to generate both narrative and title”, capture the OpenAI request IDs from the structured logs before paging ML infra.

Once these items are complete, the story audio and title pipeline should be **production ready**: new voice stories have durable audio + metadata, LLM title failures degrade gracefully, and both detail and timeline views surface consistent, user-friendly titles and playback behavior.
