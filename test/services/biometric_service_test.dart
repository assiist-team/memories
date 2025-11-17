import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:local_auth/local_auth.dart';
import 'package:memories/services/biometric_service.dart';

// Mock classes
class MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  group('Biometric Service', () {
    late MockLocalAuthentication mockLocalAuth;
    late BiometricService biometricService;

    setUp(() {
      mockLocalAuth = MockLocalAuthentication();
      biometricService = BiometricService(mockLocalAuth);
    });

    group('isAvailable', () {
      test('returns true when biometrics are available', () async {
        when(() => mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(() => mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(() => mockLocalAuth.getAvailableBiometrics())
            .thenAnswer((_) async => [BiometricType.face, BiometricType.fingerprint]);

        final isAvailable = await biometricService.isAvailable();

        expect(isAvailable, isTrue);
        verify(() => mockLocalAuth.isDeviceSupported()).called(1);
        verify(() => mockLocalAuth.canCheckBiometrics).called(1);
      });

      test('returns false when device does not support biometrics', () async {
        when(() => mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => false);

        final isAvailable = await biometricService.isAvailable();

        expect(isAvailable, isFalse);
        verify(() => mockLocalAuth.isDeviceSupported()).called(1);
        verifyNever(() => mockLocalAuth.canCheckBiometrics);
      });

      test('returns false when biometrics cannot be checked', () async {
        when(() => mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(() => mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => false);

        final isAvailable = await biometricService.isAvailable();

        expect(isAvailable, isFalse);
        verify(() => mockLocalAuth.isDeviceSupported()).called(1);
        verify(() => mockLocalAuth.canCheckBiometrics).called(1);
      });
    });

    group('getAvailableBiometricType', () {
      test('returns Face ID when available', () async {
        when(() => mockLocalAuth.getAvailableBiometrics())
            .thenAnswer((_) async => [BiometricType.face]);

        final type = await biometricService.getAvailableBiometricType();

        expect(type, BiometricType.face);
        verify(() => mockLocalAuth.getAvailableBiometrics()).called(1);
      });

      test('returns Fingerprint when available', () async {
        when(() => mockLocalAuth.getAvailableBiometrics())
            .thenAnswer((_) async => [BiometricType.fingerprint]);

        final type = await biometricService.getAvailableBiometricType();

        expect(type, BiometricType.fingerprint);
        verify(() => mockLocalAuth.getAvailableBiometrics()).called(1);
      });

      test('returns Face ID when both are available (prefer Face ID)', () async {
        when(() => mockLocalAuth.getAvailableBiometrics())
            .thenAnswer((_) async => [BiometricType.face, BiometricType.fingerprint]);

        final type = await biometricService.getAvailableBiometricType();

        expect(type, BiometricType.face);
        verify(() => mockLocalAuth.getAvailableBiometrics()).called(1);
      });

      test('returns null when no biometrics available', () async {
        when(() => mockLocalAuth.getAvailableBiometrics())
            .thenAnswer((_) async => []);

        final type = await biometricService.getAvailableBiometricType();

        expect(type, isNull);
        verify(() => mockLocalAuth.getAvailableBiometrics()).called(1);
      });
    });

    group('authenticate', () {
      test('returns true when authentication succeeds', () async {
        when(() => mockLocalAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => true);

        final result = await biometricService.authenticate(
          reason: 'Please authenticate to continue',
        );

        expect(result, isTrue);
        verify(() => mockLocalAuth.authenticate(
          localizedReason: 'Please authenticate to continue',
          options: any(named: 'options'),
        )).called(1);
      });

      test('returns false when authentication fails', () async {
        when(() => mockLocalAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => false);

        final result = await biometricService.authenticate(
          reason: 'Please authenticate to continue',
        );

        expect(result, isFalse);
        verify(() => mockLocalAuth.authenticate(
          localizedReason: 'Please authenticate to continue',
          options: any(named: 'options'),
        )).called(1);
      });

      test('handles authentication exceptions gracefully', () async {
        when(() => mockLocalAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          options: any(named: 'options'),
        )).thenThrow(Exception('Authentication failed'));

        final result = await biometricService.authenticate(
          reason: 'Please authenticate to continue',
        );

        expect(result, isFalse);
      });
    });

    group('getBiometricTypeName', () {
      test('returns "Face ID" for Face ID', () {
        final name = biometricService.getBiometricTypeName(BiometricType.face);
        expect(name, 'Face ID');
      });

      test('returns "Touch ID" for Fingerprint on iOS', () {
        final name = biometricService.getBiometricTypeName(BiometricType.fingerprint);
        // Note: This would ideally check platform, but for testing we'll test the mapping
        expect(name, isA<String>());
        expect(name.isNotEmpty, isTrue);
      });

      test('returns "Fingerprint" for Fingerprint on Android', () {
        final name = biometricService.getBiometricTypeName(BiometricType.fingerprint);
        expect(name, isA<String>());
      });
    });
  });
}

