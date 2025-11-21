// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shared_preferences_local_memory_preview_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$localMemoryPreviewStoreHash() =>
    r'8e2273e0720dfc9a1894a81107cf78b4a67a209a';

/// SharedPreferences-based implementation of LocalMemoryPreviewStore
///
/// Stores preview entries in SharedPreferences as JSON, following the same
/// pattern as OfflineQueueService and OfflineStoryQueueService.
///
/// Copied from [localMemoryPreviewStore].
@ProviderFor(localMemoryPreviewStore)
final localMemoryPreviewStoreProvider =
    AutoDisposeProvider<SharedPreferencesLocalMemoryPreviewStore>.internal(
  localMemoryPreviewStore,
  name: r'localMemoryPreviewStoreProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$localMemoryPreviewStoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LocalMemoryPreviewStoreRef
    = AutoDisposeProviderRef<SharedPreferencesLocalMemoryPreviewStore>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
