//
//  AudioVaavudElectronicDetection.h
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 27/08/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import "VEAudioIO.h"

@protocol VEAudioSleipnirDetectionDelegate <NSObject>

/**
 @param available is true if the Sliepnir wind meter is available to start measureing.
 */
- (void) sleipnirAvailabliltyChanged: (BOOL) available;

/**
 called when a device (jack-plug) is inserted into the jack-plug
 @param available is true if the Sliepnir wind meter is available to start measureing.
 */
- (void) deviceConnectedTypeSleipnir: (BOOL) sleipnir;

/**
 called when a device is removed from the jack-plug
 @param sleipnir is true if it were a Sliepnir wind meter that were disconnected.
 */
- (void) deviceDisconnectedTypeSleipnir: (BOOL) sleipnir;

/**
 called when a audio route changes and a new device is pluged in, 
 starts checkking if it's a sleipnir.
 */
- (void) deviceConnectedChecking;

/**
 called when a audiofile is ready to be uploaded for analysis purposes
 */
- (void) newRecordingReadyToUpload;

@end


@interface VEAudioSleipnirDetection : NSObject <AudioProcessorProtocol>

// Initializer
- (id) initWithDelegate:(id<VEAudioSleipnirDetectionDelegate>)delegate;

- (void)processBuffer:(VECircularBuffer *)circBuffer withDefaultBufferLengthInFrames:(UInt32)bufferLengthInFrames;

@property (nonatomic, readonly) BOOL sleipnirAvailable;

@end
