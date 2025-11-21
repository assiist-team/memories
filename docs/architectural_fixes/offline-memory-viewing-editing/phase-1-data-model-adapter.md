## Phase 1: Data Model & Preview/Queue Adapter (Foundation)

### Objective

Define a **single, unified timeline data model** that can represent:

- **Queued offline memories** (captured while offline, fully available locally), and  
- **Preview-index entries** for **previously-synced memories** (visible offline, but often **preview-only**),

and introduce an adapter layer that converts queue + preview-index records into timeline-ready objects.

This phase is strictly about **Phase 1 offline support**:

- We support a **preview index** so the unified timeline remains populated when offline.
- We support **full local detail/editing only for queued offline memories**.
- We explicitly **do not** implement or design **full offline caching of all details/media** (that will be **Phase 2 – Full Offline Caching**).

### Prerequisites

- Existing models:
  - `TimelineMoment` (or equivalent unified timeline model)
  - `QueuedMoment`, `QueuedStory` (offline queues)
- Baseline understanding of:
  - Offline capture → queue → sync flow
  - Unified timeline feed (Stories, Moments, Mementos)

---

### Deliverables

1. A unified `TimelineMoment` contract that communicates offline/preview states **without any backward-compatibility shim**. All consumers will be updated in lockstep.
   - queued offline entries,
   - preview-index entries for previously-synced memories, and
   - basic offline/preview flags (no heavy caching policy).
2. A pair of adapter services:
   - `OfflineQueueToTimelineAdapter` for queue entries,
   - `PreviewIndexToTimelineAdapter` for preview index rows.
3. Unit tests that lock in the adapter behaviour and model changes.

---

## Implementation Steps

### Step 1: Extend `TimelineMoment` (preview-aware, offline-aware)

**File**: `lib/models/timeline_moment.dart`

Extend `TimelineMoment` so it can distinguish:

- **Queued offline memories** (full local detail), and  
- **Preview-only synced memories** (shown via preview index, not openable offline).

Add/confirm the following fields:

- `final bool isOfflineQueued;`
  - `true` for queued offline memories.
  - `false` for anything coming from the server or preview index.
- `final bool isPreviewOnly;`
  - `true` for preview-index memories that **do not** have local detail cached.
  - `false` for:
    - queued offline memories, and
    - memories with full local detail (Phase 2 concern).
- `final bool isDetailCachedLocally;`
  - Phase-1 usage:
    - `true` only for queued offline memories (they *are* fully local).
    - `false` for preview-only synced memories.
  - Phase-2 usage:
    - Later extended when we start caching details/media for more memories.
- `final String? localId;`
  - Local identifier for queued memories (never set for preview-only entries).
- `final String? serverId;`
  - Supabase `id` for synced memories (may be null for not-yet-synced queued items).
- `final OfflineSyncStatus offlineSyncStatus;`
  - Enum with values: `queued`, `syncing`, `failed`, `synced`.
  - For preview-only entries, default to `synced`.

Also add two convenience getters that the rest of the app can rely on:

- `String get effectiveId => serverId ?? localId ?? id;`
- `bool get isAvailableOffline => isOfflineQueued || isDetailCachedLocally;`

Illustrative shape:

```dart
enum OfflineSyncStatus { queued, syncing, failed, synced }

class TimelineMoment {
  // Existing fields (id, memoryType, capturedAt, title/snippet, etc.)

  /// True when this memory was captured offline and is stored in a local queue.
  final bool isOfflineQueued;

  /// True when this memory is only represented as a lightweight preview entry.
  /// In Phase 1 this means:
  /// - The card can be shown in the timeline.
  /// - Full detail is NOT available offline.
  final bool isPreviewOnly;

  /// True when full detail for this memory is cached locally.
  /// Phase 1: queued offline memories only.
  /// Phase 2: may also include fully cached synced memories.
  final bool isDetailCachedLocally;

  /// Local ID for queued offline memories (null for preview-only/server entries).
  final String? localId;

  /// Server ID for synced memories (null while queued offline).
  final String? serverId;

  final OfflineSyncStatus offlineSyncStatus;

  TimelineMoment({
    // existing params...
    this.isOfflineQueued = false,
    this.isPreviewOnly = false,
    this.isDetailCachedLocally = false,
    this.localId,
    this.serverId,
    this.offlineSyncStatus = OfflineSyncStatus.synced,
  });

  String get effectiveId => serverId ?? localId ?? id;

  /// Whether the user can open a full detail view while offline.
  bool get isAvailableOffline => isOfflineQueued || isDetailCachedLocally;

  TimelineMoment copyWith({
    // include all fields including new ones
  });

  Map<String, dynamic> toJson() { /* mirrors fromJson with safe defaults */ }

  factory TimelineMoment.fromJson(Map<String, dynamic> json) {
    return TimelineMoment(
      // existing fields...
      isOfflineQueued: json['is_offline_queued'] as bool? ?? false,
      isPreviewOnly: json['is_preview_only'] as bool? ?? false,
      isDetailCachedLocally: json['is_detail_cached_locally'] as bool? ?? false,
      localId: json['local_id'] as String?,
      serverId: json['server_id'] as String?,
      offlineSyncStatus: _offlineSyncStatusFromJson(json['offline_sync_status']),
    );
  }
}
```

> **Phase 1 constraint**: do **not** add any fields that imply heavy media caching policies (e.g., “download window” or “offline collection size”). Those belong in Phase 2.

---

### Step 2: Define Preview Index Row Model

**File**: `lib/models/local_memory_preview.dart` (new)

The preview index is a **local store** that holds only the data required to render a card when offline. It is populated/refreshed when the app is online and reading from Supabase.

Define a simple model that can be stored in SQLite/Hive/SharedPreferences (implementation is out of scope here):

```dart
class LocalMemoryPreview {
  final String serverId;
  final MemoryType memoryType;
  final String titleOrFirstLine;
  final DateTime capturedAt;

  /// Lightweight flags used in Phase 1.
  final bool isDetailCachedLocally; // false for Phase 1 except queued mapped via adapter

  LocalMemoryPreview({
    required this.serverId,
    required this.memoryType,
    required this.titleOrFirstLine,
    required this.capturedAt,
    this.isDetailCachedLocally = false,
  });

  Map<String, dynamic> toJson() { /* serialize for chosen store */ }
  factory LocalMemoryPreview.fromJson(Map<String, dynamic> json) { /* ... */ }
}
```

This model is **intentionally small**:

- No media URLs or blobs.
- No full text bodies.
- Just enough to keep the unified timeline useful when offline.

---

### Step 3: Create `OfflineQueueToTimelineAdapter`

**File**: `lib/services/offline_queue_to_timeline_adapter.dart` (new)

Purpose: convert `QueuedMoment` / `QueuedStory` into `TimelineMoment` instances for the unified feed.

Key responsibilities:

- Mark entries as **offline queued** and **locally detailed**:
  - `isOfflineQueued: true`
  - `isDetailCachedLocally: true`
  - `isPreviewOnly: false`
- Use `localId` as the primary identifier until `serverId` is known.
- Populate basic card fields (title/snippet, capturedAt, type).
- Avoid **full-media caching logic**: we only surface whatever local paths exist.

Shape:

```dart
class OfflineQueueToTimelineAdapter {
  static TimelineMoment fromQueuedMoment(QueuedMoment queued);
  static TimelineMoment fromQueuedStory(QueuedStory queued);
}
```

Behaviour:

- `TimelineMoment.id` / `localId`:
  - Set both to `queued.localId`.
- `serverId`:
  - Use `queued.serverMomentId` / `queued.serverStoryId` if present, else `null`.
- `isOfflineQueued`:
  - Always `true`.
- `isDetailCachedLocally`:
  - Always `true` in Phase 1 (queue has full detail).
- `isPreviewOnly`:
  - Always `false`.
- `offlineSyncStatus`:
  - Mapped from queue status: `queued`, `syncing`, `failed`, `synced`.
- `titleOrSnippet`:
  - Derived from `inputText` or a simple fallback string.

> Any mapping of local media paths into `TimelineMoment` is allowed as **metadata only** (e.g., pointing to `file://` URLs), not as a caching policy. The adapter must not decide how much to store or pre-download—that is a Phase 2 concern.

---

### Step 4: Create `PreviewIndexToTimelineAdapter`

**File**: `lib/services/preview_index_to_timeline_adapter.dart` (new)

Purpose: convert `LocalMemoryPreview` rows into `TimelineMoment` entries suitable for rendering in the timeline when the app is offline.

Key responsibilities:

- Mark entries as **preview-only** when offline.
- Ensure they appear in the correct order alongside queued offline memories.
- Make it clear to the UI that full detail is **not available offline** in Phase 1.

Shape:

```dart
class PreviewIndexToTimelineAdapter {
  static TimelineMoment fromPreview(LocalMemoryPreview preview) {
    return TimelineMoment(
      id: preview.serverId,
      serverId: preview.serverId,
      localId: null,
      memoryType: preview.memoryType,
      capturedAt: preview.capturedAt,
      titleOrFirstLine: preview.titleOrFirstLine,
      isOfflineQueued: false,
      isPreviewOnly: !preview.isDetailCachedLocally,
      isDetailCachedLocally: preview.isDetailCachedLocally,
      offlineSyncStatus: OfflineSyncStatus.synced,
      // all other offline-related flags default to "synced from server" semantics
    );
  }
}
```

Phase-1 behaviour:

- For most entries in the preview index:
  - `isDetailCachedLocally == false`
  - `isPreviewOnly == true`
- The UI will:
  - Render them **greyed out** when offline.
  - Either disable taps or show a small “Not available offline” message.

---

### Step 5: Introduce `LocalMemoryPreviewStore` (interface-only)

**File**: `lib/services/local_memory_preview_store.dart` (new)

Purpose: define an abstraction to:

- **Write** preview entries when online (as the unified timeline fetches from Supabase).
- **Read** them when offline for the unified feed.

Phase 1 does **not** dictate the storage technology—this is just an interface.

```dart
abstract class LocalMemoryPreviewStore {
  /// Upsert a batch of preview entries derived from the latest online feed page.
  Future<void> upsertPreviews(List<LocalMemoryPreview> previews);

  /// Read a window of preview entries for the unified feed.
  ///
  /// This is the primary entry point for offline timeline rendering.
  Future<List<LocalMemoryPreview>> fetchPreviews({
    Set<MemoryType>? filters,
    int limit = 50,
  });

  /// Optional: clear all previews, used for logout / account switch.
  Future<void> clear();
}
```

> **Phase 1 constraint**: The store holds **only** preview-level metadata. It must not start pre-downloading or caching large bodies/media; that belongs in Phase 2.

---

### Step 6: Unit Tests

**File**: `test/services/offline_queue_to_timeline_adapter_test.dart`  
**File**: `test/services/preview_index_to_timeline_adapter_test.dart`

Test matrix:

- `OfflineQueueToTimelineAdapter`:
  - Queued moment → `TimelineMoment` with:
    - `isOfflineQueued == true`
    - `isDetailCachedLocally == true`
    - `isPreviewOnly == false`
    - Proper `effectiveId`, timestamps, and basic fields.
  - Queued story → carries through audio metadata (if present) and flags correctly.
  - Status mapping from queue status → `OfflineSyncStatus`.
- `PreviewIndexToTimelineAdapter`:
  - Preview row with `isDetailCachedLocally == false` → `isPreviewOnly == true`, `isAvailableOffline == false`.
  - (Future-proof) preview row with `isDetailCachedLocally == true` → `isPreviewOnly == false`, `isAvailableOffline == true`.
  - Sorting/ordering handled externally (repository), but verify that `capturedAt` is preserved.

---

## Files to Create/Modify

### New Files

- `lib/models/local_memory_preview.dart` — preview index row model.
- `lib/services/offline_queue_to_timeline_adapter.dart` — maps queue → timeline.
- `lib/services/preview_index_to_timeline_adapter.dart` — maps preview index → timeline.
- `lib/services/local_memory_preview_store.dart` — abstraction for preview index storage.
- `test/services/offline_queue_to_timeline_adapter_test.dart`
- `test/services/preview_index_to_timeline_adapter_test.dart`

### Files to Modify

- `lib/models/timeline_moment.dart` — add offline/preview flags and identifiers.

---

## Success Criteria

- **Data model readiness**
  - [ ] `TimelineMoment` can represent **queued offline**, **preview-only**, and **online-synced** entries with all RPC consumers updated simultaneously—no backward compatibility layer retained.
  - [ ] Legacy-only timeline fields are removed instead of dual-written.
  - [ ] Flags `isOfflineQueued`, `isPreviewOnly`, and `isDetailCachedLocally` are documented and self-explanatory.
- **Adapter correctness**
  - [ ] Queued offline memories adapt to `TimelineMoment` with full offline availability (`isAvailableOffline == true`).
  - [ ] Preview index entries adapt to `TimelineMoment` with preview-only semantics when offline (`isPreviewOnly == true`, `isAvailableOffline == false`).
- **Preview index foundation**
  - [ ] `LocalMemoryPreview` + `LocalMemoryPreviewStore` are defined with clear responsibilities.
  - [ ] No implementation step attempts **full offline caching** of all details/media.
- **Tests**
  - [ ] Adapter tests cover both queue and preview index flows.
  - [ ] JSON/serialization tests ensure offline/preview flags round-trip correctly.

When this phase is complete, Phase 2 (Timeline Integration) can safely:

- Pull from **preview index + queue** when offline,
- Populate the preview index when online,
- Present a consistent, full unified timeline even without connectivity.


