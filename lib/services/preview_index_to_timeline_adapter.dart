import 'package:memories/models/local_memory_preview.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/models/timeline_memory.dart';

/// Adapter service that converts LocalMemoryPreview rows into TimelineMemory
/// entries suitable for rendering in the timeline when the app is offline.
///
/// Key responsibilities:
/// - Mark entries as preview-only when offline
/// - Ensure they appear in the correct order alongside queued offline memories
/// - Make it clear to the UI that full detail is not available offline in Phase 1
class PreviewIndexToTimelineAdapter {
  /// Convert a LocalMemoryPreview to a TimelineMemory
  static TimelineMemory fromPreview(LocalMemoryPreview preview) {
    // Use memoryDate from preview (now stored), fallback to capturedAt for backward compatibility
    final memoryDate = preview.memoryDate;
    final year = memoryDate.year;
    final season = _getSeason(memoryDate.month);
    final month = memoryDate.month;
    final day = memoryDate.day;

    // Determine display title - prefer generatedTitle, then titleOrFirstLine
    final displayTitle = preview.generatedTitle?.isNotEmpty == true
        ? preview.generatedTitle!
        : preview.titleOrFirstLine;

    // Determine snippet text - prefer processedText, then inputText, then titleOrFirstLine
    final snippetText = preview.processedText?.isNotEmpty == true
        ? preview.processedText
        : (preview.inputText?.isNotEmpty == true
            ? preview.inputText
            : preview.titleOrFirstLine);

    return TimelineMemory(
      id: preview.serverId,
      userId: '', // Not available in preview
      title: displayTitle,
      // Use cached text fields if available (Phase 1: text-only caching)
      inputText: preview.inputText,
      processedText: preview.processedText,
      generatedTitle: preview.generatedTitle,
      tags: preview.tags,
      memoryType: preview.memoryType.apiValue,
      capturedAt: preview.capturedAt,
      createdAt: preview.capturedAt, // Use capturedAt as fallback
      memoryDate: memoryDate,
      year: year,
      season: season,
      month: month,
      day: day,
      primaryMedia: null, // Media not cached in Phase 1 (text-only)
      snippetText: snippetText,
      memoryLocationData: preview.memoryLocationData,
      isOfflineQueued: false,
      // Phase 1: Text-cached synced memories are NOT preview-only (they have text cached)
      // isPreviewOnly should be false when isDetailCachedLocally is true
      isPreviewOnly: !preview.isDetailCachedLocally,
      isDetailCachedLocally: preview.isDetailCachedLocally,
      localId: null, // Preview entries don't have local IDs
      serverId: preview.serverId,
      offlineSyncStatus:
          OfflineSyncStatus.synced, // Preview entries are from synced memories
    );
  }

  /// Get season from month
  static String _getSeason(int month) {
    switch (month) {
      case 12:
      case 1:
      case 2:
        return 'Winter';
      case 3:
      case 4:
      case 5:
        return 'Spring';
      case 6:
      case 7:
      case 8:
        return 'Summer';
      case 9:
      case 10:
      case 11:
        return 'Fall';
      default:
        return 'Unknown';
    }
  }
}
