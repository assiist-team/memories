// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'capture_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dictationServiceHash() => r'93ad50543ea9d6633920c761d573865260e5dff9';

/// Provider for dictation service
///
/// Kept alive for the entire capture surface lifetime to ensure
/// stable lifecycle so mic events continue streaming.
///
/// CRITICAL: Read the feature flag with ref.read() instead of ref.watch()
/// to prevent the service from being recreated if the flag changes.
/// The flag should only be read once when the service is first created.
///
/// Copied from [dictationService].
@ProviderFor(dictationService)
final dictationServiceProvider = Provider<DictationService>.internal(
  dictationService,
  name: r'dictationServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$dictationServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DictationServiceRef = ProviderRef<DictationService>;
String _$waveformControllerHash() =>
    r'2eb5347834419178ad7c67db9e6ff9961f593f10';

/// Provider for waveform controller
///
/// Manages waveform visualization state for dictation.
/// Kept alive for the capture surface lifetime.
///
/// Copied from [waveformController].
@ProviderFor(waveformController)
final waveformControllerProvider = Provider<WaveformController>.internal(
  waveformController,
  name: r'waveformControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$waveformControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WaveformControllerRef = ProviderRef<WaveformController>;
String _$geolocationServiceHash() =>
    r'05dd867526d104eaa2a329fe4982be9c281ae68f';

/// Provider for geolocation service
///
/// Copied from [geolocationService].
@ProviderFor(geolocationService)
final geolocationServiceProvider =
    AutoDisposeProvider<GeolocationService>.internal(
  geolocationService,
  name: r'geolocationServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$geolocationServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GeolocationServiceRef = AutoDisposeProviderRef<GeolocationService>;
String _$captureStateNotifierHash() =>
    r'00e36c1f6009c72836b1b73d8fa2b09f0e251d67';

/// Provider for capture state
///
/// Manages the state of the unified capture sheet including:
/// - Memory type selection (Moment/Story/Memento)
/// - Dictation transcript
/// - Description text
/// - Media attachments (photos/videos)
/// - Tags
/// - Dictation status
///
/// Copied from [CaptureStateNotifier].
@ProviderFor(CaptureStateNotifier)
final captureStateNotifierProvider =
    AutoDisposeNotifierProvider<CaptureStateNotifier, CaptureState>.internal(
  CaptureStateNotifier.new,
  name: r'captureStateNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$captureStateNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CaptureStateNotifier = AutoDisposeNotifier<CaptureState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
