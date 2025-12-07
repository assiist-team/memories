import 'package:memories/models/memory_type.dart';
import 'package:memories/models/memory_detail.dart';

/// Model representing a preview entry for a memory in the local preview index.
///
/// The preview index is a local store that holds data required to render
/// a card and view detail when offline. It is populated/refreshed when the app
/// is online and reading from Supabase.
///
/// Phase 1: Stores full text fields (input_text, processed_text, generated_title,
/// tags, location metadata) for previously-synced memories, but NOT media files.
/// Media URLs are kept but files are not downloaded.
class LocalMemoryPreview {
  /// Server ID for the synced memory
  final String serverId;

  /// Memory type (moment, story, or memento)
  final MemoryType memoryType;

  /// Title or first line of text for display
  final String titleOrFirstLine;

  /// Capture timestamp (for ordering)
  final DateTime capturedAt;

  /// Memory date (when the memory happened, distinct from capturedAt)
  final DateTime memoryDate;

  /// Lightweight flag used in Phase 1.
  /// True when full text detail is cached locally (text-only caching for synced memories,
  /// or full caching for queued offline memories).
  final bool isDetailCachedLocally;

  /// Full text fields (cached for text-only synced memories)
  final String? inputText;
  final String? processedText;
  final String? generatedTitle;
  final List<String> tags;
  final MemoryLocationData? memoryLocationData;

  LocalMemoryPreview({
    required this.serverId,
    required this.memoryType,
    required this.titleOrFirstLine,
    required this.capturedAt,
    required this.memoryDate,
    this.isDetailCachedLocally = false,
    this.inputText,
    this.processedText,
    this.generatedTitle,
    this.tags = const [],
    this.memoryLocationData,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'server_id': serverId,
      'memory_type': memoryType.apiValue,
      'title_or_first_line': titleOrFirstLine,
      'captured_at': capturedAt.toIso8601String(),
      'memory_date': memoryDate.toIso8601String(),
      'is_detail_cached_locally': isDetailCachedLocally,
      if (inputText != null) 'input_text': inputText,
      if (processedText != null) 'processed_text': processedText,
      if (generatedTitle != null) 'generated_title': generatedTitle,
      if (tags.isNotEmpty) 'tags': tags,
      if (memoryLocationData != null)
        'memory_location_data': memoryLocationData!.toJson(),
    };
  }

  /// Create from JSON
  factory LocalMemoryPreview.fromJson(Map<String, dynamic> json) {
    // Handle backward compatibility: old entries may not have memory_date
    final memoryDate = json['memory_date'] != null
        ? DateTime.parse(json['memory_date'] as String)
        : DateTime.parse(json['captured_at'] as String);

    // Handle backward compatibility: old entries may not have text fields
    final tagsJson = json['tags'] as List<dynamic>?;
    final tags = tagsJson?.map((e) => e.toString()).toList() ?? [];

    MemoryLocationData? memoryLocationData;
    if (json['memory_location_data'] != null) {
      memoryLocationData = MemoryLocationData.fromJson(
        json['memory_location_data'] as Map<String, dynamic>,
      );
    }

    return LocalMemoryPreview(
      serverId: json['server_id'] as String,
      memoryType: MemoryTypeExtension.fromApiValue(
        json['memory_type'] as String? ?? 'moment',
      ),
      titleOrFirstLine: json['title_or_first_line'] as String,
      capturedAt: DateTime.parse(json['captured_at'] as String),
      memoryDate: memoryDate,
      isDetailCachedLocally: json['is_detail_cached_locally'] as bool? ?? false,
      inputText: json['input_text'] as String?,
      processedText: json['processed_text'] as String?,
      generatedTitle: json['generated_title'] as String?,
      tags: tags,
      memoryLocationData: memoryLocationData,
    );
  }

  /// Create a copy with updated fields
  LocalMemoryPreview copyWith({
    String? serverId,
    MemoryType? memoryType,
    String? titleOrFirstLine,
    DateTime? capturedAt,
    DateTime? memoryDate,
    bool? isDetailCachedLocally,
    String? inputText,
    String? processedText,
    String? generatedTitle,
    List<String>? tags,
    MemoryLocationData? memoryLocationData,
  }) {
    return LocalMemoryPreview(
      serverId: serverId ?? this.serverId,
      memoryType: memoryType ?? this.memoryType,
      titleOrFirstLine: titleOrFirstLine ?? this.titleOrFirstLine,
      capturedAt: capturedAt ?? this.capturedAt,
      memoryDate: memoryDate ?? this.memoryDate,
      isDetailCachedLocally:
          isDetailCachedLocally ?? this.isDetailCachedLocally,
      inputText: inputText ?? this.inputText,
      processedText: processedText ?? this.processedText,
      generatedTitle: generatedTitle ?? this.generatedTitle,
      tags: tags ?? this.tags,
      memoryLocationData: memoryLocationData ?? this.memoryLocationData,
    );
  }

  /// Whether this preview has full text cached (text-only caching for synced memories)
  bool get hasTextCached =>
      inputText != null ||
      processedText != null ||
      generatedTitle != null ||
      tags.isNotEmpty ||
      memoryLocationData != null;
}
