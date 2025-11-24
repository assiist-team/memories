## Memory Processing & Notification UI Companion

### 1. Scope

- **Goal**: Define the **UI behaviour** for:
  - Save button states during synchronous work (online + offline).
  - Global/background processing notifications.
  - Timeline and detail indicators that surface:
    - **Sync status** (offline queues / preview index).
    - **Processing status** (LLM pipeline).
- **Backend contract**:
  - Processing lifecycle is defined in `docs/architectural_fixes/memory-processing-and-notification-architecture.md`.
  - UI code treats:
    - `memory_processing_status.state` as the **processing axis**.
    - `TimelineMoment.offlineSyncStatus` and related flags as the **sync/offline axis**.

This doc intentionally does **not** define database schemas. It describes how the app should present the states defined by the backend and offline specs.

---

### 2. Save Button Behaviour (Capture Screen)

#### 2.1 States

- **Idle**:
  - Label: “Save”.
  - Enabled.
- **Saving (Online)**:
  - Compact spinner replaces label (no height growth).
  - Disabled.
  - Covers **only** synchronous work:
    - Validation.
    - Media uploads.
    - DB writes (including `memory_processing_status` insert).
- **Saving (Offline)**:
  - Compact spinner, disabled.
  - Covers **queue write only** (`OfflineQueueService` / `OfflineStoryQueueService`).
- **Success (Online)**:
  - Brief checkmark animation in button.
  - Navigate away to timeline or detail.
  - LLM processing continues in background.
- **Success (Offline)**:
  - Brief checkmark animation + subtle copy (e.g. “Queued for sync” where appropriate).
  - Navigate away; user sees a queued card with a “Pending sync” badge.

#### 2.2 UX Principles

- Button height is **fixed**; no in-button progress text or bars.
- Detailed messages (“Uploading…”, “Saving…”) belong in banners/overlays, not inside the button.
- A successful save **always** results in navigation and/or a visible card; no reliance on SnackBars as the only confirmation.

---

### 3. Per-Memory Processing Indicators (Online Only)

Per-memory processing indicators surface the background processing lifecycle for a **single memory** and are embedded directly into that memory’s own UI (detail view and, optionally, its timeline card). They:

- Are **non-modal** and participate in normal layout (no overlays).
- Never appear on the **capture screen**.
- Never obscure primary actions or navigation.

#### 3.1 Where They Appear

- **Memory detail screen**:
  - A slim banner near the top of the content area.
  - Sits above the main body content and below any app bar.
  - Moves content down rather than covering it.
- **Timeline card (optional)**:
  - A small chip or inline status row on the specific card for that memory.
  - Never shown as a global banner across the entire timeline.

#### 3.2 When to Show

Show processing indicators for a **specific memory** only when **all** of the following are true:

- We’re online.
- The memory has **offline changes** that have been synced to the server and now require AI processing.
- There is a corresponding `memory_processing_status` row for that memory where:
  - `state IN ('scheduled', 'processing')`.
- The user is **viewing that memory**:
  - On its detail screen, or
  - As a card in the timeline (if we choose to surface the indicator there).

Do **not** show processing indicators:

- On the capture screen (even if other memories are processing).
- For memories that are only processing due to pure online edits unless explicitly desired.

#### 3.3 Content Mapping

Map `memory_processing_status.state` to copy for that **specific memory**:

- `scheduled`:
  - “Processing scheduled…”
- `processing`:
  - Default: “Processing in background…”
  - Optional refinement (if `metadata` exposes a phase):
    - Phase `"title"` → “Generating title…”
    - Phase `"text"` / `"narrative"` → “Processing text…” / “Generating narrative…”
- `failed`:
  - “Processing failed. We’ll retry automatically.” (optional “Retry now” CTA).
- `complete`:
  - The banner/chip should shortly after disappear (or show a brief success state then dismiss).

#### 3.4 Behaviour

- Indicators are **scoped to a single memory**:
  - The detail screen shows only that memory’s processing state.
  - The timeline card (if used) shows only that card’s processing state.
- Multiple processing memories:
  - Each memory can show its own indicator in its own UI context.
  - There is **no global, app-wide processing banner or overlay**.

---

### 4. Timeline & Detail Indicators

UI distinguishes between:

- **Sync/transport axis** (offline docs):
  - `TimelineMoment.offlineSyncStatus`:
    - `queued`, `syncing`, `failed`, `synced`.
  - `TimelineMoment.isOfflineQueued`, `isPreviewOnly`, `isDetailCachedLocally`.
- **Processing axis** (this doc + backend doc):
  - `memory_processing_status.state`.

#### 4.1 Timeline Cards

Each `TimelineMoment` card uses:

- `offlineSyncStatus`, `isOfflineQueued`, `isPreviewOnly`, and `isDetailCachedLocally` to drive:
  - **Queued offline memories**:
    - Normal opacity.
    - Distinct border (e.g., orange).
    - Tappable **even when offline**.
    - Show a small chip:
      - `queued` → “Pending sync”.
      - `syncing` → “Syncing…”.
      - `failed` → “Sync failed”.
  - **Preview-only entries when offline**:
    - Slightly faded opacity.
    - Grey outline.
    - Either:
      - Not tappable, or
      - Taps show a subtle “Not available offline” message.
- Optional processing indicator for server-backed memories:
  - If `offlineSyncStatus == synced` **and** `memory_processing_status.state` is not `complete`/`failed`, cards may show a tiny gear/spinner icon to hint “processing in background”.

#### 4.2 Detail Screen

For **queued offline memories**:

- Use `OfflineMemoryDetailProvider` and offline editing paths from the offline docs.
- Show a slim status banner at the top:
  - `OfflineSyncStatus.queued`:
    - “Pending sync – This memory will upload automatically when you’re online.”
  - `OfflineSyncStatus.syncing`:
    - “Syncing… – We’re uploading this memory in the background.”
  - `OfflineSyncStatus.failed`:
    - “Sync failed – We’ll retry automatically. You can also try again later.”
- Disable or clearly grey out share actions until the memory is synced.

For **server-backed memories**:

- Use the online detail provider as today.
- Optionally surface processing state from `memory_processing_status.state`:
  - A tiny banner or inline chip (e.g., “Generating title…”, “Processing text…”).
  - This should **never** block editing or viewing; it’s informational only.

---

### 5. Offline vs Online Empty / Edge States

- **Offline, no data**:
  - Show a friendly empty state:
    - Icon (e.g., cloud-off).
    - Title: “You’re offline”.
    - Body: “New memories you capture will appear here and sync when you’re back online.”
- **Online, no data**:
  - Standard empty timeline messaging for a new user.

The presence of the **preview index** means that in normal situations, going offline does **not** clear the timeline; the empty offline state is a genuine edge case.

---

### 6. Accessibility & Copy

- **Color + text**:
  - Use color to differentiate states, but always pair it with text and/or icons.
  - Example palette:
    - Pending/queued: warm orange.
    - Syncing: blue.
    - Failed: red.
    - Preview-only: neutral grey.
- **Contrast**:
  - Badges and banners must meet basic contrast guidelines.
- **Copy tone**:
  - Keep strings short, clear, and reassuring:
    - “Pending sync”.
    - “This memory will upload automatically when you’re online.”
    - “Not available offline”.

---

### 7. Implementation Checklist (UI Layer)

- [ ] Implement compact save button states for online/offline, with checkmark-on-success.
- [ ] Implement per-memory processing indicators (detail banner + optional timeline badge) driven by `memory_processing_status.state`, visible only for memories with synced offline changes that are queued/processing.
- [ ] Ensure timeline cards:
  - [ ] Correctly show sync badges and offline visual treatments based on offline flags.
  - [ ] Optionally show a subtle processing indicator for server-backed memories still processing.
- [ ] Ensure detail screens:
  - [ ] Show sync banners for queued offline memories.
  - [ ] Do **not** block reading/editing while processing is running in the background.
- [ ] Wire all strings into localization where appropriate.


