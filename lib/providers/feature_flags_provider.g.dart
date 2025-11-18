// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feature_flags_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dictationConfigHash() => r'099ee18c0c77ce86f3fe63c9a27bbcfbcbe8d110';

/// Project-level dictation configuration provider
///
/// Provides the dictation config for the Memories app.
/// Other projects can override this provider to customize behavior.
///
/// Copied from [dictationConfig].
@ProviderFor(dictationConfig)
final dictationConfigProvider = AutoDisposeProvider<DictationConfig>.internal(
  dictationConfig,
  name: r'dictationConfigProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$dictationConfigHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DictationConfigRef = AutoDisposeProviderRef<DictationConfig>;
String _$useNewDictationPluginHash() =>
    r'df7e78a5698ebffe98a021e6a029434b1a507258';

/// Feature flag for the new dictation plugin behavior
///
/// Precedence order:
/// 1. Manual override stored under `feature_flag_new_dictation_plugin` (for QA/testing)
/// 2. Default from `DictationConfig.enablePreservedAudio` (project-level config)
///
/// When enabled, uses the latest plugin build that surfaces raw-audio references
/// along with streaming transcripts/event channels.
///
/// Copied from [useNewDictationPlugin].
@ProviderFor(useNewDictationPlugin)
final useNewDictationPluginProvider = AutoDisposeFutureProvider<bool>.internal(
  useNewDictationPlugin,
  name: r'useNewDictationPluginProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$useNewDictationPluginHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UseNewDictationPluginRef = AutoDisposeFutureProviderRef<bool>;
String _$useNewDictationPluginSyncHash() =>
    r'be32ca2dba1813dd21df7d05811c839266322c41';

/// Synchronous provider that watches the async feature flag
/// Returns false if the async provider is loading or has an error
/// CRITICAL: This must be keepAlive to prevent dictation service from being recreated mid-session
///
/// Copied from [useNewDictationPluginSync].
@ProviderFor(useNewDictationPluginSync)
final useNewDictationPluginSyncProvider = Provider<bool>.internal(
  useNewDictationPluginSync,
  name: r'useNewDictationPluginSyncProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$useNewDictationPluginSyncHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UseNewDictationPluginSyncRef = ProviderRef<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
