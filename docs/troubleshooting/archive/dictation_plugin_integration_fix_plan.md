# Dictation Plugin Integration Status (Memories)

This single reference captures the fixes, open questions, and troubleshooting guidance for running the `flutter_dictation` plugin inside Memories. It replaces the older `audio_waveforms_plugin_bridge_fix.md` and `dictation_integration_troubleshooting.md` notes.

## Projects and Reference Apps

- **Memories app**: `/Users/benjaminmackenzie/Dev/memories`
- **Plugin + example app**: `/Users/benjaminmackenzie/Dev/flutter_dictation/example`
  - Before triaging Memories, run the example app. If the plugin fails there, fix it upstream first.

## Implementation Snapshot (18 Nov 2025)

| Area | Status | Details |
| --- | --- | --- |
| Service lifecycle | Complete | `lib/providers/capture_state_provider.dart` keeps `dictationServiceProvider` alive (`@Riverpod(keepAlive: true)`), reads the feature flag exactly once with `ref.read`, and pre-warms the native layer by calling `service.ensureInitialized()` when the provider is created. `CaptureStateNotifier.build()` watches the provider so the same instance survives for the capture surface lifetime. |
| Native dictation wrapper | Complete | `lib/services/dictation_service.dart` wraps `NativeDictationService`, exposes transcript/status/audio-level/error streams, maps plugin callbacks into app state, and passes `DictationSessionOptions(preserveAudio: true, deleteAudioIfCancelled: false)` whenever the `useNewPlugin` flag evaluates to true. |
| Project config + feature flag | Complete | `lib/config/dictation_config.dart` defaults Memories to `enablePreservedAudio: true`. `lib/providers/feature_flags_provider.dart` prefers a persisted override (`feature_flag_new_dictation_plugin`) before falling back to the config, and exposes `setUseNewDictationPlugin` for QA toggles without a rebuild. |
| Capture UI + plugin widgets | Complete | `_DictationControl` in `lib/screens/capture/capture_screen.dart` is gated to `TargetPlatform.iOS`, feeds the plugin `WaveformController`, and renders `AudioControlsDecorator` so waveform, timer, mic, and cancel affordances match the plugin README. Non‑iOS platforms receive an informational banner instead of unusable controls. |
| Audio persistence + queue integration | Complete | `CaptureStateNotifier` keeps a deterministic `sessionId`, pipes `audioLevelStream` into the waveform controller, and uses `AudioCacheService` (`lib/services/audio_cache_service.dart`) to persist the recorded `.m4a` so stories can be queued or retried. `stopDictation()` copies metadata into `state.audioDuration` and `state.audioPath`, letting save/queue flows enforce “audio required” rules. |
| Physical-device validation | Needs validation | Simulator runs remain flaky because `AVAudioEngine` frequently fails to start when embedded in the full Memories stack. Always test on a physical iOS device before closing bugs. |
| `audio_waveforms` registration | Needs verification | If Xcode logs `Undefined symbol: _OBJC_CLASS_$_AudioWaveformsPlugin`, add the local Objective‑C bridge described below and re-run `pod install`; otherwise builds will continue to fail with `use_frameworks!`. |

## Simulator vs Physical Device Behavior

`audio_waveforms` relies on `AVAudioEngine`, which is notoriously unreliable on the iOS simulator (especially on Apple Silicon). Typical simulator-only symptoms:

- `startListening` returns immediately with `AUDIO_ENGINE_ERROR`.
- Waveform never animates even though callbacks fire in the plugin example.
- Permission dialog randomly fails to appear.

Treat simulator failures as noise unless they also reproduce on:

1. `/Users/benjaminmackenzie/Dev/flutter_dictation/example` running in the same simulator.
2. A physical device connected via `flutter run -d <device-id>`.

Add a lightweight simulator detector so the UI can show clearer messaging when dictation is unavailable:

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';

bool get isSimulator {
  if (Platform.isIOS && !kIsWeb) {
    return Platform.environment['SIMULATOR_DEVICE_NAME'] != null ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
  return false;
}
```

**Status: Implemented** — Added `lib/utils/platform_utils.dart` and integrated the guard into `lib/screens/capture/capture_screen.dart` to disable the microphone button and show an explanatory banner when running on the iOS Simulator.

Use this guard to disable the mic button or to show an explanatory banner when running on unsupported targets.

## Troubleshooting Playbook

### 1. Service lifecycle mistakes

- **Wrong:** Watching feature flags causes the provider to rebuild mid-session, disposing the native service.

```dart
@Riverpod(keepAlive: true)
DictationService dictationService(DictationServiceRef ref) {
  final useNewPlugin = ref.watch(useNewDictationPluginSyncProvider); // wrong
  return DictationService(useNewPlugin: useNewPlugin);
}
```

- **Correct:** Read the flag once when the provider is created, pre-warm the native layer, and dispose only when the capture surface unmounts.

```dart
@Riverpod(keepAlive: true)
DictationService dictationService(DictationServiceRef ref) {
  final useNewPlugin = ref.read(useNewDictationPluginSyncProvider);
  final service = DictationService(useNewPlugin: useNewPlugin);
  service.ensureInitialized().catchError((error) {
    debugPrint('[dictationServiceProvider] Failed to initialize: $error');
  });
  ref.onDispose(service.dispose);
  return service;
}
```

### 2. Permission dialog not appearing

iOS requires microphone permission requests to execute on the main thread directly from the user gesture. Do not wrap `startListening` in detached async contexts that break the tap chain.

```dart
CupertinoButton(
  onPressed: () async {
    await dictationService.ensureInitialized();
    final started = await dictationService.start();
    if (!started) {
      // handle error
    }
  },
  child: const Icon(CupertinoIcons.mic),
);
```

### 3. Initialization races

Wait for `startDictation()` to resolve before flipping UI state. The service already calls `ensureInitialized()`, but callers must check the boolean return and only mark `state.isDictating = true` when the start succeeded.

### 4. Multiple service instances

Only one `DictationService` may exist per capture surface. Do not create additional instances inside widgets or callbacks. Use the provider everywhere and let Riverpod manage disposal through `ref.onDispose`.

### 5. Audio session conflicts

Stop or pause other audio plugins (e.g., `audio_players`, `just_audio`) before invoking dictation. If the audio session remains locked, inspect other services that might still own `AVAudioSession` and release them before starting dictation.

## Audio Waveforms Plugin Registration (iOS)

When `use_frameworks!` is enabled, Flutter sometimes fails to find `AudioWaveformsPlugin` even though the Swift implementation exists. If you see `Undefined symbol: _OBJC_CLASS_$_AudioWaveformsPlugin` during `flutter build ios` or in Xcode, add a bridge inside the Runner target:

1. Create `ios/Runner/AudioWaveformsPlugin.h`:

```objc
#import <Flutter/Flutter.h>

@interface AudioWaveformsPlugin : NSObject<FlutterPlugin>
@end
```

2. Create `ios/Runner/AudioWaveformsPlugin.m`:

```objc
#import "AudioWaveformsPlugin.h"
#import <audio_waveforms/audio_waveforms-Swift.h>

@implementation AudioWaveformsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftAudioWaveformsPlugin registerWithRegistrar:registrar];
}
@end
```

3. Open `ios/Runner.xcworkspace`, add both files to the Runner target (do **not** copy files), and verify they appear under **Compile Sources**.
4. Run `cd ios && pod install`, then return to the repo root.
5. Clean builds:
   ```bash
   flutter clean
   flutter pub get
   flutter build ios --no-codesign
   ```

This ensures the Objective‑C symbol exists even when CocoaPods fails to expose it from the framework. Skip this step if current pods already provide `AudioWaveformsPlugin.h` and builds succeed.

## Testing and Verification Flow

1. **Pod + Flutter clean**
   ```bash
   cd ios
   pod install
   cd ..
   flutter clean
   flutter pub get
   ```
2. **Xcode build**
   - Open `ios/Runner.xcworkspace`.
   - Product → Clean Build Folder (Cmd+Shift+K).
   - Product → Build (Cmd+B) targeting a physical device.
3. **Flutter CLI smoke test**
   ```bash
   flutter build ios --no-codesign
   flutter run -d <device-id>
   ```
4. **Functional checks**
   - Start dictation, speak, confirm waveform animation and streaming transcript updates.
   - Stop dictation, ensure `CaptureState.audioPath` is populated and `state.canSave` flips true for Stories.
   - Cancel dictation and verify `AudioCacheService.cleanupAudioFile` removes the cached `.m4a` when `keepIfQueued` is false.
   - Queue a Story offline and confirm the cached audio survives the clear/reset flow so sync can upload it later.

Capture both Flutter and Xcode logs during testing; include them when filing bugs or verifying regressions.

## Outstanding Follow-ups

1. **Physical-device regression pass** – Required to prove recent code changes resolved simulator-only failures.
2. **`audio_waveforms` bridge audit** – Only necessary if the undefined symbol resurfaces; otherwise leave the pod-provided bridge alone.
3. **README alignment** – Mirror the lifecycle, troubleshooting, and testing guidance into `/Users/benjaminmackenzie/Dev/flutter_dictation/README.md` so other consumers do not repeat these mistakes.

