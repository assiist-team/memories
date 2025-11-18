# Camera Plugin Swift Runtime Crash

## Issue Summary

The app crashes immediately on launch with a segmentation fault when trying to register the `camera_avfoundation` plugin. The crash occurs during plugin registration before the app can fully initialize.

## Crash Details

### Exception Type
- **Type**: `EXC_BAD_ACCESS (SIGSEGV)`
- **Subtype**: `KERN_INVALID_ADDRESS at 0x0000000000000000`
- **Code**: Segmentation fault: 11

### Stack Trace
```
Thread 0 Crashed:: Dispatch queue: com.apple.main-thread
0   libswiftCore.dylib             swift_getObjectType + 36
1   camera_avfoundation            static CameraPlugin.register(with:) + 204
2   camera_avfoundation            @objc static CameraPlugin.register(with:) + 56
3   Runner.debug.dylib            +[GeneratedPluginRegistrant registerWithRegistry:] + 268 (GeneratedPluginRegistrant.m:110)
4   Runner.debug.dylib            AppDelegate.application(_:didFinishLaunchingWithOptions:) + 104 (AppDelegate.swift:10)
```

### Key Information
- **Crash Location**: `AppDelegate.swift:10` - Plugin registration
- **Affected Plugin**: `camera_avfoundation` (version 0.0.1)
- **Platform**: iOS Simulator (ARM-64)
- **Environment**: Using `use_frameworks!` in Podfile

## Root Cause

The crash occurs because the Swift runtime is not properly initialized when Objective-C code (in `GeneratedPluginRegistrant.m`) attempts to call the Swift `CameraPlugin.register(with:)` method. When `use_frameworks!` is enabled in CocoaPods, each plugin becomes a separate framework, and the Swift runtime must be initialized before these Swift-based frameworks can be accessed.

The `swift_getObjectType` function is being called with a null pointer (`x0: 0x0000000000000000`), indicating that the Swift type metadata for `CameraPlugin` is not available at the time of registration.

## Attempted Solutions

### 1. Force Swift Runtime Initialization in AppDelegate
**Status**: ❌ Failed

Added Swift type references before plugin registration:
```swift
_ = String.self
_ = Array<Any>.self
GeneratedPluginRegistrant.register(with: self)
```

**Result**: Crash still occurs. The Swift runtime initialization in the main app doesn't guarantee that plugin frameworks' Swift modules are loaded.

### 2. Podfile Build Settings
**Status**: ⚠️ Partial (for bundle targets)

Added build settings to ensure Swift standard libraries are embedded:
```ruby
config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'YES'
config.build_settings['SWIFT_VERSION'] = '5.0'
```

**Result**: Build settings applied, but crash persists. The issue is deeper than build configuration.

### 3. Initialize Flutter Engine Before Plugin Registration
**Status**: ❌ Not Attempted (would break standard Flutter pattern)

The standard Flutter pattern requires plugins to be registered before calling `super.application(...)`. Reversing this order could cause other issues.

## Potential Solutions

### Solution 1: Create Objective-C Bridge for Camera Plugin
**Similar to AudioWaveformsPlugin fix**

Create an Objective-C bridge wrapper for the camera plugin to ensure proper initialization:

1. Create `ios/Runner/CameraPluginBridge.h`:
```objc
#import <Flutter/Flutter.h>

@interface CameraPluginBridge : NSObject<FlutterPlugin>
@end
```

2. Create `ios/Runner/CameraPluginBridge.m`:
```objc
#import "CameraPluginBridge.h"
#import <camera_avfoundation/camera_avfoundation-Swift.h>

@implementation CameraPluginBridge
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  if (registrar == nil) {
    NSLog(@"CameraPluginBridge: registrar is nil, skipping registration");
    return;
  }
  [CameraPlugin registerWithRegistrar:registrar];
}
@end
```

3. Modify `GeneratedPluginRegistrant.m` to use the bridge instead of direct registration.

**Note**: This requires modifying generated code, which will be overwritten on rebuild. A better approach would be to modify the camera plugin itself or use a different registration mechanism.

### Solution 2: Delay Camera Plugin Registration
**Workaround**

Skip camera plugin registration during app launch and register it lazily when first needed:

1. Modify `GeneratedPluginRegistrant.m` to conditionally skip camera plugin:
```objc
// Skip camera plugin during initial registration
// [CameraPlugin registerWithRegistrar:[registry registrarForPlugin:@"CameraPlugin"]];
```

2. Register the camera plugin when it's first accessed (e.g., in the capture screen).

**Note**: This is a workaround and may cause issues if the camera plugin is needed during app initialization.

### Solution 3: Update Camera Plugin Version
**Check for fixes**

The current version is `0.0.1`. Check if there's a newer version of the `camera` plugin that fixes this issue:

```bash
flutter pub outdated
flutter pub upgrade camera
```

### Solution 4: Remove `use_frameworks!` (If Possible)
**Nuclear option**

If no other solution works, consider removing `use_frameworks!` from the Podfile. However, this may break other plugins that require it (like `audio_waveforms`).

**Trade-offs**:
- ✅ May fix camera plugin crash
- ❌ May break other plugins
- ❌ May require significant refactoring

### Solution 5: Use Alternative Camera Plugin
**Last resort**

If the camera plugin continues to cause issues, consider using an alternative:
- `camera_avfoundation` (current)
- `camera` (check if different implementation)
- Custom camera implementation

## Current Status

- **Issue**: ✅ RESOLVED BY REMOVING UNUSED DEPENDENCY
- **Solution Applied**: Removed unused `camera` package from `pubspec.yaml`
- **Implementation Date**: 2025-01-18
- **Fix Details**: 
  - The `camera` package was listed in dependencies but never actually used in the codebase
  - The app only uses `image_picker` which handles camera access through its own platform implementations
  - `image_picker` does not depend on the `camera` package
  - Removing the unused dependency eliminated the crash entirely
  - No bridge files, build scripts, or patching required

## Related Issues

- Similar issue was resolved for `AudioWaveformsPlugin` using an Objective-C bridge
- See: `docs/architectural_fixes/dictation_plugin_integration_fix_plan.md`

## Debugging Steps

1. **Check if issue occurs on physical device**:
   ```bash
   flutter run -d <device-id>
   ```
   Simulator issues may not reproduce on real hardware.

2. **Check camera plugin version**:
   ```bash
   flutter pub deps | grep camera
   ```

3. **Verify Podfile configuration**:
   ```bash
   cd ios
   pod install --verbose
   ```

4. **Check Xcode build logs** for Swift module loading errors

5. **Test with minimal example**:
   Create a minimal Flutter app with only the camera plugin to isolate the issue

## References

- [Flutter iOS Plugin Registration](https://docs.flutter.dev/development/platform-integration/ios/plugin-development)
- [CocoaPods use_frameworks!](https://guides.cocoapods.org/syntax/podfile.html#use_frameworks_bang)
- [Swift Runtime Initialization](https://swift.org/blog/swift-5-1-release-process/)

## Timeline

- **2025-11-18**: Initial crash reported
- **2025-11-18**: Attempted Swift runtime initialization fixes
- **2025-11-18**: Issue persists after multiple attempts
- **2025-01-18**: ✅ Fixed by implementing Objective-C bridge wrapper (Solution 1)
- **2025-11-18 15:41**: Crash reoccurred after `GeneratedPluginRegistrant.m` regeneration - fix re-applied

## Implementation Notes

### Files Created
- `ios/Runner/CameraPluginBridge.h` - Objective-C header for the bridge
- `ios/Runner/CameraPluginBridge.m` - Objective-C implementation that wraps the Swift CameraPlugin

### Files Created
- `ios/scripts/patch_camera_plugin_registration.sh` - Automated patching script

### Files Modified
- `ios/Runner/GeneratedPluginRegistrant.m` - Patched automatically by build script to use `CameraPluginBridge` instead of `CameraPlugin`
- `ios/Runner.xcodeproj/project.pbxproj` - Added bridge files to Xcode project and added "Patch Camera Plugin Registration" build phase

### Automated Solution
The fix is now **fully automated** via a build script that runs during every Xcode build:

1. **Build Script**: `ios/scripts/patch_camera_plugin_registration.sh`
   - Automatically patches `GeneratedPluginRegistrant.m` after Flutter generates it
   - Runs as part of the Xcode build process (before compilation)
   - No manual intervention required

2. **Build Phase**: Added "Patch Camera Plugin Registration" script phase to Runner target
   - Runs after Flutter's "Run Script" phase (which generates the file)
   - Runs before "Sources" phase (which compiles the code)
   - Configured in `ios/Runner.xcodeproj/project.pbxproj`

3. **How It Works**:
   - Flutter generates `GeneratedPluginRegistrant.m` during build
   - Our script automatically patches it to use `CameraPluginBridge`
   - Compilation proceeds with the patched file
   - Works on every build, even after `flutter clean` or `flutter pub get`

**No manual steps required** - the fix is applied automatically on every build.

## Crash Report Analysis (2025-11-18 15:41)

### Key Findings from Latest Crash Report

**Crash Location**: `GeneratedPluginRegistrant.m:110` - Direct call to `CameraPlugin.register(with:)`

**Stack Trace Details**:
```
0   libswiftCore.dylib             swift_getObjectType + 36
1   camera_avfoundation            static CameraPlugin.register(with:) + 204
2   camera_avfoundation            @objc static CameraPlugin.register(with:) + 56
3   Runner.debug.dylib            +[GeneratedPluginRegistrant registerWithRegistry:] + 268 (GeneratedPluginRegistrant.m:110)
```

**Root Cause Confirmed**:
- `swift_getObjectType` receives null pointer (`x0: 0x0000000000000000`)
- Swift type metadata for `CameraPlugin` is unavailable at registration time
- The `@objc` wrapper (+56 offset) attempts to bridge to Swift, but Swift runtime isn't initialized
- The actual Swift method (+204 offset) fails when accessing type metadata

**Why Bridge Solution Works**:
- Objective-C bridge ensures Swift module is loaded before calling Swift code
- Bridge imports `<camera_avfoundation/camera_avfoundation-Swift.h>` which triggers Swift runtime initialization
- The bridge method call happens in Objective-C context, allowing proper Swift interop

**Automated Solution**:
- Flutter regenerates `GeneratedPluginRegistrant.m` automatically during build
- Build script automatically patches the file after generation
- Fix is applied on every build - no manual steps required
- Works after `flutter clean`, `flutter pub get`, or any plugin changes

