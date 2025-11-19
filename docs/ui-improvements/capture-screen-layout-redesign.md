# Capture Screen Layout Redesign

## Overview
Redesign the capture screen to optimize vertical space usage and improve ergonomics by placing the primary input control at the bottom for better thumb reach, while maintaining all functionality without requiring scrolling.

## Key Changes
1. Remove "Capture Memory" title from AppBar
2. Replace Tag/Video/Photo outlined buttons with icon-only buttons
3. Combine media thumbnails and tag chips into single horizontal scrollable strip
4. Reorder layout: place main input area (text/mic) at bottom for better ergonomics
5. Group media action buttons with their display section
6. Tighten spacing throughout

## New Layout Structure

```
┌─────────────────────────────────────┐
│ [Moment] [Story] [Memento]          │ ← Memory type tabs (unchanged)
│                                     │   
│                   12px gap          │
│                                     │
├─────────────────────────────────────┤
│         [#] [📹] [📷]               │ ← Icon-only action buttons (centered)
│                                     │
│                   8px gap           │
│                                     │
│  [🖼️][🖼️][#tag][#tag]...          │ ← Horizontal scroll (only if items exist)
│                                     │
│                  16px gap           │
│                                     │
├─────────────────────────────────────┤
│                                     │
│     [Large Text Input Area]         │ ← Main capture area (MOVED TO BOTTOM)
│     [Mic Button / TextField]        │   Same height as current implementation
│                                     │   Best thumb reach for primary action
│     [Tap to talk / Swipe hints]    │
│                                     │
│                  12px gap           │
│                                     │
├─────────────────────────────────────┤
│            [Save]                   │ ← Save button (unchanged)
└─────────────────────────────────────┘
```

## Detailed Implementation Steps

### 1. Remove AppBar Title
**File:** `lib/screens/capture/capture_screen.dart`
**Lines:** ~442-445

**Current:**
```dart
appBar: AppBar(
  title: const Text('Capture Memory'),
  centerTitle: true,
),
```

**New:**
```dart
appBar: AppBar(
  // Title removed to save vertical space
),
```

### 2. Replace Action Buttons with Icon-Only Buttons
**File:** `lib/screens/capture/capture_screen.dart`
**Lines:** ~470-525 (replace entire Row section)

**Current:** Three full-width OutlinedButton.icon widgets
**New:** Three compact IconButton widgets centered in a Row

```dart
// Compact icon-only action buttons (centered)
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    _CompactIconButton(
      icon: Icons.tag,
      label: 'Add tag',
      onPressed: _handleAddTag,
    ),
    const SizedBox(width: 24),
    _CompactIconButton(
      icon: Icons.videocam,
      label: 'Add video',
      onPressed: state.canAddVideo ? _handleAddVideo : null,
    ),
    const SizedBox(width: 24),
    _CompactIconButton(
      icon: Icons.photo_camera,
      label: 'Add photo',
      onPressed: state.canAddPhoto ? _handleAddPhoto : null,
    ),
  ],
),
```

### 3. Create New Compact Icon Button Widget
**File:** `lib/screens/capture/capture_screen.dart`
**Location:** Add after `_AddTagDialog` class (before end of file)

```dart
/// Compact icon button for media and tag actions
class _CompactIconButton extends StatelessWidget {
  final IconData icon;
  final String label; // For accessibility only
  final VoidCallback? onPressed;

  const _CompactIconButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    
    return Semantics(
      label: label,
      button: true,
      enabled: isEnabled,
      child: IconButton(
        icon: Icon(icon),
        iconSize: 24,
        onPressed: onPressed,
        color: isEnabled
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
```

### 4. Unify Media and Tags Display
**File:** `lib/screens/capture/capture_screen.dart`
**Lines:** ~547-582 (replace entire media tray and tags section)

**Replace:**
- Separate `MediaTray` widget
- Separate `Wrap` widget for tags

**With:**
```dart
// Unified media + tags strip (only show if items exist)
if (state.photoPaths.isNotEmpty || 
    state.videoPaths.isNotEmpty || 
    state.tags.isNotEmpty) ...[
  const SizedBox(height: 8),
  SizedBox(
    height: 64,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      children: [
        // Photo thumbnails
        for (int i = 0; i < state.photoPaths.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _MediaThumbnailCompact(
              path: state.photoPaths[i],
              isVideo: false,
              onRemove: () => notifier.removePhoto(i),
            ),
          ),
        // Video thumbnails
        for (int i = 0; i < state.videoPaths.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _MediaThumbnailCompact(
              path: state.videoPaths[i],
              isVideo: true,
              onRemove: () => notifier.removeVideo(i),
            ),
          ),
        // Tag chips
        for (int i = 0; i < state.tags.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InputChip(
              label: Text(state.tags[i]),
              onDeleted: () => notifier.removeTag(i),
              deleteIcon: const Icon(Icons.close, size: 18),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    ),
  ),
],
```

### 5. Create Compact Media Thumbnail Widget
**File:** `lib/screens/capture/capture_screen.dart`
**Location:** Add after `_CompactIconButton` class

```dart
/// Compact media thumbnail for the horizontal strip
class _MediaThumbnailCompact extends StatelessWidget {
  final String path;
  final bool isVideo;
  final VoidCallback onRemove;

  const _MediaThumbnailCompact({
    required this.path,
    required this.isVideo,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                isVideo ? Icons.videocam : Icons.photo,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        // Video indicator
        if (isVideo)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.play_arrow,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        // Remove button
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

### 6. Reorder Main Content Layout
**File:** `lib/screens/capture/capture_screen.dart`
**Lines:** ~454-586 (restructure the Column children)

**Current Order:**
1. Memory type toggles
2. Expanded (with text input centered)
3. Media tray and tags

**New Order:**
1. Memory type toggles
2. Action buttons (Tag/Video/Photo)
3. Media + tags strip
4. Expanded (with text input - moves to bottom)

**New Structure:**
```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    // 1. Memory type toggles at top
    _MemoryTypeToggle(
      selectedType: state.memoryType,
      onTypeChanged: (type) => notifier.setMemoryType(type),
    ),
    const SizedBox(height: 12),
    
    // 2. Compact action buttons (Tag/Video/Photo)
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CompactIconButton(
          icon: Icons.tag,
          label: 'Add tag',
          onPressed: _handleAddTag,
        ),
        const SizedBox(width: 24),
        _CompactIconButton(
          icon: Icons.videocam,
          label: 'Add video',
          onPressed: state.canAddVideo ? _handleAddVideo : null,
        ),
        const SizedBox(width: 24),
        _CompactIconButton(
          icon: Icons.photo_camera,
          label: 'Add photo',
          onPressed: state.canAddPhoto ? _handleAddPhoto : null,
        ),
      ],
    ),
    
    // 3. Unified media + tags strip (only if items exist)
    if (state.photoPaths.isNotEmpty || 
        state.videoPaths.isNotEmpty || 
        state.tags.isNotEmpty) ...[
      const SizedBox(height: 8),
      SizedBox(
        height: 64,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          children: [
            // Photo thumbnails
            for (int i = 0; i < state.photoPaths.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _MediaThumbnailCompact(
                  path: state.photoPaths[i],
                  isVideo: false,
                  onRemove: () => notifier.removePhoto(i),
                ),
              ),
            // Video thumbnails
            for (int i = 0; i < state.videoPaths.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _MediaThumbnailCompact(
                  path: state.videoPaths[i],
                  isVideo: true,
                  onRemove: () => notifier.removeVideo(i),
                ),
              ),
            // Tag chips
            for (int i = 0; i < state.tags.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InputChip(
                  label: Text(state.tags[i]),
                  onDeleted: () => notifier.removeTag(i),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
      ),
    ],
    const SizedBox(height: 16),
    
    // 4. Main capture area (text input / mic) - NOW AT BOTTOM
    Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end, // Pin to bottom
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Swipeable input container (dictation and type modes)
          _SwipeableInputContainer(
            inputMode: state.inputMode,
            memoryType: state.memoryType,
            isDictating: state.isDictating,
            transcript: state.inputText ?? '',
            elapsedDuration: state.elapsedDuration,
            errorMessage: state.errorMessage,
            descriptionController: _descriptionController,
            onInputModeChanged: (mode) => notifier.setInputMode(mode),
            onStartDictation: () => notifier.startDictation(),
            onStopDictation: () => notifier.stopDictation(),
            onCancelDictation: () => notifier.cancelDictation(),
            onTextChanged: (value) => notifier
                .updateInputText(value.isEmpty ? null : value),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  ],
),
```

### 7. Update Spacing in _SwipeableInputContainer
**File:** `lib/screens/capture/capture_screen.dart`
**No structural changes needed** - the input container itself remains unchanged. The repositioning happens in the parent layout.

## Spacing Specifications

| Section | Spacing |
|---------|---------|
| Memory tabs → Action buttons | 12px |
| Action buttons → Media strip | 8px |
| Media strip → Input area | 16px |
| Input area → Save button | 12px (already handled by existing container padding) |
| Between icon buttons | 24px |

## Import Requirements

Add to top of file if not already present:
```dart
import 'dart:io'; // For File class in thumbnails
```

## Testing Checklist

- [ ] AppBar has no title
- [ ] Action buttons are icon-only and centered
- [ ] Media thumbnails and tags appear in single horizontal scrollable row
- [ ] Input area is at bottom, above Save button
- [ ] All items (photos, videos, tags) display correctly in unified strip
- [ ] Keyboard behavior works correctly in type mode (content scrolls above keyboard)
- [ ] Mic button is easily reachable with thumb in dictation mode
- [ ] No scrolling required to access any controls or see added items
- [ ] Visual hierarchy is clear: type selection → enhancements → main input → save
- [ ] Remove buttons work on media thumbnails
- [ ] Tag deletion works in unified strip
- [ ] All existing functionality preserved

## Expected Vertical Space Savings
- AppBar title removal: ~20px
- Action buttons (44px → 40px): ~4px
- Tighter spacing: ~12px
- **Total: ~36px saved**

## Notes
- The main input container (`_SwipeableInputContainer`) remains unchanged internally
- Media thumbnails use existing `MediaTray` logic but rendered differently
- All existing state management and handlers remain unchanged
- Keyboard overlay will naturally push content up when TextField is focused in type mode

## Additional UI Improvement: Bottom Navigation Bar
**Issue:** There's excessive dead space beneath the Capture/Timeline/Settings buttons in the bottom persistent navigation menu.

**Action Required:** Reduce the vertical padding/spacing in the bottom navigation bar to eliminate wasted space. This will provide a few extra pixels of usable screen space for the capture content area.

**Location:** Check the bottom navigation implementation (likely in main app scaffold or navigation shell) and reduce bottom padding/margin.

