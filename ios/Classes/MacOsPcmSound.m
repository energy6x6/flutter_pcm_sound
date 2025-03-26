#import MacOsPcmSound.h

@implementation MacOsPcmSound

- (BOOL)setup:(AudioObjectID)deviceId into:(AudioStreamBasicDescription *)outFormat {

    // cleanup
    if (_mAudioUnit != nil) {
        [self cleanup];
    }

    // create
    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_HALOutput;

    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;

    AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
    OSStatus status = AudioComponentInstanceNew(inputComponent, &_mAudioUnit);
    if (status != noErr) {
        NSString *message = [NSString stringWithFormat:@"AudioComponentInstanceNew failed. OSStatus: %@", @(status)];
        result([FlutterError errorWithCode:@"AudioUnitError" message:message details:nil]);
        return;
    }

    UInt32 enableIO = 1;
    status = AudioUnitSetProperty(
            _mAudioUnit,
            kAudioOutputUnitProperty_EnableIO,
            kAudioUnitScope_Output,
            0,
            &enableIO,
            sizeof(enableIO));
    if (status != noErr) {
        NSString *message = [NSString stringWithFormat:@"EnableIO failed. OSStatus: %@", @(status)];
        result([FlutterError errorWithCode:@"AudioUnitError" message:message details:nil]);
        return;
    }



    // set stream format
//            AudioStreamBasicDescription audioFormat;
//            audioFormat.mSampleRate = [sampleRate intValue];
//            audioFormat.mFormatID = kAudioFormatLinearPCM;
//            audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
//            audioFormat.mFramesPerPacket = 1;
//            audioFormat.mChannelsPerFrame = self.mNumChannels;
//            audioFormat.mBitsPerChannel = 16;
//            audioFormat.mBytesPerFrame = self.mNumChannels * (audioFormat.mBitsPerChannel / 8);
//            audioFormat.mBytesPerPacket = audioFormat.mBytesPerFrame * audioFormat.mFramesPerPacket;

    // set stream format to match the selected device
    AudioStreamBasicDescription audioFormat;
    UInt32 formatSize = sizeof(audioFormat);

    AudioObjectPropertyAddress formatAddress = {
            kAudioDevicePropertyStreamFormat,
            kAudioDevicePropertyScopeOutput,
            kAudioObjectPropertyElementMain
    };

    OSStatus getFormatStatus = AudioObjectGetPropertyData(
            kAudioObjectSystemObject,
            &formatAddress,
            0,
            NULL,
            &formatSize,
            &audioFormat
    );

    if (getFormatStatus != noErr) {
        NSString *message = [NSString stringWithFormat:@"Failed to get output device format. OSStatus: %d", getFormatStatus];
        result([FlutterError errorWithCode:@"AudioUnitError" message:message details:nil]);
        return;
    }

    // ✅ Print the format in console
    NSLog(@"Using output device format:");
    NSLog(@"  SampleRate: %.2f", audioFormat.mSampleRate);
    NSLog(@"  Channels: %u", audioFormat.mChannelsPerFrame);
    NSLog(@"  FormatID: %u", (unsigned int)audioFormat.mFormatID);
    NSLog(@"  FormatFlags: %u", (unsigned int)audioFormat.mFormatFlags);
    NSLog(@"  BitsPerChannel: %u", audioFormat.mBitsPerChannel);
    NSLog(@"  BytesPerFrame: %u", audioFormat.mBytesPerFrame);
    NSLog(@"  BytesPerPacket: %u", audioFormat.mBytesPerPacket);


    status = AudioUnitSetProperty(_mAudioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  0, // <- scope output, element 0
                                  &audioFormat,
                                  sizeof(audioFormat));

    if (status != noErr) {
        NSString *message = [NSString stringWithFormat:@"AudioUnitSetProperty StreamFormat failed. OSStatus: %@", @(status)];
        result([FlutterError errorWithCode:@"AudioUnitError" message:message details:nil]);
        return;
    }

    // set callback
    AURenderCallbackStruct callback;
    callback.inputProc = RenderCallback;
    callback.inputProcRefCon = (__bridge void *) (self);

    status = AudioUnitSetProperty(_mAudioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Global,
                                  kOutputBus,
                                  &callback,
                                  sizeof(callback));
    if (status != noErr) {
        NSString *message = [NSString stringWithFormat:@"AudioUnitSetProperty SetRenderCallback failed. OSStatus: %@", @(status)];
        result([FlutterError errorWithCode:@"AudioUnitError" message:message details:nil]);
        return;
    }

    // initialize
    status = AudioUnitInitialize(_mAudioUnit);
    if (status != noErr) {
        NSString *message = [NSString stringWithFormat:@"AudioUnitInitialize failed. OSStatus: %@", @(status)];
        result([FlutterError errorWithCode:@"AudioUnitError" message:message details:nil]);
        return;
    }

    self.mDidSetup = true;
}

- (void)cleanup {
    if (_mAudioUnit != nil) {
        AudioUnitUninitialize(_mAudioUnit);
        AudioComponentInstanceDispose(_mAudioUnit);
        _mAudioUnit = nil;
        self.mDidSetup = false;
    }
    @synchronized (self.mSamples) {
        self.mSamples = [NSMutableData new];
    }
}

- (BOOL)setAudioUnitFormat:(AudioComponentInstance)audioUnit
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

- (NSData *)convertBuffer:(NSData *)input
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
