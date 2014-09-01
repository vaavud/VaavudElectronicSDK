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
#import "VaavudElectronicSDK.h"

@protocol AudioVaavudElectronicDetectionDelegate <NSObject>

- (void) vaavudPlugedIn;
- (void) vaavudWasUnpluged;
- (void) notVaavudPlugedIn;

@end


@interface AudioVaavudElectronicDetection : NSObject

// Initializer
- (id) initWithDelegate:(id<AudioVaavudElectronicDetectionDelegate>)delegate;

@property (nonatomic, readonly) VaavudElectronicConnectionStatus vaavudElectronicConnectionStatus;

@end
