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

@protocol AudioProcessorProtocol <NSObject>

@optional
- (void)processBuffer:(VECircularBuffer *)circBuffer withDefaultBufferLengthInFrames:(UInt32)bufferLengthInFrames;
@optional
- (void)processBufferList:(AudioBufferList *)bufferList withBufferLengthInFrames:(UInt32)bufferLengthInFrames;
@optional
- (void)processFloatBuffer:(float *)buffer withBufferLengthInFrames:(UInt32)bufferLengthInFrames;

@end

@interface VEAudioIO : NSObject

@property (nonatomic, strong) id<AudioProcessorProtocol> delegate;

// control object
-(void)start;
-(void)startMicrophoneOnly;
-(void)stop;

- (AudioStreamBasicDescription)inputAudioStreamBasicDescription;
- (AudioStreamBasicDescription)outputAudioStreamBasicDescription;

/**
 Nicely logs out the contents of an AudioStreamBasicDescription struct
 @param 	asbd 	The AudioStreamBasicDescription struct with content to print out
 */
+(void)printASBD:(AudioStreamBasicDescription)asbd;

+ (NSString *)ASBDtoString:(AudioStreamBasicDescription)asbd;

@end
