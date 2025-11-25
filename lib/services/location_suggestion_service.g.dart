// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_suggestion_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$locationSuggestionServiceHash() =>
    r'b90da5a44798b419d45199f48a774c7160d8bf2d';

/// Service for forward geocoding / place search suggestions
///
/// Calls the Supabase Edge Function to search for places based on text queries.
/// Provides debounced search functionality for typeahead suggestions.
///
/// Copied from [locationSuggestionService].
@ProviderFor(locationSuggestionService)
final locationSuggestionServiceProvider =
    AutoDisposeProvider<LocationSuggestionService>.internal(
  locationSuggestionService,
  name: r'locationSuggestionServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$locationSuggestionServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LocationSuggestionServiceRef
    = AutoDisposeProviderRef<LocationSuggestionService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
