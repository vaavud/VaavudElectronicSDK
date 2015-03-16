//
//  soundManager.m
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 21/07/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#define kAudioFilePath @"tempRawAudioFile.wav"

#import "VEAudioManager.h"

@interface VEAudioManager()

@property (nonatomic,strong) VEAudioIO *audioProcessor;
@property (nonatomic,strong) VERecorder *recorder; /** The recorder component */
@property (atomic) BOOL askedToMeasure;
@property (atomic) BOOL recordingActive;
@property (atomic) BOOL algorithmActive;
@property (nonatomic, weak) id<AudioManagerDelegate> delegate;
@property (nonatomic) dispatch_queue_t dispatchQueue;

@end

@implementation VEAudioManager


#pragma mark - Initialization
- (id)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"-init is not a valid initializer for the class AudioManager"
                                 userInfo:nil];
    return nil;
}

- (id)initWithDelegate:(id<AudioManagerDelegate, SoundProcessingDelegate, DirectionDetectionDelegate>)delegate {
    self = [super init];
    
    self.dispatchQueue = (dispatch_queue_create("com.vaavud.processTickQueue", DISPATCH_QUEUE_SERIAL));
    dispatch_set_target_queue(self.dispatchQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    
    self.delegate = delegate;
    self.soundProcessor = [[VESoundProcessingAlgo alloc] initWithDelegate:delegate];
    self.audioProcessor = [[VEAudioIO alloc] init];
    self.audioProcessor.delegate = self;
    
    // Check the microphone input format
    if (LOG_AUDIO){
        NSLog(@"[VESDK] input");
        [VEAudioIO printASBD: [self.audioProcessor inputAudioStreamBasicDescription]];
    }
    
    // Check the microphone input format
    if (LOG_AUDIO){
        NSLog(@"[VESDK] output");
        [VEAudioIO printASBD: [self.audioProcessor outputAudioStreamBasicDescription]];
    }
    
    self.askedToMeasure = NO;
    self.algorithmActive = NO;
    self.recordingActive = NO;
        
    return self;
}


- (void)processBuffer:(VECircularBuffer *)circBuffer withDefaultBufferLengthInFrames:(UInt32)bufferLengthInFrames {
    dispatch_async(self.dispatchQueue, ^(void){
        [self.soundProcessor processBuffer:circBuffer withDefaultBufferLengthInFrames:bufferLengthInFrames];
    });
}

- (void)processBufferList:(AudioBufferList *)bufferList withBufferLengthInFrames:(UInt32)bufferLengthInFrames {
    if (self.recordingActive) {
        [self.recorder appendDataFromBufferList:bufferList withBufferSize:bufferLengthInFrames];
    }
}

- (void)processFloatBuffer:(float *)buffer withBufferLengthInFrames:(UInt32)bufferLengthInFrames {
    [self.microphoneOutputDeletage updateBuffer:buffer withBufferSize:bufferLengthInFrames]; // migth be nil
}

- (void)start {
    self.askedToMeasure = YES;
    
    if (!self.algorithmActive) {
        if (self.delegate.sleipnirAvailable) {
            [self startInternal];
        }
    }
}

- (void)stop {
    self.askedToMeasure = NO;
    
    if (self.algorithmActive) {
        [self stopInternal];
    }
    
    [self.soundProcessor returnVolumeToInitialState];
}


- (void)startInternal {
    self.algorithmActive = YES;
    [self.audioProcessor start];
    [self.soundProcessor setVolumeAtSavedLevel];
    
     dispatch_async(dispatch_get_main_queue(),^{
        [self.delegate vaavudStartedMeasuring];
    });
}


- (void)stopInternal {
    self.algorithmActive = NO;
    [self.audioProcessor stop];
    
    dispatch_async(dispatch_get_main_queue(),^{
        [self.delegate vaavudStopMeasuring];
    });
}

- (void)sleipnirAvailabliltyChanged:(BOOL)available {
    if (available) {
        if (self.askedToMeasure) {
            [self startInternal];
        }
    }
    else {
        if (self.algorithmActive) {
            [self stopInternal];
        }
    }
}

///* delegate method - Feed microphone data to sound-processor and plot */
//#pragma mark - EZMicrophoneDelegate
//// #warning Thread Safety
//// Note that any callback that provides streamed audio data (like streaming microphone input) happens on a separate audio thread that should not be blocked. When we feed audio data into any of the UI components we need to explicity create a GCD block on the main thread to properly get the UI to work.
//-(void)microphone:(EZMicrophone *)microphone
// hasAudioReceived:(float **)buffer
//   withBufferSize:(UInt32)bufferSize
//withNumberOfChannels:(UInt32)numberOfChannels {
//    // Getting audio data as an array of float buffer arrays. What does that mean? Because the audio is coming in as a stereo signal the data is split into a left and right channel. So buffer[0] corresponds to the float* data for the left channel while buffer[1] corresponds to the float* data for the right channel.
//    
//    if (intArray == NULL) {
//        arrayLeft = buffer[0];
//        
//        intArray = malloc(sizeof(int) * bufferSize); /* allocate memory for 50 int's */
//        if (!intArray) { /* If data == 0 after the call to malloc, allocation failed for some reason */
//            perror("Error allocating memory");
//            abort();
//        }
//        /* at this point, we know that data points to a valid block of memory.
//         Remember, however, that this memory is not initialized in any way -- it contains garbage.
//         Let's start by clearing it. */
//        memset(intArray, 0, sizeof(int)*bufferSize);
//        /* now our array contains all zeroes. */
//    }
//    
//    for (int i = 0; i < bufferSize; ++i) {
//        intArray[i] = (int)(arrayLeft[i]*1000);
//    }
//    
//    [self.soundProcessor newSoundData:intArray bufferLength:bufferSize];
//    
//    // See the Thread Safety warning above, but in a nutshell these callbacks happen on a separate audio thread. We wrap any UI updating in a GCD block on the main thread to avoid blocking that audio flow.
//    dispatch_async(dispatch_get_main_queue(),^{
//        // All the audio plot needs is the buffer data (float*) and the size. Internally the audio plot will handle all the drawing related code, history management, and freeing its own resources. Hence, one badass line of code gets you a pretty plot :)
//        if (self.audioPlot) {
//            [self.audioPlot updateBuffer:buffer[0] withBufferSize:bufferSize];
//        }
//    });
//}

// Starts the internal soundfile recorder
- (void)startRecording {
    // Create the recorder
    self.recorder = [VERecorder recorderWithDestinationURL:[self recordingFilePathURL]
                                              sourceFormat:[self.audioProcessor inputAudioStreamBasicDescription]
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
    return [VEAudioIO ASBDtoString:[self.audioProcessor outputAudioStreamBasicDescription]];
}

- (NSString *)soundInputDescription {
    return [VEAudioIO ASBDtoString:[self.audioProcessor inputAudioStreamBasicDescription]];
}

/**
 EZaudio File Utility functions
 */

- (NSString *)applicationDocumentsDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}

-(NSURL *)recordingFilePathURL {
    return [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@",
                                   [self applicationDocumentsDirectory],
                                   kAudioFilePath]];
}

@end
