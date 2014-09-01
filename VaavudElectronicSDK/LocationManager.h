//
//  LocationManager.h
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 07/08/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VaavudElectronicSDK.h"

@protocol locationManagerDelegate <NSObject>

- (void) newHeading: (NSNumber*) heading;

@end

@interface LocationManager : NSObject

- (id) initWithDelegate:(id<locationManagerDelegate>)delegate;

- (void) start;
- (void) stop;

- (BOOL) isHeadingAvailable;
- (NSNumber*) getHeading;

@end
