import 'package:shared_preferences/shared_preferences.dart';
import 'package:memories/models/memory_type.dart';

/// Service for persisting the selected memory types in the unified feed
class UnifiedFeedTabPersistenceService {
  static const String _selectedTypesKey = 'unified_feed_selected_types';
  static const Set<MemoryType> _defaultSelectedTypes = {
    MemoryType.story,
    MemoryType.moment,
    MemoryType.memento,
  };

  /// Get the selected memory types
  /// 
  /// Returns default set (all three types) if no preference was saved
  Future<Set<MemoryType>> getSelectedTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final typesList = prefs.getStringList(_selectedTypesKey);
    
    if (typesList == null || typesList.isEmpty) {
      return _defaultSelectedTypes;
    }
    
    return typesList
        .map((value) => MemoryTypeExtension.fromApiValue(value))
        .toSet();
  }

  /// Save the selected memory types
  /// 
  /// [selectedTypes] is the set of memory types to show
  Future<void> saveSelectedTypes(Set<MemoryType> selectedTypes) async {
    final prefs = await SharedPreferences.getInstance();
    final typesList = selectedTypes.map((type) => type.apiValue).toList();
    await prefs.setStringList(_selectedTypesKey, typesList);
  }

  /// Clear the saved preference (resets to default)
  Future<void> clearSavedTab() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedTypesKey);
  }
}

