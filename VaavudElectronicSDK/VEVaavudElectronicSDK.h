//
//  VaavudElectronicSDK.h
//  VaavudElectronicSDK
//
//  Created by Andreas Okholm on 31/08/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WindMeasurement : NSObject
@property NSDate *time;
@property float speed;
@property float directionGlobal;
@property float directionLocal;
@property float heading;
@end


@protocol VaavudElectronicWindDelegate <NSObject>

@optional
/**
 @param new measurement containing all live wind data.
 */
- (void)newWindMeasurement:(WindMeasurement *)measurement;

/**
 @param speed is the windspeed in m/s measured.
 */
- (void)newSpeed:(NSNumber *)speed;

/**
 @param windDirection is the direction where the wind is comming from measured in degrees from 0 to 359.
 */
- (void)newWindDirection:(NSNumber *)windDirection;

/**
 @param wind angle is the wind direction where the wind is comming from relative to the phone in degrees
 from 0 to 359. The 0 reference direction is when the direction perpendicular to the screen, comming from the backside
 towards the front.
 */
- (void)newWindAngleLocal:(NSNumber *)angle;

/**
 @param heading is the direction the the phone is pointing as defined by iOS when the phone is upside down 180 degrees is added.
 */
- (void)newHeading:(NSNumber *)heading;

/**
 @param available is true if the Sliepnir wind meter is available to start measureing.
 */
- (void)sleipnirAvailabliltyChanged:(BOOL)available;

/**
 If SDK is asked start before device is avilable it will automatically start.
 is called when the algorithm start measureing and will deliver callbacks.
 */
- (void)sleipnirStartedMeasuring;

/**
 Is called when the algorithm stops measureing. ie. if device is removed.
 */
- (void)sleipnirStoppedMeasuring;

/**
 Called during the calibration process to provided user feedback
 */
- (void)calibrationPercentageComplete:(NSNumber *)percentage;

@end


@interface VEVaavudElectronicSDK : NSObject

+ (VEVaavudElectronicSDK *)sharedVaavudElectronic;

/* Is the Sleipnir avialable to start measureing? */
- (BOOL)sleipnirAvailable;

/* add listener of heading, windspeed and device information */
- (void)addListener:(id<VaavudElectronicWindDelegate>)delegate;

/* remove listener of heading, windspeed and device information */
- (void)removeListener:(id<VaavudElectronicWindDelegate>)delegate;

/* start the audio input/output (and location,heading) and starts sending data */
- (void)start;

/* start the audio input/output (and location,heading) and starts sending data */
- (void)startWithClipFacingScreen:(BOOL)isFacingScreen;

/* stop the audio input/output (and location, heading) and stop sending data */
- (void)stop;

// start calibration mode
- (void)startCalibration;

// end calibration mode
- (void)endCalibration;

// resets the calibration coefficients
- (void)resetCalibration;
@end