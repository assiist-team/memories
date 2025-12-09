## Goal

Replace the custom `AudioNormalizerService` (FFmpeg-based) in the Memories app with the built-in `normalizeAudio` support from the `flutter_dictation` plugin, so that **all audio we upload (dictation and imported)** is normalized via the plugin’s canonical pipeline and we can delete the project-specific normalization code.

---

## 1. Current state

### 1.1 Design intent

- **Design doc**: `docs/ensure-audio-under-50mb.md` describes the target behavior:
  - Canonical format: `.m4a` AAC, voice-focused bitrate (~48–64 kbps mono) with a hard **< 50 MB** constraint.
  - Client-side normalization before upload; backend just enforces guardrails.

### 1.2 Project-specific normalization implementation

- **Service**: `lib/services/audio_normalizer_service.dart`
  - Uses `ffmpeg_kit_flutter` + `ffprobe_kit` to:
    - Detect duration (with millisecond/second normalization).
    - Compute a safe bitrate given duration and 50 MB cap.
    - Transcode to `.m4a` (AAC, mono, 24 kHz) at target bitrate.
    - Retry with lower bitrates (48/40/32 kbps) if still too large.
  - Exposes:
    - `Future<AudioNormalizationResult> normalizeAudio({ inputFilePath, inputDuration, onProgress, cancelToken })`
    - `Future<void> cleanupNormalizedFile(String filePath)`
    - `AudioNormalizationCancelToken` for cancellation.

- **Tests**: `test/services/audio_normalizer_service_test.dart` cover duration parsing logic and normalization behavior.

### 1.3 Where the custom normalizer is used

- **Dictation flow (recorded audio)**
  - `lib/services/dictation_service.dart`
    - Wraps `NativeDictationService` from `flutter_dictation`.
    - When `useNewPlugin` is true and `preserveAudio` is enabled, `stop()` returns a `DictationStopResult` containing:
      - `audioFilePath` (raw preserved audio) and `metadata` (duration, size, sampleRate, channels, etc.).
  - `lib/providers/capture_state_provider.dart` (dictation stop handler)
    - Caches the preserved audio via `audioCacheService.storeAudioFile(...)` and gets `cachedAudioPath`.
    - Calls the custom normalizer:
      - `audioNormalizerServiceProvider.normalizeAudio(inputFilePath: cachedAudioPath, inputDuration: audioDuration, ...)`
    - Stores the result into state:
      - `normalizedAudioPath`, `audioDuration`, `audioBitrateKbps`, `audioFileSizeBytes`.
    - On failure, sets a user-visible error and aborts saving.

- **Imported / existing audio flow**
  - `lib/services/media_picker_service.dart`
    - `pickAudioFromFiles({ cancelToken, onProgress })` uses `file_picker` to let the user select an audio file.
    - Immediately calls the custom normalizer:
      - `_audioNormalizerService.normalizeAudio(inputFilePath: path, onProgress: onProgress, cancelToken: cancelToken)`.
    - Wraps the result in `PickedAudioFile`:
      - `sourceFilePath` (original) + `AudioNormalizationResult normalizedResult`.
  - `lib/providers/media_picker_provider.dart` wires `MediaPickerService` behind a Riverpod provider.
  - `lib/screens/capture/capture_screen.dart` owns:
    - `_isImportingAudio`, `_audioImportProgress`, and `AudioNormalizationCancelToken? _audioImportCancelToken` to drive UI for import + normalization.

### 1.4 Plugin-provided normalization

- **Plugin repo**: `/Users/benjaminmackenzie/Dev/flutter_dictation`
  - Core service: `lib/services/native_dictation_service.dart`.
  - Normalization API:
    - `Future<NormalizedAudioResult> normalizeAudio(String sourcePath)`
      - Calls the native method channel `normalizeAudio` with a file path.
      - Returns `NormalizedAudioResult`:
        - `canonicalPath` (string)
        - `duration` (Dart `Duration`, backed by `durationMs` from native side)
        - `sizeBytes` (int)
        - `wasReencoded` (bool: `true` if transcoded, `false` if already canonical).
  - Example usage: `example/lib/main.dart` (`_importAndNormalizeAudio()`):
    - Lets user pick a file with `file_picker`.
    - Calls `_dictationService.normalizeAudio(sourcePath)`.
    - Displays canonical path, duration, size, and whether it was re-encoded.

---

## 2. Target architecture

### 2.1 Single source of truth for audio normalization

- **All audio normalization (dictation + imports) should go through `NativeDictationService.normalizeAudio`.**
- The Memories app **no longer uses FFmpeg directly**; all transcoding/bitrate choices live inside the plugin.
- Memories only:
  - Calls `normalizeAudio(sourcePath)`.
  - Enforces high-level business rules:
    - Output must be < 50 MB.
    - Duration and size stored in Memory metadata.
    - Errors are surfaced to users with clear messaging.

### 2.2 Minimal adaptation layer in Memories

- Introduce a very thin, plugin-backed normalizer abstraction in Memories for clarity and testability, e.g. `PluginBackedAudioNormalizer`:
  - Depends on `NativeDictationService` (or an interface we can mock).
  - Responsible only for:
    - Calling `normalizeAudio(sourcePath)`.
    - Enforcing the 50 MB limit.
    - Mapping `NormalizedAudioResult` into the fields our app cares about.
  - No FFmpeg or file-system policy lives here; it’s just a wrapper around the plugin.

- Dictation and import flows depend on this new abstraction instead of the old `AudioNormalizerService`.

### 2.3 What disappears from the app

- `AudioNormalizerService`, `AudioNormalizationResult`, and `AudioNormalizationCancelToken`.
- Direct dependency on `ffmpeg_kit_flutter` / `ffprobe_kit` in the Memories app.
- Tests that exercise FFmpeg-specific behavior (duration parsing, bitrate selection) inside the app.

---

## 3. Implementation steps

### 3.1 Add a plugin-backed normalizer abstraction

**Objective**: Centralize plugin normalization behind a simple interface so both dictation and import flows can share it.

1. **Create a new service** in `lib/services` (name to confirm, but goal is self-explanatory), e.g. `plugin_audio_normalizer.dart`:
   - Defines a small DTO (if desired) so the rest of the app isn’t tied directly to the plugin type names:
     - `canonicalPath` (string)
     - `durationSeconds` (double)
     - `fileSizeBytes` (int)
     - `wasReencoded` (bool)
   - Holds a `NativeDictationService` instance (or is injected with one).
   - Implements `Future<PluginNormalizedAudio> normalize(String sourcePath)` by:
     - Calling `NativeDictationService.normalizeAudio(sourcePath)`.
     - Checking `result.sizeBytes`:
       - If `> 50 * 1024 * 1024`, throw an error such as `AudioTooLargeException` so callers can show a user-friendly message.
     - Returning a mapped DTO.

2. **Add a Riverpod provider** for this abstraction, similar to how `audioNormalizerServiceProvider` works today.
   - e.g. `pluginAudioNormalizerProvider` exposing the `PluginBackedAudioNormalizer`.

3. **(Optional) Common error type**
   - Define a small exception hierarchy (e.g. `AudioNormalizationFailure`) that can be used for both dictation and import flows, so UI can render a consistent message.

### 3.2 Switch dictation flow to use the plugin normalizer

**Objective**: When dictation stops, use the plugin to normalize the preserved audio file instead of FFmpeg.

1. **Capture preserved audio (unchanged)**
   - Keep the existing behavior in `DictationService` and `capture_state_provider`:
     - `DictationService.stop()` returns `DictationStopResult` with `audioFilePath` and `metadata`.
     - `capture_state_provider` caches the raw audio via `audioCacheService.storeAudioFile(...)`, yielding `cachedAudioPath`.

2. **Replace FFmpeg-based normalization call** in `capture_state_provider`:
   - Today:
     - `audioNormalizerServiceProvider.normalizeAudio(inputFilePath: cachedAudioPath, inputDuration: audioDuration, ...)`.
   - Future:
     - Read `pluginAudioNormalizerProvider` and call `normalize(cachedAudioPath)`.
     - Use the returned DTO to populate:
       - `normalizedAudioPath` (use `canonicalPath`).
       - `audioDuration` (convert from `Duration` to seconds if needed).
       - `audioFileSizeBytes`.
       - Optionally store `wasReencoded` in metadata if helpful.

3. **Handle oversize / errors**
   - If the plugin-backed normalizer throws (e.g. because `sizeBytes > 50 MB` or native normalization fails), mirror the current UX:
     - Set `state.errorMessage` to a clear explanation.
     - Do **not** proceed with saving the memory.
   - Keep the existing logic that cleans up any previous normalized file when a new one is created (if we continue to track previous `normalizedAudioPath`).

4. **Keep metadata semantics aligned with the spec**
   - Ensure `audioDuration` in state/DB is in **seconds** (matching the fix described in `ensure-audio-under-50mb.md`).
   - Ensure `audioFileSizeBytes` is the plugin output size, not the original preserved audio.

### 3.3 Switch imported audio flow to use the plugin normalizer

**Objective**: When a user imports an existing audio file (via Files / storage), normalize it with the plugin instead of FFmpeg.

1. **Update `MediaPickerService`** (`lib/services/media_picker_service.dart`):
   - Replace `_audioNormalizerService` field with a dependency on `PluginBackedAudioNormalizer` (from the new provider).
   - In `pickAudioFromFiles(...)`:
     - After selecting the file path with `file_picker`, call the plugin-backed normalizer:
       - `final normalized = await pluginAudioNormalizer.normalize(path);`
     - Return a `PickedAudioFile` that now references the plugin-backed DTO instead of `AudioNormalizationResult`.
       - Either:
         - Change `PickedAudioFile.normalizedResult` type, **or**
         - Create a small wrapper type that embeds the plugin result but keeps the same surface fields.

2. **Update consumers of `PickedAudioFile`**
   - Find all call sites that expect `AudioNormalizationResult`-specific fields (codec, bitrateKbps) and update them to use the new DTO.
   - If bitrate information is still needed for analytics, add it to the plugin DTO once we confirm the plugin exposes it (or derive from size + duration if necessary).

3. **Update capture screen import UX** (`lib/screens/capture/capture_screen.dart`):
   - The screen currently models progress and cancellation around `AudioNormalizationCancelToken` and `onProgress`.
   - With the plugin:
     - `normalizeAudio` is a single async call without built-in cancellation.
     - Plan options:
       - **Simple path (initial implementation)**: treat normalization as non-cancellable, keep a simple busy state (`_isImportingAudio`) and basic progress indicator (indeterminate spinner).
       - **Future enhancement**: if the plugin later adds progress/cancellation hooks, wire them into the same UI fields.
   - Adjust `_audioImportCancelToken` and any related code accordingly (likely removing the token and simplifying the state machine).

### 3.4 Remove the old FFmpeg-based normalizer and dependencies

**Objective**: Once both flows use the plugin-backed normalizer and tests are green, delete project-specific normalization code and direct FFmpeg usage.

1. **Delete the service and its provider**
   - Remove `lib/services/audio_normalizer_service.dart` and its generated part `audio_normalizer_service.g.dart`.
   - Remove `audioNormalizerServiceProvider` references in:
     - `capture_state_provider.dart`.
     - Any other services/providers that might still import it.

2. **Delete tests**
   - Remove `test/services/audio_normalizer_service_test.dart`.
   - If there are tests that assert specific FFmpeg commands/bitrate logic, replace them with tests that:
     - Mock `NativeDictationService` and validate we:
       - Call `normalizeAudio` with the right path.
       - Correctly handle success and error cases.
       - Enforce the 50 MB cap on `sizeBytes`.

3. **Clean up dependencies**
   - In `pubspec.yaml`:
     - Remove `ffmpeg_kit_flutter` and `ffprobe_kit` if they are only used by `AudioNormalizerService`.
   - In `ios/Podfile` and any platform-specific build files:
     - Remove FFmpeg-related configuration that was added explicitly for the app’s own usage (leaving plugin-managed dependencies intact).

4. **Static analysis & build cleanup**
   - Run `flutter pub get`, `flutter analyze`, and tests to confirm there are no remaining references to the old service.
   - Fix any lints or unused imports introduced by the removal.

---

## 4. Testing & validation plan

### 4.1 Automated tests

- **Dictation normalization path**
  - Unit-test the capture provider logic by mocking the plugin-backed normalizer:
    - Success case: normalized file under 50 MB updates `normalizedAudioPath`, `audioDuration`, and `audioFileSizeBytes` correctly.
    - Error case: plugin throws (e.g., oversize) and provider sets `errorMessage` and **does not** mark the memory as saved.

- **Import normalization path**
  - Unit-test `MediaPickerService.pickAudioFromFiles` with a mocked normalizer:
    - User cancels file picking → returns `null`.
    - Normalization succeeds → returns `PickedAudioFile` with expected canonical path and metadata.
    - Normalization fails → throws `MediaPickerException` with a user-friendly message.

### 4.2 Manual QA matrix

- **Platforms**: iOS (at least one modern device + one older) and Android (low/mid/high-end).
- **Scenarios**:
  - Dictation:
    - Record short (1–2 min), medium (10–20 min), and long (30–45 min) stories; verify:
      - Upload succeeds.
      - Stored audio object in Supabase is < 50 MB.
      - Duration metadata in the app matches actual playback.
  - Import:
    - Import a large WAV/FLAC (e.g. > 200 MB) and confirm plugin-normalized output is < 50 MB or fails gracefully with clear UX.
    - Import an already-canonical small `.m4a` and confirm plugin returns `wasReencoded == false` (if applicable) and we still respect size/duration constraints.

### 4.3 Backend guardrails (unchanged but revalidated)

- Confirm Supabase bucket/object-level size limits still reject files > 50 MB and that the app surfaces these errors correctly.
- Optional: ensure any Edge Functions that validate audio assets treat plugin-normalized files as the source of truth.

---

## 5. Rollout & de-risking

1. **Feature flag the switch if needed**
   - Introduce a remote-config / feature flag for "usePluginAudioNormalizer".
   - Initially:
     - Keep both implementations wired but only execute the plugin-backed normalizer when the flag is on.
     - Log normalized size/duration for comparison across a small % of users.

2. **Gradual rollout**
   - Start with internal/testing accounts.
   - Gradually roll out to production users once metrics look healthy and no regressions are reported.

3. **Final cleanup**
   - After the plugin-backed path has been stable for at least one release:
     - Remove the feature flag.
     - Delete the leftover FFmpeg-based implementation and any dead code paths.

---

## 6. Definition of done

- **Functional**
  - All dictation and imported audio is normalized using `NativeDictationService.normalizeAudio` (via the new abstraction).
  - No code in the Memories app imports or calls `ffmpeg_kit_flutter` / `ffprobe_kit`.
  - Dictation and import flows both enforce the < 50 MB constraint using plugin output (`sizeBytes`).

- **Codebase**
  - `AudioNormalizerService` and related tests are removed.
  - New plugin-backed normalizer and providers are in place and covered by tests.

- **Operational**
  - Manual QA matrix passes on iOS and Android.
  - Supabase still rejects any oversize uploads and the app surfaces errors cleanly.
  - No regressions in dictation UX, memory creation, or audio playback for existing and new memories.
