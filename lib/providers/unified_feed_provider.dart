import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:memories/models/timeline_memory.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/models/queue_change_event.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/services/memory_sync_service.dart';
import 'package:memories/services/unified_feed_repository.dart';
import 'package:memories/providers/timeline_analytics_provider.dart';
import 'package:memories/services/offline_memory_queue_service.dart';
import 'package:memories/services/shared_preferences_local_memory_preview_store.dart';
import 'package:memories/providers/memory_timeline_update_bus_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'unified_feed_provider.g.dart';

/// State of the unified feed
enum UnifiedFeedState {
  /// Initial state before any load attempt
  initial,

  /// Loading initial page
  loading,

  /// Feed is ready with data
  ready,

  /// Appending more items (pagination)
  appending,

  /// Error state (initial load failed)
  error,

  /// Pagination error (has existing data)
  paginationError,

  /// Empty state (no memories found)
  empty,
}

/// Unified feed view state
class UnifiedFeedViewState {
  final UnifiedFeedState state;
  final List<TimelineMemory> memories;
  final UnifiedFeedCursor? nextCursor;
  final String? errorMessage;
  final bool hasMore;
  final bool isOffline;
  final List<int> availableYears;

  const UnifiedFeedViewState({
    required this.state,
    this.memories = const [],
    this.nextCursor,
    this.errorMessage,
    this.hasMore = false,
    this.isOffline = false,
    this.availableYears = const [],
  });

  UnifiedFeedViewState copyWith({
    UnifiedFeedState? state,
    List<TimelineMemory>? memories,
    UnifiedFeedCursor? nextCursor,
    String? errorMessage,
    bool? hasMore,
    bool? isOffline,
    List<int>? availableYears,
  }) {
    return UnifiedFeedViewState(
      state: state ?? this.state,
      memories: memories ?? this.memories,
      nextCursor: nextCursor ?? this.nextCursor,
      errorMessage: errorMessage ?? this.errorMessage,
      hasMore: hasMore ?? this.hasMore,
      isOffline: isOffline ?? this.isOffline,
      availableYears: availableYears ?? this.availableYears,
    );
  }
}

/// Provider for unified feed repository
@riverpod
UnifiedFeedRepository unifiedFeedRepository(UnifiedFeedRepositoryRef ref) {
  final supabase = ref.read(supabaseClientProvider);
  final offlineQueueService = ref.read(offlineMemoryQueueServiceProvider);
  final localPreviewStore = ref.read(localMemoryPreviewStoreProvider);

  return UnifiedFeedRepository(
    supabase,
    offlineQueueService,
    localPreviewStore,
  );
}

/// Provider for unified feed state
///
/// [memoryTypeFilters] is the set of memory types to include (empty set means all)
@riverpod
class UnifiedFeedController extends _$UnifiedFeedController {
  static const int _batchSize = 20;
  int _currentPageNumber = 1;
  Set<MemoryType> _memoryTypeFilters = {};
  StreamSubscription<SyncCompleteEvent>? _syncSub;
  StreamSubscription<QueueChangeEvent>? _queueChangeSub;
  StreamSubscription<MemoryTimelineEvent>? _timelineUpdateSub;
  RealtimeChannel? _realtimeChannel;

  @override
  UnifiedFeedViewState build([Set<MemoryType>? memoryTypeFilters]) {
    _memoryTypeFilters = memoryTypeFilters ??
        {
          MemoryType.story,
          MemoryType.moment,
          MemoryType.memento,
        };
    _setupSyncListener();
    _setupQueueChangeListeners();
    _setupRealtimeSubscription();
    _setupTimelineUpdateBusListener();
    ref.onDispose(() {
      _syncSub?.cancel();
      _queueChangeSub?.cancel();
      _timelineUpdateSub?.cancel();
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = null;
    });
    return const UnifiedFeedViewState(state: UnifiedFeedState.initial);
  }

  void _setupSyncListener() {
    final syncService = ref.read(memorySyncServiceProvider);

    _syncSub?.cancel();
    _syncSub = syncService.syncCompleteStream.listen((event) {
      _removeQueuedEntry(event.localId);
      // We do NOT immediately re-fetch the feed here; the server-backed
      // version will naturally appear on next pagination/refresh.
    });
  }

  void _setupQueueChangeListeners() {
    final queueService = ref.read(offlineMemoryQueueServiceProvider);

    _queueChangeSub?.cancel();
    _queueChangeSub = queueService.changeStream.listen((event) {
      _handleQueueChange(event);
    });
  }

  void _setupTimelineUpdateBusListener() {
    final bus = ref.read(memoryTimelineUpdateBusProvider);

    _timelineUpdateSub?.cancel();
    _timelineUpdateSub = bus.stream.listen((event) {
      _handleTimelineUpdateEvent(event);
    });
  }

  Future<void> _handleTimelineUpdateEvent(MemoryTimelineEvent event) async {
    switch (event.type) {
      case MemoryTimelineEventType.updated:
        // Fetch the updated memory and update it in-place for deterministic refresh
        debugPrint(
            '[UnifiedFeedController] Handling updated event for memory: ${event.memoryId}');
        try {
          final connectivityService = ref.read(connectivityServiceProvider);
          final isOnline = await connectivityService.isOnline();
          
          if (state.state == UnifiedFeedState.ready ||
              state.state == UnifiedFeedState.empty) {
            if (isOnline) {
              // Online: Fetch the specific memory by ID for deterministic update
              final repository = ref.read(unifiedFeedRepositoryProvider);
              final updatedMemory = await repository.fetchMemoryById(event.memoryId);
              
              if (updatedMemory != null) {
                // Update the memory in-place if it exists in the current feed
                final memoryIndex = state.memories.indexWhere((m) =>
                    m.id == event.memoryId ||
                    m.serverId == event.memoryId ||
                    m.localId == event.memoryId);
                
                if (memoryIndex != -1) {
                  // Replace the existing memory with the updated one
                  final updatedMemories = List<TimelineMemory>.from(state.memories);
                  updatedMemories[memoryIndex] = updatedMemory;
                  state = state.copyWith(memories: updatedMemories);
                  debugPrint(
                      '[UnifiedFeedController] Updated memory ${event.memoryId} in-place at index $memoryIndex');
                } else {
                  // Memory not in current feed, remove it (it may appear on pagination)
                  removeMemory(event.memoryId);
                  debugPrint(
                      '[UnifiedFeedController] Updated memory ${event.memoryId} not in current feed, removed from view');
                }
              } else {
                // Memory not found in feed (may have been deleted or filtered out)
                removeMemory(event.memoryId);
                debugPrint(
                    '[UnifiedFeedController] Updated memory ${event.memoryId} not found in feed');
              }
            } else {
              // Offline: Refresh feed to pick up queued edit
              // The feed merge logic will prefer queued entries over server-backed ones
              debugPrint(
                  '[UnifiedFeedController] Offline edit detected, refreshing feed to show queued edit');
              await _fetchPage(
                cursor: null,
                append: false,
                pageNumber: 1,
              );
            }
          }
        } catch (e) {
          debugPrint(
              '[UnifiedFeedController] Error handling updated memory: $e');
          // Fallback: remove the old entry
          removeMemory(event.memoryId);
        }
        break;
      case MemoryTimelineEventType.deleted:
        // Remove from feed immediately - memory was deleted on server
        debugPrint(
            '[UnifiedFeedController] Handling deleted event for memory: ${event.memoryId}');
        removeMemory(event.memoryId);
        break;
    }
  }

  void _setupRealtimeSubscription() {
    final supabase = ref.read(supabaseClientProvider);
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      debugPrint('[UnifiedFeedController] No user ID, skipping realtime subscription');
      return;
    }

    // Cancel existing subscription if any
    _realtimeChannel?.unsubscribe();

    // Set up realtime subscription for memory changes
    _realtimeChannel = supabase
        .channel('unified_feed_memories_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'memories',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _handleMemoryUpdate(payload);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'memories',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _handleMemoryDelete(payload);
          },
        )
        .subscribe();

    debugPrint('[UnifiedFeedController] Realtime subscription set up for user $userId');
  }

  void _handleMemoryUpdate(PostgresChangePayload payload) {
    try {
      final oldRecord = payload.oldRecord as Map<String, dynamic>?;
      final newRecord = payload.newRecord as Map<String, dynamic>?;

      if (oldRecord == null || newRecord == null) {
        return;
      }

      final memoryId = oldRecord['id'] as String?;
      if (memoryId == null) {
        return;
      }

      // Check if the memory type matches our filters
      final memoryTypeStr = newRecord['memory_type'] as String?;
      if (memoryTypeStr != null) {
        final memoryType = MemoryTypeExtension.fromApiValue(memoryTypeStr);
        if (!_memoryTypeFilters.contains(memoryType)) {
          // Memory type doesn't match filters, ignore
          return;
        }
      }

      debugPrint('[UnifiedFeedController] Memory updated via realtime: $memoryId');

      // Remove the old entry - it will be refreshed on next fetch/refresh
      // This ensures the timeline shows updated data without needing manual refresh
      removeMemory(memoryId);

      // Optionally refresh the feed to get the updated version immediately
      // For now, we'll just remove it and let it appear on next pagination/refresh
      // This is more efficient than immediately refetching
    } catch (e) {
      debugPrint('[UnifiedFeedController] Error handling memory update: $e');
    }
  }

  void _handleMemoryDelete(PostgresChangePayload payload) {
    try {
      final oldRecord = payload.oldRecord as Map<String, dynamic>?;
      if (oldRecord == null) {
        return;
      }

      final memoryId = oldRecord['id'] as String?;
      if (memoryId == null) {
        return;
      }

      debugPrint('[UnifiedFeedController] Memory deleted via realtime: $memoryId');

      // Remove from feed immediately
      removeMemory(memoryId);
    } catch (e) {
      debugPrint('[UnifiedFeedController] Error handling memory delete: $e');
    }
  }

  void _handleQueueChange(QueueChangeEvent event) {
    // Handle different change types
    switch (event.type) {
      case QueueChangeType.added:
      case QueueChangeType.updated:
        // For added/updated, re-fetch the feed to get latest queue state
        // This ensures the feed reflects the latest queue contents
        if (state.state == UnifiedFeedState.ready ||
            state.state == UnifiedFeedState.empty) {
          // Only refresh if feed is already loaded
          _fetchPage(
            cursor: null,
            append: false,
            pageNumber: 1,
          );
        }
        break;
      case QueueChangeType.removed:
        // For removed, optimistically remove from feed immediately
        _removeQueuedEntryByLocalId(event.localId);
        break;
    }
  }

  void _removeQueuedEntry(String localId) {
    final updated = state.memories
        .where((m) => !(m.isOfflineQueued && m.localId == localId))
        .toList();

    state = state.copyWith(memories: updated);
  }

  /// Handle queue change event - remove queued entry by localId
  void _removeQueuedEntryByLocalId(String localId) {
    final updated = state.memories
        .where((m) => !(m.isOfflineQueued && m.localId == localId))
        .toList();

    state = state.copyWith(memories: updated);
  }

  /// Load initial feed
  Future<void> loadInitial() async {
    final connectivityService = ref.read(connectivityServiceProvider);
    final isOnline = await connectivityService.isOnline();

    state = state.copyWith(
      state: UnifiedFeedState.loading,
      memories: [],
      nextCursor: null,
      hasMore: false,
      isOffline: !isOnline,
      availableYears: const [],
    );

    try {
      await _fetchPage(
        cursor: null,
        append: false,
        pageNumber: 1,
      );
    } catch (e) {
      ref.read(timelineAnalyticsServiceProvider).trackError(
        e,
        'unified_feed_initial_load',
        context: {
          'memory_type_filters':
              _memoryTypeFilters.map((t) => t.apiValue).join(','),
          'is_offline': !isOnline,
        },
      );
      state = state.copyWith(
        state: UnifiedFeedState.error,
        errorMessage: _getUserFriendlyErrorMessage(e),
        isOffline: !isOnline,
      );
    }
  }

  /// Load next page (pagination)
  Future<void> loadMore() async {
    // Allow retry from pagination error state
    if (state.state == UnifiedFeedState.appending ||
        (!state.hasMore && state.state != UnifiedFeedState.paginationError) ||
        (state.nextCursor == null &&
            state.state != UnifiedFeedState.paginationError)) {
      return;
    }

    final connectivityService = ref.read(connectivityServiceProvider);
    final isOnline = await connectivityService.isOnline();

    _currentPageNumber++;
    state = state.copyWith(
      state: UnifiedFeedState.appending,
      isOffline: !isOnline,
    );

    try {
      await _fetchPage(
        cursor: state.nextCursor!,
        append: true,
        pageNumber: _currentPageNumber,
      );
    } catch (e) {
      // Track pagination failure
      ref
          .read(timelineAnalyticsServiceProvider)
          .trackUnifiedFeedPaginationFailure(
            _currentPageNumber,
            e.toString(),
          );

      ref.read(timelineAnalyticsServiceProvider).trackError(
        e,
        'unified_feed_pagination',
        context: {
          'page_number': _currentPageNumber,
          'memory_type_filters':
              _memoryTypeFilters.map((t) => t.apiValue).join(','),
          'is_offline': !isOnline,
        },
      );

      // Keep existing memories visible, show inline error
      state = state.copyWith(
        state: UnifiedFeedState.paginationError,
        errorMessage: _getUserFriendlyErrorMessage(e),
        isOffline: !isOnline,
      );
    }
  }

  /// Refresh feed (reload first page)
  Future<void> refresh() async {
    final connectivityService = ref.read(connectivityServiceProvider);
    final isOnline = await connectivityService.isOnline();

    // Disable refresh while offline
    if (!isOnline) {
      return;
    }

    _currentPageNumber = 1;
    await loadInitial();
  }

  /// Remove a memory from the feed (optimistic update)
  ///
  /// [memoryId] is the ID of the memory to remove (can be server ID or local ID)
  /// Removes entries that match by id, serverId, or localId
  void removeMemory(String memoryId) {
    final updatedMemories = state.memories.where((m) {
      // Remove if id matches (for server-backed memories or queued memories by localId)
      if (m.id == memoryId) return false;
      // Remove if serverId matches (for server-backed memories)
      if (m.serverId == memoryId) return false;
      // Remove if localId matches (for queued memories)
      if (m.localId == memoryId) return false;
      return true;
    }).toList();
    state = state.copyWith(memories: updatedMemories);
  }

  /// Update the memory type filters and reload
  Future<void> setFilter(Set<MemoryType> filters) async {
    _memoryTypeFilters = filters;
    _currentPageNumber = 1;
    await loadInitial();
  }

  Future<void> _fetchPage({
    UnifiedFeedCursor? cursor,
    required bool append,
    required int pageNumber,
  }) async {
    final stopwatch = Stopwatch()..start();
    final repository = ref.read(unifiedFeedRepositoryProvider);
    final connectivityService = ref.read(connectivityServiceProvider);

    // Check connectivity
    final isOnline = await connectivityService.isOnline();

    final result = await repository.fetchMergedFeed(
      cursor: cursor,
      filters: _memoryTypeFilters,
      batchSize: _batchSize,
      isOnline: isOnline,
    );

    final resolvedAvailableYears = append
        ? state.availableYears
        : await repository.fetchAvailableYears(filters: _memoryTypeFilters);

    stopwatch.stop();

    // Track pagination success
    ref
        .read(timelineAnalyticsServiceProvider)
        .trackUnifiedFeedPaginationSuccess(
          pageNumber,
          result.memories.length,
          stopwatch.elapsedMilliseconds,
        );

    // Deduplicate by serverId when appending to prevent duplicate entries
    final finalMemories = append
        ? _deduplicateMemories([...state.memories, ...result.memories])
        : result.memories;

    state = state.copyWith(
      state: result.memories.isEmpty && !append
          ? UnifiedFeedState.empty
          : UnifiedFeedState.ready,
      memories: finalMemories,
      nextCursor: result.nextCursor,
      hasMore: result.hasMore,
      errorMessage: null,
      isOffline: !isOnline,
      availableYears: resolvedAvailableYears,
    );
  }

  /// Deduplicate timeline memories by serverId.
  ///
  /// Ensures at most one TimelineMemory per serverId. When duplicates exist:
  /// - Prefers server-backed entries (isOfflineQueued == false) over queued entries
  /// - Prefers queued entries (isOfflineQueued == true) over preview-only entries
  /// - Entries without a serverId are kept (they use localId or id as identifier)
  List<TimelineMemory> _deduplicateMemories(List<TimelineMemory> memories) {
    final Map<String, TimelineMemory> byServerId = {};
    final List<TimelineMemory> withoutServerId = [];

    for (final memory in memories) {
      if (memory.serverId == null) {
        // Entries without serverId use localId or id as identifier - keep all
        withoutServerId.add(memory);
      } else {
        final existing = byServerId[memory.serverId!];
        if (existing == null) {
          // First entry with this serverId
          byServerId[memory.serverId!] = memory;
        } else {
          // Duplicate found - prefer server-backed over queued, queued over preview-only
          final shouldReplace = _shouldReplaceMemory(existing, memory);
          if (shouldReplace) {
            byServerId[memory.serverId!] = memory;
          }
        }
      }
    }

    return <TimelineMemory>[...byServerId.values, ...withoutServerId];
  }

  /// Determine if [newEntry] should replace [existingEntry] when both have the same serverId.
  ///
  /// Prefers server-backed entries over queued entries, and queued entries over preview-only.
  /// When both are server-backed, prefers the newer entry (to handle memory updates).
  bool _shouldReplaceMemory(TimelineMemory existing, TimelineMemory newEntry) {
    // Prefer server-backed entries (not queued) over queued entries
    if (!existing.isOfflineQueued && newEntry.isOfflineQueued) {
      return false; // Keep existing server-backed entry
    }
    if (existing.isOfflineQueued && !newEntry.isOfflineQueued) {
      return true; // Replace queued with server-backed
    }
    
    // If both are queued
    if (existing.isOfflineQueued && newEntry.isOfflineQueued) {
      // Both queued - prefer the one with full detail cached locally
      if (!existing.isDetailCachedLocally && newEntry.isDetailCachedLocally) {
        return true;
      }
      if (existing.isDetailCachedLocally && !newEntry.isDetailCachedLocally) {
        return false;
      }
      // If both have same detail cache status, prefer newer (later in list = more recent fetch)
      return true;
    }
    
    // If both are server-backed, prefer the newer entry (handles memory updates)
    // The newEntry appears later in the list, so it's from a more recent fetch
    if (!existing.isOfflineQueued && !newEntry.isOfflineQueued) {
      return true; // Always replace with newer server-backed entry
    }
    
    // Fallback: prefer existing (first seen)
    return false;
  }

  /// Get user-friendly error message from exception
  String _getUserFriendlyErrorMessage(Object error) {
    // Handle network/connectivity errors
    if (error is SocketException || error is TimeoutException) {
      return 'Unable to connect. Please check your internet connection and try again.';
    }

    // Handle offline errors
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('offline') ||
        errorString.contains('no internet')) {
      return 'You appear to be offline. Please check your internet connection and try again.';
    }

    // Handle network errors
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network error. Please check your connection and try again.';
    }

    // Handle timeout errors
    if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    // Generic error - don't expose technical details
    return 'Failed to load memories. Please try again.';
  }
}

/// Convenience provider for unified feed (all memory types)
final unifiedFeedProvider = unifiedFeedControllerProvider({
  MemoryType.story,
  MemoryType.moment,
  MemoryType.memento,
});
