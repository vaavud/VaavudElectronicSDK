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
#import "TPCircularBuffer.h"

@protocol AudioProcessorProtocol <NSObject>

- (void)processBuffer:(TPCircularBuffer *)circBuffer withDefaultBufferLengthInFrames:(UInt32)bufferLengthInFrames;

@end

@interface VEAudioProcessor : NSObject

@property (weak, nonatomic) EZAudioPlotGL *audioPlot;
@property (nonatomic, strong) id<AudioProcessorProtocol> delegate;
@property (nonatomic) float gain;

// control object
-(void)start;
-(void)startMicrophoneOnly;
-(void)stop;

@end
