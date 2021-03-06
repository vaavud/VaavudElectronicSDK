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
#import "VESummeryGenerator.h"

@protocol VEAudioProcessingRawDelegate <NSObject>
- (void)newMaxAmplitude:(NSNumber*) amplitude; // Analysis
- (void)volumeResponse:(VEVolumeReponse *)volumeResponse;
- (void)adjustVolume:(float) adjustment;
@end

@interface VEAudioProcessingRaw : NSObject

- (void)checkAndProcess:(VECircularBuffer *)circBuffer withDefaultBufferLengthInFrames:(UInt32)bufferLengthInFrames;
- (id)initWithDelegate:(id<VEAudioProcessingRawDelegate>)delegate;

@property (weak, nonatomic) VEAudioProcessingTick *processorTick;

@end
