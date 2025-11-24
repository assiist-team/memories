## Capture Screen Offline Queue Indicator – Misplacement & Behaviour Fix (2025‑11‑22)

### 1. Problem Statement

- **What’s happening now**
  - After saving a memory, the **capture screen** shows:
    - A **success checkmark** inside the Save button.
    - A **global “Queued” chip** directly under the app bar, via `QueueStatusChips`.
  - This chip is driven by the **offline queue status** (transport axis), not AI processing, but it:
    - Appears on the **capture screen**, even when nothing on that screen needs attention.
    - Appears even when the device is **online** with a full Wi‑Fi signal.
- **Why this is bad**
  - It was **never a product requirement** to show a **global queue indicator** on the capture screen.
  - The chip is **confusing**:
    - Reads as if the *current* capture is in some special state.
    - Conflates **offline sync state** with the capture experience.
  - It **adds noise** to the primary capture flow without giving actionable information:
    - The user can’t act on those queued items from the capture screen.
    - The useful context (“this specific memory is queued for sync”) belongs in **per‑memory views**, not in a global banner above the composer.

**Desired high‑level behaviour:**

- The **capture screen should not show any offline queue or processing indicators**.
- Offline/sync state belongs at the **memory level** (detail & timeline), not as a global chip in capture.

---

### 2. Current Implementation (Why the “Queued” Chip Shows Up)

#### 2.1 Capture screen wiring

- `CaptureScreen.build` includes `QueueStatusChips` at the top of the body:

  - Right after the app bar:
    - `const QueueStatusChips(),`
  - This means **any change** in the offline queue state is surfaced **globally** on the capture screen.

#### 2.2 Queue status source

- `QueueStatusChips` → `queueStatusProvider` (`queue_status_provider.dart`):
  - Reads from the unified `OfflineMemoryQueueService`.
  - Fetches counts by status:
    - `queued = getByStatus('queued')`
    - `syncing = getByStatus('syncing')`
    - `failed = getByStatus('failed')`
  - Renders chips:
    - “Queued”
    - “Syncing”
    - “Needs Attention”

- `CaptureScreen._handleSave`:
  - Enqueues a `QueuedMemory` via `OfflineMemoryQueueService.enqueue(...)` for:
    - Always in the dedicated “queue first” branch.
    - Again in the `OfflineException` branch for online save failures.
  - Then explicitly calls:
    - `ref.invalidate(queueStatusProvider);`
  - Result:
    - **Every time** you save (especially when offline or when we choose to queue), `queuedCount > 0`.
    - The **global “Queued” chip** turns on at the top of the capture screen.

#### 2.3 Why it shows even when online

- The offline queue is **sticky**:
  - Once there are queued entries, they remain until `MemorySyncService` syncs them.
  - That state is **independent of current connectivity**.
- So when you open the app online:
  - You still have queued items in `OfflineMemoryQueueService`.
  - `QueueStatusChips` sees `queuedCount > 0`.
  - You get the global “Queued” chip **even though connectivity is fine**.

This behaviour is **by code**, but **not by product intent** for the capture experience.

---

### 3. Desired Behaviour (New Source of Truth)

#### 3.1 Capture screen

- **No global queue/processing indicators on capture.**
  - The capture screen focuses on:
    - Input (text, dictation, media, tags).
    - A simple **Save** affordance with:
      - Spinner while synchronously saving/queuing.
      - Brief checkmark on success.
  - It **does not** surface:
    - “Queued”, “Syncing”, or “Needs Attention” chips.
    - Any “Processing scheduled…” / processing‑axis status.

#### 3.2 Per‑memory offline/sync indicators

- **Offline / queued for sync** is a **per‑memory concern**:
  - Detail screen for **offline queued memories**:
    - Already uses:
      - `OfflineMemoryDetailNotifier` to load queued entries.
      - `_getOfflineSyncStatus` + `_buildOfflineQueuedBanner` to show:
        - “Pending sync”, “Syncing…”, “Sync failed…”.
  - Timeline:
    - Uses `OfflineSyncStatus` and flags (`isOfflineQueued`, `isPreviewOnly`, etc.) to render:
      - “Pending sync” chips.
      - Distinct visual treatment for offline entries.

- **Processing indicators** (scheduled / processing) are also **per‑memory**:
  - On the **online detail** screen only:
    - `_buildProcessingStatusBanner` shows:
      - “Processing scheduled…”
      - “Processing in background…”
      - etc., based on `memory_processing_status.state`.
  - They **never appear** on the capture screen, and are not global.

#### 3.3 Online vs offline semantics

- **Being online** should **not** cause a global “Queued” chip to appear on capture just because old offline items exist.
- Instead:
  - Online/offline affects:
    - Whether queued items can sync.
    - How per‑memory banners and timeline badges behave.
  - The capture flow itself remains:
    - “Save → brief checkmark → route to timeline/detail” with **no global queue noise**.

---

### 4. Proposed Changes

#### 4.1 Remove global queue chips from capture screen

- **Remove `QueueStatusChips` from `CaptureScreen`**:
  - Delete the `const QueueStatusChips()` row at the top of the capture body.
  - Result:
    - Capture screen shows **no global queue state**.
    - Offline queue still works behind the scenes and in per‑memory views.

#### 4.2 Keep/strengthen per‑memory offline banners

- **Detail screen (offline queued memories)**:
  - Keep and, if necessary, tighten:
    - `_buildOfflineQueuedBanner` that maps `OfflineSyncStatus`:
      - `queued` → “Pending sync – This memory will upload automatically when you’re online.”
      - `syncing` → “Syncing… – We’re uploading this memory in the background.”
      - `failed` → “Sync failed – We’ll retry automatically. You can also try again later.”
  - This is the **correct place** to surface offline queue state.

- **Timeline**:
  - Continue to use:
    - `OfflineSyncStatus` and flags (`isOfflineQueued`, `isPreviewOnly`, `isDetailCachedLocally`) to render per‑card offline/sync badges.
  - If any global queue summary is desired in the future:
    - It should live on **timeline**, not capture, and be clearly about “You have N memories pending sync”, not “this capture is queued”.

#### 4.3 Re‑scope `QueueStatusChips` (if still needed)

- Options:
  - **Option A (preferred)**: Retire `QueueStatusChips` from the product entirely.
    - Rely solely on **per‑memory** indicators (timeline + detail).
  - **Option B**: Move `QueueStatusChips` out of capture and into:
    - Timeline header, or
    - A dedicated **settings/debug** view for power users.
  - In both cases, **do not** render it on capture.

---

### 5. Implementation Checklist (App)

- **Capture screen**
  - [ ] Remove `QueueStatusChips` from `CaptureScreen` body.
  - [ ] Ensure save button flow remains:
    - [ ] Spinner while saving/queuing.
    - [ ] Brief checkmark on success.
    - [ ] Navigate to timeline/detail after success.

- **Offline detail**
  - [ ] Verify `_buildOfflineQueuedBanner` is the only place showing offline queue banners for detail.
  - [ ] Ensure copy is aligned with offline docs (“Pending sync”, “Syncing…”, “Sync failed…”).

- **Timeline**
  - [ ] Ensure offline/sync badges remain **per‑memory**:
    - [ ] Use `OfflineSyncStatus` and flags on `TimelineMemory`.
    - [ ] No global, capture‑scope banners.

- **QueueStatusChips**
  - [ ] Remove its usage from capture.
  - [ ] Either:
    - [ ] Retire it, or
    - [ ] Re‑home it to a non‑capture context (timeline header or settings) if a global summary is still desired.

---

### 6. Summary

- The **“Queued” chip on the capture screen is an offline sync indicator**, not a processing banner, and it was **never intended** to be global at the capture level.
- This doc re‑scopes queue indicators to **per‑memory** contexts (detail + timeline) and explicitly removes them from the capture screen.
- The **Save** button’s success checkmark is intended to be **brief and ephemeral**:
  - It should appear only for a short animation window after a successful save/queue, then either:
    - Navigate away (to timeline or detail), or
    - Reset back to the normal “Save” label if the user remains on capture.
  - It should **never remain stuck** in the checkmark state on the capture screen after the save flow is complete.
- After these changes, the capture experience becomes:
  - Clean: **no global chips**.
  - Focused: **only** input + save + brief, transient checkmark.
  - Correctly aligned with the offline architecture and the new processing/UI specs.


