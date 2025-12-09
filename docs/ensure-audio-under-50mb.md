# Ensure uploaded audio files are < 50 MB — Implementation plan

Overall goal

Guarantee that every audio story your app uploads is < 50 MB, even at 30+ minutes, by standardizing the format/bitrate and enforcing checks in the app (with optional backend safeguards).

Below is a concrete, handoff-ready plan for a dev.

---

## 1. Clarify requirements and decisions

- **Functional requirements**
  - **FR1**: Any new audio recorded or imported via the app must be stored in a canonical format that ensures file size < 50 MB for up to at least 30 minutes.
  - **FR2**: If a user picks a huge source file (e.g. lossless, 200+ MB), the app must transparently compress it before upload, or warn/fail gracefully.
  - **FR3**: The rest of the app continues to play back stories using your existing audio player; no changes to consumers beyond using the new URL/format.

- **Format & bitrate decision (voice-focused)**
  - **Canonical format for Memories**: `m4a` with AAC or HE-AAC (`.m4a`) as used by the Flutter app.
  - **Optional future format**: Opus in `ogg`/`webm` if we later add Opus playback support across all Memories clients.
  - **Target bitrate** (voice): **48–64 kbps mono**, sample rate 24 kHz or 32 kHz.
    - Size estimate: (size MB) ≈ (bitrate kbps × duration s) / (8 × 1024)
    - At **64 kbps**, 30 min → (64 × 1800) / 8192 ≈ 14.1 MB.
    - So 48–64 kbps mono gives **plenty of room** under 50 MB even for long stories.
    - These settings produce good-sounding playback for spoken-word stories in the Memories app on typical iOS and Android devices.
  - **Max duration**: Decide a hard upper bound (e.g. 60–90 min) where you warn/stop recording.

- **Source types**
  - **New recordings in-app** (you control codec/bitrate up front).
  - **Imported/existing audio** (must be transcoded/normalized in-app before upload).

---

## 2. High-level architecture

- **Client-side first, server as a safety net**
  - **Primary**: Do **all compression/transcoding on-device before upload** (saves bandwidth, guarantees size at the edge).
  - **Secondary**: Keep a **backend guardrail** (Supabase storage limit + optional Edge Function to validate / log / reject outliers).

- **Pipeline overview**
  1. User records or selects an audio file.
  2. App runs it through an **Audio Normalizer**:
     - Reads metadata (duration, size, current bitrate).
     - Chooses target bitrate (and possibly mono/stereo).
     - Transcodes to canonical format if needed.
     - Ensures output < 50 MB (or fails with a clear UX message).
  3. App uploads normalized file to Supabase Storage as the story’s audio asset.
  4. Existing processing/dispatch/metadata flows continue as they do today.

---

## 3. Client-side implementation plan (Flutter app)

### 3.1. Choose & integrate an audio transcoding library

- **Task**: Add a Flutter plugin that exposes FFmpeg or similar on iOS/Android.
  - Candidate: `ffmpeg_kit_flutter` (or whichever FFmpeg wrapper you already use/prefer).
- **Dev notes**:
  - Configure build settings for iOS/Android (min iOS version, ABI filters for Android).
  - Add basic smoke tests: simple transcode `wav → m4a`, check file exists and plays.

### 3.2. Implement `AudioNormalizer` service

- **New service**: `AudioNormalizer` (or similarly self-explanatory name).
- **Responsibilities**:
  - Accept a local audio file path (from recorder or file picker).
  - Extract metadata:
    - Duration (seconds).
    - Original size (bytes).
    - Channels (mono/stereo) – optional but nice to know.
  - **Decide target encoding settings**:
    - Mono vs stereo (default: force mono for voice).
    - Bitrate:
      - Start with **default 64 kbps mono**.
      - Optionally scale down if duration is extremely long:
        - (max_kbps_for_under_50MB) = floor((50 × 8 × 1024) / duration_seconds)
        - Use `min(default_kbps, max_kbps_for_under_50MB)` and clamp to a lower bound (e.g. 32 kbps).
  - **Transcode** via FFmpeg:
    - Input: original file path.
    - Output: temporary canonical file (`.m4a` or `.ogg`).
  - Verify:
    - Check final file **size < 50 MB**.
    - If not, either:
      - Retry with a lower bitrate (e.g. 32 kbps), or
      - Fail with explicit error for UX layer: “Audio too long to compress under 50 MB; please re-record a shorter story.”
  - Return a simple DTO:
    - `normalizedFilePath`
    - `durationSeconds`
    - `fileSizeBytes`
    - `codec`, `bitrateKbps` (optional, for logging/analytics).

### 3.3. Integrate into recording and import flows

- **Recording flow changes**
  - When **starting a recording**:
    - Configure the recorder to already use your canonical format if possible:
      - e.g. recorder outputs AAC `m4a` at ~64 kbps mono.
    - This may already be sufficient and **avoid** a post-pass transcode in most cases.
  - When **stopping a recording**:
    - Run the resulting file through `AudioNormalizer` **only if**:
      - It’s over a “soft size” threshold (e.g. 10–15 MB), or
      - Recorder cannot be fully controlled and you need to normalize everything anyway.
    - If normalization fails, show user-friendly error and don’t proceed to upload.

- **Import flow changes**
  - When user picks an existing file (e.g. from Files app/Android storage):
    - Immediately pass the selected path into `AudioNormalizer`.
    - Show a progress UI (“Optimizing audio for upload…”) with cancellation.
  - Only enable the “Continue / Save memory” button once normalization completes successfully.
  - Use the normalized path as the upload source.

### 3.4. Upload pipeline integration

- **Wherever you currently upload audio** for a memory:
  - Replace direct uploads of arbitrary files with:
    1. Call `AudioNormalizer` → get normalized file.
    2. **Assert** `size_bytes < 50 * 1024 * 1024` in code.
    3. Upload normalized file to Supabase Storage.
  - Ensure you **never** upload the original large file to Storage.

- **Error handling & UX**
  - If normalization fails (FFmpeg error, disk full, user cancels):
    - Show a concise error; keep them on the memory creation screen.
    - Allow retry.
  - If output is still too large:
    - Show a tailored message explaining that the story is too long for the current limits.

---

## 4. Backend / Supabase-side safeguards

Even with client-side normalization, add safety checks.

### 4.1. Storage configuration

- **Bucket size limit**
  - Confirm / configure Supabase bucket policies so that **no single object > 50 MB** is accepted.
  - Ensure app handles 413/4xx responses gracefully (show a clear error).

### 4.2. Optional: validation Edge Function

- **New (or extended) function**: `validate-audio-asset` (name it clearly).
- **Triggered by**: storage object creation in the audio bucket (if that fits your architecture).
- **Responsibilities**:
  - Read object metadata (size, path).
  - If size > 50 MB:
    - Either:
      - Mark the memory as invalid in DB and delete the object, or
      - Keep as a “quarantine” object for investigation and prevent it from being used.
  - Log metrics: count of uploaded audio files, duration (if stored), size distribution.

- **Integration with existing `dispatch-memory-processing`**
  - If you already have a memory processing dispatcher:
    - Ensure it **assumes audio is already normalized**.
    - Optionally add a defensive check: if size>50 MB, short-circuit with a logged error and mark the memory as “audio_unsupported_oversize”.

---

## 5. Data model & metadata

- **DB changes (if needed)**
  - In your `memories` (or equivalent) table, consider adding:
    - `audio_duration_seconds` (if you don’t already store it).
    - `audio_bitrate_kbps` (optional, but useful for monitoring).
    - `audio_filesize_bytes`.
  - Populate these from the client using the `AudioNormalizer` result when creating/updating a memory.

- **Why**: lets you:
  - Debug bad cases.
  - Build admin tooling around size/duration distribution.
  - Evolve compression strategy later without guessing.

---

## 6. Testing, QA, and rollout

- **Unit tests**
  - `AudioNormalizer`:
    - Short file (2–5 min) → normalized, < 5 MB.
    - Long file (~30–45 min) → normalized, < 50 MB.
    - Already-compressed file slightly over threshold → still normalized down.
    - Edge case: extremely long (e.g. 3+ hours) → either very low bitrate or explicit failure.

- **Manual QA matrix**
  - **Platforms**: iOS (various devices) and Android (low/mid/high-end).
  - **Scenarios**:
    - Record 1, 10, 30, 45 minutes; verify upload success and Storage size.
    - Import large WAV (e.g. 200 MB+, 44.1kHz stereo) → ensure app compresses it and output < 50 MB or gives clear error.
    - Airplane/low bandwidth: ensure normalization is local and doesn’t need network.

- **Rollout**
  - Feature-flag the new normalization pipeline (e.g. remote config).
  - Log:
    - Raw vs normalized size per upload.
    - Failures (normalization, upload).
  - After confirming stability, enforce the behavior for all users.

---

## 6.5. Implementation gaps to fix

- **Duration metadata is 1000× too short**  
  `_getAudioDuration` now uses `FFprobeKit.getMediaInformation`, but it still divides the returned duration by 1000 as if the value were milliseconds. FFprobe already reports seconds, so we write ~1.8 s for a 30 min story, the bitrate clamp never triggers, and `story_fields.audio_duration` is junk. Drop the `/ 1000` (and add a regression test) so guardrails and analytics use the real length.

- **Imported audio still bypasses normalization**  
  The app only runs `AudioNormalizerService` from `stopDictation`; the import flow retains the old TODO. Users can select a 200 MB WAV/FLAC and we upload it untouched, defeating the <50 MB requirement. Wire the import picker through the normalizer (with progress + cancellation) and block upload until it succeeds, just like dictation output.

---

## 7. What to hand to the dev

You can summarize the “ask” to your dev like this:

- **Implement a client-side `AudioNormalizer` that ensures every audio file we upload is trans-coded/compressed into a canonical format (e.g. 64 kbps mono AAC `.m4a`) and is guaranteed < 50 MB, even for 30+ minute recordings.**
- **Integrate this into both the recording flow and imported-audio flow so that we never upload unnormalized source files.**
- **Add basic backend guardrails (size limit + optional validation function) so oversize files can’t be used, even if something breaks client-side.**

If you’d like, next step I can help you turn this into a more formal engineering spec (with pseudo-code for the `AudioNormalizer`, suggested FFmpeg command lines, and concrete changes in your existing Flutter & Supabase code).