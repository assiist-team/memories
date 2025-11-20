# Timeline Header Stacking Issue

**Date:** 2025-01-17  
**Status:** 🔴 Unresolved  
**Issue:** Month headers in timeline view are stacking instead of replacing each other

## Problem Description

When scrolling through the timeline, month headers (e.g., "November 2025", "December 2025") are stacking on top of each other instead of replacing each other. This causes the screen to fill up with header text and content disappears, making the timeline unusable.

**Expected Behavior:** Only ONE month header should be sticky at a time. As you scroll, when a new month header reaches the top, it should replace the previous sticky header.

**Current Behavior:** All month headers that have scrolled past remain pinned/sticky, causing them to stack vertically.

## Root Cause

The timeline uses `SliverPersistentHeader` widgets with `pinned: true` for each month header. In Flutter, when multiple `SliverPersistentHeader` widgets with `pinned: true` are used, they all stick to the top and stack on top of each other. This is the default behavior of Flutter's sliver system.

## Attempted Solutions

### Attempt 1: Using `overlapAbsorb` Property
**What was tried:**
- Added `overlapAbsorb` getter to `TimelineHeader` delegate
- Set `overlapAbsorb: true` for month headers

**Why it failed:**
- `overlapAbsorb` is not a valid property/method on `SliverPersistentHeaderDelegate`
- Linter error: "The getter doesn't override an inherited getter"
- This property doesn't exist in Flutter's API

**Code attempted:**
```dart
@override
bool get overlapAbsorb => level == TimelineHeaderLevel.month;
```

### Attempt 2: Making Background Fully Opaque
**What was tried:**
- Changed header background from `scaffoldBackgroundColor` to `scaffoldBackgroundColor.withOpacity(1.0)`
- Attempted to make headers fully opaque so they would visually cover each other

**Why it failed:**
- This doesn't actually prevent stacking - headers still stack, they just have opaque backgrounds
- The underlying issue (multiple pinned headers) remains unchanged

### Attempt 3: Single Dynamic Sticky Header
**What was tried:**
- Made all month headers non-pinned (`pinned: false`)
- Created a single sticky header at the top of the `CustomScrollView`
- Attempted to track scroll position and dynamically update the sticky header content to show the current month
- Used `GlobalKey` to track month header positions
- Implemented `_updateActiveMonth()` method to determine which month should be shown

**Why it failed:**
- Only the first header sticks (the one at the top of the list)
- The dynamic update mechanism doesn't work properly - the sticky header doesn't update as you scroll
- Month headers that scroll past are no longer visible (they're not sticky)
- The tracking mechanism using `GlobalKey` and scroll position calculation is unreliable

**Code structure:**
```dart
// Single sticky header at top
if (_activeMonth != null && _activeMonthYear != null)
  SliverPersistentHeader(
    pinned: true,
    delegate: TimelineHeader(...),
  ),

// Regular month headers (not pinned)
SliverToBoxAdapter(
  key: _monthKeys[monthKey],
  child: _buildMonthHeaderWidget(month, year),
),
```

### Attempt 4: Two-Column Layout with Year Sidebar
**What was tried:**
- Created a two-column layout with year sidebar (60px) on left
- Removed season and year headers from timeline
- Changed grouping from `Year → Season → Month` to `Year → Month`
- Month headers show "Month Year" format

**Status:** Partially implemented but header stacking issue remains unresolved

## Current State

- ✅ Two-column layout implemented (year sidebar + timeline)
- ✅ Season headers removed
- ✅ Year headers removed from timeline (shown in sidebar)
- ✅ Month headers show "Month Year" format
- ⚠️ **TEMPORARY FIX:** Sticky headers disabled to prevent stacking
- ⚠️ Month headers now scroll normally (not sticky) - no stacking occurs
- ❌ Header stacking issue NOT resolved (workaround applied)
- ❌ Sticky header functionality disabled until proper solution is found

## Important Notes

### Why `floating: true` Won't Work

**DO NOT USE `floating: true`** for headers because:
- Headers with `floating: true` will NOT stick - they scroll away with content
- The requirement is that headers MUST stick (remain visible at top while scrolling)
- `floating: true` is the opposite of what we need

### Flutter Sliver Behavior

Flutter's `SliverPersistentHeader` with `pinned: true`:
- Each header with `pinned: true` will stick to the top
- Multiple pinned headers will stack vertically
- There's no built-in way to make headers "replace" each other
- This is a limitation of Flutter's sliver system

## Potential Solutions to Explore

### Option 1: Custom Sliver Implementation
- Create a custom sliver that manages a single sticky header
- Track scroll position to determine which month should be sticky
- Dynamically update the sticky header content
- **Challenge:** Requires complex scroll position tracking and layout calculations

### Option 2: Use `SliverAppBar` Pattern
- Use a single `SliverAppBar` or similar widget at the top
- Track which month section is currently visible
- Update the app bar title/content dynamically
- **Challenge:** May not provide the same visual appearance as headers

### Option 3: Manual Header Management
- Don't use `SliverPersistentHeader` for month headers
- Use regular widgets for month headers
- Implement custom sticky behavior using `Stack` and `Positioned` widgets
- Track scroll position and manually position a single sticky header
- **Challenge:** Complex implementation, may have performance issues

### Option 4: Third-Party Package
- Look for Flutter packages that provide "replacing sticky headers" functionality
- May need to implement custom solution if no package exists

## Related Files

- `lib/widgets/timeline_header.dart` - Header delegate and widgets
- `lib/widgets/memory_header.dart` - Memory-specific header wrappers
- `lib/screens/timeline/unified_timeline_screen.dart` - Timeline screen implementation
- `lib/widgets/year_sidebar.dart` - Year navigation sidebar

## Temporary Workaround (Current State)

**Status:** Sticky headers have been disabled to prevent stacking.

**Implementation:**
- All month headers use `SliverToBoxAdapter` (not pinned)
- Headers scroll normally with content
- No sticky behavior = no stacking
- Year sidebar still functional for navigation

**Trade-offs:**
- ✅ No stacking issue
- ✅ Timeline is usable
- ❌ No sticky month headers (less context while scrolling)
- ❌ Users must scroll to see which month they're viewing

## Next Steps

1. Research Flutter sliver system limitations and workarounds
2. Consider implementing Option 1 (Custom Sliver Implementation)
3. Test with a simpler approach: single sticky header that updates based on scroll position
4. May need to file a Flutter issue or use a workaround
5. **Priority:** Find a solution that allows sticky headers without stacking

## References

- Flutter `SliverPersistentHeader` documentation
- Flutter sliver system architecture
- Custom sliver implementations

