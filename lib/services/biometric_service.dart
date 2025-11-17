import 'dart:io';
import 'package:local_auth/local_auth.dart';

/// Service for managing biometric authentication
/// 
/// Provides functionality to:
/// - Detect available biometric types (Face ID, Touch ID, Fingerprint)
/// - Authenticate users with biometrics
/// - Get user-friendly names for biometric types
class BiometricService {
  final LocalAuthentication _localAuth;

  BiometricService([LocalAuthentication? localAuth])
      : _localAuth = localAuth ?? LocalAuthentication();

  /// Check if biometric authentication is available on the device
  Future<bool> isAvailable() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) {
        return false;
      }

      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) {
        return false;
      }

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      // If any error occurs, assume biometrics are not available
      return false;
    }
  }

  /// Get the available biometric type on the device
  /// 
  /// Returns the biometric type, preferring Face ID over Fingerprint.
  /// Returns null if no biometrics are available.
  Future<BiometricType?> getAvailableBiometricType() async {
    try {
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      if (availableBiometrics.isEmpty) {
        return null;
      }

      // Prefer Face ID over Fingerprint
      if (availableBiometrics.contains(BiometricType.face)) {
        return BiometricType.face;
      }

      if (availableBiometrics.contains(BiometricType.fingerprint)) {
        return BiometricType.fingerprint;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Authenticate the user using biometrics
  /// 
  /// [reason] is the message shown to the user explaining why authentication is needed.
  /// Returns true if authentication succeeds, false otherwise.
  Future<bool> authenticate({
    required String reason,
  }) async {
    try {
      final isAvailable = await this.isAvailable();
      if (!isAvailable) {
        return false;
      }

      final result = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      return result;
    } catch (e) {
      // Handle any errors gracefully - return false to allow fallback to password
      return false;
    }
  }

  /// Get a user-friendly name for a biometric type
  /// 
  /// Returns platform-appropriate names:
  /// - Face ID on iOS
  /// - Touch ID on iOS (for fingerprint)
  /// - Fingerprint on Android
  String getBiometricTypeName(BiometricType type) {
    if (type == BiometricType.face) {
      return 'Face ID';
    }

    if (type == BiometricType.fingerprint) {
      if (Platform.isIOS) {
        return 'Touch ID';
      } else {
        return 'Fingerprint';
      }
    }

    return 'Biometric';
  }

  /// Get a user-friendly name for the available biometric type on this device
  /// 
  /// Returns null if no biometrics are available.
  Future<String?> getAvailableBiometricTypeName() async {
    final type = await getAvailableBiometricType();
    if (type == null) {
      return null;
    }
    return getBiometricTypeName(type);
  }
}

