// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_timeline_update_bus_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$memoryTimelineUpdateBusHash() =>
    r'315011a327ab58315a8d112b810f7c9c7cc58dd9';

/// Provider for the memory timeline update bus
///
/// Kept alive so all parts of the app (timeline, capture, detail) share
/// a single global bus instance. This prevents events from being missed
/// due to provider disposal or separate instances per scope.
///
/// Copied from [memoryTimelineUpdateBus].
@ProviderFor(memoryTimelineUpdateBus)
final memoryTimelineUpdateBusProvider =
    Provider<MemoryTimelineUpdateBus>.internal(
  memoryTimelineUpdateBus,
  name: r'memoryTimelineUpdateBusProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$memoryTimelineUpdateBusHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MemoryTimelineUpdateBusRef = ProviderRef<MemoryTimelineUpdateBus>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
