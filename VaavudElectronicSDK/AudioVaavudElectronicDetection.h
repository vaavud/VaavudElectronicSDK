//
//  AudioVaavudElectronicDetection.h
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 27/08/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <Foundation/Foundation.h>

@protocol AudioVaavudElectronicDetectionDelegate <NSObject>

- (void) devicePlugedInChecking;
- (void) vaavudPlugedIn;
- (void) notVaavudPlugedIn;
- (void) deviceWasUnpluged;

@end


@interface AudioVaavudElectronicDetection : NSObject

// Initializer
- (id) initWithDelegate:(id<AudioVaavudElectronicDetectionDelegate>)delegate;

@property (nonatomic, readonly) VaavudElectronicConnectionStatus vaavudElectronicConnectionStatus;

@end
