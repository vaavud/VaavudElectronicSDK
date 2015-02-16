//
//  soundManager.m
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 21/07/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#define kAudioFilePath @"tempRawAudioFile.wav"

#define sampleFrequency 44100
#define signalFrequency 14700
#define musicPlayerVolume 0.95

#import "VEAudioManager.h"

@interface VEAudioManager() <EZMicrophoneDelegate, EZOutputDataSource>

@property (atomic) BOOL askedToMeasure;
@property (atomic) BOOL recordingActive;
@property (atomic) BOOL algorithmActice;
@property (nonatomic, strong) NSNumber *originalAudioVolume;

/** The microphone component */
@property (nonatomic,strong) EZMicrophone *microphone;

/** The recorder component */
@property (nonatomic,strong) EZRecorder *recorder;

@property (nonatomic, weak) VEVaavudElectronicSDK <AudioManagerDelegate> *delegate;

@end

@implementation VEAudioManager {
    double theta;
    double theta_increment;
    double amplitude;
    int *intArray;
    float *arrayLeft;
}


#pragma mark - Initialization
- (id)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"-init is not a valid initializer for the class AudioManager"
                                 userInfo:nil];
    return nil;
}

- (id)initWithDelegate:(id<AudioManagerDelegate, SoundProcessingDelegate, DirectionDetectionDelegate>)delegate {
    self = [super init];
    
    self.delegate = delegate;
    
    // create sound processor (locates ticks)
    self.soundProcessor = [[VESoundProcessingAlgo alloc] initWithDelegate:delegate];
    
    // Create an instance of the microphone and tell it to use this object as the delegate
    self.microphone = [EZMicrophone microphoneWithDelegate:self];
    
    [self.microphone setAudioStreamBasicDescription: [self getAudioStreamBasicDiscriptionMicrophone]];
    [self.microphone _configureStreamFormatWithSampleRate: sampleFrequency]; // need to set ASBD first
    
    
    // CHECK MICROPHONE INPUT FORMAT
    if (LOG_AUDIO){
        NSLog(@"[VESDK] input");
        [EZAudio printASBD: [self.microphone audioStreamBasicDescription]];
    }
    
    AudioStreamBasicDescription ASBDinput = [self.microphone audioStreamBasicDescription];
    
    if (ASBDinput.mSampleRate != [self getAudioStreamBasicDiscriptionMicrophone].mSampleRate) {
        if(LOG_AUDIO){NSLog(@"[VESDK] Ups wrong sample rate");}
    }
      
    [self setupSoundOutput];
    
    // Assign a delegate to the shared instance of the output to provide the output audio data
    [EZOutput sharedOutput].outputDataSource = self;
    
    // set the output format from the audioOutput stream.
    [[EZOutput sharedOutput] setAudioStreamBasicDescription: [self getAudioStreamBasicDiscriptionOutput]];
    
    if(LOG_AUDIO){
        NSLog(@"[VESDK] output");
        [EZAudio printASBD: [[EZOutput sharedOutput] audioStreamBasicDescription]];
    }
    
    // CHECK OUTPUT FORMAT
    
    self.askedToMeasure = NO;
    self.algorithmActice = NO;
    self.recordingActive = NO;
    
    return self;
}

- (void)start {
    self.askedToMeasure = YES;
    
    if (!self.algorithmActice) {
        if (self.delegate.sleipnirAvailable) {
            [self startInternal];
        }
    }
}

- (void)stop {
    self.askedToMeasure = NO;
    
    if (self.algorithmActice) {
        [self stopInternal];
    }
}


- (void)startInternal {
    self.algorithmActice = YES;
    
    [self toggleMicrophone: YES];
    [self toggleOutput: YES];
    
    [self checkIfVolumeAtSavedLevel];
    
     dispatch_async(dispatch_get_main_queue(),^{
        [self.delegate vaavudStartedMeasuring];
    });
}


- (void)stopInternal {
    self.algorithmActice = NO;
    
    [self toggleMicrophone: NO];
    [self toggleOutput: NO];
    
    dispatch_async(dispatch_get_main_queue(),^{
        [self.delegate vaavudStopMeasuring];
    });
    
    [self returnVolumeToInitialState];
}

- (void)sleipnirAvailabliltyChanged:(BOOL)available {
    if (available) {
        if (self.askedToMeasure) {
            [self startInternal];
        }
    }
    else {
        [self returnVolumeToInitialState];
        if (self.algorithmActice) {
            [self stopInternal];
        }
    }
}


- (void)checkIfVolumeAtSavedLevel {
    // check if volume is at maximum.
    MPMusicPlayerController *musicPlayer = [MPMusicPlayerController applicationMusicPlayer];
    float volume = [[NSUserDefaults standardUserDefaults] floatForKey:@"VOLUME"];
    
    if (volume == 0) {
        volume = 1.0;
    }
    
    volume = 0;
    
    if (musicPlayer.volume != volume) {
        self.originalAudioVolume = @(musicPlayer.volume);
        musicPlayer.volume = volume; // device volume will be changed to maximum value
    }
}

- (void)returnVolumeToInitialState {
    [[NSUserDefaults standardUserDefaults] setFloat:[MPMusicPlayerController applicationMusicPlayer].volume forKey:@"VOLUME"];
    if (self.originalAudioVolume) {
        MPMusicPlayerController* musicPlayer = [MPMusicPlayerController applicationMusicPlayer];
        if (musicPlayer.volume != self.originalAudioVolume.floatValue) {
            musicPlayer.volume = self.originalAudioVolume.floatValue;
        }
    }
}

// Starts the internal soundfile recorder
- (void)startRecording {
    // Create the recorder
    self.recorder = [EZRecorder recorderWithDestinationURL:[self recordingFilePathURL]
                                              sourceFormat:self.microphone.audioStreamBasicDescription
                                       destinationFileType:EZRecorderFileTypeWAV];
    
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

- (void)setupSoundOutput {
    double frequency = signalFrequency;
    double samplerate = sampleFrequency;
    theta_increment = 2.0*M_PI*frequency/samplerate;
    amplitude = 1;
}

/* delegate method - Feed microphone data to sound-processor and plot */
#pragma mark - EZMicrophoneDelegate
// #warning Thread Safety
// Note that any callback that provides streamed audio data (like streaming microphone input) happens on a separate audio thread that should not be blocked. When we feed audio data into any of the UI components we need to explicity create a GCD block on the main thread to properly get the UI to work.
-(void)microphone:(EZMicrophone *)microphone
 hasAudioReceived:(float **)buffer
   withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels {
    // Getting audio data as an array of float buffer arrays. What does that mean? Because the audio is coming in as a stereo signal the data is split into a left and right channel. So buffer[0] corresponds to the float* data for the left channel while buffer[1] corresponds to the float* data for the right channel.
    
    if (intArray == NULL) {
        arrayLeft = buffer[0];
        
        intArray = malloc(sizeof(int) * bufferSize); /* allocate memory for 50 int's */
        if (!intArray) { /* If data == 0 after the call to malloc, allocation failed for some reason */
            perror("Error allocating memory");
            abort();
        }
        /* at this point, we know that data points to a valid block of memory.
         Remember, however, that this memory is not initialized in any way -- it contains garbage.
         Let's start by clearing it. */
        memset(intArray, 0, sizeof(int)*bufferSize);
        /* now our array contains all zeroes. */
    }
    
    for (int i = 0; i < bufferSize; ++i) {
        intArray[i] = (int) (arrayLeft[i]*1000);
    }
    
    [self.soundProcessor newSoundData:intArray bufferLength:bufferSize];
    
    // See the Thread Safety warning above, but in a nutshell these callbacks happen on a separate audio thread. We wrap any UI updating in a GCD block on the main thread to avoid blocking that audio flow.
    dispatch_async(dispatch_get_main_queue(),^{
        // All the audio plot needs is the buffer data (float*) and the size. Internally the audio plot will handle all the drawing related code, history management, and freeing its own resources. Hence, one badass line of code gets you a pretty plot :)
        if (self.audioPlot) {
            [self.audioPlot updateBuffer:buffer[0] withBufferSize:bufferSize];
        }
    });
}

// delegate method - feed microphone data to recorder (audio file).
-(void)microphone:(EZMicrophone *)microphone
    hasBufferList:(AudioBufferList *)bufferList
   withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels {
    // Getting audio data as a buffer list that can be directly fed into the EZRecorder. This is happening on the audio thread - any UI updating needs a GCD main queue block. This will keep appending data to the tail of the audio file.
    if (self.recordingActive) {
        [self.recorder appendDataFromBufferList:bufferList withBufferSize:bufferSize];
    }
}




- (void)toggleOutput:(BOOL)output {
    if (output) {
        [EZOutput sharedOutput].outputDataSource = self;
        [[EZOutput sharedOutput] startPlayback];
    }
    else {
        [[EZOutput sharedOutput] stopPlayback];
    }
}

- (void)toggleMicrophone:(BOOL)micOn {
    if (micOn) {
        [self.microphone startFetchingAudio];
    }
    else {
        [self.microphone stopFetchingAudio];
    }
}

/**
 OUTPUT
 */

// Use the AudioBufferList datasource method to read from an EZAudioFile
- (void)             output:(EZOutput *)output
 shouldFillAudioBufferList:(AudioBufferList *)audioBufferList
        withNumberOfFrames:(UInt32)frames
{
    // This is a mono tone generator so we only need the first buffer
	const int channelLeft = 0;
	const int channelRight = 1;
    
    Float32 *bufferLeft = (Float32 *)audioBufferList->mBuffers[channelLeft].mData;
    Float32 *bufferRight = (Float32 *)audioBufferList->mBuffers[channelRight].mData;
    
    // Generate the samples
	for (UInt32 frame = 0; frame < frames; frame++)
	{
		bufferLeft[frame] = sin(theta) * amplitude;
        bufferRight[frame] = -sin(theta) * amplitude;
        
		theta += theta_increment;
		if (theta > 2.0*M_PI)
		{
			theta -= 2.0*M_PI;
		}
	}
}

- (NSString *)soundOutputDescription {
    return [self ASBDtoString:[[EZOutput sharedOutput] audioStreamBasicDescription]];
}

- (NSString *)soundInputDescription {
    return [self ASBDtoString:[self.microphone audioStreamBasicDescription]];
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

- (AudioStreamBasicDescription)getAudioStreamBasicDiscriptionOutput {
    UInt32 bytesPerSample = sizeof(float);
    AudioStreamBasicDescription stereoStreamFormat = {0};
    
    stereoStreamFormat.mFormatID          = kAudioFormatLinearPCM;
    //    stereoStreamFormat.mFormatFlags       = kAudioFormatFlagsAudioUnitCanonical;
    stereoStreamFormat.mFormatFlags       = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    stereoStreamFormat.mBytesPerPacket    = bytesPerSample;
    stereoStreamFormat.mBytesPerFrame     = bytesPerSample;
    stereoStreamFormat.mFramesPerPacket   = 1;
    stereoStreamFormat.mBitsPerChannel    = 8 * bytesPerSample;
    stereoStreamFormat.mChannelsPerFrame  = 2;           // 2 indicates stereo
    stereoStreamFormat.mSampleRate        = sampleFrequency;
    
    return stereoStreamFormat;
}

- (AudioStreamBasicDescription)getAudioStreamBasicDiscriptionMicrophone {
    UInt32 bytesPerSample = sizeof(float);
    AudioStreamBasicDescription stereoStreamFormat = {0};
    
    stereoStreamFormat.mFormatID          = kAudioFormatLinearPCM;
    //    stereoStreamFormat.mFormatFlags       = kAudioFormatFlagsAudioUnitCanonical;
    stereoStreamFormat.mFormatFlags       = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
    stereoStreamFormat.mBytesPerPacket    = bytesPerSample;
    stereoStreamFormat.mBytesPerFrame     = bytesPerSample;
    stereoStreamFormat.mFramesPerPacket   = 1;
    stereoStreamFormat.mBitsPerChannel    = 8 * bytesPerSample;
    stereoStreamFormat.mChannelsPerFrame  = 2;           // 2 indicates stereo
    stereoStreamFormat.mSampleRate        = sampleFrequency;
    
    return stereoStreamFormat;
}

- (NSString *)ASBDtoString:(AudioStreamBasicDescription)asbd  {
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
@end
