// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$memoryDetailServiceHash() =>
    r'192ac4a3deac17d9b4f3368eb88914bbd1da1038';

/// Provider for memory detail service
///
/// Copied from [memoryDetailService].
@ProviderFor(memoryDetailService)
final memoryDetailServiceProvider =
    AutoDisposeProvider<MemoryDetailService>.internal(
  memoryDetailService,
  name: r'memoryDetailServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$memoryDetailServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MemoryDetailServiceRef = AutoDisposeProviderRef<MemoryDetailService>;
String _$memoryDetailNotifierHash() =>
    r'bdc5023edb89db53ef56b7346993033a04394204';

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

abstract class _$MemoryDetailNotifier
    extends BuildlessAutoDisposeNotifier<MemoryDetailViewState> {
  late final String memoryId;

  MemoryDetailViewState build(
    String memoryId,
  );
}

/// Provider for memory detail state
///
/// [memoryId] is the UUID of the memory to fetch
///
/// Copied from [MemoryDetailNotifier].
@ProviderFor(MemoryDetailNotifier)
const memoryDetailNotifierProvider = MemoryDetailNotifierFamily();

/// Provider for memory detail state
///
/// [memoryId] is the UUID of the memory to fetch
///
/// Copied from [MemoryDetailNotifier].
class MemoryDetailNotifierFamily extends Family<MemoryDetailViewState> {
  /// Provider for memory detail state
  ///
  /// [memoryId] is the UUID of the memory to fetch
  ///
  /// Copied from [MemoryDetailNotifier].
  const MemoryDetailNotifierFamily();

  /// Provider for memory detail state
  ///
  /// [memoryId] is the UUID of the memory to fetch
  ///
  /// Copied from [MemoryDetailNotifier].
  MemoryDetailNotifierProvider call(
    String memoryId,
  ) {
    return MemoryDetailNotifierProvider(
      memoryId,
    );
  }

  @override
  MemoryDetailNotifierProvider getProviderOverride(
    covariant MemoryDetailNotifierProvider provider,
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
  String? get name => r'memoryDetailNotifierProvider';
}

/// Provider for memory detail state
///
/// [memoryId] is the UUID of the memory to fetch
///
/// Copied from [MemoryDetailNotifier].
class MemoryDetailNotifierProvider extends AutoDisposeNotifierProviderImpl<
    MemoryDetailNotifier, MemoryDetailViewState> {
  /// Provider for memory detail state
  ///
  /// [memoryId] is the UUID of the memory to fetch
  ///
  /// Copied from [MemoryDetailNotifier].
  MemoryDetailNotifierProvider(
    String memoryId,
  ) : this._internal(
          () => MemoryDetailNotifier()..memoryId = memoryId,
          from: memoryDetailNotifierProvider,
          name: r'memoryDetailNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$memoryDetailNotifierHash,
          dependencies: MemoryDetailNotifierFamily._dependencies,
          allTransitiveDependencies:
              MemoryDetailNotifierFamily._allTransitiveDependencies,
          memoryId: memoryId,
        );

  MemoryDetailNotifierProvider._internal(
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
  MemoryDetailViewState runNotifierBuild(
    covariant MemoryDetailNotifier notifier,
  ) {
    return notifier.build(
      memoryId,
    );
  }

  @override
  Override overrideWith(MemoryDetailNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: MemoryDetailNotifierProvider._internal(
        () => create()..memoryId = memoryId,
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
  AutoDisposeNotifierProviderElement<MemoryDetailNotifier,
      MemoryDetailViewState> createElement() {
    return _MemoryDetailNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MemoryDetailNotifierProvider && other.memoryId == memoryId;
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
mixin MemoryDetailNotifierRef
    on AutoDisposeNotifierProviderRef<MemoryDetailViewState> {
  /// The parameter `memoryId` of this provider.
  String get memoryId;
}

class _MemoryDetailNotifierProviderElement
    extends AutoDisposeNotifierProviderElement<MemoryDetailNotifier,
        MemoryDetailViewState> with MemoryDetailNotifierRef {
  _MemoryDetailNotifierProviderElement(super.provider);

  @override
  String get memoryId => (origin as MemoryDetailNotifierProvider).memoryId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
