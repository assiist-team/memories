import 'package:memories/models/memory_detail.dart';
import 'package:memories/providers/supabase_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'location_lookup_service.g.dart';

/// Service for reverse geocoding coordinates to place information
/// 
/// Calls the Supabase Edge Function to convert lat/lng to structured place data
@riverpod
LocationLookupService locationLookupService(LocationLookupServiceRef ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return LocationLookupService(supabase);
}

class LocationLookupService {
  final SupabaseClient _supabase;
  static const Duration _timeout = Duration(seconds: 10);

  LocationLookupService(this._supabase);

  /// Reverse geocode coordinates to place information
  /// 
  /// Returns MemoryLocationData with display_name, city, state, country, etc.
  /// Returns null if geocoding fails or coordinates are invalid
  /// 
  /// Throws exception on network errors or invalid responses
  Future<MemoryLocationData?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    // Validate coordinates
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      throw ArgumentError('Invalid coordinates: lat=$latitude, lng=$longitude');
    }

    try {
      final response = await _supabase.functions
          .invoke(
            'reverse-geocode-location',
            body: {
              'latitude': latitude,
              'longitude': longitude,
            },
          )
          .timeout(_timeout);

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage = errorData?['message'] as String? ?? 
            'Reverse geocoding failed with status ${response.status}';
        throw Exception(errorMessage);
      }

      final data = response.data as Map<String, dynamic>?;
      if (data == null) {
        return null;
      }

      return MemoryLocationData.fromJson(data);
    } catch (e) {
      // Re-throw with context
      if (e is ArgumentError) {
        rethrow;
      }
      throw Exception('Failed to reverse geocode location: $e');
    }
  }
}

