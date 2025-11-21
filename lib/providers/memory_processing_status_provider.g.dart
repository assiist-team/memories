// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_processing_status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$memoryProcessingStatusServiceHash() =>
    r'7a5ad05071aff80379f85519f16bbc346459fa5e';

/// Provider for memory processing status service
///
/// Copied from [memoryProcessingStatusService].
@ProviderFor(memoryProcessingStatusService)
final memoryProcessingStatusServiceProvider =
    AutoDisposeProvider<MemoryProcessingStatusService>.internal(
  memoryProcessingStatusService,
  name: r'memoryProcessingStatusServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$memoryProcessingStatusServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MemoryProcessingStatusServiceRef
    = AutoDisposeProviderRef<MemoryProcessingStatusService>;
String _$memoryProcessingStatusStreamHash() =>
    r'029f34030333e6f6ea4a315d179df800aa4a1331';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Provider for a specific memory's processing status
///
/// Copied from [memoryProcessingStatusStream].
@ProviderFor(memoryProcessingStatusStream)
const memoryProcessingStatusStreamProvider =
    MemoryProcessingStatusStreamFamily();

/// Provider for a specific memory's processing status
///
/// Copied from [memoryProcessingStatusStream].
class MemoryProcessingStatusStreamFamily
    extends Family<AsyncValue<MemoryProcessingStatus?>> {
  /// Provider for a specific memory's processing status
  ///
  /// Copied from [memoryProcessingStatusStream].
  const MemoryProcessingStatusStreamFamily();

  /// Provider for a specific memory's processing status
  ///
  /// Copied from [memoryProcessingStatusStream].
  MemoryProcessingStatusStreamProvider call(
    String memoryId,
  ) {
    return MemoryProcessingStatusStreamProvider(
      memoryId,
    );
  }

  @override
  MemoryProcessingStatusStreamProvider getProviderOverride(
    covariant MemoryProcessingStatusStreamProvider provider,
  ) {
    return call(
      provider.memoryId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'memoryProcessingStatusStreamProvider';
}

/// Provider for a specific memory's processing status
///
/// Copied from [memoryProcessingStatusStream].
class MemoryProcessingStatusStreamProvider
    extends AutoDisposeStreamProvider<MemoryProcessingStatus?> {
  /// Provider for a specific memory's processing status
  ///
  /// Copied from [memoryProcessingStatusStream].
  MemoryProcessingStatusStreamProvider(
    String memoryId,
  ) : this._internal(
          (ref) => memoryProcessingStatusStream(
            ref as MemoryProcessingStatusStreamRef,
            memoryId,
          ),
          from: memoryProcessingStatusStreamProvider,
          name: r'memoryProcessingStatusStreamProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$memoryProcessingStatusStreamHash,
          dependencies: MemoryProcessingStatusStreamFamily._dependencies,
          allTransitiveDependencies:
              MemoryProcessingStatusStreamFamily._allTransitiveDependencies,
          memoryId: memoryId,
        );

  MemoryProcessingStatusStreamProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.memoryId,
  }) : super.internal();

  final String memoryId;

  @override
  Override overrideWith(
    Stream<MemoryProcessingStatus?> Function(
            MemoryProcessingStatusStreamRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MemoryProcessingStatusStreamProvider._internal(
        (ref) => create(ref as MemoryProcessingStatusStreamRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        memoryId: memoryId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<MemoryProcessingStatus?> createElement() {
    return _MemoryProcessingStatusStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MemoryProcessingStatusStreamProvider &&
        other.memoryId == memoryId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, memoryId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MemoryProcessingStatusStreamRef
    on AutoDisposeStreamProviderRef<MemoryProcessingStatus?> {
  /// The parameter `memoryId` of this provider.
  String get memoryId;
}

class _MemoryProcessingStatusStreamProviderElement
    extends AutoDisposeStreamProviderElement<MemoryProcessingStatus?>
    with MemoryProcessingStatusStreamRef {
  _MemoryProcessingStatusStreamProviderElement(super.provider);

  @override
  String get memoryId =>
      (origin as MemoryProcessingStatusStreamProvider).memoryId;
}

String _$activeProcessingStatusesStreamHash() =>
    r'04f07684599ac366aab6e0020afb058a4177f232';

/// Provider for all active processing statuses
///
/// Copied from [activeProcessingStatusesStream].
@ProviderFor(activeProcessingStatusesStream)
final activeProcessingStatusesStreamProvider =
    AutoDisposeStreamProvider<List<MemoryProcessingStatus>>.internal(
  activeProcessingStatusesStream,
  name: r'activeProcessingStatusesStreamProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$activeProcessingStatusesStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ActiveProcessingStatusesStreamRef
    = AutoDisposeStreamProviderRef<List<MemoryProcessingStatus>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
