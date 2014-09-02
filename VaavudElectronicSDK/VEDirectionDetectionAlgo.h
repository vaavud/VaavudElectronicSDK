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

@end


@interface VEDirectionDetectionAlgo : NSObject

- (void) newTick:(int)samples;
- (id) initWithDelegate:(id<DirectionDetectionDelegate>)delegate;
+ (float *) getFitCurve;
- (int *) getEdgeAngles;

@end
