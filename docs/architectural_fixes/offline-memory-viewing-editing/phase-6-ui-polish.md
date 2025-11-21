## Phase 6: UI Polish (Queued vs Preview-Only Offline States)

### Objective

Add clear, consistent UI treatments for:

- **Queued offline memories**  
  - Fully available offline, tappable, editable.  
  - Show “Pending sync” / “Syncing” / “Failed” badges and banners.
- **Preview-only memories** (previously-synced, from preview index)  
  - Visible offline to keep the timeline full, but not openable in Phase 1.  
  - Greyed / de-emphasized, with a subtle “Not available offline” cue.

This phase focuses purely on **Phase 1 offline support**:

- It assumes:
  - preview-index-driven offline timelines, and
  - full offline detail/editing **only for queued memories**.
- It does **not** design or implement any Phase 2 “Full Offline Caching” behaviours.

---

### Prerequisites

- Phase 1–5 completed:
  - `TimelineMoment` offline/preview flags, including:
    - `isOfflineQueued`
    - `isPreviewOnly`
    - `isDetailCachedLocally`
    - `offlineSyncStatus`
  - `UnifiedFeedProvider` exposes `isOffline`.
  - Preview index + queue integration in the timeline.
  - Offline detail and editing flows for queued memories.
  - Sync integration removes queued items after successful sync.
- Existing UI:
  - Timeline feed screens (`UnifiedTimelineScreen` or similar).
  - Card widgets (e.g., `MomentCard`, `StoryCard`, `MementoCard`, or a shared `MemoryCard`).
  - `MemoryDetailScreen`.

---

## Implementation Steps

### Step 1: Card-Level Visual States (Queued vs Preview-Only)

**File**: `lib/widgets/memory_card.dart` (and/or type-specific card widgets)

Each card should render differently based on:

- `TimelineMoment.isOfflineQueued`
- `TimelineMoment.isPreviewOnly`
- `UnifiedFeedViewState.isOffline`
- `TimelineMoment.offlineSyncStatus`

Example structure:

```dart
class MemoryCard extends ConsumerWidget {
  final TimelineMoment memory;

  const MemoryCard({required this.memory, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(unifiedFeedControllerProvider());
    final isOffline = feedState.isOffline;

    final isPreviewOnlyOffline =
        isOffline && memory.isPreviewOnly && !memory.isDetailCachedLocally;
    final isQueuedOffline = memory.isOfflineQueued;

    return Opacity(
      opacity: isPreviewOnlyOffline ? 0.5 : 1.0,
      child: Card(
        shape: _buildCardShape(context, isQueuedOffline, isPreviewOnlyOffline),
        child: InkWell(
          onTap: isPreviewOnlyOffline
              ? () => _showNotAvailableOfflineMessage(context)
              : () => _openDetail(context, isQueuedOffline),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPrimaryContent(context),
                const SizedBox(height: 8),
                _buildFooterBadges(context, isQueuedOffline, isPreviewOnlyOffline),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ShapeBorder _buildCardShape(
    BuildContext context,
    bool isQueuedOffline,
    bool isPreviewOnlyOffline,
  ) {
    if (isQueuedOffline) {
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade300, width: 1),
      );
    }
    if (isPreviewOnlyOffline) {
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade400, width: 0.5),
      );
    }
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
  }
}
```

Behaviour summary:

- **Queued offline memories**:
  - Normal card opacity.
  - Distinct border (e.g., orange).
  - Tappable, goes to offline detail + editing flows.
- **Preview-only memories when offline**:
  - Slightly faded opacity.
  - Grey outline.
  - Taps show a small unobtrusive message instead of opening full detail.

---

### Step 2: Badges for Sync Status and Preview-Only State

**File**: `lib/widgets/memory_card.dart` (or shared badge widgets)

Use:

- `TimelineMoment.isOfflineQueued` and `offlineSyncStatus` for **queued** status.
- `TimelineMoment.isPreviewOnly` for **preview-only** indicator.

Example footer badges:

```dart
Widget _buildFooterBadges(
  BuildContext context,
  bool isQueuedOffline,
  bool isPreviewOnlyOffline,
) {
  final badges = <Widget>[];

  if (isQueuedOffline) {
    badges.add(_buildSyncStatusChip(context));
  }

  if (isPreviewOnlyOffline) {
    badges.add(_buildPreviewOnlyChip(context));
  }

  if (badges.isEmpty) return const SizedBox.shrink();

  return Row(
    children: [
      ...badges.map((b) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: b,
          )),
    ],
  );
}

Widget _buildSyncStatusChip(BuildContext context) {
  final status = memory.offlineSyncStatus;
  Color bg;
  Color fg;
  String label;

  switch (status) {
    case OfflineSyncStatus.queued:
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade800;
      label = 'Pending sync';
      break;
    case OfflineSyncStatus.syncing:
      bg = Colors.blue.shade50;
      fg = Colors.blue.shade800;
      label = 'Syncing…';
      break;
    case OfflineSyncStatus.failed:
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
      label = 'Sync failed';
      break;
    case OfflineSyncStatus.synced:
    default:
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
      label = 'Synced';
      break;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg),
    ),
  );
}

Widget _buildPreviewOnlyChip(BuildContext context) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      'Not available offline',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade800,
          ),
    ),
  );
}
```

Design intent:

- Chips are small and non-dominant.
- `Pending sync` is warm (orange), `Syncing` is blue, `Failed` is red.
- Preview-only chip is neutral grey to indicate “read-only / limited”.

---

### Step 3: Detail View Status Banner for Queued Memories

**File**: `lib/screens/memory/memory_detail_screen.dart`

When viewing a **queued offline memory**, show a slim banner at the top of the detail screen with its sync status (Phase 1 only applies to queued entries).

Example:

```dart
Widget _buildOfflineQueuedBanner(
  BuildContext context,
  TimelineMoment timelineMoment,
) {
  if (!timelineMoment.isOfflineQueued) {
    return const SizedBox.shrink();
  }

  final status = timelineMoment.offlineSyncStatus;

  late final String title;
  late final String subtitle;
  late final Color background;
  late final Color textColor;

  switch (status) {
    case OfflineSyncStatus.queued:
      title = 'Pending sync';
      subtitle = 'This memory will upload automatically when you\'re online.';
      background = Colors.orange.shade50;
      textColor = Colors.orange.shade900;
      break;
    case OfflineSyncStatus.syncing:
      title = 'Syncing…';
      subtitle = 'We\'re uploading this memory in the background.';
      background = Colors.blue.shade50;
      textColor = Colors.blue.shade900;
      break;
    case OfflineSyncStatus.failed:
      title = 'Sync failed';
      subtitle = 'We\'ll retry automatically. You can also try again later.';
      background = Colors.red.shade50;
      textColor = Colors.red.shade900;
      break;
    case OfflineSyncStatus.synced:
    default:
      return const SizedBox.shrink();
  }

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: background,
      border: Border(
        bottom: BorderSide(color: textColor.withOpacity(0.25)),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600, color: textColor),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: textColor),
        ),
      ],
    ),
  );
}
```

Integrate in the detail screen layout:

```dart
Column(
  children: [
    _buildOfflineQueuedBanner(context, timelineMoment),
    Expanded(child: _buildMemoryContent(detail)),
  ],
);
```

Note:

- This banner is **only** for queued offline memories.  
  Preview-only memories never reach this screen while offline in Phase 1.

---

### Step 4: Disable/Explain Sharing for Queued Offline Memories

**File**: `lib/screens/memory/memory_detail_screen.dart`

Clarify that queued offline memories cannot be shared until they sync.

Example AppBar actions:

```dart
List<Widget> _buildActions(
  BuildContext context,
  MemoryDetail detail,
  bool isQueuedOffline,
) {
  final actions = <Widget>[];

  // Edit: always allowed for queued offline memories.
  actions.add(
    IconButton(
      icon: const Icon(Icons.edit),
      onPressed: () => isQueuedOffline
          ? _handleEditOffline(context, detail)
          : _handleEditOnline(context, detail),
    ),
  );

  // Share: only when not queued offline.
  if (isQueuedOffline) {
    actions.add(
      IconButton(
        icon: const Icon(Icons.share),
        onPressed: null,
        tooltip: 'Share available after this memory syncs',
        color: Colors.grey,
      ),
    );
  } else {
    actions.add(
      IconButton(
        icon: const Icon(Icons.share),
        onPressed: () => _handleShare(context, detail),
      ),
    );
  }

  return actions;
}
```

This is a small but clear signal that queued memories are “local-only” until sync completes.

---

### Step 5: Offline Timeline Empty/Edge States

**File**: `lib/screens/timeline/unified_timeline_screen.dart`

Because Phase 1 introduces a preview index, the **typical** offline timeline is **not empty**:

- It still shows previously-synced memories as preview-only cards.
- It also shows queued offline memories.

However, there are genuine edge cases where the offline list might be empty:

- A **brand-new user** with no synced or queued memories.
- The preview index has been cleared and there are no queued items.

Handle that case with a friendly empty state:

```dart
Widget _buildBody(BuildContext context, UnifiedFeedViewState state) {
  if (state.state == UnifiedFeedState.loading) {
    return const Center(child: CircularProgressIndicator());
  }

  if (state.memories.isEmpty) {
    if (state.isOffline) {
      return _OfflineEmptyTimelineMessage();
    }
    return _OnlineEmptyTimelineMessage();
  }

  // Normal list rendering...
}
```

Offline empty message:

```dart
class _OfflineEmptyTimelineMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'You\'re offline',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'New memories you capture will appear here and sync when you\'re back online.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### Step 6: Accessibility & Visual Consistency

Throughout the above UI changes:

- **Color choices**:
  - Pending/queued: orange/yellow tones.
  - Syncing: blue.
  - Failed: red.
  - Preview-only: neutral greys.
- **Contrast**:
  - Ensure badges, banners, and chips meet accessibility contrast guidelines.
  - Pair color with icons and/or text so state is not conveyed by color alone.
- **Copy**:
  - Keep strings short, positive, and descriptive:
    - “Pending sync”
    - “This memory will upload automatically when you’re online.”
    - “Not available offline”

You can consolidate these strings into the app’s localization structure as needed.

---

## Files to Create/Modify

### Files to Modify

- `lib/widgets/memory_card.dart`
  - Card-level states for:
    - queued offline memories,
    - preview-only offline memories.
  - Status chips/badges for `offlineSyncStatus` and preview-only.
- `lib/screens/memory/memory_detail_screen.dart`
  - Offline-queued status banner.
  - Disabled share button for queued offline memories.
- `lib/screens/timeline/unified_timeline_screen.dart`
  - Offline empty/edge state messaging.

### Files to Create

- None required; this phase mainly refines existing UI components.

---

## Success Criteria

- **Queued offline memories**
  - [ ] Clearly distinguished in the timeline (border/badge) and detail view (status banner).
  - [ ] Always tappable and editable offline.
  - [ ] Display intuitive “Pending sync” / “Syncing” / “Failed” states.
- **Preview-only memories**
  - [ ] Remain visible offline to keep the timeline full.
  - [ ] Are greyed / visually de-emphasized and not openable offline.
  - [ ] Show unobtrusive “Not available offline” copy when tapped.
- **Overall behaviour**
  - [ ] When going offline, the timeline remains populated via preview index + queued items (no “offline = empty” collapse).
  - [ ] Visual treatments are consistent, accessible, and aligned with copy in the README and roadmap (“Offline Timeline Preview & Offline Editing”).

With Phase 6 complete, Phase 1 offline support is ready for handoff: users can see a **full preview timeline** while offline, clearly understand what is and isn’t available offline, and confidently capture/edit queued memories that will sync later.


