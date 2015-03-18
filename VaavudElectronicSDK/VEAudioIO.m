//
//  VEAudioProcessor.m
//  VaavudElectronicSDK
//
//  Created by Andreas Okholm on 25/02/15.
//  Copyright (c) 2015 Vaavud. All rights reserved.
//
//  Inspiration from: http://www.stefanpopp.de/capture-iphone-microphone/
//  and: http://atastypixel.com/blog/a-simple-fast-circular-buffer-implementation-for-audio-processing/
//  and: https://github.com/syedhali/EZAudio

//#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "VEAudioIO.h"
#import "VEFloatConverter.h"
#import "VERecorder.h"

#define kAudioFilePath @"tempRawAudioFile.wav"

#define kOutputBus 0
#define kInputBus 1

// our default sample rate
#define SAMPLE_RATE 44100.00

#pragma mark objective-c class
@interface VEAudioIO () {
    VECircularBuffer cirbuffer;
    AudioBuffer outputBufferLeft;
    AudioBuffer outputBufferRight;
    AudioBufferList inputBufferList;
    int outputBufferShiftIndex;
    int outputBufferShift;
    int baseSignalLength;

    VEFloatConverter *converter;
    float           **floatBuffers;
    
    // Audio unit
    AudioComponentInstance audioUnit;
    
    float currentVolume, originalVolume;
}

@property (atomic) BOOL audioBuffersInitialized;

// from audioManager
@property (nonatomic,strong) VERecorder *recorder; /** The recorder component */
@property (atomic) BOOL askedToMeasure;
@property (atomic) BOOL recordingActive;
@property (atomic) BOOL algorithmActive;
@property (nonatomic) dispatch_queue_t dispatchQueue;

// from detection
@property (atomic) BOOL deviceConnected;

@end

@implementation VEAudioIO

-(VEAudioIO*)init // dont do anything on init
{
    self = [super init];
    if (self) {

        //from audio Manger
        self.dispatchQueue = (dispatch_queue_create("com.vaavud.processTickQueue", DISPATCH_QUEUE_SERIAL));
        dispatch_set_target_queue(self.dispatchQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
       
        self.audioBuffersInitialized = NO;
        self.askedToMeasure = NO;
        self.algorithmActive = NO;
        self.recordingActive = NO;
        self.sleipnirAvailable = NO;
        
        // from detection
        // register for notification for chances in audio routing (inserting/removing jack plut)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioRouteChangeListenerCallback:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:nil];
        
        [self checkDeviceAvailability];
    }
    return self;
}

#pragma mark Recording callback
static OSStatus recordingCallback(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
    // a variable where we check the status
    OSStatus status;
    
    // This is the reference to the object who owns the callback
    VEAudioIO *audioProcessor = (__bridge VEAudioIO*) inRefCon;
    
    AudioBufferList bufferList = audioProcessor->inputBufferList;
    
    // render input and check for error
    status = AudioUnitRender(audioProcessor->audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &bufferList);
//    [audioProcessor hasError:status andFile:__FILE__ andLine:__LINE__]; // concider ignoring errors, Errors might happen when changing volume
    
    if (!status) {
        // copy incoming audio data to the audio buffer
        VECircularBufferProduceBytes(&audioProcessor->cirbuffer, bufferList.mBuffers[0].mData, bufferList.mBuffers[0].mDataByteSize);
        dispatch_async(audioProcessor.dispatchQueue, ^(void){
            [audioProcessor.delegate processBuffer:&audioProcessor->cirbuffer withDefaultBufferLengthInFrames:inNumberFrames];
        });
        
        if (audioProcessor.recordingActive) {
            [audioProcessor.recorder appendDataFromBufferList:&bufferList withBufferSize:inNumberFrames];
        }
        
        
        if (audioProcessor.microphoneOutputDeletage) {
            VEFloatConverterToFloat(audioProcessor->converter,
                                    &audioProcessor->inputBufferList,
                                    audioProcessor->floatBuffers,
                                    inNumberFrames);
            // inNumberFrames changed to 256
            //        [audioProcessor.microphoneOutputDeletage processFloatBuffer:audioProcessor->floatBuffers[0] withBufferLengthInFrames:256];
            [audioProcessor.microphoneOutputDeletage updateBuffer:audioProcessor->floatBuffers[0] withBufferSize:256];
        }

    }
    else {
        if (LOG_AUDIO) NSLog(@"Error Code responded %d in file %s on line %d\n",(int)status , __FILE__, __LINE__);
    }
    return status; //    return noErr;
}

#pragma mark Playback callback

static OSStatus playbackCallback(void *inRefCon,
                                 AudioUnitRenderActionFlags *ioActionFlags,
                                 const AudioTimeStamp *inTimeStamp,
                                 UInt32 inBusNumber,
                                 UInt32 inNumberFrames,
                                 AudioBufferList *ioData) {
    
    // This is the reference to the object who owns the callback.
    VEAudioIO *audioProcessor = (__bridge VEAudioIO*)inRefCon;
    
    const int channelLeft = 0;
    const int channelRight = 1;
    
    SInt16 *bufferLeft = (SInt16 *)ioData->mBuffers[channelLeft].mData;
    SInt16 *bufferRight = (SInt16 *)ioData->mBuffers[channelRight].mData;
    
    UInt32 sampleSize = sizeof(SInt16);
    
    memcpy(bufferLeft, audioProcessor->outputBufferLeft.mData + sampleSize * audioProcessor->outputBufferShiftIndex, ioData->mBuffers[channelLeft].mDataByteSize);
    memcpy(bufferRight, audioProcessor->outputBufferRight.mData + sampleSize * audioProcessor->outputBufferShiftIndex, ioData->mBuffers[channelLeft].mDataByteSize);
    
    // calculare buffer shift
    audioProcessor->outputBufferShiftIndex += audioProcessor->outputBufferShift;
    if (audioProcessor->outputBufferShiftIndex > audioProcessor->baseSignalLength) {
        audioProcessor->outputBufferShiftIndex -= audioProcessor->baseSignalLength;
    }
    
    return noErr;
}


-(void)initializeAudioWithOutput:(BOOL)outputFlag
{
    NSLog(@"Initialized with output: %i", outputFlag);
    
    OSStatus status;
    
    // We define the audio component
    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output; // we want to ouput
    desc.componentSubType = kAudioUnitSubType_RemoteIO; // we want in and ouput
    desc.componentFlags = 0; // must be zero
    desc.componentFlagsMask = 0; // must be zero
    desc.componentManufacturer = kAudioUnitManufacturer_Apple; // select provider
    
    // find the AU component by description
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
    
    // create audio unit by component
    status = AudioComponentInstanceNew(inputComponent, &audioUnit);
    
    [self hasError:status andFile:__FILE__ andLine:__LINE__];
    
    // define that we want record io on the input bus
    UInt32 flag = 1;
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioOutputUnitProperty_EnableIO, // use io
                                  kAudioUnitScope_Input, // scope to input
                                  kInputBus, // select input bus (1)
                                  &flag, // set flag
                                  sizeof(flag));
    [self hasError:status andFile:__FILE__ andLine:__LINE__];
    
    
    flag = outputFlag;
    // define that we want play on io on the output bus
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioOutputUnitProperty_EnableIO, // use io
                                  kAudioUnitScope_Output, // scope to output
                                  kOutputBus, // select output bus (0)
                                  &flag, // set flag
                                  sizeof(flag));
    [self hasError:status andFile:__FILE__ andLine:__LINE__];
    
    /*
     We need to specifie our format on which we want to work.
     We use Linear PCM cause its uncompressed and we work on raw data.
     for more informations check.
     
     We want 16 bits, 2 bytes per packet/frames at 44.1khz Mono in, Stero Out
     */
    UInt32 bytesPerSample = sizeof(SInt16);
//    NSLog(@"Size of Int16: %i", (unsigned int) bytesPerSample);
    
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate			= SAMPLE_RATE;
    audioFormat.mFormatID			= kAudioFormatLinearPCM;
    audioFormat.mFormatFlags		= kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger;
    audioFormat.mFramesPerPacket	= 1;
    audioFormat.mChannelsPerFrame	= 1;
    audioFormat.mBitsPerChannel		= 8 * bytesPerSample;
    audioFormat.mBytesPerPacket		= bytesPerSample;
    audioFormat.mBytesPerFrame		= bytesPerSample;
    
    
    AudioStreamBasicDescription stereoStreamFormat = {0};
    stereoStreamFormat.mSampleRate        = SAMPLE_RATE;
    stereoStreamFormat.mFormatID          = kAudioFormatLinearPCM;
    stereoStreamFormat.mFormatFlags       = kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved;
    stereoStreamFormat.mFramesPerPacket   = 1;
    stereoStreamFormat.mChannelsPerFrame  = 2;           // 2 indicates stereo
    stereoStreamFormat.mBitsPerChannel    = 8 * bytesPerSample;
    stereoStreamFormat.mBytesPerPacket    = bytesPerSample;
    stereoStreamFormat.mBytesPerFrame     = bytesPerSample;
    
    
    // set the format on the output stream
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  kInputBus,
                                  &audioFormat,
                                  sizeof(audioFormat));
    
    [self hasError:status andFile:__FILE__ andLine:__LINE__];
    
    // set the format on the input stream  // Set the input stream on the output channel!
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  kOutputBus,
                                  &stereoStreamFormat,
                                  sizeof(stereoStreamFormat));
    [self hasError:status andFile:__FILE__ andLine:__LINE__];
    
    
    /**
     We need to define a callback structure which holds
     a pointer to the recordingCallback and a reference to
     the audio processor object
     */
    AURenderCallbackStruct callbackStruct;
    
    // set recording callback
    callbackStruct.inputProc = recordingCallback; // recordingCallback pointer
    callbackStruct.inputProcRefCon = (__bridge void *)(self);
    
    // set input callback to recording callback on the input bus
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioOutputUnitProperty_SetInputCallback,
                                  kAudioUnitScope_Global,
                                  kInputBus,
                                  &callbackStruct,
                                  sizeof(callbackStruct));
    
    [self hasError:status andFile:__FILE__ andLine:__LINE__];
    
    /*
     We do the same on the output stream to hear what is coming
     from the input stream
     */
    callbackStruct.inputProc = playbackCallback;
    callbackStruct.inputProcRefCon = (__bridge void *)(self);
    
    // set playbackCallback as callback on our renderer for the output bus
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Global,
                                  kOutputBus,
                                  &callbackStruct,
                                  sizeof(callbackStruct));
    [self hasError:status andFile:__FILE__ andLine:__LINE__];
    
    
    // reset flag to 0
    flag = 0; // we render into our inputbuffer
    
    /*
     we need to tell the audio unit to allocate the render buffer,
     that we can directly write into it.
     */
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_ShouldAllocateBuffer,
                                  kAudioUnitScope_Output,
                                  kInputBus,
                                  &flag,
                                  sizeof(flag));
    [self hasError:status andFile:__FILE__ andLine:__LINE__];
    
    // Maximum buffer size
    UInt32 bufferFrameSizeMax;
    UInt32 propSize = sizeof(bufferFrameSizeMax);
    status = AudioUnitGetProperty(audioUnit,
                                  kAudioUnitProperty_MaximumFramesPerSlice,
                                  kAudioUnitScope_Global,
                                  kOutputBus,
                                  &bufferFrameSizeMax,
                                  &propSize);
    NSLog(@"framesizeMax:%i", (unsigned int)bufferFrameSizeMax);
    
    
    NSError *audioSessionError = nil;
    [[AVAudioSession sharedInstance] setPreferredSampleRate:SAMPLE_RATE error:&audioSessionError];
    if (audioSessionError) {
        NSLog(@"Error setting preferredIOBufferDuration for audio session: %@", audioSessionError.description);
    }
    NSLog(@"sampleRate: %f", [AVAudioSession sharedInstance].sampleRate );
    
    if (!self.audioBuffersInitialized) {
        
        UInt32 preferedSampleSize = 1024;
        
        [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:preferedSampleSize/SAMPLE_RATE error:&audioSessionError];
        if (audioSessionError) {
            NSLog(@"Error setting preferredIOBufferDuration for audio session: %@", audioSessionError.description);
        }
        NSLog(@"bufferDuration! Will be wrong having just changed value: %f", [AVAudioSession sharedInstance].IOBufferDuration );
        
        UInt32 bufferLengthInFrames = preferedSampleSize; //round([AVAudioSession sharedInstance].sampleRate * [AVAudioSession sharedInstance].IOBufferDuration) IOBufferDuration is not updated instantly and will be wrong changing setting;
        
        NSLog(@"framesize:%u", (unsigned int)bufferLengthInFrames);
        
        
        [self prepareIntputBufferWithBufferSize:bufferLengthInFrames];
        [self prepareOutputBuffersWithBufferSize:bufferLengthInFrames andMaxBufferSize:bufferFrameSizeMax];
        [self configureFloatConverterWithFrameSize:bufferLengthInFrames andStreamFormat:audioFormat];
        
        VECircularBufferInit(&cirbuffer, bufferLengthInFrames*40);
        self.audioBuffersInitialized = YES;
    }
    
    // Initialize the Audio Unit and cross fingers =)
    status = AudioUnitInitialize(audioUnit);
    [self hasError:status andFile:__FILE__ andLine:__LINE__];
    
    NSLog(@"initialized");
    
}


- (void)prepareIntputBufferWithBufferSize:(int)bufferLengthInFrames {
    inputBufferList.mNumberBuffers = 1;
    inputBufferList.mBuffers[0].mNumberChannels = 1;
    inputBufferList.mBuffers[0].mData = malloc( bufferLengthInFrames * sizeof(SInt16));
    inputBufferList.mBuffers[0].mDataByteSize = bufferLengthInFrames * sizeof(SInt16);
}

- (void)prepareOutputBuffersWithBufferSize:(int)bufferFrameSize andMaxBufferSize:(int)bufferFrameSizeMax{
    
    baseSignalLength = 3;
    outputBufferShift = bufferFrameSize%baseSignalLength;
    outputBufferShiftIndex =0;
    
    UInt32 bytesPerSample = sizeof(SInt16);
    UInt32 bufferLength = bufferFrameSizeMax + baseSignalLength;
    
    outputBufferLeft.mNumberChannels = 1;
    outputBufferLeft.mDataByteSize = bufferLength * bytesPerSample;
    outputBufferLeft.mData = malloc( outputBufferLeft.mDataByteSize );
    
    outputBufferRight.mNumberChannels = 1;
    outputBufferRight.mDataByteSize = bufferLength * bytesPerSample;
    outputBufferRight.mData = malloc( outputBufferLeft.mDataByteSize );
    
    SInt16 *bufferLeft = (SInt16 *)outputBufferLeft.mData;
    SInt16 *bufferRight = (SInt16 *)outputBufferRight.mData;
    
    SInt16 *baseSignal = malloc(baseSignalLength * bytesPerSample);
    
    float signalOffAngle = M_PI/4;
    
    for(int i=0; i<baseSignalLength; i++){
        baseSignal[i] = (SInt16) (32767*sin(i / (float) baseSignalLength * M_PI*2 + signalOffAngle));
        NSLog(@"baseSignal[%i] = %i", i, baseSignal[i]);
    }
    
    for(int i=0; i<bufferLength; i++){
        int phaseIndex = i%baseSignalLength;
        bufferLeft[i] = baseSignal[phaseIndex];
        bufferRight[i] = -baseSignal[phaseIndex];
    }
    
    for (int i=0; i < 7; i++) {
        NSLog(@"buffer[%i]: %i", i, bufferLeft[i]);
    }
    
    free(baseSignal);
}

#pragma mark controll stream

- (void)start {
    self.askedToMeasure = YES;
    [self checkStartStop];
}


- (void)stop {
    self.askedToMeasure = NO;
    [self checkStartStop];
}

- (void)checkStartStop {
    
    if (self.algorithmActive && (!self.sleipnirAvailable || !self.askedToMeasure)) {
        self.algorithmActive = NO;
        
        OSStatus status = AudioOutputUnitStop(audioUnit); // stop the audio unit
        [self hasError:status andFile:__FILE__ andLine:__LINE__];
        if (LOG_AUDIO) NSLog(@"Stoped AudioUnit");
        [self.delegate algorithmAudioActive:NO];
        [self setVolumeToInitialState];
    }
    
    if (!self.algorithmActive && (self.sleipnirAvailable && self.askedToMeasure)) {
        self.algorithmActive = YES;
        [self initializeAudioWithOutput:YES];
        
        // Check the microphone input format
        if (LOG_AUDIO){
            NSLog(@"[VESDK] input");
            [VEAudioIO printASBD: [self inputAudioStreamBasicDescription]];
        }
        
        // Check the microphone input format
        if (LOG_AUDIO){
            NSLog(@"[VESDK] output");
            [VEAudioIO printASBD: [self outputAudioStreamBasicDescription]];
        }
        
        OSStatus status = AudioOutputUnitStart(audioUnit);  // start the audio unit. You should hear something, hopefully :)
        [self hasError:status andFile:__FILE__ andLine:__LINE__];
        if (LOG_AUDIO) NSLog(@"Started AudioUnit");
        [self.delegate algorithmAudioActive:YES];
        [self setVolumeAtSavedLevel];
    }
    
}

- (void)sleipnirIsAvaliable:(BOOL)avaliable {
    if (self.sleipnirAvailable != avaliable) {
        self.sleipnirAvailable = avaliable;
        
        [self checkStartStop];
        
        dispatch_async(dispatch_get_main_queue(),^{
            [self.delegate sleipnirAvailabliltyDidChange:avaliable];
        });
    }
}


- (AudioStreamBasicDescription)inputAudioStreamBasicDescription{
    AudioStreamBasicDescription streamDescription = {0};
    UInt32 sizeStreamDescription = sizeof(AudioStreamBasicDescription);
    OSStatus status = AudioUnitGetProperty(audioUnit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Output,kInputBus,&streamDescription,&sizeStreamDescription);
    [self hasError:status andFile:__FILE__ andLine:__LINE__];
    
    return streamDescription;
}
- (AudioStreamBasicDescription)outputAudioStreamBasicDescription{
    AudioStreamBasicDescription streamDescription = {0};
    UInt32 sizeStreamDescription = sizeof(AudioStreamBasicDescription);
    OSStatus status = AudioUnitGetProperty(audioUnit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Input,kOutputBus,&streamDescription,&sizeStreamDescription);
    [self hasError:status andFile:__FILE__ andLine:__LINE__];
    
    return streamDescription;
};

+(void)printASBD:(AudioStreamBasicDescription)asbd {
    char formatIDString[5];
    UInt32 formatID = CFSwapInt32HostToBig(asbd.mFormatID);
    bcopy (&formatID, formatIDString, 4);
    formatIDString[4] = '\0';
    NSLog (@"  Sample Rate:         %10.0f",  asbd.mSampleRate);
    NSLog (@"  Format ID:           %10s",    formatIDString);
    NSLog (@"  Format Flags:        %10X",    (unsigned int)asbd.mFormatFlags);
    NSLog (@"  Bytes per Packet:    %10d",    (unsigned int)asbd.mBytesPerPacket);
    NSLog (@"  Frames per Packet:   %10d",    (unsigned int)asbd.mFramesPerPacket);
    NSLog (@"  Bytes per Frame:     %10d",    (unsigned int)asbd.mBytesPerFrame);
    NSLog (@"  Channels per Frame:  %10d",    (unsigned int)asbd.mChannelsPerFrame);
    NSLog (@"  Bits per Channel:    %10d",    (unsigned int)asbd.mBitsPerChannel);
}

+ (NSString *)ASBDtoString:(AudioStreamBasicDescription)asbd {
    NSMutableString *description = [[NSMutableString alloc] init];
    
    char formatIDString[5];
    UInt32 formatID = CFSwapInt32HostToBig(asbd.mFormatID);
    bcopy (&formatID, formatIDString, 4);
    formatIDString[4] = '\0';
    [description appendFormat:@"  Sample Rate:         %10.0f\n",  asbd.mSampleRate];
    [description appendFormat:@"  Format ID:           %10s\n",    formatIDString];
    [description appendFormat:@"  Format Flags:        %10X\n",    (unsigned int)asbd.mFormatFlags];
    [description appendFormat:@"  Bytes per Packet:    %10d\n",    (unsigned int)asbd.mBytesPerPacket];
    [description appendFormat:@"  Frames per Packet:   %10d\n",    (unsigned int)asbd.mFramesPerPacket];
    [description appendFormat:@"  Bytes per Frame:     %10d\n",    (unsigned int)asbd.mBytesPerFrame];
    [description appendFormat:@"  Channels per Frame:  %10d\n",    (unsigned int)asbd.mChannelsPerFrame];
    [description appendFormat:@"  Bits per Channel:    %10d",      (unsigned int)asbd.mBitsPerChannel];
    
    return description;
}

#pragma mark - Float Converter Initialization
- (void)configureFloatConverterWithFrameSize:(UInt32)bufferFrameSize andStreamFormat:(AudioStreamBasicDescription)streamFormat {
    UInt32 bufferSizeBytes = bufferFrameSize * streamFormat.mBytesPerFrame;
    converter              = [[VEFloatConverter alloc] initWithSourceFormat:streamFormat];
    floatBuffers           = (float**)malloc(sizeof(float*)*streamFormat.mChannelsPerFrame);
    assert(floatBuffers);
    for ( int i=0; i<streamFormat.mChannelsPerFrame; i++ ) {
        floatBuffers[i] = (float*)malloc(bufferSizeBytes);
        assert(floatBuffers[i]);
    }
}


#pragma mark Error handling

-(void)hasError:(int)statusCode andFile:(char*)file andLine:(int)line {
    if (statusCode) {
        printf("Error Code responded %d in file %s on line %d\n", statusCode, file, line);
        exit(-1);
    }
}

- (void)dealloc {
    // Release buffer resources
    VECircularBufferCleanup(&cirbuffer);
    
    free(outputBufferLeft.mData);
    free(outputBufferRight.mData);
    free(inputBufferList.mBuffers[0].mData);
}

// Starts the internal soundfile recorder
- (void)startRecording {
    // Create the recorder
    self.recorder = [VERecorder recorderWithDestinationURL:[self recordingFilePathURL]
                                              sourceFormat:[self inputAudioStreamBasicDescription]
                                       destinationFileType:VERecorderFileTypeWAV];
    self.recordingActive = YES;
}

// Ends the internal soundfile recorder
- (void)endRecording {
    self.recordingActive = NO;
    [self.recorder closeAudioFile];
    self.recorder = nil;
}

// returns true if recording is active
- (BOOL)isRecording {
    return self.recordingActive;
}

// returns the local path of the recording
- (NSURL *)recordingPath {
    return [self recordingFilePathURL];
}

- (NSString *)soundOutputDescription {
    return [VEAudioIO ASBDtoString:[self outputAudioStreamBasicDescription]];
}

- (NSString *)soundInputDescription {
    return [VEAudioIO ASBDtoString:[self inputAudioStreamBasicDescription]];
}

/**
 EZaudio File Utility functions
 */

- (NSString *)applicationDocumentsDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}

- (NSURL *)recordingFilePathURL {
    return [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@",
                                   [self applicationDocumentsDirectory],
                                   kAudioFilePath]];
}


- (void)checkDeviceAvailability {
    
    [self initializeAudioWithOutput:YES];
    // start the audio unit. You should hear something, hopefully :)
    OSStatus status = AudioOutputUnitStart(audioUnit);
    [self hasError:status andFile:__FILE__ andLine:__LINE__];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        BOOL available = ([self isHeadphoneOutAvailable] && [self isHeadphoneMicAvailable]);
        // stop the audio unit
        OSStatus status = AudioOutputUnitStop(audioUnit);
        [self hasError:status andFile:__FILE__ andLine:__LINE__];
        
        [self sleipnirIsAvaliable:available];
    });
}

- (void)audioRouteChangeListenerCallback:(NSNotification*)notification {
    NSDictionary *interuptionDict = notification.userInfo;
    NSInteger routeChangeReason = [[interuptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    
    switch (routeChangeReason) {
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable: {
            NSLog(@"[VESDK] AVAudioSessionRouteChangeReasonOldDeviceUnavailable");
                [self sleipnirIsAvaliable:NO];
            break;
        }
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable: {
            NSLog(@"[VESDK] AVAudioSessionRouteChangeReasonNewDeviceAvailable");
            if (!self.sleipnirAvailable) {
                [self checkDeviceAvailability];
            }
            break;
        }
        default: {
            //NSLog(@"default audio stuff");
        }
    }
}

- (BOOL) isHeadphoneOutAvailable {
    //   Microphone should be on before running script
    AVAudioSessionRouteDescription *audioRoute = [[AVAudioSession sharedInstance] currentRoute];
    for (AVAudioSessionPortDescription* desc in [audioRoute outputs]) {
        if ([[desc portType] isEqualToString:AVAudioSessionPortHeadphones]) {
            return YES;
        }
    }
    if (LOG_AUDIO) NSLog(@"[VESDK] headphoneOut not Available");
    return NO;
}


- (BOOL) isHeadphoneMicAvailable {
    
    // For some reason Microphone needs to be active to determine audio route properly.
    // It works fine the first time the app is started without....
    
    //   Microphone should be on before running script
    AVAudioSessionRouteDescription *audioRoute = [[AVAudioSession sharedInstance] currentRoute];
    for (AVAudioSessionPortDescription* desc in [audioRoute inputs]) {
        if ([[desc portType] isEqualToString:AVAudioSessionPortHeadsetMic]) {
            return YES;
        }
    }
    if (LOG_AUDIO) NSLog(@"[VESDK] microphone not availiable");
    return NO;
}

- (void)adjustVolumeLevelAmount:(float) adjustment {
    currentVolume += adjustment;
    
    if (currentVolume < 0) {
        currentVolume = 0;
    }
    if (currentVolume > 1) {
        currentVolume = 1;
    }
    [MPMusicPlayerController applicationMusicPlayer].volume = currentVolume;
    if (LOG_AUDIO) NSLog(@"[VESDK] new volume %f", currentVolume);
}

- (void)setVolumeAtSavedLevel {
    currentVolume = [[NSUserDefaults standardUserDefaults] floatForKey:@"VOLUME"];
    if (currentVolume == 0) {
        currentVolume = 1.0;
    }
    // check if volume is at maximum.
    MPMusicPlayerController *musicPlayer = [MPMusicPlayerController applicationMusicPlayer];
    originalVolume = musicPlayer.volume;
    musicPlayer.volume = currentVolume; // device volume will be changed to stored // commented out due to -10876 audio render error
    if (LOG_AUDIO) NSLog(@"[VESDK] Loaded volume from user defaults and set to %f", currentVolume);
}

- (void)setVolumeToInitialState {
    [[NSUserDefaults standardUserDefaults] setFloat:currentVolume forKey:@"VOLUME"];
    if (LOG_AUDIO) NSLog(@"[VESDK] Saved volume: %f to user defaults", currentVolume);
    
    MPMusicPlayerController *musicPlayer = [MPMusicPlayerController applicationMusicPlayer];
    musicPlayer.volume = originalVolume;
    if (LOG_AUDIO) NSLog(@"[VESDK] Returned volume to original setting: %f", originalVolume);
    
}

@end

