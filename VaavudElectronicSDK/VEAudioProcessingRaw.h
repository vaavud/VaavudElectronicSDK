//
//  soundProcessing.h
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 09/06/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "VEAudioProcessingTick.h"
#import "VEAudioIO.h"

@protocol VEAudioProcessingDelegate <NSObject>
- (void)newMaxAmplitude:(NSNumber*) amplitude; // Analysis
@end

@interface VEAudioProcessingRaw : NSObject

- (void)processBuffer:(VECircularBuffer *)circBuffer withDefaultBufferLengthInFrames:(UInt32)bufferLengthInFrames;
- (void)newSoundData:(int *)data bufferLength:(UInt32) bufferLength;
- (id)initWithDelegate:(id<VEAudioProcessingDelegate>)delegate;
- (void)setVolumeAtSavedLevel;
- (void)returnVolumeToInitialState;

@property (weak, nonatomic) VEAudioProcessingTick *processorTick;
@end
