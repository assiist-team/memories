# Phase 8: Sync Service Renaming (MomentSyncService → MemorySyncService)

## Objective

Rename `MomentSyncService` to `MemorySyncService` to accurately reflect that it handles syncing for all memory types (Moments and Mementos), not just Moments. Note that Stories have a separate sync service that needs to be implemented (see story syncing todo).

## Current State

- Service class: `MomentSyncService` in `lib/services/moment_sync_service.dart`
- Provider: `momentSyncServiceProvider` (generated)
- File: `moment_sync_service.g.dart` (generated)
- Used by: `SyncServiceInitializer` widget
- Handles: Syncing queued moments and mementos from `OfflineQueueService`

## Target State

- Service class: `MemorySyncService` in `lib/services/memory_sync_service.dart`
- Provider: `memorySyncServiceProvider` (generated)
- File: `memory_sync_service.g.dart` (generated)
- All references updated throughout codebase
- Method names updated to reflect "memory" terminology where appropriate

## Implementation Steps

### Step 1: Rename Service Class and File
**Action**: Rename file and update class name

**File**: `lib/services/moment_sync_service.dart` → `lib/services/memory_sync_service.dart`

**Changes**:
1. Rename class `MomentSyncService` → `MemorySyncService`
2. Update `part` directive: `part 'memory_sync_service.g.dart';`
3. Update provider function name: `momentSyncService` → `memorySyncService`
4. Update provider annotation: `@riverpod MemorySyncService memorySyncService(...)`
5. Update type references: `MomentSyncServiceRef` → `MemorySyncServiceRef`

### Step 2: Update Method Names/Comments
**File**: `lib/services/memory_sync_service.dart`

**Changes**:
1. Update method name: `syncQueuedMoments()` → `syncQueuedMemories()` (or keep as `syncQueuedMoments` for backward compatibility? Check usage)
2. Update method name: `syncMoment()` → `syncMemory()` (or keep as `syncMoment`?)
3. Update method documentation to reference "memory" instead of "moment" where appropriate
4. Update comments throughout file
5. Update variable names: `momentsToSync` → `memoriesToSync`, `queuedMoment` → `queuedMemory`

**Decision**: Check if `syncQueuedMoments()` and `syncMoment()` are called from many places. If so, consider:
- Option A: Rename to `syncQueuedMemories()` and `syncMemory()` and update all call sites
- Option B: Keep old names as aliases, add new names that call them (deprecated approach)
- **Recommendation**: Option A - clean rename, update all call sites

### Step 3: Regenerate Generated File
**Action**: Run code generation

**Command**: `dart run build_runner build --delete-conflicting-outputs`

**Result**: New file `memory_sync_service.g.dart` with `memorySyncServiceProvider`

### Step 4: Update All Usages
**Files to search and update**:

1. **Sync Service Initializer**:
   - `lib/widgets/sync_service_initializer.dart`
   - Update import: `moment_sync_service.dart` → `memory_sync_service.dart`
   - Update provider reference: `momentSyncServiceProvider` → `memorySyncServiceProvider`
   - Update comments to reference "memories" instead of "moments"

2. **Any other services/widgets**:
   - Search codebase for `momentSyncServiceProvider`
   - Update all references

### Step 5: Update Tests
**Files**:
- `test/services/moment_sync_service_test.dart` → `test/services/memory_sync_service_test.dart` (if exists)

**Changes**:
1. Rename test file if it exists
2. Update imports
3. Update provider references in tests
4. Update class name references in test descriptions
5. Update any mock/service variable names

### Step 6: Update Documentation/Comments
**Files**: Any documentation that references the service

**Changes**:
- Update references from "MomentSyncService" to "MemorySyncService"
- Update comments in `SyncServiceInitializer` to mention "memories" instead of "moments"
- Update any architecture diagrams or docs

## Files to Modify

1. `lib/services/moment_sync_service.dart` → `lib/services/memory_sync_service.dart` (rename + update)
2. `lib/widgets/sync_service_initializer.dart`
3. `test/services/moment_sync_service_test.dart` → `test/services/memory_sync_service_test.dart` (if exists)
4. Any other files referencing `momentSyncServiceProvider` (search codebase)

## Search Patterns

Use these patterns to find all references:

```bash
# Find provider references
grep -r "momentSyncServiceProvider" lib/ test/

# Find class references
grep -r "MomentSyncService" lib/ test/

# Find file imports
grep -r "moment_sync_service" lib/ test/

# Find method calls
grep -r "syncQueuedMoments\|syncMoment" lib/ test/
```

## Risk Assessment

**Risk Level**: Low
- Mostly find/replace operation
- No logic changes
- Easy to verify with tests
- Easy to rollback

**Potential Issues**:
- Missing a reference somewhere (mitigated by thorough search)
- Generated file conflicts (handled by build_runner --delete-conflicting-outputs)
- Method name changes might require updating call sites

## Testing Strategy

1. **Compile Check**: Ensure code compiles after rename
2. **Unit Tests**: Run all service tests (if they exist)
3. **Integration Tests**: Test offline queue → sync flow for moments and mementos
4. **Manual QA**: 
   - Queue a Moment offline
   - Queue a Memento offline
   - Verify both sync when connectivity is restored
   - Verify sync service initializes correctly

## Success Criteria

- [ ] Service class renamed to `MemorySyncService`
- [ ] File renamed to `memory_sync_service.dart`
- [ ] Provider renamed to `memorySyncServiceProvider`
- [ ] Generated file updated
- [ ] Method names updated (if decided)
- [ ] All references updated throughout codebase
- [ ] All tests pass
- [ ] No regressions in sync functionality
- [ ] Sync works for both moments and mementos

## Dependencies

- **Independent**: Can be done at any time, doesn't depend on other phases
- **Related**: Should be done before implementing story sync service to maintain consistency

## Rollback Plan

If issues arise:
1. Revert file rename
2. Revert class name changes
3. Regenerate old file
4. Revert all reference updates

## Notes

- This is a straightforward rename operation
- Consider using IDE refactoring tools for safety
- Double-check generated file is updated correctly
- Verify no hardcoded strings reference old name (e.g., in error messages)
- Note that Stories will have a separate sync service (see story syncing todo document)

