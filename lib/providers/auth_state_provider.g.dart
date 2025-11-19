// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$secureStorageServiceHash() =>
    r'28ef5a96de61720fa06a7ba59ceb572a1791b078';

/// Provider for secure storage service
///
/// Copied from [secureStorageService].
@ProviderFor(secureStorageService)
final secureStorageServiceProvider =
    AutoDisposeProvider<SecureStorageService>.internal(
  secureStorageService,
  name: r'secureStorageServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$secureStorageServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SecureStorageServiceRef = AutoDisposeProviderRef<SecureStorageService>;
String _$authStateHash() => r'dc168b2b29a6b2ba6a33493596badb2eb25968b3';

/// Provider that listens to Supabase auth state changes and determines routing
///
/// This provider:
/// - Listens to auth state changes from Supabase
/// - Determines the appropriate route state based on user authentication,
///   email verification, and onboarding completion
/// - Handles session refresh and expiration
/// - Persists session tokens securely
///
/// Copied from [authState].
@ProviderFor(authState)
final authStateProvider = AutoDisposeStreamProvider<AuthRoutingState>.internal(
  authState,
  name: r'authStateProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthStateRef = AutoDisposeStreamProviderRef<AuthRoutingState>;
String _$currentAuthStateHash() => r'65e6e8dc09e2b32d8c84cf3c40c2e1f41bae342e';

/// Provider for current auth routing state (non-stream, synchronous access)
///
/// Note: This provider watches the auth state stream. In practice, you may want
/// to use AsyncValue or a StateNotifier to track the latest state more explicitly.
/// For now, components should watch authStateProvider directly to get stream updates.
///
/// Copied from [currentAuthState].
@ProviderFor(currentAuthState)
final currentAuthStateProvider =
    AutoDisposeStreamProvider<AuthRoutingState>.internal(
  currentAuthState,
  name: r'currentAuthStateProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentAuthStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentAuthStateRef = AutoDisposeStreamProviderRef<AuthRoutingState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
