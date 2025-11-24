// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$searchServiceHash() => r'9ec0440c87498353ac916ba8459bba0f419e8454';

/// Provider for search service
///
/// Copied from [searchService].
@ProviderFor(searchService)
final searchServiceProvider = AutoDisposeProvider<SearchService>.internal(
  searchService,
  name: r'searchServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$searchServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SearchServiceRef = AutoDisposeProviderRef<SearchService>;
String _$recentSearchesHash() => r'c2f025257b737845e1d1327d870a4250f28bcc90';

/// Provider for recent searches
///
/// Copied from [recentSearches].
@ProviderFor(recentSearches)
final recentSearchesProvider =
    AutoDisposeFutureProvider<List<RecentSearch>>.internal(
  recentSearches,
  name: r'recentSearchesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$recentSearchesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RecentSearchesRef = AutoDisposeFutureProviderRef<List<RecentSearch>>;
String _$searchQueryHash() => r'a2de29f344488b8b351fbfcf9c230f993798b9ea';

/// Provider for current search query string
///
/// Copied from [SearchQuery].
@ProviderFor(SearchQuery)
final searchQueryProvider =
    AutoDisposeNotifierProvider<SearchQuery, String>.internal(
  SearchQuery.new,
  name: r'searchQueryProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$searchQueryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SearchQuery = AutoDisposeNotifier<String>;
String _$debouncedSearchQueryHash() =>
    r'f199d81e5bd1c418276e9d4c893758b1349cb47a';

/// Provider for debounced search query
///
/// Debounces the search query by 250ms before updating
///
/// Copied from [DebouncedSearchQuery].
@ProviderFor(DebouncedSearchQuery)
final debouncedSearchQueryProvider =
    AutoDisposeNotifierProvider<DebouncedSearchQuery, String>.internal(
  DebouncedSearchQuery.new,
  name: r'debouncedSearchQueryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$debouncedSearchQueryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DebouncedSearchQuery = AutoDisposeNotifier<String>;
String _$searchResultsHash() => r'789e8b556cf080bd3537614a7c0201d64319d682';

/// Provider for search results with pagination
///
/// Copied from [SearchResults].
@ProviderFor(SearchResults)
final searchResultsProvider =
    AutoDisposeNotifierProvider<SearchResults, SearchResultsState>.internal(
  SearchResults.new,
  name: r'searchResultsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$searchResultsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SearchResults = AutoDisposeNotifier<SearchResultsState>;
String _$clearRecentSearchesHash() =>
    r'7b21d2bcde9ac8ad87e61cf99e0b233d37b1e8c6';

/// Provider for clearing recent searches
///
/// Copied from [ClearRecentSearches].
@ProviderFor(ClearRecentSearches)
final clearRecentSearchesProvider =
    AutoDisposeAsyncNotifierProvider<ClearRecentSearches, void>.internal(
  ClearRecentSearches.new,
  name: r'clearRecentSearchesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$clearRecentSearchesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ClearRecentSearches = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
