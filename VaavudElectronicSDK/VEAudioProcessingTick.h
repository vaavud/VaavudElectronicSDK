//
//  DirectionDetectionAlgo.h
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 11/06/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol VEAudioProcessingTickDelegate
- (void)newSpeed: (NSNumber*) speed;
- (void)newAngularVelocities: (NSArray*) angularVelocities;
- (void)newWindAngleLocal:(NSNumber*) angle;
- (void)calibrationPercentageComplete: (NSNumber*) percentage;
- (void)newTickDetectionErrorCount: (NSNumber *) tickDetectionErrorCount;
- (void)newVelocityProfileError: (NSNumber *) profileError;
@end


@interface VEAudioProcessingTick : NSObject
- (BOOL)newTick:(int)tickLength; // return true if next tick is long
- (void)newTickReset; // when the raw processing measures zero
- (id)initWithDelegate:(id<VEAudioProcessingTickDelegate>)delegate;

- (NSArray *)getEncoderCoefficients;
+ (float *)getFitCurve;
- (int *)getEdgeAngles;

// start calibration mode
- (void)startCalibration;

// end calibbration mode
- (void)endCalibration;

// reset calibration
- (void)resetCalibration;

@end
