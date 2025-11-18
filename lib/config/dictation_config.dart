/// Project-level configuration for dictation behavior
/// 
/// This allows each project to decide whether to enable preserved audio
/// without editing the plugin code. For Memories, we enable preserved audio
/// by default so Stories can save audio files.
class DictationConfig {
  /// Whether to enable preserved audio (audio file saving)
  /// 
  /// When true, the dictation plugin will save audio files to disk
  /// and provide file paths via the audioFile callback.
  /// This is required for Story memory types that need audio persistence.
  final bool enablePreservedAudio;

  const DictationConfig({
    required this.enablePreservedAudio,
  });

  /// Default configuration for Memories app
  /// 
  /// Enables preserved audio by default since Stories require audio files
  static const DictationConfig memories = DictationConfig(
    enablePreservedAudio: true,
  );
}

