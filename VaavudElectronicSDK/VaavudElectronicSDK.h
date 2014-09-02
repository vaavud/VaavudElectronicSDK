//
//  VaavudElectronicSDK.h
//  VaavudElectronicSDK
//
//  Created by Andreas Okholm on 31/08/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VaavudElectronicSDK.h"
#import "EZAudio.h"


@protocol VaavudElectronicWindDelegate <NSObject>

@optional
- (void) newSpeed: (NSNumber*) speed;
- (void) newWindDirection: (NSNumber*) windDirection;

- (void) vaavudPlugedIn;
- (void) vaavudWasUnpluged;
- (void) vaavudStartedMeasureing;
- (void) vaavudStopMeasureing;
- (void) notVaavudPlugedIn;

@end

typedef NS_ENUM(NSUInteger, VaavudElectronicConnectionStatus) {
    VaavudElectronicConnectionStatusUnchecked,
    VaavudElectronicConnectionStatusConnected,
    VaavudElectronicConnectionStatusNotConnected
};

@interface VaavudElectronicSDK : NSObject

+ (VaavudElectronicSDK *) sharedVaavudElectronic;

/* What is the current Vaavud Electronic connection status ? Initialize class as soon as possible to start detection*/
- (VaavudElectronicConnectionStatus) isVaavudElectronicConnected;

/* add listener of heading, windspeed and device information */
- (void) addListener:(id <VaavudElectronicWindDelegate>) delegate;

/* remove listener of heading, windspeed and device information */
- (void) removeListener:(id <VaavudElectronicWindDelegate>) delegate;

/* start the audio input/output (and location,heading) and starts sending data */
// If Vaavud Electronic is not inserted nothing will happen.
- (void) start;

/* stop the audio input/output  (and location,heading) and stop sending data */
- (void) stop;

// returnt the volume to initial state - to be used when the app closes
- (void) returnVolumeToInitialState;


@end