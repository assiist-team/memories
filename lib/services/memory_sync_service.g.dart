// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_sync_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$memorySyncServiceHash() => r'13724bdb2a6cd5d9c52e2172e97fd3e861f3fe1f';

/// Service for syncing queued memories (moments, mementos, and stories) to the server
///
/// Handles automatic retry with exponential backoff for all memory types
/// stored in the offline queues (moments/mementos and stories).
///
/// Copied from [memorySyncService].
@ProviderFor(memorySyncService)
final memorySyncServiceProvider =
    AutoDisposeProvider<MemorySyncService>.internal(
  memorySyncService,
  name: r'memorySyncServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$memorySyncServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MemorySyncServiceRef = AutoDisposeProviderRef<MemorySyncService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
