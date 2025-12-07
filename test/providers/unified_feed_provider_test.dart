import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:io';
import 'package:memories/providers/unified_feed_provider.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:memories/services/connectivity_service.dart';
import 'package:memories/services/unified_feed_repository.dart';
import 'package:memories/models/timeline_memory.dart';
import 'package:memories/models/memory_type.dart';
import 'package:memories/models/queue_change_event.dart';
import 'package:memories/models/queued_memory.dart';
import 'package:memories/providers/memory_timeline_update_bus_provider.dart';
import 'package:memories/services/offline_memory_queue_service.dart';
import 'package:memories/services/shared_preferences_local_memory_preview_store.dart';
import 'package:memories/services/memory_sync_service.dart';

// Mock classes
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockUnifiedFeedRepository extends Mock implements UnifiedFeedRepository {}

class MockOfflineMemoryQueueService extends Mock
    implements OfflineMemoryQueueService {}

class MockLocalMemoryPreviewStore extends Mock
    implements SharedPreferencesLocalMemoryPreviewStore {}

class MockMemorySyncService extends Mock implements MemorySyncService {}

QueuedMemory _buildTestQueuedMemory({String? localId}) {
  return QueuedMemory(
    localId: localId ?? 'local-test',
    memoryType: 'moment',
    createdAt: DateTime(2025, 1, 1),
  );
}

void main() {
  group('UnifiedFeedController', () {
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockGoTrueClient;
    late MockConnectivityService mockConnectivity;
    late MockUnifiedFeedRepository mockRepository;
    late MockOfflineMemoryQueueService mockOfflineMemoryQueueService;
    late MockLocalMemoryPreviewStore mockLocalMemoryPreviewStore;
    late ProviderContainer container;
    late StreamController<QueueChangeEvent> queueChangeController;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockGoTrueClient = MockGoTrueClient();
      mockConnectivity = MockConnectivityService();
      mockRepository = MockUnifiedFeedRepository();
      mockOfflineMemoryQueueService = MockOfflineMemoryQueueService();
      mockLocalMemoryPreviewStore = MockLocalMemoryPreviewStore();
      queueChangeController = StreamController<QueueChangeEvent>.broadcast();

      container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(mockSupabase),
          connectivityServiceProvider.overrideWithValue(mockConnectivity),
          offlineMemoryQueueServiceProvider
              .overrideWithValue(mockOfflineMemoryQueueService),
          localMemoryPreviewStoreProvider
              .overrideWithValue(mockLocalMemoryPreviewStore),
          unifiedFeedRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );

      // Default connectivity to online
      when(() => mockConnectivity.isOnline()).thenAnswer((_) async => true);

      when(() => mockSupabase.auth).thenReturn(mockGoTrueClient);
      when(() => mockGoTrueClient.currentUser).thenReturn(null);

      // Default mock for fetchAvailableYears
      when(() => mockRepository.fetchAvailableYears(
            filters: any(named: 'filters'),
          )).thenAnswer((_) async => [2025]);

      when(() => mockRepository.fetchMemoryById(any()))
          .thenAnswer((_) async => null);

      when(() => mockOfflineMemoryQueueService.changeStream)
          .thenAnswer((_) => queueChangeController.stream);
      when(() => mockOfflineMemoryQueueService.getByLocalId(any())).thenAnswer(
        (invocation) async => _buildTestQueuedMemory(
          localId: invocation.positionalArguments.first as String,
        ),
      );
      when(() => mockOfflineMemoryQueueService.getAllQueued())
          .thenAnswer((_) async => []);
    });

    tearDown(() {
      queueChangeController.close();
      container.dispose();
    });

    group('Initial State', () {
      test('starts in initial state', () {
        final state = container.read(unifiedFeedProvider);
        expect(state.state, UnifiedFeedState.initial);
        expect(state.memories, isEmpty);
        expect(state.hasMore, false);
        expect(state.isOffline, false);
      });
    });

    group('Timeline & queue events', () {
      test('created timeline event triggers initial load when feed not ready',
          () async {
        when(() => mockOfflineMemoryQueueService.getByLocalId(any()))
            .thenAnswer((_) async => null);
        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: any(named: 'isOnline'),
            )).thenAnswer((_) async => UnifiedFeedPageResult(
              memories: [],
              hasMore: false,
            ));

        container.read(unifiedFeedProvider);

        final bus = container.read(memoryTimelineUpdateBusProvider);
        bus.emitCreated('server-memory-1');

        await Future.delayed(const Duration(milliseconds: 20));

        verify(() => mockRepository.fetchMergedFeed(
              cursor: null,
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: true,
            )).called(1);
      });

      test(
          'queue added event retriggers load after current loading sequence finishes',
          () async {
        var callCount = 0;
        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: any(named: 'isOnline'),
            )).thenAnswer((_) async {
          callCount++;
          await Future.delayed(const Duration(milliseconds: 30));
          return UnifiedFeedPageResult(
            memories: [],
            hasMore: false,
          );
        });

        final notifier = container.read(unifiedFeedProvider.notifier);
        final initialLoad = notifier.loadInitial();

        await Future.delayed(const Duration(milliseconds: 5));

        queueChangeController.add(
          QueueChangeEvent(
            localId: 'local-trigger',
            memoryType: 'moment',
            type: QueueChangeType.added,
          ),
        );

        await initialLoad;

        await Future.delayed(const Duration(milliseconds: 40));

        expect(callCount, 2);
      });
    });

    group('State Transitions', () {
      test('transitions from initial to empty on loadInitial', () async {
        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: any(named: 'isOnline'),
            )).thenAnswer((_) async => UnifiedFeedPageResult(
              memories: [],
              hasMore: false,
            ));

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        // Check final state
        final finalState = container.read(unifiedFeedProvider);
        expect(finalState.state, UnifiedFeedState.empty);
      });

      test('transitions to ready state when data is loaded', () async {
        final testMemory = TimelineMemory(
          id: 'memory-1',
          userId: 'user-1',
          title: 'Test Memory',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          memoryDate: DateTime(2025, 1, 17),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 17,
          tags: [],
          memoryType: 'moment',
          isOfflineQueued: false,
          isPreviewOnly: false,
          isDetailCachedLocally: false,
          serverId: 'memory-1',
          offlineSyncStatus: OfflineSyncStatus.synced,
        );

        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: any(named: 'isOnline'),
            )).thenAnswer((_) async => UnifiedFeedPageResult(
              memories: [testMemory],
              hasMore: true,
              nextCursor: UnifiedFeedCursor(
                createdAt: testMemory.createdAt,
                id: testMemory.id,
              ),
            ));

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        final state = container.read(unifiedFeedProvider);
        expect(state.state, UnifiedFeedState.ready);
        expect(state.memories.length, 1);
        expect(state.hasMore, true);
      });

      test('transitions to appending state during pagination', () async {
        final testMemory1 = TimelineMemory(
          id: 'memory-1',
          userId: 'user-1',
          title: 'Test Memory 1',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          memoryDate: DateTime(2025, 1, 17),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 17,
          tags: [],
          memoryType: 'moment',
          isOfflineQueued: false,
          isPreviewOnly: false,
          isDetailCachedLocally: false,
          serverId: 'memory-1',
          offlineSyncStatus: OfflineSyncStatus.synced,
        );

        final testMemory2 = TimelineMemory(
          id: 'memory-2',
          userId: 'user-1',
          title: 'Test Memory 2',
          capturedAt: DateTime(2025, 1, 16),
          createdAt: DateTime(2025, 1, 16),
          memoryDate: DateTime(2025, 1, 16),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 16,
          tags: [],
          memoryType: 'moment',
          isOfflineQueued: false,
          isPreviewOnly: false,
          isDetailCachedLocally: false,
          serverId: 'memory-2',
          offlineSyncStatus: OfflineSyncStatus.synced,
        );

        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: any(named: 'isOnline'),
            )).thenAnswer((invocation) async {
          final cursor =
              invocation.namedArguments[#cursor] as UnifiedFeedCursor?;

          if (cursor == null) {
            // Initial load
            return UnifiedFeedPageResult(
              memories: [testMemory1],
              hasMore: true,
              nextCursor: UnifiedFeedCursor(
                createdAt: testMemory1.createdAt,
                id: testMemory1.id,
              ),
            );
          } else {
            // Pagination load
            return UnifiedFeedPageResult(
              memories: [testMemory2],
              hasMore: false,
            );
          }
        });

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        // Verify initial load succeeded
        final stateAfterLoad = container.read(unifiedFeedProvider);
        expect(stateAfterLoad.state, UnifiedFeedState.ready);
        expect(stateAfterLoad.memories.length, 1);

        // Load more
        await notifier.loadMore();

        // Check final state
        final finalState = container.read(unifiedFeedProvider);
        expect(finalState.state, UnifiedFeedState.ready);
        expect(finalState.memories.length, 2);
      });
    });

    group('Error Handling - Initial Load', () {
      test('shows full-page error on initial load failure', () async {
        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: any(named: 'isOnline'),
            )).thenThrow(Exception('Network error'));

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        final state = container.read(unifiedFeedProvider);
        expect(state.state, UnifiedFeedState.error);
        expect(state.errorMessage, isNotNull);
        expect(state.errorMessage, contains('Network error'));
        expect(state.memories, isEmpty);
      });

      test('provides user-friendly error message for network errors', () async {
        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: any(named: 'isOnline'),
            )).thenThrow(SocketException('Connection failed'));

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        final state = container.read(unifiedFeedProvider);
        expect(state.state, UnifiedFeedState.error);
        expect(state.errorMessage, contains('Unable to connect'));
        expect(state.errorMessage, isNot(contains('SocketException')));
      });

      test('provides user-friendly error message for timeout errors', () async {
        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: any(named: 'isOnline'),
            )).thenThrow(TimeoutException('Request timed out'));

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        final state = container.read(unifiedFeedProvider);
        expect(state.state, UnifiedFeedState.error);
        expect(state.errorMessage, contains('Unable to connect'));
      });
    });

    group('Error Handling - Pagination', () {
      test(
          'shows inline error on pagination failure while keeping existing data',
          () async {
        final testMemory = TimelineMemory(
          id: 'memory-1',
          userId: 'user-1',
          title: 'Test Memory',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          memoryDate: DateTime(2025, 1, 17),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 17,
          tags: [],
          memoryType: 'moment',
          isOfflineQueued: false,
          isPreviewOnly: false,
          isDetailCachedLocally: false,
          serverId: 'memory-1',
          offlineSyncStatus: OfflineSyncStatus.synced,
        );

        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: any(named: 'isOnline'),
            )).thenAnswer((invocation) async {
          final cursor =
              invocation.namedArguments[#cursor] as UnifiedFeedCursor?;

          if (cursor == null) {
            // Initial load succeeds
            return UnifiedFeedPageResult(
              memories: [testMemory],
              hasMore: true,
              nextCursor: UnifiedFeedCursor(
                createdAt: testMemory.createdAt,
                id: testMemory.id,
              ),
            );
          } else {
            // Pagination fails
            throw Exception('Network error');
          }
        });

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        // Verify initial load succeeded
        final stateAfterLoad = container.read(unifiedFeedProvider);
        expect(stateAfterLoad.state, UnifiedFeedState.ready);
        expect(stateAfterLoad.memories.length, 1);

        // Try to load more (will fail)
        await notifier.loadMore();

        // Verify pagination error state
        final stateAfterError = container.read(unifiedFeedProvider);
        expect(stateAfterError.state, UnifiedFeedState.paginationError);
        expect(stateAfterError.errorMessage, isNotNull);
        // Existing memories should still be visible
        expect(stateAfterError.memories.length, 1);
      });

      test('can retry pagination after error', () async {
        final testMemory1 = TimelineMemory(
          id: 'memory-1',
          userId: 'user-1',
          title: 'Test Memory 1',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          memoryDate: DateTime(2025, 1, 17),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 17,
          tags: [],
          memoryType: 'moment',
          isOfflineQueued: false,
          isPreviewOnly: false,
          isDetailCachedLocally: false,
          serverId: 'memory-1',
          offlineSyncStatus: OfflineSyncStatus.synced,
        );

        final testMemory2 = TimelineMemory(
          id: 'memory-2',
          userId: 'user-1',
          title: 'Test Memory 2',
          capturedAt: DateTime(2025, 1, 16),
          createdAt: DateTime(2025, 1, 16),
          memoryDate: DateTime(2025, 1, 16),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 16,
          tags: [],
          memoryType: 'moment',
          isOfflineQueued: false,
          isPreviewOnly: false,
          isDetailCachedLocally: false,
          serverId: 'memory-2',
          offlineSyncStatus: OfflineSyncStatus.synced,
        );

        var callCount = 0;
        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: any(named: 'isOnline'),
            )).thenAnswer((invocation) async {
          final cursor =
              invocation.namedArguments[#cursor] as UnifiedFeedCursor?;
          callCount++;

          if (cursor == null) {
            // Initial load succeeds
            return UnifiedFeedPageResult(
              memories: [testMemory1],
              hasMore: true,
              nextCursor: UnifiedFeedCursor(
                createdAt: testMemory1.createdAt,
                id: testMemory1.id,
              ),
            );
          } else if (callCount == 2) {
            // First pagination attempt fails
            throw Exception('Network error');
          } else {
            // Retry succeeds
            return UnifiedFeedPageResult(
              memories: [testMemory2],
              hasMore: false,
            );
          }
        });

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        // First pagination attempt fails
        await notifier.loadMore();
        final stateAfterError = container.read(unifiedFeedProvider);
        expect(stateAfterError.state, UnifiedFeedState.paginationError);
        expect(stateAfterError.memories.length, 1);

        // Retry pagination (will succeed on third call)
        await notifier.loadMore();
        final stateAfterRetry = container.read(unifiedFeedProvider);
        expect(stateAfterRetry.state, UnifiedFeedState.ready);
        expect(stateAfterRetry.memories.length, 2);
      });
    });

    group('Offline Handling', () {
      test('detects offline state and sets isOffline flag', () async {
        when(() => mockConnectivity.isOnline()).thenAnswer((_) async => false);

        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: false,
            )).thenAnswer((_) async => UnifiedFeedPageResult(
              memories: [],
              hasMore: false,
            ));

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        final state = container.read(unifiedFeedProvider);
        expect(state.isOffline, true);
        expect(state.state, UnifiedFeedState.empty);
      });

      test('disables refresh while offline', () async {
        when(() => mockConnectivity.isOnline()).thenAnswer((_) async => false);

        final notifier = container.read(unifiedFeedProvider.notifier);

        // Refresh should return early without making API calls
        await notifier.refresh();

        // Verify no repository calls were made
        verifyNever(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: any(named: 'isOnline'),
            ));
      });

      test('shows offline banner when isOffline is true', () {
        // This is tested via widget tests, but we verify the state
        final state = UnifiedFeedViewState(
          state: UnifiedFeedState.ready,
          isOffline: true,
        );
        expect(state.isOffline, true);
      });
    });

    group('Filter Management', () {
      test('setFilter updates filter and reloads', () async {
        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: any(named: 'isOnline'),
            )).thenAnswer((_) async => UnifiedFeedPageResult(
              memories: [],
              hasMore: false,
            ));

        final notifier = container.read(unifiedFeedProvider.notifier);

        // Set filter to Story
        await notifier.setFilter({MemoryType.story});

        // Verify repository was called with Story filter
        verify(() => mockRepository.fetchMergedFeed(
              cursor: null,
              filters: {MemoryType.story},
              batchSize: 20,
              isOnline: true,
            )).called(1);
      });

      test('setFilter resets pagination', () async {
        final testMemory = TimelineMemory(
          id: 'memory-1',
          userId: 'user-1',
          title: 'Test Memory',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          memoryDate: DateTime(2025, 1, 17),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 17,
          tags: [],
          memoryType: 'moment',
          isOfflineQueued: false,
          isPreviewOnly: false,
          isDetailCachedLocally: false,
          serverId: 'memory-1',
          offlineSyncStatus: OfflineSyncStatus.synced,
        );

        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: any(named: 'isOnline'),
            )).thenAnswer((_) async => UnifiedFeedPageResult(
              memories: [testMemory],
              hasMore: true,
              nextCursor: UnifiedFeedCursor(
                createdAt: testMemory.createdAt,
                id: testMemory.id,
              ),
            ));

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        // Change filter
        await notifier.setFilter({MemoryType.story});

        // Verify cursor was reset (new initial load)
        verify(() => mockRepository.fetchMergedFeed(
              cursor: null,
              filters: {MemoryType.story},
              batchSize: 20,
              isOnline: true,
            )).called(1);
      });
    });

    group('Empty State', () {
      test('transitions to empty state when no memories found', () async {
        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: any(named: 'isOnline'),
            )).thenAnswer((_) async => UnifiedFeedPageResult(
              memories: [],
              hasMore: false,
            ));

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        final state = container.read(unifiedFeedProvider);
        expect(state.state, UnifiedFeedState.empty);
        expect(state.memories, isEmpty);
        expect(state.hasMore, false);
      });
    });

    group('Phase 2: Offline Timeline Integration', () {
      test('offline timeline includes preview index + queue', () async {
        when(() => mockConnectivity.isOnline()).thenAnswer((_) async => false);

        final previewMemory = TimelineMemory(
          id: 'preview-1',
          userId: 'user-1',
          title: 'Preview Memory',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          memoryDate: DateTime(2025, 1, 17),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 17,
          tags: [],
          memoryType: 'moment',
          isOfflineQueued: false,
          isPreviewOnly: true,
          isDetailCachedLocally: false,
          offlineSyncStatus: OfflineSyncStatus.synced,
        );

        final queuedMemory = TimelineMemory(
          id: 'queued-1',
          userId: 'user-1',
          title: 'Queued Memory',
          capturedAt: DateTime(2025, 1, 16),
          createdAt: DateTime(2025, 1, 16),
          memoryDate: DateTime(2025, 1, 16),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 16,
          tags: [],
          memoryType: 'moment',
          isOfflineQueued: true,
          isPreviewOnly: false,
          isDetailCachedLocally: true,
          localId: 'local-1',
          offlineSyncStatus: OfflineSyncStatus.queued,
        );

        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: false,
            )).thenAnswer((_) async => UnifiedFeedPageResult(
              memories: [queuedMemory, previewMemory],
              hasMore: false,
            ));

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        final state = container.read(unifiedFeedProvider);
        expect(state.isOffline, true);
        expect(state.state, UnifiedFeedState.ready);
        expect(state.memories.length, 2);
        expect(state.memories.any((m) => m.isPreviewOnly), true);
        expect(state.memories.any((m) => m.isOfflineQueued), true);
      });

      test('online timeline merges online + queue, keeps preview index updated',
          () async {
        when(() => mockConnectivity.isOnline()).thenAnswer((_) async => true);

        final onlineMemory = TimelineMemory(
          id: 'online-1',
          userId: 'user-1',
          title: 'Online Memory',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          memoryDate: DateTime(2025, 1, 17),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 17,
          tags: [],
          memoryType: 'moment',
          isOfflineQueued: false,
          isPreviewOnly: false,
          isDetailCachedLocally: false,
          serverId: 'online-1',
          offlineSyncStatus: OfflineSyncStatus.synced,
        );

        final queuedMemory = TimelineMemory(
          id: 'queued-1',
          userId: 'user-1',
          title: 'Queued Memory',
          capturedAt: DateTime(2025, 1, 16),
          createdAt: DateTime(2025, 1, 16),
          memoryDate: DateTime(2025, 1, 16),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 16,
          tags: [],
          memoryType: 'moment',
          isOfflineQueued: true,
          isPreviewOnly: false,
          isDetailCachedLocally: true,
          localId: 'local-1',
          offlineSyncStatus: OfflineSyncStatus.queued,
        );

        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: true,
            )).thenAnswer((_) async => UnifiedFeedPageResult(
              memories: [onlineMemory, queuedMemory],
              hasMore: false,
            ));

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        final state = container.read(unifiedFeedProvider);
        expect(state.isOffline, false);
        expect(state.state, UnifiedFeedState.ready);
        expect(state.memories.length, 2);
        expect(state.memories.any((m) => m.isOfflineQueued), true);
        expect(state.memories.any((m) => m.serverId != null), true);
      });

      test('filters still work with preview index and queue', () async {
        when(() => mockConnectivity.isOnline()).thenAnswer((_) async => false);

        final storyMemory = TimelineMemory(
          id: 'story-1',
          userId: 'user-1',
          title: 'Story Memory',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          memoryDate: DateTime(2025, 1, 17),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 17,
          tags: [],
          memoryType: 'story',
          isOfflineQueued: false,
          isPreviewOnly: true,
          isDetailCachedLocally: false,
          offlineSyncStatus: OfflineSyncStatus.synced,
        );

        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: {MemoryType.story},
              batchSize: any(named: 'batchSize'),
              isOnline: false,
            )).thenAnswer((_) async => UnifiedFeedPageResult(
              memories: [storyMemory],
              hasMore: false,
            ));

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.setFilter({MemoryType.story});

        final state = container.read(unifiedFeedProvider);
        expect(state.memories.length, 1);
        expect(state.memories.first.memoryType, 'story');
      });
    });

    group('Sync Integration', () {
      late MockMemorySyncService mockSyncService;
      late StreamController<SyncCompleteEvent> syncEventController;

      setUp(() {
        mockSyncService = MockMemorySyncService();
        syncEventController = StreamController<SyncCompleteEvent>.broadcast();
        when(() => mockSyncService.syncCompleteStream)
            .thenAnswer((_) => syncEventController.stream);
      });

      tearDown(() {
        syncEventController.close();
      });

      test('removes queued entry when sync completes', () async {
        final queuedMemory = TimelineMemory(
          id: 'queued-1',
          userId: 'user-1',
          title: 'Queued Memory',
          capturedAt: DateTime(2025, 1, 16),
          createdAt: DateTime(2025, 1, 16),
          memoryDate: DateTime(2025, 1, 16),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 16,
          tags: [],
          memoryType: 'moment',
          isOfflineQueued: true,
          isPreviewOnly: false,
          isDetailCachedLocally: true,
          localId: 'local-1',
          offlineSyncStatus: OfflineSyncStatus.queued,
        );

        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: true,
            )).thenAnswer((_) async => UnifiedFeedPageResult(
              memories: [queuedMemory],
              hasMore: false,
            ));

        final containerWithSync = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
            connectivityServiceProvider.overrideWithValue(mockConnectivity),
            offlineMemoryQueueServiceProvider
                .overrideWithValue(mockOfflineMemoryQueueService),
            localMemoryPreviewStoreProvider
                .overrideWithValue(mockLocalMemoryPreviewStore),
            unifiedFeedRepositoryProvider.overrideWithValue(mockRepository),
            memorySyncServiceProvider.overrideWithValue(mockSyncService),
          ],
        );

        final notifier = containerWithSync.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        // Verify queued memory is present
        var state = containerWithSync.read(unifiedFeedProvider);
        expect(state.memories.length, 1);
        expect(state.memories.first.localId, 'local-1');
        expect(state.memories.first.isOfflineQueued, true);

        // Emit sync completion event
        syncEventController.add(
          SyncCompleteEvent(
            localId: 'local-1',
            serverId: 'server-1',
            memoryType: MemoryType.moment,
          ),
        );

        // Wait for event to be processed
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify queued memory is removed
        state = containerWithSync.read(unifiedFeedProvider);
        expect(state.memories.length, 0);

        containerWithSync.dispose();
      });

      test('does not remove non-matching queued entry', () async {
        final queuedMemory1 = TimelineMemory(
          id: 'queued-1',
          userId: 'user-1',
          title: 'Queued Memory 1',
          capturedAt: DateTime(2025, 1, 16),
          createdAt: DateTime(2025, 1, 16),
          memoryDate: DateTime(2025, 1, 16),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 16,
          tags: [],
          memoryType: 'moment',
          isOfflineQueued: true,
          isPreviewOnly: false,
          isDetailCachedLocally: true,
          localId: 'local-1',
          offlineSyncStatus: OfflineSyncStatus.queued,
        );

        final queuedMemory2 = TimelineMemory(
          id: 'queued-2',
          userId: 'user-1',
          title: 'Queued Memory 2',
          capturedAt: DateTime(2025, 1, 15),
          createdAt: DateTime(2025, 1, 15),
          memoryDate: DateTime(2025, 1, 15),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 15,
          tags: [],
          memoryType: 'moment',
          isOfflineQueued: true,
          isPreviewOnly: false,
          isDetailCachedLocally: true,
          localId: 'local-2',
          offlineSyncStatus: OfflineSyncStatus.queued,
        );

        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: true,
            )).thenAnswer((_) async => UnifiedFeedPageResult(
              memories: [queuedMemory1, queuedMemory2],
              hasMore: false,
            ));

        final containerWithSync = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
            connectivityServiceProvider.overrideWithValue(mockConnectivity),
            offlineMemoryQueueServiceProvider
                .overrideWithValue(mockOfflineMemoryQueueService),
            localMemoryPreviewStoreProvider
                .overrideWithValue(mockLocalMemoryPreviewStore),
            unifiedFeedRepositoryProvider.overrideWithValue(mockRepository),
            memorySyncServiceProvider.overrideWithValue(mockSyncService),
          ],
        );

        final notifier = containerWithSync.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        // Verify both queued memories are present
        var state = containerWithSync.read(unifiedFeedProvider);
        expect(state.memories.length, 2);

        // Emit sync completion event for local-1 only
        syncEventController.add(
          SyncCompleteEvent(
            localId: 'local-1',
            serverId: 'server-1',
            memoryType: MemoryType.moment,
          ),
        );

        // Wait for event to be processed
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify only local-1 is removed, local-2 remains
        state = containerWithSync.read(unifiedFeedProvider);
        expect(state.memories.length, 1);
        expect(state.memories.first.localId, 'local-2');

        containerWithSync.dispose();
      });

      test('does not remove non-queued entries', () async {
        final serverMemory = TimelineMemory(
          id: 'server-1',
          userId: 'user-1',
          title: 'Server Memory',
          capturedAt: DateTime(2025, 1, 17),
          createdAt: DateTime(2025, 1, 17),
          memoryDate: DateTime(2025, 1, 17),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 17,
          tags: [],
          memoryType: 'moment',
          isOfflineQueued: false,
          isPreviewOnly: false,
          isDetailCachedLocally: false,
          serverId: 'server-1',
          offlineSyncStatus: OfflineSyncStatus.synced,
        );

        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: true,
            )).thenAnswer((_) async => UnifiedFeedPageResult(
              memories: [serverMemory],
              hasMore: false,
            ));

        final containerWithSync = ProviderContainer(
          overrides: [
            supabaseClientProvider.overrideWithValue(mockSupabase),
            connectivityServiceProvider.overrideWithValue(mockConnectivity),
            offlineMemoryQueueServiceProvider
                .overrideWithValue(mockOfflineMemoryQueueService),
            localMemoryPreviewStoreProvider
                .overrideWithValue(mockLocalMemoryPreviewStore),
            unifiedFeedRepositoryProvider.overrideWithValue(mockRepository),
            memorySyncServiceProvider.overrideWithValue(mockSyncService),
          ],
        );

        final notifier = containerWithSync.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        // Verify server memory is present
        var state = containerWithSync.read(unifiedFeedProvider);
        expect(state.memories.length, 1);

        // Emit sync completion event (should not affect server memory)
        syncEventController.add(
          SyncCompleteEvent(
            localId: 'local-1',
            serverId: 'server-1',
            memoryType: MemoryType.moment,
          ),
        );

        // Wait for event to be processed
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify server memory is still present (not removed because it's not queued)
        state = containerWithSync.read(unifiedFeedProvider);
        expect(state.memories.length, 1);
        expect(state.memories.first.id, 'server-1');

        containerWithSync.dispose();
      });
    });

    group('Offline Delete Ghost Card Fix', () {
      test('deleting queued memory keeps it removed - no fetch after delete',
          () async {
        when(() => mockConnectivity.isOnline()).thenAnswer((_) async => false);

        final queuedMemory = TimelineMemory(
          id: 'local-1',
          userId: 'user-1',
          title: 'Queued Memory',
          capturedAt: DateTime(2025, 1, 16),
          createdAt: DateTime(2025, 1, 16),
          memoryDate: DateTime(2025, 1, 16),
          year: 2025,
          season: 'Winter',
          month: 1,
          day: 16,
          tags: [],
          memoryType: 'moment',
          isOfflineQueued: true,
          isPreviewOnly: false,
          isDetailCachedLocally: true,
          localId: 'local-1',
          offlineSyncStatus: OfflineSyncStatus.queued,
        );

        // Mock initial load
        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: false,
            )).thenAnswer((_) async => UnifiedFeedPageResult(
              memories: [queuedMemory],
              hasMore: false,
            ));

        // Mock queue service - return memory initially, null after delete
        when(() => mockOfflineMemoryQueueService.getByLocalId('local-1'))
            .thenAnswer(
                (_) async => _buildTestQueuedMemory(localId: 'local-1'));

        final notifier = container.read(unifiedFeedProvider.notifier);

        // Trigger initial load to get feed ready
        await notifier.loadInitial();

        // Verify memory is in feed
        var state = container.read(unifiedFeedProvider);
        expect(state.memories.length, 1);
        expect(state.memories.first.localId, 'local-1');

        // Now simulate delete - this should remove the memory immediately
        // and NOT trigger a fetch
        queueChangeController.add(
          QueueChangeEvent(
            localId: 'local-1',
            memoryType: 'moment',
            type: QueueChangeType.removed,
          ),
        );

        // Wait for event to be processed
        await Future.delayed(const Duration(milliseconds: 50));

        // Verify memory is removed and no fetch was triggered
        state = container.read(unifiedFeedProvider);
        expect(state.memories.length, 0,
            reason:
                'Deleted queued memory should remain removed without triggering fetch');

        // Verify fetchMergedFeed was only called once (initial load)
        verify(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: false,
            )).called(1);
      });

      test('skips redundant offline _fetchPage when queue added event fires',
          () async {
        when(() => mockConnectivity.isOnline()).thenAnswer((_) async => false);

        var fetchCallCount = 0;
        when(() => mockRepository.fetchMergedFeed(
              cursor: any(named: 'cursor'),
              filters: any(named: 'filters'),
              batchSize: any(named: 'batchSize'),
              isOnline: false,
            )).thenAnswer((_) async {
          fetchCallCount++;
          return UnifiedFeedPageResult(
            memories: [],
            hasMore: false,
          );
        });

        final notifier = container.read(unifiedFeedProvider.notifier);
        await notifier.loadInitial();

        // Simulate queue added event while offline
        queueChangeController.add(
          QueueChangeEvent(
            localId: 'local-1',
            memoryType: 'moment',
            type: QueueChangeType.added,
          ),
        );

        // Wait for event processing
        await Future.delayed(const Duration(milliseconds: 50));

        // Verify no additional fetch was triggered (MemoryTimelineEvent.created handles it)
        expect(fetchCallCount, 1,
            reason:
                'Offline queue added should not trigger redundant _fetchPage');
      });
    });
  });
}
