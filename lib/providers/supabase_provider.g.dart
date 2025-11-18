// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supabase_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$supabaseUrlHash() => r'2417ff925836d3ef2bd7c68622e664c40cf9d8b3';

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
String _$supabaseAnonKeyHash() => r'9f556cffac373f7584c4945bbc9015647b3dab3b';

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
String _$supabaseClientHash() => r'5fc18958064a78b37cd181d96e6df4582ed77148';

/// Provider for the single Supabase client instance
///
/// This provider creates and maintains a single Supabase client instance
/// that is shared app-wide. It uses the anon key for client-side operations
/// and relies on RLS policies for authorization.
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
