import 'dart:async';
import 'package:memories/models/location_suggestion.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'location_suggestion_service.g.dart';

/// Service for forward geocoding / place search suggestions
/// 
/// Calls the Supabase Edge Function to search for places based on text queries.
/// Provides debounced search functionality for typeahead suggestions.
@riverpod
LocationSuggestionService locationSuggestionService(LocationSuggestionServiceRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return LocationSuggestionService(supabase);
}

class LocationSuggestionService {
  final SupabaseClient _supabase;
  static const Duration _timeout = Duration(seconds: 10);
  
  // Debounce timer for search queries
  Timer? _debounceTimer;

  LocationSuggestionService(this._supabase);

  /// Search for places based on a text query
  /// 
  /// [query] - The search query (minimum 2 characters)
  /// [limit] - Maximum number of results (default: 5, max: 10)
  /// [userLocation] - Optional user location to bias results toward nearby places
  /// 
  /// Returns a list of LocationSuggestion objects.
  /// Returns an empty list if search fails or query is too short.
  /// 
  /// Throws exception on network errors or invalid responses.
  Future<List<LocationSuggestion>> search({
    required String query,
    int limit = 5,
    ({double latitude, double longitude})? userLocation,
  }) async {
    // Validate query length
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) {
      return [];
    }

    // Validate limit
    final validLimit = limit.clamp(1, 10);

    try {
      final requestBody = <String, dynamic>{
        'query': trimmedQuery,
        'limit': validLimit,
      };

      // Add user location if provided
      if (userLocation != null) {
        requestBody['user_location'] = {
          'latitude': userLocation.latitude,
          'longitude': userLocation.longitude,
        };
      }

      final response = await _supabase.functions
          .invoke(
            'search-places',
            body: requestBody,
          )
          .timeout(_timeout);

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage = errorData?['message'] as String? ?? 
            'Place search failed with status ${response.status}';
        throw Exception(errorMessage);
      }

      final data = response.data as Map<String, dynamic>?;
      if (data == null) {
        return [];
      }

      final results = data['results'] as List<dynamic>?;
      if (results == null) {
        return [];
      }

      return results
          .map((item) => LocationSuggestion.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Log error but return empty list to allow graceful fallback
      // The UI will handle offline state separately
      if (e is TimeoutException) {
        throw Exception('Search request timed out');
      }
      throw Exception('Failed to search places: $e');
    }
  }

  /// Debounced search - useful for typeahead functionality
  /// 
  /// This method cancels any pending search and schedules a new one after [delay].
  /// Use this when the user is typing to avoid making too many API calls.
  /// 
  /// Returns a Future that completes with the search results.
  /// The previous debounced call is cancelled if a new one is made.
  Future<List<LocationSuggestion>> searchDebounced({
    required String query,
    int limit = 5,
    ({double latitude, double longitude})? userLocation,
    Duration delay = const Duration(milliseconds: 300),
  }) {
    // Cancel any pending debounced search
    _debounceTimer?.cancel();

    final completer = Completer<List<LocationSuggestion>>();

    _debounceTimer = Timer(delay, () async {
      try {
        final results = await search(
          query: query,
          limit: limit,
          userLocation: userLocation,
        );
        if (!completer.isCompleted) {
          completer.complete(results);
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
    });

    return completer.future;
  }

  /// Cancel any pending debounced search
  void cancelDebouncedSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Dispose resources
  void dispose() {
    cancelDebouncedSearch();
  }
}

