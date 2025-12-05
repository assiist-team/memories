# Timeline media regressions (Dec 5, 2025)

## Summary
- Timeline and detail thumbnails now blow up before the network request because `TimelineImageCacheService` tries to send a custom object through `compute`, which isolates reject. The `FutureBuilder`s never receive data, so no image or fallback renders.
- The detail screen never auto-selects the first asset (and never renders a placeholder component) because `_selectedMediaIndex` stays `null` until the user taps a thumbnail.
- `MemorySaveService.updateMemory` resets `processed_text`, re-schedules processing, and rewrites the fallback title whenever *any* edit occurs as long as the memory has text. Media-only edits therefore re-trigger title generation and risk clobbering curated titles.

## User impact
- Every timeline card that relies on `primaryMedia` (moments, mementos) now shows a spinner forever. Signed URLs fail preflight, so the user never sees their photos/videos.
- The memory detail page looks empty even when media exists: the strip shows grey boxes (no signed URLs), and the large preview area stays blank because nothing selects index `0`.
- Adding or removing media from an existing story/moment queues a full NLP reprocess and can overwrite a hand-edited title, even though the text never changed.

## Evidence
```143:189:lib/services/timeline_image_cache_service.dart
final future = compute(
  _createSignedUrlInIsolate,
  _SignedUrlRequest(
    supabaseUrl: supabaseUrl,
    supabaseAnonKey: supabaseAnonKey,
    bucket: bucket,
    path: normalizedPath,
    expirySeconds: expirySeconds,
    accessToken: accessToken,
  ),
);
```
`compute` only accepts sendable values (basic types, lists, maps, `SendPort`). Passing `_SignedUrlRequest` throws `Illegal argument in isolate message: Instance of '_SignedUrlRequest'`, so every signed URL future completes with an error before the HTTP call can run.

```52:56:lib/screens/memory/memory_detail_screen.dart
class _MemoryDetailScreenState extends ConsumerState<MemoryDetailScreen> {
  int? _selectedMediaIndex;
```
```978:999:lib/screens/memory/memory_detail_screen.dart
MediaStrip(
  photos: memory.photos,
  videos: memory.videos,
  selectedIndex: _selectedMediaIndex,
  onThumbnailSelected: (index) {
    setState(() {
      _selectedMediaIndex = index;
    });
  },
),
if (_selectedMediaIndex != null) ...[
  MediaPreview(
    photos: memory.photos,
    videos: memory.videos,
    selectedIndex: _selectedMediaIndex,
  ),
]
```
No code ever assigns `_selectedMediaIndex` when the screen loads, so the preview never renders and there is no placeholder path for the `else` case.

```600:711:lib/services/memory_save_service.dart
final updateData = <String, dynamic>{
  'input_text': state.inputText,
  'processed_text': null,
  'photo_urls': allPhotoUrls,
  'video_urls': allVideoUrls,
  ...
};
...
if (hasInputText) {
  await _supabase.from('memory_processing_status').update({
    'state': 'scheduled',
    'attempts': 0,
    'last_error': null,
    'metadata': {
      'memory_type': state.memoryType.apiValue,
    },
  }).eq('memory_id', memoryId);
}
```
`CaptureState` has no "original text" field, so `hasInputText` stays true even when the text was untouched. Every update therefore clears `processed_text` and bumps the processing queue.

## Root causes
1. **Unsigned objects passed to `compute`** – `_SignedUrlRequest` is a custom class, so isolate message serialization fails before Supabase is called. Timeline/detail widgets never get a signed URL.
2. **No default media selection or placeholder** – `_selectedMediaIndex` stays `null`, so `_buildLoadedState` never renders `MediaPreview`. Users see an empty gap instead of at least a loading skeleton.
3. **Processing reset on every edit** – `updateMemory` assumes any edit means the text mutated. It clears NLP outputs and forces title regeneration even for media-only updates.

## Remediation plan
1. **Fix signed URL fetching**
   - Stop sending `_SignedUrlRequest` through `compute`. Either pass a plain `Map<String, dynamic>`/`List` or skip `compute` and call Supabase on the main isolate (less risky short-term).
   - When isolate creation fails, immediately fall back to the synchronous path so the UI still gets a URL while we refactor.
   - Add regression tests around `TimelineImageCacheService.getSignedUrl` ensuring it resolves both with storage paths and full URLs.
2. **Show media in detail by default**
   - Initialize `_selectedMediaIndex = 0` inside `_buildLoadedState` (or `didChangeDependencies`) when `memory.photos + memory.videos` is non-empty.
   - When there is no media, render an explicit placeholder block instead of omitting the preview entirely so users know why nothing appears.
3. **Avoid unnecessary reprocessing**
   - Teach `CaptureState` to hold the original text and pass an `inputTextChanged` flag into `updateMemory`.
   - Only clear `processed_text`/reset `memory_processing_status` when the text actually changed.
   - Preserve curated titles by skipping the fallback rewrite when `hasInputText` is true but `inputTextChanged` is false.

## Logging coverage to add
- **Image cache service (`TimelineImageCacheService`)**
  - Log every compute failure with bucket/path and the exact exception so we can differentiate serialization errors from `storage.createSignedUrl` 4xx responses.
  - Emit structured logs for cache hits vs misses and include whether we fell back to the non-isolate path.
- **Timeline/detail widgets**
  - When `snapshot.hasError`, log the memory id + media path and surface a lightweight breadcrumb to Sentry/Firebase so we can trace which assets fail most.
  - When `_selectedMediaIndex` is `null` but media exists, log once per screen to confirm whether the default-selection fix landed.
- **Memory save/update flow**
  - After uploads, log counts of `photoUrls`/`videoUrls` and whether any uploads were skipped because the file disappeared on disk.
  - When `updateMemory` queues processing, log why (text change vs forced media edit) so we can track down unexpected reprocessing.

## Verification ideas
1. Load a feed with server-backed memories: thumbnails should appear instantly (or after a quick spinner) and logs should show successful signed URL generation without isolate errors.
2. Open a memory detail screen with photos: the first image should display in the preview automatically, and removing network access should now show the explicit placeholder instead of a blank area.
3. Edit a story by adding only photos: the UI should skip any "Processing" banners, and logs should confirm that `memory_processing_status` stayed `complete`.
