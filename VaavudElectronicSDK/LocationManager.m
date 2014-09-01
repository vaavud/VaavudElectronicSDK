//
//  LocationManager.m
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 07/08/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import "LocationManager.h"
#import <CoreLocation/CoreLocation.h>

@interface LocationManager() <CLLocationManagerDelegate>

@property (strong, nonatomic) id<locationManagerDelegate> delegate;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) NSNumber *globalHeading;
@end


@implementation LocationManager



#pragma mark - Initialization
-(id)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"-init is not a valid initializer for the class LocationManager"
                                 userInfo:nil];
    return nil;
}

- (id) initWithDelegate:(id<locationManagerDelegate>)delegate {
    
    
    self = [super init];
    self.delegate = delegate;
    
    return self;
}

- (BOOL) isHeadingAvailable {
    return [CLLocationManager headingAvailable];
}


- (void) start {
    if ([CLLocationManager headingAvailable])
    {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.headingFilter = 1;
        [self.locationManager startUpdatingHeading];
    } else
    {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Trying to start heading. Heading is not available" userInfo:nil];
    }

}

- (void) stop {
    [self.locationManager stopUpdatingHeading];
}


- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
{
    
    self.globalHeading = [NSNumber numberWithDouble: newHeading.trueHeading];
    [self.delegate newHeading: self.globalHeading];
    
}


- (NSNumber*) getHeading {
    return self.globalHeading;
}




@end
