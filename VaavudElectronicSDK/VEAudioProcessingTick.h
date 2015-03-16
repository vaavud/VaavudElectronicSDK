//
//  soundProcessing.h
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 09/06/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "VEAudioProcessingSpeedDirection.h"
#import "VEAudioIO.h"

@protocol SoundProcessingDelegate <NSObject>

- (void) newMaxAmplitude: (NSNumber*) amplitude;

@end


@interface VEAudioProcessingTick : NSObject <AudioProcessorProtocol>

- (void)processBuffer:(VECircularBuffer *)circBuffer withDefaultBufferLengthInFrames:(UInt32)bufferLengthInFrames;
- (void)newSoundData:(int *)data bufferLength:(UInt32) bufferLength;
- (id)initWithDelegate:(id<SoundProcessingDelegate, DirectionDetectionDelegate>)delegate;
- (void)setVolumeAtSavedLevel;
- (void)returnVolumeToInitialState;

@property (strong, nonatomic) VEAudioProcessingSpeedDirection *dirDetectionAlgo;
@end
