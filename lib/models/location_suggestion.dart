/// Model representing a location suggestion from forward geocoding
/// 
/// Used for typeahead suggestions in the location picker.
/// This converts cleanly into MemoryLocationData when a suggestion is chosen.
class LocationSuggestion {
  final String displayName;
  final String? city;
  final String? state;
  final String? country;
  final double latitude;
  final double longitude;
  final String? provider;

  LocationSuggestion({
    required this.displayName,
    this.city,
    this.state,
    this.country,
    required this.latitude,
    required this.longitude,
    this.provider,
  });

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    return LocationSuggestion(
      displayName: json['display_name'] as String,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      provider: json['provider'] as String?,
    );
  }

  /// Convert to MemoryLocationData format
  /// 
  /// Sets source to 'manual_with_suggestion' to indicate the user
  /// selected this from a suggestion list
  Map<String, dynamic> toMemoryLocationDataJson() {
    return {
      'display_name': displayName,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (country != null) 'country': country,
      'latitude': latitude,
      'longitude': longitude,
      if (provider != null) 'provider': provider,
      'source': 'manual_with_suggestion',
    };
  }

  /// Get a secondary display line (e.g., "City, Country")
  String? get secondaryLine {
    if (city != null && country != null) {
      return '$city, $country';
    } else if (city != null) {
      return city;
    } else if (state != null && country != null) {
      return '$state, $country';
    } else if (state != null) {
      return state;
    } else if (country != null) {
      return country;
    }
    return null;
  }
}

