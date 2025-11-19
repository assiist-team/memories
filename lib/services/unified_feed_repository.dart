import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:memories/models/timeline_moment.dart';
import 'package:memories/models/memory_type.dart';

/// Cursor for unified feed pagination
class UnifiedFeedCursor {
  final DateTime? createdAt;
  final String? id;

  const UnifiedFeedCursor({
    this.createdAt,
    this.id,
  });

  bool get isEmpty => createdAt == null && id == null;

  Map<String, dynamic> toParams() {
    if (isEmpty) {
      return {};
    }
    return {
      'p_cursor_created_at': createdAt?.toIso8601String(),
      'p_cursor_id': id,
    };
  }

  /// Create cursor from last item in response
  factory UnifiedFeedCursor.fromTimelineMoment(TimelineMoment moment) {
    return UnifiedFeedCursor(
      createdAt: moment.createdAt,
      id: moment.id,
    );
  }
}

/// Result of fetching a page of unified feed
class UnifiedFeedPageResult {
  final List<TimelineMoment> memories;
  final UnifiedFeedCursor? nextCursor;
  final bool hasMore;

  UnifiedFeedPageResult({
    required this.memories,
    this.nextCursor,
    required this.hasMore,
  });
}

/// Repository for fetching unified feed data
/// 
/// Handles API calls to the unified feed endpoint, cursor tracking,
/// and exposes typed DTOs (TimelineMoment).
class UnifiedFeedRepository {
  final SupabaseClient _supabase;
  static const int _defaultBatchSize = 20;

  UnifiedFeedRepository(this._supabase);

  /// Fetch a page of unified feed memories
  /// 
  /// [cursor] is the pagination cursor (null for first page)
  /// [filters] is the set of memory types to include (empty set or all three means 'all')
  /// [batchSize] is the number of items to fetch (default: 20)
  /// 
  /// Returns a [UnifiedFeedPageResult] with memories, next cursor, and hasMore flag
  Future<UnifiedFeedPageResult> fetchPage({
    UnifiedFeedCursor? cursor,
    Set<MemoryType>? filters,
    int batchSize = _defaultBatchSize,
  }) async {
    final allTypes = {
      MemoryType.story,
      MemoryType.moment,
      MemoryType.memento,
    };
    
    final effectiveFilters = filters ?? allTypes;
    
    // Determine if we need to fetch all and filter client-side
    final shouldFetchAll = effectiveFilters.length == allTypes.length || 
                          effectiveFilters.length == 2;
    
    MemoryType? singleFilter;
    if (!shouldFetchAll && effectiveFilters.length == 1) {
      singleFilter = effectiveFilters.first;
    }

    final params = <String, dynamic>{
      'p_batch_size': batchSize,
      ...cursor?.toParams() ?? {},
    };

    // Add filter parameter
    if (singleFilter != null) {
      params['p_memory_type'] = singleFilter.apiValue;
    } else {
      params['p_memory_type'] = 'all';
    }

    final response = await _supabase.rpc('get_unified_timeline_feed', params: params);

    if (response is! List) {
      throw Exception('Invalid response format from get_unified_timeline_feed');
    }

    var memories = response
        .map((json) => TimelineMoment.fromJson(json as Map<String, dynamic>))
        .toList();

    // Filter client-side if needed (when 2 types selected or when filtering from 'all')
    if (shouldFetchAll && effectiveFilters.length < allTypes.length) {
      final filterSet = effectiveFilters.map((t) => t.apiValue.toLowerCase()).toSet();
      memories = memories.where((memory) {
        return filterSet.contains(memory.memoryType.toLowerCase());
      }).toList();
    }

    // Determine next cursor from last item
    UnifiedFeedCursor? nextCursor;
    bool hasMore = false;

    if (memories.isNotEmpty) {
      final lastMemory = memories.last;
      // For client-side filtering, we need to be more conservative about hasMore
      // since we might have filtered out some items
      if (shouldFetchAll && effectiveFilters.length < allTypes.length) {
        // If we filtered client-side, we can't be sure if there are more
        // Use the original response length to determine
        hasMore = response.length >= batchSize;
      } else {
        hasMore = memories.length >= batchSize;
      }
      
      if (hasMore) {
        nextCursor = UnifiedFeedCursor.fromTimelineMoment(lastMemory);
      }
    }

    return UnifiedFeedPageResult(
      memories: memories,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }
}

