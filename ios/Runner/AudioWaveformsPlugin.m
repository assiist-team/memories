#import "AudioWaveformsPlugin.h"
#import <audio_waveforms/audio_waveforms-Swift.h>

@implementation AudioWaveformsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  if (registrar == nil) {
    NSLog(@"AudioWaveformsPlugin: registrar is nil, skipping registration");
    return;
  }
  [SwiftAudioWaveformsPlugin registerWithRegistrar:registrar];
}
@end

