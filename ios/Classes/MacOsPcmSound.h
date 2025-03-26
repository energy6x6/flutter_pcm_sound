
@interface MacOsPcmSound : NSObject

- (BOOL)setup:(AudioObjectID)deviceId
        into:(AudioStreamBasicDescription *)outFormat;

- (BOOL)setAudioUnitFormat:(AudioComponentInstance)audioUnit
        format:(AudioStreamBasicDescription *)audioFormat;

- (NSData *)convertBuffer:(NSData *)input
        fromSampleRate:(Float64)inRate
        toSampleRate:(Float64)outRate
        fromChannels:(UInt32)inChannels
        toChannels:(UInt32)outChannels;

@end