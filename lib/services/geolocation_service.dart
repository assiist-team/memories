import 'package:geolocator/geolocator.dart';

/// Service for capturing geolocation data
/// 
/// Handles permission requests and location capture for memory metadata
class GeolocationService {
  /// Request location permissions and get current position
  /// 
  /// Returns:
  /// - Position if permission granted and location available
  /// - null if permission denied or location unavailable
  /// 
  /// Throws exception if there's an error during location capture
  Future<Position?> getCurrentPosition() async {
    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    // Check location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    // Get current position
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      return position;
    } catch (e) {
      // Return null if location capture fails
      return null;
    }
  }

  /// Get location status string for storage
  /// 
  /// Returns:
  /// - "granted" if location was successfully captured
  /// - "denied" if permission was denied
  /// - "unavailable" if location services are disabled or unavailable
  Future<String> getLocationStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return 'unavailable';
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return 'denied';
    }

    // Try to get position to confirm it's actually available
    try {
      final position = await getCurrentPosition();
      return position != null ? 'granted' : 'unavailable';
    } catch (e) {
      return 'unavailable';
    }
  }
}

