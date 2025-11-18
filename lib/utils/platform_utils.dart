import 'dart:io';
import 'package:flutter/foundation.dart';

/// Platform utility functions for detecting runtime environment
class PlatformUtils {
  /// Returns true if running on iOS simulator
  /// 
  /// AVAudioEngine (used by audio_waveforms) is unreliable on iOS simulators,
  /// especially on Apple Silicon. This guard helps disable dictation features
  /// or show explanatory messages when running on unsupported targets.
  /// 
  /// Detection is based on the presence of the SIMULATOR_DEVICE_NAME environment
  /// variable, which is set by the iOS simulator runtime.
  static bool get isSimulator {
    if (Platform.isIOS && !kIsWeb) {
      // Check for simulator environment variable
      return Platform.environment['SIMULATOR_DEVICE_NAME'] != null;
    }
    return false;
  }
  
  /// Returns true if dictation is supported on the current platform
  /// 
  /// Dictation requires:
  /// - iOS platform (not web)
  /// - Physical device (not simulator)
  static bool get isDictationSupported {
    return Platform.isIOS && !kIsWeb && !isSimulator;
  }
}

