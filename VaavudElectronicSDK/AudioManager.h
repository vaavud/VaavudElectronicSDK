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
#import "VaavudElectronicSDK.h"

// Import EZAudio header
#import "EZAudio.h"

#import "SoundProcessingAlgo.h"
#import "AudioVaavudElectronicDetection.h"


@protocol AudioManagerDelegate <NSObject>

- (void) vaavudStartedMeasureing;
- (void) vaavudStopMeasureing;

@end


@interface AudioManager : NSObject

// Initializer
- (id) initWithDelegate:( VaavudElectronicSDK <AudioManagerDelegate, SoundProcessingDelegate, DirectionDetectionDelegate>*) delegate;


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

- (void) deviceWasUnpluged;

- (void) vaavudPlugedIn;

- (void) returnVolumeToInitialState;


@property (strong, nonatomic) SoundProcessingAlgo *soundProcessor;
@property (weak, nonatomic) EZAudioPlotGL *audioPlot;

@end
