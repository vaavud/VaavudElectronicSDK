//
//  DirectionDetectionAlgo.h
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 11/06/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol DirectionDetectionDelegate

- (void) newSpeed: (NSNumber*) speed;
- (void) newAngularVelocities: (NSArray*) angularVelocities;
- (void) newWindAngleLocal:(NSNumber*) angle;
- (void) calibrationPercentageComplete: (NSNumber*) percentage;
- (void) newTickDetectionErrorCount: (NSNumber *) tickDetectionErrorCount;


@end


@interface VEDirectionDetectionAlgo : NSObject

- (BOOL) newTick:(int)tickLength; // return true if next tick is long
- (id) initWithDelegate:(id<DirectionDetectionDelegate>)delegate;
+ (float *) getFitCurve;
- (int *) getEdgeAngles;

// start calibration mode
-(void) startCalibration;

// end calibbration mode
-(void) endCalibration;

@end
