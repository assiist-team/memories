import 'package:flutter/foundation.dart';
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
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('[GeolocationService] Location services enabled: $serviceEnabled');
      if (!serviceEnabled) {
        debugPrint('[GeolocationService] Location services are disabled');
        return null;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('[GeolocationService] Current permission status: $permission');
      
      if (permission == LocationPermission.denied) {
        // Request permission
        debugPrint('[GeolocationService] Requesting location permission...');
        permission = await Geolocator.requestPermission();
        debugPrint('[GeolocationService] Permission request result: $permission');
        if (permission == LocationPermission.denied) {
          debugPrint('[GeolocationService] Permission denied by user');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[GeolocationService] Permission denied forever - user must enable in settings');
        return null;
      }

      // Get current position
      debugPrint('[GeolocationService] Attempting to get current position...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      debugPrint('[GeolocationService] Successfully obtained position: lat=${position.latitude}, lng=${position.longitude}');
      return position;
    } catch (e, stackTrace) {
      // Log error details for debugging
      debugPrint('[GeolocationService] Error getting current position: $e');
      debugPrint('[GeolocationService] Stack trace: $stackTrace');
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
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('[GeolocationService] Checking location status - services enabled: $serviceEnabled');
      if (!serviceEnabled) {
        debugPrint('[GeolocationService] Status: unavailable (services disabled)');
        return 'unavailable';
      }

      final permission = await Geolocator.checkPermission();
      debugPrint('[GeolocationService] Permission status: $permission');
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[GeolocationService] Status: denied');
        return 'denied';
      }

      // Try to get position to confirm it's actually available
      debugPrint('[GeolocationService] Verifying location availability by getting position...');
      final position = await getCurrentPosition();
      final status = position != null ? 'granted' : 'unavailable';
      debugPrint('[GeolocationService] Final status: $status');
      return status;
    } catch (e, stackTrace) {
      debugPrint('[GeolocationService] Error getting location status: $e');
      debugPrint('[GeolocationService] Stack trace: $stackTrace');
      return 'unavailable';
    }
  }
}

