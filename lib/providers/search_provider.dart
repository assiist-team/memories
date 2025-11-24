import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:memories/services/search_service.dart';
import 'package:memories/models/search_result.dart';
import 'package:memories/providers/supabase_provider.dart';

part 'search_provider.g.dart';

/// Provider for search service
@riverpod
SearchService searchService(SearchServiceRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return SearchService(supabase);
}

/// Provider for current search query string
@riverpod
class SearchQuery extends _$SearchQuery {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

/// Provider for debounced search query
///
/// Debounces the search query by 250ms before updating
@riverpod
class DebouncedSearchQuery extends _$DebouncedSearchQuery {
  Timer? _debounceTimer;
  String _lastDebouncedValue = '';

  @override
  String build() {
    // Always initialize state first - this must happen before any reads
    state = _lastDebouncedValue;

    final query = ref.watch(searchQueryProvider);

    // Cancel previous timer
    _debounceTimer?.cancel();

    // If query is empty, update immediately and clear state
    if (query.isEmpty) {
      state = '';
      _lastDebouncedValue = '';
      return '';
    }

    // Otherwise, debounce by 250ms
    // Keep the last debounced value while waiting for the timer
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      state = query;
      _lastDebouncedValue = query;
    });

    ref.onDispose(() {
      _debounceTimer?.cancel();
    });

    // Return last debounced value (will be updated by timer after debounce)
    return _lastDebouncedValue;
  }
}

/// State for search results
class SearchResultsState {
  final List<SearchResult> items;
  final int currentPage;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;

  SearchResultsState({
    required this.items,
    required this.currentPage,
    required this.hasMore,
    required this.isLoading,
    required this.isLoadingMore,
    this.errorMessage,
  });

  SearchResultsState copyWith({
    List<SearchResult>? items,
    int? currentPage,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SearchResultsState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  static SearchResultsState initial() {
    return SearchResultsState(
      items: [],
      currentPage: 0,
      hasMore: false,
      isLoading: false,
      isLoadingMore: false,
      errorMessage: null,
    );
  }
}

/// Provider for search results with pagination
@riverpod
class SearchResults extends _$SearchResults {
  String? _lastQuery;
  Future<void>? _lastSearchFuture;

  @override
  SearchResultsState build() {
    // Initialize state first
    final initialState = SearchResultsState.initial();

    // React to debounced query changes instead of doing work directly in build.
    // This avoids reading state before it has been initialized.
    ref.listen<String>(
      debouncedSearchQueryProvider,
      (previous, next) {
        // When query is cleared, reset results
        if (next.isEmpty) {
          if (_lastQuery != null) {
            _lastQuery = null;
            // Use post-frame callback to ensure state is initialized
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                state = SearchResultsState.initial();
              } catch (_) {
                // Provider may have been disposed, ignore
              }
            });
          }
          return;
        }

        // For non-empty queries, trigger a new search when the query changes
        if (next != _lastQuery) {
          _lastQuery = next;
          // Cancel any pending search
          _lastSearchFuture?.ignore();
          // Trigger new search after ensuring state is initialized
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              _lastSearchFuture = _performSearch(next, page: 1);
            } catch (_) {
              // Provider may have been disposed, ignore
            }
          });
        }
      },
    );

    // Return initial state
    return initialState;
  }

  Future<void> _performSearch(String query, {required int page}) async {
    // Set loading state
    if (page == 1) {
      state = state.copyWith(
        isLoading: true,
        errorMessage: null,
        clearError: true,
      );
    } else {
      state = state.copyWith(isLoadingMore: true);
    }

    try {
      final searchService = ref.read(searchServiceProvider);
      final results = await searchService.searchMemories(
        query: query,
        page: page,
      );

      // Ignore stale responses if the query changed while we were fetching
      if (_lastQuery != query && page == 1) {
        return;
      }

      // Add recent search if this is the first page and we have results
      if (page == 1 && results.items.isNotEmpty) {
        try {
          await searchService.addRecentSearch(query);
          // Refresh recent searches provider
          ref.invalidate(recentSearchesProvider);
        } catch (_) {
          // Don't fail the search if recent search save fails
        }
      }

      // Update state with results
      state = state.copyWith(
        items: page == 1 ? results.items : [...state.items, ...results.items],
        currentPage: results.page,
        hasMore: results.hasMore,
        isLoading: false,
        isLoadingMore: false,
        clearError: true,
      );
    } catch (e) {
      // Ignore stale errors if the query changed while we were fetching
      if (_lastQuery != query && page == 1) {
        return;
      }

      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: _getUserFriendlyErrorMessage(e),
      );
    }
  }

  /// Load more results for the current query
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) {
      return;
    }

    final query = ref.read(debouncedSearchQueryProvider);
    if (query.isEmpty) {
      return;
    }

    await _performSearch(query, page: state.currentPage + 1);
  }

  /// Refresh search results for the current query
  Future<void> refresh() async {
    final query = ref.read(debouncedSearchQueryProvider);
    if (query.isEmpty) {
      return;
    }

    await _performSearch(query, page: 1);
  }

  /// Clear search results
  void clear() {
    _lastQuery = null;
    state = SearchResultsState.initial();
  }

  /// Get user-friendly error message from exception
  String _getUserFriendlyErrorMessage(Object error) {
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('offline') || errorString.contains('network')) {
      return 'Unable to connect. Please check your internet connection.';
    } else if (errorString.contains('unauthorized')) {
      return 'Please sign in to search your memories.';
    } else if (errorString.contains('empty') ||
        errorString.contains('argument')) {
      return 'Please enter a search query.';
    } else {
      return 'Unable to search. Please try again.';
    }
  }
}

/// Provider for recent searches
@riverpod
Future<List<RecentSearch>> recentSearches(RecentSearchesRef ref) async {
  final searchService = ref.read(searchServiceProvider);
  return await searchService.getRecentSearches();
}

/// Provider for clearing recent searches
@riverpod
class ClearRecentSearches extends _$ClearRecentSearches {
  @override
  FutureOr<void> build() {
    // This provider doesn't maintain state, it's just for triggering the action
  }

  Future<void> clear() async {
    final searchService = ref.read(searchServiceProvider);
    await searchService.clearRecentSearches();
    // Invalidate recent searches provider to refresh the list
    ref.invalidate(recentSearchesProvider);
  }
}
