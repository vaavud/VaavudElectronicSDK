//
//  AudioVaavudElectronicDetection.m
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 27/08/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import "AudioVaavudElectronicDetection.h"
#import "AudioManager.h"

# define VAAVUD_NOISE_PP_MAXIMUM 0.01
# define NUMBER_OF_SAMPLES 20

@interface AudioVaavudElectronicDetection() <EZMicrophoneDelegate>

@property id<AudioVaavudElectronicDetectionDelegate> delegate;
@property (nonatomic, readwrite) VaavudElectronicConnectionStatus vaavudElectronicConnectionStatus;

/** The microphone component */
@property (nonatomic,strong) EZMicrophone *microphone;

@property (nonatomic) NSUInteger sampleCounter;
@property (nonatomic) float noiseMax;
@property (nonatomic) float noiseMin;
@property (nonatomic) BOOL samplingMicrophoneActice;


@end

@implementation AudioVaavudElectronicDetection


-(id)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"-init is not a valid initializer for the class AudioVaavudElectronicDetection"
                                 userInfo:nil];
    return nil;
}

- (id) initWithDelegate:(id<AudioVaavudElectronicDetectionDelegate>)delegate {
    self = [super init];
    if (self) {
        // register for notification for chances in audio routing (inserting/removing jack plut)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioRouteChangeListenerCallback:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:nil];
        self.delegate = delegate;
        
        self.vaavudElectronicConnectionStatus = VaavudElectronicConnectionStatusUnchecked;
        
        
        // Create an instance of the microphone and tell it to use this object as the delegate
        self.microphone = [EZMicrophone microphoneWithDelegate:self];
        
        self.samplingMicrophoneActice = NO;
        
        // INITIALIZE CHECK;
        [self checkIfRegularHeadsetOrVaavud];
    }
    
    return  self;
    
    
}


- (BOOL) isHeadphoneOutAvailable {
    [self.microphone startFetchingAudio];
    AVAudioSessionRouteDescription *audioRoute = [[AVAudioSession sharedInstance] currentRoute];
    for (AVAudioSessionPortDescription* desc in [audioRoute outputs]) {
        if ([[desc portType] isEqualToString:AVAudioSessionPortHeadphones]) {
            [self.microphone stopFetchingAudio];
            return YES;
        }
    }
    return NO;
}


- (BOOL) isHeadphoneMicAvailable {
    
    // For some reason Microphone needs to be active to determine audio route properly.
    // It works fine the first time the app is started without....

    [self.microphone startFetchingAudio];
    AVAudioSessionRouteDescription *audioRoute = [[AVAudioSession sharedInstance] currentRoute];
    for (AVAudioSessionPortDescription* desc in [audioRoute inputs]) {
        if ([[desc portType] isEqualToString:AVAudioSessionPortHeadsetMic]) {
            [self.microphone stopFetchingAudio];
            return YES;
        }
        
    }
    [self.microphone stopFetchingAudio];
    return NO;
}



// If the user pulls out he headphone jack, stop playing.
- (void)audioRouteChangeListenerCallback:(NSNotification*)notification
{
    NSDictionary *interuptionDict = notification.userInfo;
    
    NSInteger routeChangeReason = [[interuptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    
    switch (routeChangeReason) {
            
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable: {
            
            self.vaavudElectronicConnectionStatus = VaavudElectronicConnectionStatusNotConnected;
            dispatch_async(dispatch_get_main_queue(),^{
                [self.delegate deviceWasUnpluged];
            });
            break;
        }
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable: {
            
            if (self.vaavudElectronicConnectionStatus != VaavudElectronicConnectionStatusConnected) {
                dispatch_async(dispatch_get_main_queue(),^{
                    [self.delegate devicePlugedInChecking];
                });
                
                [self checkIfRegularHeadsetOrVaavud];
            }
            
            break;
        }
            //        case AVAudioSessionRouteChangeReasonCategoryChange:
            //            // called at start - also when other audio wants to play
            //            NSLog(@"AVAudioSessionRouteChangeReasonCategoryChange");
            //            break;
            
        default: {
            //NSLog(@"default audio stuff");
        }
    }
}


- (void) checkIfRegularHeadsetOrVaavud {
    
    
    if ([self isHeadphoneOutAvailable] && [self isHeadphoneMicAvailable]) {
         // take 20 samples (full buffers) from the micrphone and estimate sum. If sum is over a certain threshold it's most likely a microphone because of the low frequency noise.

        self.sampleCounter = 0;
        self.samplingMicrophoneActice = YES;
        
        float sampleFrequency = 44100;
        float wantedBufferLength = 512;
        float bufferDuration = wantedBufferLength / sampleFrequency;
        
        NSError* err;
        [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:bufferDuration error:&err];
        
        if (err) {
            [NSException raise:@"VAEAudioException" format: @"Could not set prefered IOBuffer durration on AVAudioSession. %@", err.description];
        }
        
        
        [self.microphone startFetchingAudio];

    }

    
}

- (void) endCheckIfRegularHeadSetOrVaavud {
    
    self.samplingMicrophoneActice = NO;
    [self.microphone stopFetchingAudio];
    
    float noisePP = self.noiseMax - self.noiseMin;
    
    NSLog(@"Noise max: %f, min: %f, PP-value: %f", self.noiseMax, self.noiseMin, noisePP);
    
    if (noisePP < VAAVUD_NOISE_PP_MAXIMUM) {
        self.vaavudElectronicConnectionStatus = VaavudElectronicConnectionStatusConnected;
        dispatch_async(dispatch_get_main_queue(),^{
            [self.delegate vaavudPlugedIn];
        });
    } else {
        self.vaavudElectronicConnectionStatus = VaavudElectronicConnectionStatusNotConnected;
        dispatch_async(dispatch_get_main_queue(),^{
            [self.delegate notVaavudPlugedIn];
        });
    }
    
}


/* delegate method - Feed microphone data to sound-processor and plot */
#pragma mark - EZMicrophoneDelegate
#warning Thread Safety
// Note that any callback that provides streamed audio data (like streaming microphone input) happens on a separate audio thread that should not be blocked. When we feed audio data into any of the UI components we need to explicity create a GCD block on the main thread to properly get the UI to work.
-(void)microphone:(EZMicrophone *)microphone
 hasAudioReceived:(float **)buffer
   withBufferSize:(UInt32)bufferSize
withNumberOfChannels:(UInt32)numberOfChannels {
    // Getting audio data as an array of float buffer arrays. What does that mean? Because the audio is coming in as a stereo signal the data is split into a left and right channel. So buffer[0] corresponds to the float* data for the left channel while buffer[1] corresponds to the float* data for the right channel.
    
    if (self.samplingMicrophoneActice) {
        float *bufferArray = buffer[0];
        
        float sum = 0;
        
        for (int i = 0; i < bufferSize; i++) {
            sum = sum + bufferArray[i];
        }
        
        
        if (self.sampleCounter == 0) {
            self.noiseMax = sum;
            self.noiseMin = sum;
        } else {
            if (sum > self.noiseMax) {
                self.noiseMax = sum;
            }
            
            if (sum < self.noiseMin) {
                self.noiseMin = sum;
            }
        }
        
        
        self.sampleCounter += 1;
        
        
        NSLog(@"sum value: %f with Bufferlength %i", sum, (unsigned int)bufferSize);
        
        
        if (self.sampleCounter == NUMBER_OF_SAMPLES) {
            [self endCheckIfRegularHeadSetOrVaavud];
        }
        
        
    }
    
//    // See the Thread Safety warning above, but in a nutshell these callbacks happen on a separate audio thread. We wrap any UI updating in a GCD block on the main thread to avoid blocking that audio flow.
//    dispatch_async(dispatch_get_main_queue(),^{
//        
//    });
    
    
}



@end
