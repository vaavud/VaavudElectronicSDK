//
//  VEAudioProcessor.m
//  VaavudElectronicSDK
//
//  Created by Andreas Okholm on 25/02/15.
//  Copyright (c) 2015 Vaavud. All rights reserved.
//

#import "VEAudioProcessor.h"

#define kOutputBus 0
#define kInputBus 1

// our default sample rate
#define SAMPLE_RATE 44100.00

#pragma mark objective-c class
@interface VEAudioProcessor () {
    TPCircularBuffer cirbuffer;
    AudioBuffer outputBufferLeft;
    AudioBuffer outputBufferRight;
    AudioBufferList inputBufferList;
    int outputBufferShiftIndex;
    int outputBufferShift;
    int baseSignalLength;
//    struct dispatch_queue_s *dispatchQueue;
    dispatch_queue_t dispatchQueue;
    
    // Audio unit
    AudioComponentInstance audioUnit;
}

@end

@implementation VEAudioProcessor

#pragma mark Recording callback
static OSStatus recordingCallback(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData) {
    
    
    
    // a variable where we check the status
    OSStatus status;
    
    /**
     This is the reference to the object who owns the callback.
     */
    VEAudioProcessor *audioProcessor = (__bridge VEAudioProcessor*) inRefCon;
    
    AudioBufferList bufferList = audioProcessor->inputBufferList;
    
    // render input and check for error
//    NSLog(@"inNumberOfFrames: %i", (unsigned int)inNumberFrames);
    status = AudioUnitRender(audioProcessor->audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &bufferList);
    [audioProcessor hasError:status andFile:__FILE__ andLine:__LINE__];
    
    // copy incoming audio data to the audio buffer
    TPCircularBufferProduceBytes(&audioProcessor->cirbuffer, bufferList.mBuffers[0].mData, bufferList.mBuffers[0].mDataByteSize);
    

    
    SInt16 *bufferOut = bufferList.mBuffers[0].mData;
    float *buffer = (float *) malloc(sizeof(float) * inNumberFrames);
    for (int i; i < inNumberFrames; i++) {
        buffer[i] = ((float) bufferOut[i]) / 32768.0; /// ((float) 32767.0);
    }
    
    for (int i=0; i < 3; i++) {
        NSLog(@"bufferVal[%i]: %f", i, buffer[i]);
    }
    
    
    dispatch_async(dispatch_get_main_queue(),^{
        // All the audio plot needs is the buffer data (float*) and the size. Internally the audio plot will handle all the drawing related code, history management, and freeing its own resources. Hence, one badass line of code gets you a pretty plot :)
        if (audioProcessor.audioPlot) {
            [audioProcessor.audioPlot updateBuffer:buffer withBufferSize:inNumberFrames];
        }
        free(buffer);
    });
    
    
    
    
    dispatch_async(audioProcessor->dispatchQueue, ^(void){
        if (audioProcessor.delegate) {
            [audioProcessor.delegate processBuffer:&audioProcessor->cirbuffer withDefaultBufferLengthInFrames:inNumberFrames];
        } else {
            NSLog(@"no audioProcessor delegate");
        }
    });
    
    
    return noErr;
}

#pragma mark Playback callback

static OSStatus playbackCallback(void *inRefCon,
                                 AudioUnitRenderActionFlags *ioActionFlags,
                                 const AudioTimeStamp *inTimeStamp,
                                 UInt32 inBusNumber,
                                 UInt32 inNumberFrames,
                                 AudioBufferList *ioData) {
    
    /**
     This is the reference to the object who owns the callback.
     */
    //    AudioProcessor *audioProcessor = (AudioProcessor*) inRefCon;
    VEAudioProcessor *audioProcessor = (__bridge VEAudioProcessor*)inRefCon;
    
    // This is a mono tone generator so we only need the first buffer
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
    
    
//    // keep for now to comsume bytes
//    int32_t availableBytes;
//    SInt16 *circBufferTail = TPCircularBufferTail(&audioProcessor->cirbuffer, &availableBytes);
//    
//    AudioBuffer targetBuffer = ioData->mBuffers[0];
//    UInt32 size = MIN(targetBuffer.mDataByteSize, availableBytes);
//    
//    // iterate over incoming stream an copy to output stream
//    for (int i=0; i < ioData->mNumberBuffers; i++) {
//        AudioBuffer targetBuffer = ioData->mBuffers[i];
//        
//        // copy buffer to audio buffer which gets played after function return
//        memcpy(targetBuffer.mData, circBufferTail, size);
//        
//        // set data size
//        targetBuffer.mDataByteSize = size;
//    }
    
    return noErr;
}

-(VEAudioProcessor*)init
{
    self = [super init];
    if (self) {
        dispatchQueue = (dispatch_queue_create("com.vaavud.processTickQueue", DISPATCH_QUEUE_SERIAL));
//        self.delegate = [[SoundProcessor alloc] init];
        [self initializeAudioWithOutput:true];
    }
    return self;
}

-(void)initializeAudioWithOutput:(BOOL)outputFlag
{
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
    NSLog(@"Size of Int16: %i", (unsigned int) bytesPerSample);
    
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
    
    TPCircularBufferInit(&cirbuffer, bufferLengthInFrames*10);
    
    // Initialize the Audio Unit and cross fingers =)
    status = AudioUnitInitialize(audioUnit);
    [self hasError:status andFile:__FILE__ andLine:__LINE__];
    
    NSLog(@"Started");
    
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
    
    for(int i=0; i<baseSignalLength; i++){
        baseSignal[i] = (SInt16) (32767*sin(i / (float) baseSignalLength * M_PI*2));
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
    // start the audio unit. You should hear something, hopefully :)
    OSStatus status = AudioOutputUnitStart(audioUnit);
    [self hasError:status andFile:__FILE__ andLine:__LINE__];
}

- (void)startMicrophoneOnly {
    
}

- (void)stop {
    // stop the audio unit
    OSStatus status = AudioOutputUnitStop(audioUnit);
    [self hasError:status andFile:__FILE__ andLine:__LINE__];
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
    TPCircularBufferCleanup(&cirbuffer);
    
    free(outputBufferLeft.mData);
    free(outputBufferRight.mData);
    free(inputBufferList.mBuffers[0].mData);
}


@end
