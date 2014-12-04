//
//  soundManager.h
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 21/07/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "VEVaavudElectronicSDK.h"

// Import EZAudio header
#import "EZAudio.h"

#import "VESoundProcessingAlgo.h"
#import "VEAudioVaavudElectronicDetection.h"


@protocol AudioManagerDelegate <NSObject>

- (void) vaavudStartedMeasureing;
- (void) vaavudStopMeasureing;

@end


@interface VEAudioManager : NSObject

// Initializer
- (id) initWithDelegate:( VEVaavudElectronicSDK <AudioManagerDelegate, SoundProcessingDelegate, DirectionDetectionDelegate>*) delegate;


// Starts Playback and Recording when Vaavud becomes available
- (void) start;

// End Playback and Recording
- (void) stop;


// Recording of sound files
// Starts the internal soundfile recorder
- (void) startRecording;

// Ends the internal soundfile recorder
- (void) endRecording;

// returns true if recording is active
- (BOOL) isRecording;

// returns the local path of the recording
- (NSURL*) recordingPath;

- (void) sleipnirAvailabliltyChanged: (BOOL) available ;

- (void) returnVolumeToInitialState;

// return the sound output description as NSString
- (NSString*) soundOutputDescription;

// return the sound input descriotion as NSString
- (NSString*) soundInputDescription;


@property (strong, nonatomic) VESoundProcessingAlgo *soundProcessor;
@property (weak, nonatomic) EZAudioPlotGL *audioPlot;

@end