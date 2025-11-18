import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Feature flag for the new dictation plugin behavior
/// 
/// Precedence order:
/// 1. Manual override stored under `feature_flag_new_dictation_plugin` (for QA/testing)
/// 2. Default from `DictationConfig.enablePreservedAudio` (project-level config)
/// 
/// When enabled, uses the latest plugin build that surfaces raw-audio references
/// along with streaming transcripts/event channels.
@riverpod
Future<bool> useNewDictationPlugin(UseNewDictationPluginRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final manualOverride = prefs.getBool('feature_flag_new_dictation_plugin');
  
  // If manual override exists, use it
  if (manualOverride != null) {
    return manualOverride;
  }
  
  // Otherwise, use project-level config default
  final config = ref.watch(dictationConfigProvider);
  return config.enablePreservedAudio;
}

/// Synchronous provider that watches the async feature flag
/// Returns false if the async provider is loading or has an error
/// CRITICAL: This must be keepAlive to prevent dictation service from being recreated mid-session
@Riverpod(keepAlive: true)
bool useNewDictationPluginSync(UseNewDictationPluginSyncRef ref) {
  final asyncValue = ref.watch(useNewDictationPluginProvider);
  return asyncValue.valueOrNull ?? false;
}

/// Set the new dictation plugin feature flag
Future<void> setUseNewDictationPlugin(bool enabled) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('feature_flag_new_dictation_plugin', enabled);
}

