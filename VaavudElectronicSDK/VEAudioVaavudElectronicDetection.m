//
//  AudioVaavudElectronicDetection.m
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 27/08/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import "VEAudioVaavudElectronicDetection.h"
#import "VEAudioManager.h"

#import <Accelerate/Accelerate.h>

# define VAAVUD_NOISE_MAXIMUM 0.01

# define NUMBER_OF_OUTPUT_SIGNAL_SAMPLES 1024

# define BufferLength 256
# define NFFT 8192
# define Log2N 13
# define sampleFrequency 44100

#define kAudioFilePath @"tempRawAudioFile.wav"

@interface VEAudioVaavudElectronicDetection() <EZMicrophoneDelegate>

@property id<AudioVaavudElectronicDetectionDelegate> delegate;
@property (atomic, readwrite) BOOL sleipnirAvailable;
@property (atomic) BOOL deviceConnected;
@property (nonatomic) BOOL audioRouteChange;

/** The microphone component */
@property (nonatomic,strong) EZMicrophone *microphone;

/** The recorder component */
@property (nonatomic,strong) EZRecorder *recorder;
@property (atomic) BOOL recordingActive;


@property (nonatomic) NSUInteger sampleCounter;
@property (nonatomic) BOOL samplingMicrophoneActice;
@property (nonatomic) double timer;

@end

@implementation VEAudioVaavudElectronicDetection {
    float micSignal[NFFT];
    int micSignalIndex;
}


-(id)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"[VESDK] -init is not a valid initializer for the class AudioVaavudElectronicDetection"
                                 userInfo:nil];
    return nil;
}

/*
  Initializer - setup and starts device detection
 */
- (id) initWithDelegate:(id<AudioVaavudElectronicDetectionDelegate>)delegate {
    self = [super init];
    if (self) {
        // register for notification for chances in audio routing (inserting/removing jack plut)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioRouteChangeListenerCallback:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:nil];
        self.delegate = delegate;
        self.sleipnirAvailable = NO;
        self.audioRouteChange = NO;
        self.samplingMicrophoneActice = NO;
        self.recordingActive = NO;
        
        // Create an instance of the microphone and tell it to use this object as the delegate
        self.microphone = [EZMicrophone microphoneWithDelegate:self];
        [self setupMicrophone];
        [self.microphone setAudioStreamBasicDescription: [self getAudioStreamBasicDiscriptionMicrophone]];
        
        
        self.timer = CACurrentMediaTime();
        [self startCheckDeviceAvailabilityByAudioReroute: NO];
        
    }
    
    return  self;
}



/*
 Starts checking for device availability
 */
- (void) startCheckDeviceAvailabilityByAudioReroute: (BOOL) audioRouteChange{
    
    micSignalIndex = 0;
    
    self.audioRouteChange = audioRouteChange;
    
    // start microphone to be able to deterime if Headphone and microphone is available
    [self.microphone startFetchingAudio];

    // check if headset Out and headset mic is available
    
    if ([self isHeadphoneOutAvailable] && [self isHeadphoneMicAvailable]) {
        self.deviceConnected = YES;
        
        // OTHER recording doesnt work when active - [self startRecording];
        self.sampleCounter = 0; // analysis algorithm is reset when samples is set to 0.
        self.samplingMicrophoneActice = YES; // Since the micrphone is already running this enables the analysis of the data

    
    } else {
        self.deviceConnected = NO;
        [self updateSleipnirAvailable: NO];
        
        if (self.audioRouteChange) {
            [self.delegate deviceConnectedTypeSleipnir:NO];
        }
    }
    
}


/*
 Setup microphone details
 */

- (void) setupMicrophone {
    // SETUP microphone buffer settings and start microphone
    
    float bufferDuration = (float) BufferLength / sampleFrequency;
    
    NSError* err;
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:bufferDuration error:&err];
    
    if (err) {
        [NSException raise:@"VAEAudioException" format: @"Could not set prefered IOBuffer durration on AVAudioSession. %@", err.description];
    }
//    [EZAudio printASBD: [self.microphone audioStreamBasicDescription]];
    
}


/*
 End the Check
 */

- (void) endAudioCharacteristicsAnalysisPass {
    
    
    if (YES) {
        
        if (self.audioRouteChange) {
            [self.delegate deviceConnectedTypeSleipnir:YES];
        }
        [self updateSleipnirAvailable: YES];
        
    } else {
        
        if (self.audioRouteChange) {
             [self.delegate deviceConnectedTypeSleipnir:NO];
        }
        [self updateSleipnirAvailable: NO];
        [self.microphone stopFetchingAudio];
    }
    
    [self.delegate newRecordingReadyToUpload];
    [self processMicSample];
    
    
}


- (void) processMicSample {
    float magnitude[NFFT/2];
    
    FFTSetup fftSetup = vDSP_create_fftsetup(Log2N, FFT_RADIX2);
    COMPLEX_SPLIT A;
    COMPLEX_SPLIT B;
    A.realp = (float*) malloc(sizeof(float) * NFFT/2);
    A.imagp = (float*) malloc(sizeof(float) * NFFT/2);
    
    B.realp = (float*) malloc(sizeof(float) * NFFT/2);
    B.imagp = (float*) malloc(sizeof(float) * NFFT/2);
    
    
    /* Carry out a Forward and Inverse FFT transform. */
    vDSP_ctoz((COMPLEX *) micSignal, 2, &A, 1, NFFT/2);
    vDSP_fft_zrip(fftSetup, &A, 1, Log2N, FFT_FORWARD);
    
    
    
    magnitude[0] = sqrtf(A.realp[0]*A.realp[0]);
    
    
    //get magnitude;
    for(int i = 1; i < NFFT/2; i++){
        magnitude[i] = sqrtf(A.realp[i]*A.realp[i] + A.imagp[i] * A.imagp[i]);
    }
    
    for (int i = 0 ;i < 66; i++) {
//        NSLog(@"mag %i : %f", i, magnitude[i]);
    }
    
    
    free(A.realp);
    free(A.imagp);
    free(B.realp);
    free(B.imagp);
}



// #warning Thread Safety
// Note that any callback that provides streamed audio data (like streaming microphone input) happens on a separate audio thread that should not be blocked. When we feed audio data into any of the UI components we need to explicity create a GCD block on the main thread to properly get the UI to work.
// If the user pulls out he headphone jack, stop playing.
- (void)audioRouteChangeListenerCallback:(NSNotification*)notification
{
    NSDictionary *interuptionDict = notification.userInfo;
    
    NSInteger routeChangeReason = [[interuptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    
    switch (routeChangeReason) {
            
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable: {
            
            if (self.deviceConnected) {
                self.deviceConnected = NO;
                
                dispatch_async(dispatch_get_main_queue(),^{
                    [self.delegate deviceDisconnectedTypeSleipnir: self.sleipnirAvailable]; // Important to send update beforesetting availablity
                    [self updateSleipnirAvailable: NO];
                });
            }
            
            break;
        }
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable: {
            
            self.deviceConnected = YES;
            
            if (!self.sleipnirAvailable) {
                
                dispatch_async(dispatch_get_main_queue(),^{
                    [self.delegate deviceConnectedChecking];
                    
                    self.timer = CACurrentMediaTime();
                    [self startCheckDeviceAvailabilityByAudioReroute: YES];
                });
            }
            break;
        }
            
        default: {
            //NSLog(@"default audio stuff");
        }
    }
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
    

    
    
    if (self.samplingMicrophoneActice) {
        float *bufferArray = *buffer;
        
        
        if (self.sampleCounter > 10) {
            if (micSignalIndex < NFFT) {
                for (int i = 0; i < bufferSize; i++) {
                    micSignal[micSignalIndex] = bufferArray[i]*1000;
                    micSignalIndex++;
                }
            }
        }
    
        float max;
        float min;
        float sum;
        
        vDSP_maxv(bufferArray, 1, &max, bufferSize);
        vDSP_minv(bufferArray, 1, &min, bufferSize);
        vDSP_sve(bufferArray, 1, &sum, bufferSize);
        
        
        self.sampleCounter += 1;
        
        
//        NSLog(@"[VESDK] sum value: %f with Bufferlength %i", sum, (unsigned int)bufferSize);
        
        if (self.sampleCounter == 100) {
            self.samplingMicrophoneActice = NO;
            
            dispatch_async(dispatch_get_main_queue(),^{
                [self endAudioCharacteristicsAnalysisPass];
            });
        }
        
        
    }
    
}


// delegate method - feed microphone data to recorder (audio file).
-(void)microphone:(EZMicrophone *)microphone
    hasBufferList:(AudioBufferList *)bufferList
   withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels {
    
    // Getting audio data as a buffer list that can be directly fed into the EZRecorder. This is happening on the audio thread - any UI updating needs a GCD main queue block. This will keep appending data to the tail of the audio file.
    if( self.recordingActive ){
        [self.recorder appendDataFromBufferList:bufferList
                                 withBufferSize:bufferSize];
    }
}



- (void) updateSleipnirAvailable: (BOOL) available {
    
    if (self.sleipnirAvailable != available) {
        self.sleipnirAvailable = available;
        
        [self.delegate sleipnirAvailabliltyChanged:available];
        
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
    NSLog(@"[VESDK] Not vaavud, failed on headphoneOut");
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
    //[self.microphone stopFetchingAudio];
    NSLog(@"[VESDK] Not vaavud, failed on mic availiable");
    return NO;
}



// Starts the internal soundfile recorder
- (void) startRecording {
    // Create the recorder
    self.recorder = [EZRecorder recorderWithDestinationURL:[self recordingFilePathURL]
                                              sourceFormat:self.microphone.audioStreamBasicDescription
                                       destinationFileType:EZRecorderFileTypeWAV];
    
    self.recordingActive = YES;
}

// Ends the internal soundfile recorder
- (void) endRecording {
    self.recordingActive = NO;
    [self.recorder closeAudioFile];
    self.recorder = nil;
    
}


// returns the local path of the recording
- (NSURL*) recordingPath {
    return [self recordingFilePathURL];
}



/**
 EZaudio File Utility functions
 */

-(NSString*)applicationDocumentsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}

-(NSURL*)recordingFilePathURL {
    return [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@",
                                   [self applicationDocumentsDirectory],
                                   kAudioFilePath]];
}




- (AudioStreamBasicDescription) getAudioStreamBasicDiscriptionOutput {
    
    UInt32 bytesPerSample = sizeof (float);
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


- (AudioStreamBasicDescription) getAudioStreamBasicDiscriptionMicrophone {
    
    UInt32 bytesPerSample = sizeof (float);
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



@end