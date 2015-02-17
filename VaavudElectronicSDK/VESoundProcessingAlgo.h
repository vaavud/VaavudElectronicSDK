//
//  soundProcessing.h
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 09/06/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "VEDirectionDetectionAlgo.h"

@protocol SoundProcessingDelegate <NSObject>

- (void) newMaxAmplitude: (NSNumber*) amplitude;

@end


@interface VESoundProcessingAlgo : NSObject

- (void) newSoundData:(int *)data bufferLength:(UInt32) bufferLength;

- (id)initWithDelegate:(id<SoundProcessingDelegate, DirectionDetectionDelegate>)delegate andVolume:(float)volume;

@property (strong, nonatomic) VEDirectionDetectionAlgo *dirDetectionAlgo;
@property (nonatomic, readonly) NSNumber *volume;

@end
