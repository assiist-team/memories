import 'package:memories/models/memory_type.dart';

/// Model representing a lightweight preview entry for a memory in the local preview index.
///
/// The preview index is a local store that holds only the data required to render
/// a card when offline. It is populated/refreshed when the app is online and reading
/// from Supabase.
///
/// This model is intentionally small:
/// - No media URLs or blobs.
/// - No full text bodies.
/// - Just enough to keep the unified timeline useful when offline.
class LocalMemoryPreview {
  /// Server ID for the synced memory
  final String serverId;

  /// Memory type (moment, story, or memento)
  final MemoryType memoryType;

  /// Title or first line of text for display
  final String titleOrFirstLine;

  /// Capture timestamp (for ordering)
  final DateTime capturedAt;

  /// Lightweight flag used in Phase 1.
  /// False for Phase 1 except queued memories mapped via adapter.
  final bool isDetailCachedLocally;

  LocalMemoryPreview({
    required this.serverId,
    required this.memoryType,
    required this.titleOrFirstLine,
    required this.capturedAt,
    this.isDetailCachedLocally = false,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'server_id': serverId,
      'memory_type': memoryType.apiValue,
      'title_or_first_line': titleOrFirstLine,
      'captured_at': capturedAt.toIso8601String(),
      'is_detail_cached_locally': isDetailCachedLocally,
    };
  }

  /// Create from JSON
  factory LocalMemoryPreview.fromJson(Map<String, dynamic> json) {
    return LocalMemoryPreview(
      serverId: json['server_id'] as String,
      memoryType: MemoryTypeExtension.fromApiValue(
        json['memory_type'] as String? ?? 'moment',
      ),
      titleOrFirstLine: json['title_or_first_line'] as String,
      capturedAt: DateTime.parse(json['captured_at'] as String),
      isDetailCachedLocally: json['is_detail_cached_locally'] as bool? ?? false,
    );
  }

  /// Create a copy with updated fields
  LocalMemoryPreview copyWith({
    String? serverId,
    MemoryType? memoryType,
    String? titleOrFirstLine,
    DateTime? capturedAt,
    bool? isDetailCachedLocally,
  }) {
    return LocalMemoryPreview(
      serverId: serverId ?? this.serverId,
      memoryType: memoryType ?? this.memoryType,
      titleOrFirstLine: titleOrFirstLine ?? this.titleOrFirstLine,
      capturedAt: capturedAt ?? this.capturedAt,
      isDetailCachedLocally: isDetailCachedLocally ?? this.isDetailCachedLocally,
    );
  }
}

