# Moment to Memory Naming Refactor

## Overview

This document tracks all instances where "moment" is used to refer to memories in general, when it should be "memory" since a memory can be a moment, memento, or story. The unified detail screen handles all memory types, so naming should reflect this.

## Refactor Strategy

**Rule**: Use "moment" only when referring specifically to the memory type `'moment'`. Use "memory" for:
- Generic references to any memory (moment, memento, or story)
- Unified screens/services/providers that handle all memory types
- Database IDs and API parameters that can reference any memory type

## File and Directory Renames

### Core Files (High Priority)
- `lib/screens/moment/moment_detail_screen.dart` → `lib/screens/memory/memory_detail_screen.dart`
- `lib/models/moment_detail.dart` → `lib/models/memory_detail.dart`
- `lib/services/moment_detail_service.dart` → `lib/services/memory_detail_service.dart`
- `lib/providers/moment_detail_provider.dart` → `lib/providers/memory_detail_provider.dart`
- `lib/providers/moment_detail_provider.g.dart` → `lib/providers/memory_detail_provider.g.dart`
- `lib/widgets/moment_metadata_section.dart` → `lib/widgets/memory_metadata_section.dart`
- `test/widgets/moment_detail_test.dart` → `test/widgets/memory_detail_test.dart`

### Directory Structure
- `lib/screens/moment/` → `lib/screens/memory/` (if directory only contains detail screen)

## Class and Type Renames

### Models
- `MomentDetail` → `MemoryDetail`
- `MomentDetailResult` → `MemoryDetailResult`

### Services
- `MomentDetailService` → `MemoryDetailService`

### Providers
- `MomentDetailNotifier` → `MemoryDetailNotifier`
- `MomentDetailViewState` → `MemoryDetailViewState`
- `MomentDetailState` enum → `MemoryDetailState` enum
- `momentDetailServiceProvider` → `memoryDetailServiceProvider`
- `momentDetailNotifierProvider` → `memoryDetailNotifierProvider`

### Screens
- `MomentDetailScreen` → `MemoryDetailScreen`
- `_MomentDetailScreenState` → `_MemoryDetailScreenState`

### Widgets
- `MomentMetadataSection` → `MemoryMetadataSection` (if it handles all memory types)

## Variable and Parameter Renames

### Parameters
- `momentId` → `memoryId` (when referring to any memory type)
- `p_moment_id` (RPC parameter) → `p_memory_id`
- `savedMomentId` → `savedMemoryId`
- `serverMomentId` → `serverMemoryId` (in queued models)

### Local Variables
- `_momentId` → `_memoryId` (in providers/services)
- `moment` → `memory` (when the variable can be any memory type)
- `cachedMoment` → `cachedMemory`

### Method Names
- `getMomentDetail()` → `getMemoryDetail()`
- `loadMomentDetail()` → `loadMemoryDetail()`
- `deleteMoment()` → `deleteMemory()` (when it can delete any memory type)
- `_getCachedMomentDetail()` → `_getCachedMemoryDetail()`
- `_cacheMomentDetail()` → `_cacheMemoryDetail()`
- `hasCachedData()` - parameter `momentId` → `memoryId`
- `loadMomentForEdit()` → `loadMemoryForEdit()` (in capture_state_provider)

## Database and API References

### RPC Function Names
- `get_moment_detail()` → `get_memory_detail()` (or keep if backend can't change)

### RPC Parameters
- `p_moment_id` → `p_memory_id`

### Cache Keys
- `moment_detail_cache_` → `memory_detail_cache_`

### Database Columns (if applicable)
- `moment_id` in `media_cleanup_queue` → `memory_id` (already noted in migration comments)

## Comments and Documentation

### Code Comments
- "Moment detail screen" → "Memory detail screen"
- "Moment detail service" → "Memory detail service"
- "Moment detail provider" → "Memory detail provider"
- "Moment detail data" → "Memory detail data"
- "UUID of the moment" → "UUID of the memory" (when generic)
- "Location data for a Moment" → "Location data for a Memory"
- "Model representing detailed Moment data" → "Model representing detailed Memory data"

### Debug Logs
- `[MomentDetail]` → `[MemoryDetail]`
- `[MomentDetailService]` → `[MemoryDetailService]`
- `[MomentDetailNotifier]` → `[MemoryDetailNotifier]`
- "Loading moment detail" → "Loading memory detail"
- "Moment ID" → "Memory ID" (when generic)
- "Parsed X photos for moment" → "Parsed X photos for memory"

## Import Statements

All files importing the renamed files will need updates:
- `import 'package:memories/models/moment_detail.dart'` → `import 'package:memories/models/memory_detail.dart'`
- `import 'package:memories/services/moment_detail_service.dart'` → `import 'package:memories/services/memory_detail_service.dart'`
- `import 'package:memories/providers/moment_detail_provider.dart'` → `import 'package:memories/providers/memory_detail_provider.dart'`
- `import 'package:memories/screens/moment/moment_detail_screen.dart'` → `import 'package:memories/screens/memory/memory_detail_screen.dart'`

### Files with Imports to Update
- `lib/screens/capture/capture_screen.dart`
- `lib/screens/timeline/unified_timeline_screen.dart`
- `lib/screens/timeline/story_timeline_screen.dart`
- `lib/screens/timeline/timeline_screen.dart`
- `lib/widgets/media_preview.dart`
- `lib/widgets/media_strip.dart`
- `lib/widgets/media_carousel.dart`
- `lib/widgets/search_results_list.dart`
- `lib/providers/capture_state_provider.dart`
- `test/integration_test/story_timeline_integration_test.dart`
- `test/integration_test/story_navigation_e2e_test.dart`

## Analytics and Tracking

### Analytics Service Methods
- `trackMomentCardTap()` - parameter `momentId` → `memoryId` (if generic)
- `trackMomentDetailView()` - parameter `momentId` → `memoryId`
- `trackMomentShare()` - parameter `momentId` → `memoryId`
- `trackMomentDetailEdit()` - parameter `momentId` → `memoryId`
- `trackMomentDetailDelete()` - parameter `momentId` → `memoryId`

### Analytics Event Properties
- `'moment_id'` → `'memory_id'` (in analytics payloads)

## Timeline Provider Methods

- `removeMoment()` - parameter `momentId` → `memoryId` (if it handles all memory types)

## Memory Save Service

- `MemorySaveResult.momentId` → `MemorySaveResult.memoryId` (field name)
- Comments referring to "moment" when generic → "memory"

## Queued Models

- `QueuedMoment.serverMomentId` → `QueuedMoment.serverMemoryId` (if it can reference any memory type)

## Test Files

### Test File Updates
- `test/widgets/moment_detail_test.dart` → `test/widgets/memory_detail_test.dart`
- Update all test references to use `MemoryDetail`, `MemoryDetailScreen`, etc.
- Update test method names and variable names

## Edge Cases and Special Considerations

### When to Keep "Moment"
- `MemoryType.moment` enum value (correct - this is the specific type)
- `memoryType == 'moment'` comparisons (correct - checking for specific type)
- "Untitled Moment" fallback text (correct - specific to moment type)
- References to the memory type specifically (not the generic concept)

### Database Table Name
- Table is already `memories` (correct) ✅

### RPC Function Name
- `get_moment_detail()` - May need to keep for backward compatibility if backend can't change immediately. Document that it works for all memory types.

## Implementation Order

1. **Phase 1: Models and Core Types**
   - Rename `MomentDetail` → `MemoryDetail`
   - Rename `MomentDetailResult` → `MemoryDetailResult`
   - Update all references

2. **Phase 2: Services**
   - Rename `MomentDetailService` → `MemoryDetailService`
   - Update method names and parameters
   - Update cache keys

3. **Phase 3: Providers**
   - Rename `MomentDetailNotifier` → `MemoryDetailNotifier`
   - Rename state classes and enums
   - Regenerate provider files

4. **Phase 4: Screens**
   - Rename `MomentDetailScreen` → `MemoryDetailScreen`
   - Move file to new location if needed
   - Update all imports

5. **Phase 5: Widgets**
   - Rename `MomentMetadataSection` → `MemoryMetadataSection` (if applicable)
   - Update all widget references

6. **Phase 6: Tests**
   - Rename test files
   - Update all test references

7. **Phase 7: Analytics and Other Services**
   - Update analytics method parameters
   - Update timeline provider methods
   - Update memory save service references

8. **Phase 8: Documentation and Comments**
   - Update all code comments
   - Update debug logs
   - Update documentation files

## Notes

- This is a breaking change that will require careful coordination
- Consider keeping old names as deprecated aliases during transition if needed
- Update all import statements across the codebase
- Regenerate generated files (`.g.dart`) after provider changes
- Update any external documentation or API contracts
- Consider database migration if RPC function names change

