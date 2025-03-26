#import "PcmAudioFormatUtils.h"

@implementation PcmAudioFormatUtils

+ (BOOL)getDeviceFormat:(AudioObjectID)deviceId
                   into:(AudioStreamBasicDescription *)outFormat {
    UInt32 formatSize = sizeof(AudioStreamBasicDescription);

    AudioObjectPropertyAddress formatAddress = {
            kAudioDevicePropertyStreamFormat,
            kAudioDevicePropertyScopeOutput,
            kAudioObjectPropertyElementMain
    };

    OSStatus status = AudioObjectGetPropertyData(
            deviceId,
            &formatAddress,
            0,
            NULL,
            &formatSize,
            outFormat
    );

    if (status == noErr) {
        NSLog(@"[PcmAudioFormatUtils] Device format:");
        NSLog(@"  SampleRate: %.2f", outFormat->mSampleRate);
        NSLog(@"  Channels: %u", outFormat->mChannelsPerFrame);
        NSLog(@"  FormatID: %u", (unsigned int)outFormat->mFormatID);
        NSLog(@"  BitsPerChannel: %u", outFormat->mBitsPerChannel);
        return YES;
    } else {
        NSLog(@"[PcmAudioFormatUtils] Failed to get format. OSStatus: %d", status);
        return NO;
    }
}

+ (BOOL)setAudioUnitFormat:(AudioComponentInstance)audioUnit
                    format:(AudioStreamBasicDescription *)audioFormat {
    OSStatus status = AudioUnitSetProperty(
            audioUnit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output,
            0,
            audioFormat,
            sizeof(AudioStreamBasicDescription)
    );

    if (status != noErr) {
        NSLog(@"[PcmAudioFormatUtils] Failed to set AudioUnit format. OSStatus: %d", status);
        return NO;
    }

    return YES;
}

+ (NSData *)convertBuffer:(NSData *)input
           fromSampleRate:(Float64)inRate
             toSampleRate:(Float64)outRate
             fromChannels:(UInt32)inChannels
               toChannels:(UInt32)outChannels {

    if (inRate == outRate && inChannels == outChannels) {
        return input; // no conversion needed
    }

    NSMutableData *output = [NSMutableData data];
    const int16_t *inputSamples = input.bytes;
    NSUInteger inputCount = input.length / sizeof(int16_t);

    float rateRatio = outRate / inRate;

    for (NSUInteger i = 0; i < inputCount; i++) {
        int16_t sample = inputSamples[i];

        for (int r = 0; r < rateRatio; r++) {
            for (int ch = 0; ch < outChannels; ch++) {
                [output appendBytes:&sample length:sizeof(sample)];
            }
        }
    }

    return output;
}

@end
