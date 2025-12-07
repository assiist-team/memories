import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:memories/config/dictation_config.dart';

part 'feature_flags_provider.g.dart';

/// Project-level dictation configuration provider
///
/// Provides the dictation config for the Memories app.
/// Other projects can override this provider to customize behavior.
@riverpod
DictationConfig dictationConfig(DictationConfigRef ref) {
  return DictationConfig.memories;
}

/// Feature flag for the new dictation plugin behavior.
///
/// For the Memories app, we always use the new dictation plugin as defined
/// by the project-level `DictationConfig`. There is no per-device/manual
/// override – this returns the same value for all users of this build.
@riverpod
Future<bool> useNewDictationPlugin(UseNewDictationPluginRef ref) async {
  final config = ref.watch(dictationConfigProvider);
  return config.enablePreservedAudio;
}

/// Synchronous provider that watches the async feature flag
/// Returns false if the async provider is loading or has an error
/// CRITICAL: This must be keepAlive to prevent dictation service from being recreated mid-session
@Riverpod(keepAlive: true)
bool useNewDictationPluginSync(UseNewDictationPluginSyncRef ref) {
  final asyncValue = ref.watch(useNewDictationPluginProvider);
  final config = ref.watch(dictationConfigProvider);

  // If the async feature flag has resolved, prefer it.
  if (asyncValue.hasValue && asyncValue.value != null) {
    return asyncValue.value!;
  }

  // While loading or on error, fall back to the project-level default so
  // Memories enables preserved audio/new plugin behavior by default.
  return config.enablePreservedAudio;
}
