//
//  soundProcessing.h
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 09/06/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VEDirectionDetectionAlgo.h"

@protocol SoundProcessingDelegate <NSObject>

- (void) newMaxAmplitude: (NSNumber*) amplitude;

@end


@interface VESoundProcessingAlgo : NSObject

@property (strong, nonatomic) VEDirectionDetectionAlgo *dirDetectionAlgo;

- (void) newSoundData:(int *)data bufferLength:(UInt32) bufferLength;
- (id)initWithDelegate:(id<SoundProcessingDelegate, DirectionDetectionDelegate>)delegate;

@end
