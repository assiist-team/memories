import 'package:memories/models/local_memory_preview.dart';
import 'package:memories/models/memory_type.dart';

/// Abstract interface for storing and retrieving local memory preview entries.
///
/// The preview index is a local store that holds only the data required to render
/// a card when offline. It is populated/refreshed when the app is online and reading
/// from Supabase.
///
/// Phase 1 does not dictate the storage technology—this is just an interface.
/// Implementations could use SQLite, Hive, SharedPreferences, or any other
/// local storage mechanism.
///
/// Phase 1 constraint: The store holds only preview-level metadata. It must not
/// start pre-downloading or caching large bodies/media; that belongs in Phase 2.
abstract class LocalMemoryPreviewStore {
  /// Upsert a batch of preview entries derived from the latest online feed page.
  ///
  /// This should be called when the app is online and fetching from Supabase.
  /// The preview entries allow the timeline to remain populated when offline.
  ///
  /// [previews] - List of preview entries to upsert
  Future<void> upsertPreviews(List<LocalMemoryPreview> previews);

  /// Read a window of preview entries for the unified feed.
  ///
  /// This is the primary entry point for offline timeline rendering.
  ///
  /// [filters] - Optional set of memory types to filter by
  /// [limit] - Maximum number of entries to return (default: 50)
  ///
  /// Returns a list of preview entries, ordered by capturedAt descending
  Future<List<LocalMemoryPreview>> fetchPreviews({
    Set<MemoryType>? filters,
    int limit = 50,
  });

  /// Clear all preview entries.
  ///
  /// Used for logout / account switch scenarios.
  Future<void> clear();
}

