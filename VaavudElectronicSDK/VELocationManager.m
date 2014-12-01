//
//  LocationManager.m
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 07/08/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import "VELocationManager.h"
#import <CoreLocation/CoreLocation.h>

@interface VELocationManager() <CLLocationManagerDelegate>

@property (strong, nonatomic) id<locationManagerDelegate> delegate;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) NSNumber *globalHeading;
@property (nonatomic) UIInterfaceOrientation orientation;
@end


@implementation VELocationManager

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

- (void) interfaceOrientationChanged {
    self.orientation = [[UIApplication sharedApplication] statusBarOrientation];
}


- (void) start {
    // determine upside down
    self.orientation = [[UIApplication sharedApplication] statusBarOrientation];
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    
    // Register for device orientation change notifications.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(interfaceOrientationChanged)
                                                 name:UIDeviceOrientationDidChangeNotification object:nil];
    
    
    // start heading updates
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
    
    float heading = newHeading.trueHeading;
    
    if (self.orientation == UIInterfaceOrientationPortraitUpsideDown) {
        heading = heading + 180;
        if (heading > 360) {
            heading = heading - 360;
        }
    }
    
    self.globalHeading = [NSNumber numberWithDouble: heading];
    [self.delegate newHeading: self.globalHeading];
    
}


- (NSNumber*) getHeading {
    return self.globalHeading;
}




@end
