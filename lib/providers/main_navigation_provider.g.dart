// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main_navigation_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$mainNavigationTabNotifierHash() =>
    r'1ead4497ea5a0e313513b328bdc33a141813f831';

/// Provider for managing the selected tab in MainNavigationShell
///
/// Allows any screen to switch to a different tab programmatically.
///
/// Copied from [MainNavigationTabNotifier].
@ProviderFor(MainNavigationTabNotifier)
final mainNavigationTabNotifierProvider = AutoDisposeNotifierProvider<
    MainNavigationTabNotifier, MainNavigationTab>.internal(
  MainNavigationTabNotifier.new,
  name: r'mainNavigationTabNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$mainNavigationTabNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MainNavigationTabNotifier = AutoDisposeNotifier<MainNavigationTab>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
