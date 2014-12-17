//
//  VaavudElectronicSDK.h
//  VaavudElectronicSDK
//
//  Created by Andreas Okholm on 31/08/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EZAudio.h"


@protocol VaavudElectronicWindDelegate <NSObject>

@optional
/**
 
 @param speed is the windspeed in m/s measured.
 */
- (void) newSpeed: (NSNumber*) speed;

/**
 
 @param windDirection is the direction where the wind is comming from measured in degrees from 0 to 359.
 */
- (void) newWindDirection: (NSNumber*) windDirection;

/**
 
 @param wind angle is the wind direction where the wind is comming from relative to the phone in degrees
 from 0 to 359. The 0 reference direction is when the direction perpendicular to the screen, comming from the backside
 towards the front.
 */
- (void) newWindAngleLocal:(NSNumber*) angle;

/**
 
 @param heading is the direction the the phone is pointing as defined by iOS when the phone is upside down 180 degrees is added.
 */
- (void) newHeading: (NSNumber*) heading;


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
 if SDK is asked start before device is avilable it will automatically start.
 is called when the algorithm start measureing and will deliver callbacks.
 */
- (void) sleipnirStartedMeasureing;

/**
 is called when the algorithm stops measureing. ie. if device is removed.
 */
- (void) sleipnirStopedMeasureing;


/**
 called during the calibration process to provided user feedback
 */
- (void) calibrationPercentageComplete: (NSNumber*) percentage;

@end


@interface VEVaavudElectronicSDK : NSObject

+ (VEVaavudElectronicSDK *) sharedVaavudElectronic;

/**
 is the sleipnir avialable to start measureing?
 */
- (BOOL) sleipnirAvailable;

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

// start calibration mode
-(void) startCalibration;

// end calibbration mode
-(void) endCalibration;

@end