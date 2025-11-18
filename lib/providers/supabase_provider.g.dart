// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supabase_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$supabaseUrlHash() => r'f09e8478a2847fdcd73f4688d295e09ee42d1bc2';

/// Provider for Supabase URL from .env file
///
/// Copied from [supabaseUrl].
@ProviderFor(supabaseUrl)
final supabaseUrlProvider = AutoDisposeProvider<String>.internal(
  supabaseUrl,
  name: r'supabaseUrlProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$supabaseUrlHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SupabaseUrlRef = AutoDisposeProviderRef<String>;
String _$supabaseAnonKeyHash() => r'bc6aa3157c99ab265580e649e356167f3f48ff04';

/// Provider for Supabase anonymous key from .env file
///
/// Copied from [supabaseAnonKey].
@ProviderFor(supabaseAnonKey)
final supabaseAnonKeyProvider = AutoDisposeProvider<String>.internal(
  supabaseAnonKey,
  name: r'supabaseAnonKeyProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$supabaseAnonKeyHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SupabaseAnonKeyRef = AutoDisposeProviderRef<String>;
String _$supabaseClientHash() => r'36e9cae00709545a85bfe4a5a2cb98d8686a01ea';

/// Provider for the single Supabase client instance
///
/// This provider returns the Supabase client instance that was initialized
/// in main.dart. It uses the anon key for client-side operations
/// and relies on RLS policies for authorization.
///
/// The client is initialized with asyncStorage (FlutterSecureStorage) to
/// support OAuth PKCE flows.
///
/// Copied from [supabaseClient].
@ProviderFor(supabaseClient)
final supabaseClientProvider = AutoDisposeProvider<SupabaseClient>.internal(
  supabaseClient,
  name: r'supabaseClientProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$supabaseClientHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SupabaseClientRef = AutoDisposeProviderRef<SupabaseClient>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
