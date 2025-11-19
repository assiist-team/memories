import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/services/unified_feed_tab_persistence_service.dart';

part 'unified_feed_tab_provider.g.dart';

/// Provider for unified feed tab persistence service
@riverpod
UnifiedFeedTabPersistenceService unifiedFeedTabPersistenceService(
    UnifiedFeedTabPersistenceServiceRef ref) {
  return UnifiedFeedTabPersistenceService();
}

/// Provider for the selected memory types in unified feed
/// 
/// Manages the current filter selection (set of memory types) and persists it to SharedPreferences.
/// Defaults to all three memory types selected.
@riverpod
class UnifiedFeedTabNotifier extends _$UnifiedFeedTabNotifier {
  @override
  Future<Set<MemoryType>> build() async {
    // Restore last selected types on init
    final service = ref.read(unifiedFeedTabPersistenceServiceProvider);
    return await service.getSelectedTypes();
  }

  /// Set the selected memory types and persist them
  /// 
  /// [selectedTypes] is the set of memory types to show
  Future<void> setSelectedTypes(Set<MemoryType> selectedTypes) async {
    final previousTypes = state.valueOrNull ?? {};
    state = AsyncValue.data(selectedTypes);
    final service = ref.read(unifiedFeedTabPersistenceServiceProvider);
    await service.saveSelectedTypes(selectedTypes);
    
    // Track tab switch analytics (compare previous and current selections)
    // For simplicity, we'll track when the selection changes
    if (previousTypes != selectedTypes) {
      // Note: Analytics might need updating to handle Set<MemoryType>
      // For now, we'll skip analytics or track a simplified version
    }
  }

  /// Clear the saved preference (resets to default: all three types)
  Future<void> clearTab() async {
    final defaultTypes = {
      MemoryType.story,
      MemoryType.moment,
      MemoryType.memento,
    };
    state = AsyncValue.data(defaultTypes);
    final service = ref.read(unifiedFeedTabPersistenceServiceProvider);
    await service.clearSavedTab();
  }
}

