//
//  VEAudioProcessor.h
//  VaavudElectronicSDK
//
//  Created by Andreas Okholm on 25/02/15.
//  Copyright (c) 2015 Vaavud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "VECircularBuffer.h"

@protocol VEAudioIODelegate <NSObject>

/**
 @param available is true if the Sliepnir wind meter is available to start measureing.
 */
- (void)sleipnirAvailabliltyDidChange: (BOOL) available;
- (void)processBuffer:(VECircularBuffer *)circBuffer withDefaultBufferLengthInFrames:(UInt32)bufferLengthInFrames;

@end

@protocol AudioManagerDelegate <NSObject>

- (void)vaavudStartedMeasuring;
- (void)vaavudStopMeasuring;
- (BOOL)sleipnirAvailable;

@end


//@protocol AudioProcessorProtocol <NSObject>
//
//- (void)processBuffer:(VECircularBuffer *)circBuffer withDefaultBufferLengthInFrames:(UInt32)bufferLengthInFrames;
//- (void)processBufferList:(AudioBufferList *)bufferList withBufferLengthInFrames:(UInt32)bufferLengthInFrames;
//- (void)processFloatBuffer:(float *)buffer withBufferLengthInFrames:(UInt32)bufferLengthInFrames;
//
//@end

@interface VEAudioIO : NSObject

@property (atomic) BOOL sleipnirAvailable;
@property (weak, nonatomic) id<VEAudioIODelegate> delegate;
@property (weak, nonatomic) id<VaavudElectronicMicrophoneOutputDelegate> microphoneOutputDeletage;


// Starts Playback and Recording when Vaavud becomes available
- (void)start;

// End Playback and Recording
- (void)stop;

// Recording of sound files

// Starts the internal soundfile recorder
- (void)startRecording;

// Ends the internal soundfile recorder
- (void)endRecording;

// returns true if recording is active
- (BOOL)isRecording;

// returns the local path of the recording
- (NSURL *)recordingPath;

// return the sound output description as NSString
- (NSString *)soundOutputDescription;

// return the sound input descriotion as NSString
- (NSString *)soundInputDescription;

// turns up or down the volume by a certain amount (0.0 - 1.0)
- (void)adjustVolumeLevelAmount:(float)adjustment;

@end
