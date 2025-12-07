# Story audio playback failing with "Cannot Open" (Dec 6, 2025)

## Summary
- Story audio recordings fail to play on iOS with repeated `Failed to load audio source: (-11829) Cannot Open` errors from `just_audio` / AVPlayer.
- Supabase Storage uploads succeed and signed URLs are generated, but the audio player shows **"Unable to load audio"** and never starts playback.
- Root cause: we upload a **WAV** dictation file while labeling it as **M4A** (`.m4a` filename and `contentType: 'audio/m4a'`), which AVPlayer then refuses to open.

## User impact
- Voice stories appear to have an audio track (duration shows, play button is enabled), but tapping play never starts playback.
- The sticky audio player on the story detail screen shows an error banner: **"Unable to load audio."**
- This affects **all new voice stories** captured via the native dictation path until the upload code is fixed.

## Evidence

### 1. Dictation plugin produces WAV audio
From the device logs while capturing a story via dictation:

```text
flutter: [NativeDictationService] Event data: {sampleRate: 48000.0, path: /private/var/mobile/Containers/Data/Application/AE70F2FA-DEA3-4541-91F4-7872D4EDF233/tmp/dictation-2025-12-06T03-06-26.wav, channelCount: 1, wasCancelled: false, fileSizeBytes: 541696, type: audioFile, durationMs: 2800.0}
flutter: [NativeDictationService] Event type: audioFile
flutter: [NativeDictationService] Processing audioFile event: path=/private/var/mobile/Containers/Data/Application/AE70F2FA-DEA3-4541-91F4-7872D4EDF233/tmp/dictation-2025-12-06T03-06-26.wav
```

- The native dictation service clearly reports a **`.wav`** file and a duration of ~2.8s.

### 2. Memory detail includes audio metadata
For the affected story ID `aa81545a-82d1-4a68-b434-ebb152a94f9f`:

```sql
SELECT id, user_id, title, memory_type, created_at,
       (SELECT audio_path FROM story_fields sf WHERE sf.memory_id = m.id) AS audio_path,
       (SELECT audio_duration FROM story_fields sf2 WHERE sf2.memory_id = m.id) AS audio_duration
FROM memories m
WHERE title = 'This is a test story'
ORDER BY created_at DESC
LIMIT 5;

-- Result:
-- id          = aa81545a-82d1-4a68-b434-ebb152a94f9f
-- memory_type = story
-- audio_path  = stories/audio/5aeed2a7-26f9-40ac-a700-3a6da123f3b5/aa81545a-82d1-4a68-b434-ebb152a94f9f/1764990391531.m4a
-- audio_duration = 2.8
```

- `story_fields.audio_path` and `audio_duration` are populated correctly and surfaced through `get_memory_detail`.

### 3. Supabase Storage confirms successful uploads and signed URLs
Supabase storage logs around the same time show successful object creation and signed URL traffic for the story's audio object:

```text
[Lifecycle]: ObjectCreated:Post .../stories-audio/stories/audio/5aeed2a7-26f9-40ac-a700-3a6da123f3b5/aa81545a-82d1-4a68-b434-ebb152a94f9f/1764990391531.m4a

... multiple lines of ...
GET | 200 | ... | /object/sign/stories-audio/stories/audio/5aeed2a7-26f9-40ac-a700-3a6da123f3b5/aa81545a-82d1-4a68-b434-ebb152a94f9f/1764990391531.m4a?token=redacted | AppleCoreMedia/1.0.0.23B85 (iPhone...)
```

- Storage upload completed (`ObjectCreated:Post`).
- Both the app (Dart client) and the iOS media stack (`AppleCoreMedia`) are requesting signed URLs and receiving **HTTP 200** responses.

### 4. Audio engine fails to open the stream
On the device, while opening the story detail screen:

```text
flutter: [MemoryDetailService] Response keys: [id, user_id, title, input_text, processed_text, generated_title, tags, memory_type, captured_at, created_at, updated_at, public_share_token, location_data, photos, videos, related_stories, related_mementos, audio_path, audio_duration, memory_date, memory_location_data]

flutter: Failed to load audio source: (-11829) Cannot Open
flutter: #0      AudioPlayer._load (package:just_audio/just_audio.dart:886)
flutter: #1      AudioPlayer._setPlatformActive.setPlatform (package:just_audio/just_audio.dart:1532)

(repeated several times)
```

- `MemoryDetailService` confirms that `audio_path` and `audio_duration` are present.
- `just_audio` fails in `_load`, and the underlying AVPlayer error code is **`-11829` (Cannot Open)**, which typically means the file format or headers are invalid for the declared type.

### 5. Upload code mismatches file format and content type
The story save path in `MemorySaveService.saveMemory()` always uploads the dictation file as **M4A** regardless of the actual file type:

```221:325:lib/services/memory_save_service.dart
// Step 3.5: Create story_fields row if this is a story
if (state.memoryType == MemoryType.story) {
  // Upload audio if available
  String? audioPath;
  if (state.audioPath != null) {
    try {
      final audioFile = File(state.audioPath!);
      if (await audioFile.exists()) {
        final audioFileName =
            '${DateTime.now().millisecondsSinceEpoch}.m4a';
        final audioStoragePath =
            'stories/audio/${_supabase.auth.currentUser?.id}/$memoryId/$audioFileName';

        await _supabase.storage.from('stories-audio').upload(
          audioStoragePath,
          audioFile,
          fileOptions: const FileOptions(
            upsert: false,
            contentType: 'audio/m4a',
          ),
        );

        audioPath = audioStoragePath;
      }
    } catch (e) {
      // Audio upload failed, but continue with story creation
      // The story_fields row will be created without audio_path
    }
  }

  await _supabase.from('story_fields').insert({
    'memory_id': memoryId,
    'audio_path': audioPath,
    'audio_duration': state.audioDuration,
  });
}
```

- The **source file is WAV** (per dictation logs), but we:
  - Force the **filename extension to `.m4a`**.
  - Force the **MIME type to `audio/m4a`**.
- iOS tries to interpret the WAV bytes as M4A/AAC and fails with `Cannot Open`.

## Root cause

1. **Format mismatch** between the recorded audio file and the way we upload it:
   - Recorder output: `*.wav`, PCM data, `durationMs` ~ 2800.
   - Upload code: names it `*.m4a` and declares `contentType: 'audio/m4a'`.
2. **AVPlayer is strict about container/codec vs advertised type**, so it rejects the stream and `just_audio` surfaces `(-11829) Cannot Open`.
3. The UI then shows the **"Unable to load audio."** banner from `StickyAudioPlayer._loadAudioSource()` while still rendering a full player with the duration from `audio_duration`, which looks "half working" to the user.

## Fix

### Change: Derive file extension and MIME type from the actual file path

Update the story audio upload block in `MemorySaveService.saveMemory()` to infer the extension and content type from `state.audioPath` instead of hard-coding `.m4a`:

```dart
// Inside: if (state.memoryType == MemoryType.story) {
String? audioPath;
if (state.audioPath != null) {
  try {
    final audioFile = File(state.audioPath!);
    if (await audioFile.exists()) {
      final lowerPath = audioFile.path.toLowerCase();
      final isWav = lowerPath.endsWith('.wav');
      final isM4a = lowerPath.endsWith('.m4a');

      // Default to WAV for now, since dictation currently outputs .wav
      final fileExtension = isM4a ? 'm4a' : 'wav';
      final contentType = isM4a ? 'audio/m4a' : 'audio/wav';

      final audioFileName =
          '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final audioStoragePath =
          'stories/audio/${_supabase.auth.currentUser?.id}/$memoryId/$audioFileName';

      await _supabase.storage.from('stories-audio').upload(
        audioStoragePath,
        audioFile,
        fileOptions: FileOptions(
          upsert: false,
          contentType: contentType,
        ),
      );

      audioPath = audioStoragePath;
    }
  } catch (e) {
    // Audio upload failed, but continue with story creation
  }
}

await _supabase.from('story_fields').insert({
  'memory_id': memoryId,
  'audio_path': audioPath,
  'audio_duration': state.audioDuration,
});
```

### Why this works
- New recordings keep using the existing dictation path, but are now uploaded as **WAV with `audio/wav`** (or M4A with `audio/m4a` if/when the recorder changes formats).
- AVPlayer recognizes the container/codec and successfully opens the stream; `just_audio` no longer throws `Cannot Open`.
- The sticky player continues to use `audio_duration` from `story_fields` and behaves as expected.

## Verification steps

### 1. Capture a new voice story
1. Build and run the app after the `MemorySaveService` change.
2. Create a new story using dictation.
3. Confirm dictation logs still show a `.wav` file and sensible `durationMs`.
4. Save the story and navigate to the detail screen.

**Expected:**
- Sticky audio player shows `0:00 / 0:0X` with play button.
- Tapping play starts audio playback; no `Failed to load audio source: (-11829) Cannot Open` logs.

### 2. Inspect Supabase Storage object
1. Query the new story's `audio_path` from `story_fields`.
2. In the `stories-audio` bucket, verify that:
   - The object key ends with `.wav`.
   - The content type is `audio/wav`.

**Expected:**
- Object metadata matches the actual stored format.

### 3. Check logs for regressions
- Filter Xcode / Flutter logs for:
  - `Failed to load audio source:`
  - `Cannot Open`

**Expected:**
- No new `(-11829) Cannot Open` errors when playing newly recorded stories.

## Notes and follow-ups

- **Existing broken stories** (recorded before this fix) were uploaded as WAV bytes with `.m4a` names and `audio/m4a`. Those files will likely remain unplayable until we either:
  - Re-upload them with the correct extension/MIME, or
  - Re-encode them server-side to a true M4A/AAC stream.
- A follow-up repair script could:
  - Iterate over `story_fields` for affected users.
  - Download mis-labeled objects from `stories-audio`.
  - Detect the real format and re-upload with the correct metadata or re-encode.
- This doc focuses on the **client-side upload bug**; pipeline and processing behavior for stories is documented separately in `story-audio-and-title-processing-failures-2025-12-05.md` and `story-audio-player-shown-without-audio-2025-12-06.md`.
