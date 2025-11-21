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

### 3. Global Processing Overlay (Online Only)

The global overlay surfaces the background processing lifecycle driven by `memory_processing_status.state`. It should:

- Be **non-modal**.
- Avoid overlapping bottom navigation or critical controls.
- Persist until processing is actually done or the user dismisses it.

#### 3.1 When to Show

Show the overlay when **all** of the following are true:

- We’re online.
- There is at least one memory for the current user where:
  - `state IN ('queued', 'processing')`.
- Either:
  - The user has just saved that memory, or
  - We have a global “currently processing” list we want to expose.

#### 3.2 Content Mapping

Map `memory_processing_status.state` to copy:

- `queued`:
  - “Queued for processing…”
- `processing`:
  - Default: “Processing in background…”
  - Optional refinement (if `metadata` exposes a phase):
    - Phase `"title"` → “Generating title…”
    - Phase `"text"` / `"narrative"` → “Processing text…” / “Generating narrative…”
- `failed`:
  - “Processing failed. We’ll retry automatically.” (optional “Retry now” CTA).
- `complete`:
  - Overlay should shortly after disappear (or show a brief success state then dismiss).

#### 3.3 Behaviour

- The overlay:
  - Appears near the bottom of the content, above the button row and bottom nav.
  - Can shrink into a **compact, sticky** form when the user navigates away from capture/detail.
  - Can be dismissed by the user, but will reappear on next app launch if processing is still not `complete`.
- Multiple memories:
  - Start simple: show the **most recent** processing memory.
  - If we add multi-memory processing later, consider a small list view in the overlay.

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
- [ ] Implement global processing overlay driven by `memory_processing_status.state`.
- [ ] Ensure timeline cards:
  - [ ] Correctly show sync badges and offline visual treatments based on offline flags.
  - [ ] Optionally show a subtle processing indicator for server-backed memories still processing.
- [ ] Ensure detail screens:
  - [ ] Show sync banners for queued offline memories.
  - [ ] Do **not** block reading/editing while processing is running in the background.
- [ ] Wire all strings into localization where appropriate.


