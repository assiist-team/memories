import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:memories/services/biometric_service.dart';

part 'biometric_provider.g.dart';

/// Provider for biometric service instance
@riverpod
BiometricService biometricService(BiometricServiceRef ref) {
  return BiometricService();
}

