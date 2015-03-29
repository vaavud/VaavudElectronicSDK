//
//  VaavudElectronicSDK.m
//  VaavudElectronicSDK
//
//  Created by Andreas Okholm on 31/08/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import "VEAudioIO.h"
#import "VEAudioProcessingRaw.h"
#import "VEAudioProcessingTick.h"
#import "VESummeryGenerator.h"
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>

@interface VEVaavudElectronicSDK() <VEAudioProcessingDelegate, DirectionDetectionDelegate, VEAudioIODelegate, CLLocationManagerDelegate>

@property (strong, atomic) NSMutableArray *VaaElecWindDelegates;
@property (strong, atomic) NSMutableArray *VaaElecAnalysisDelegates;
@property (strong, nonatomic) VEAudioIO *audioIO;
@property (strong, nonatomic) VEAudioProcessingRaw *rawProcessor;
@property (strong, nonatomic) VEAudioProcessingTick *tickProcessor;
@property (strong, nonatomic) VESummeryGenerator *summeryGenerator;
@property (strong, atomic) NSNumber *currentHeading;
@property (nonatomic) BOOL isClipFacingScreen;

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (nonatomic) UIInterfaceOrientation orientation;

@property (weak, nonatomic) id<VaavudElectronicMicrophoneOutputDelegate> microphoneOutputDeletage;

@end

@implementation VEVaavudElectronicSDK

// initialize sharedObject as nil (first call only)
static VEVaavudElectronicSDK *sharedInstance = nil;

+ (VEVaavudElectronicSDK *)sharedVaavudElectronic {
    // structure used to test whether the block has completed or not
    static dispatch_once_t p = 0;
    
    // executes a block object once and only once for the lifetime of an application
    dispatch_once(&p, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
        [sharedInstance initSingleton];
    });
    
    // returns the same object each time
    return sharedInstance;
}

- (void)initSingleton {
    self.VaaElecWindDelegates = [[NSMutableArray alloc] initWithCapacity:3];
    self.VaaElecAnalysisDelegates = [[NSMutableArray alloc] initWithCapacity:3];
    self.summeryGenerator = [[VESummeryGenerator alloc] init];
    self.rawProcessor = [[VEAudioProcessingRaw alloc] initWithDelegate:self];
    self.tickProcessor = [[VEAudioProcessingTick alloc] initWithDelegate:self];
    
    self.rawProcessor.processorTick = self.tickProcessor;
    
    self.audioIO = [[VEAudioIO alloc] init];
    self.audioIO.delegate = self;
}

+ (id)allocWithZone:(NSZone *)zone {
    //If coder misunderstands this is a singleton, behave properly with
    // ref count +1 on alloc anyway, and still return singleton!
    return [VEVaavudElectronicSDK sharedVaavudElectronic];
}

- (BOOL)sleipnirAvailable {
    return self.audioIO.sleipnirAvailable;
}

/* add listener of heading and windspeed information */
- (void)addListener:(id<VaavudElectronicWindDelegate>)delegate {
    NSArray *array = [self.VaaElecWindDelegates copy];
    
    if ([array containsObject:delegate]) {
        // do nothing
        NSLog(@"trying to add delegate twice");
    } else {
        [self.VaaElecWindDelegates addObject:delegate];
    }
}

/* remove listener of heading and windspeed information */
- (void)removeListener:(id<VaavudElectronicWindDelegate>)delegate {
    NSArray *array = [self.VaaElecWindDelegates copy];
    if ([array containsObject:delegate]) {
        // do nothing
        [self.VaaElecWindDelegates removeObject:delegate];
    } else {
        NSLog(@"trying to remove delegate, which does not excists");
    }
}

- (void)newSpeed:(NSNumber *)speed {
    // REFACTOR with better naming / logic
    NSNumber *windspeed = [self frequencyToWindspeed:speed];
    
    for (id<VaavudElectronicWindDelegate>delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(newSpeed:)]) {
            [delegate newSpeed:windspeed];
        }
    }
}

- (void)newWindDirection:(NSNumber *)speed {
    for (id<VaavudElectronicWindDelegate>delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(newWindDirection:)]) {
            [delegate newWindDirection:speed];
        }
    }
}

- (void)newWindAngleLocal:(NSNumber *)angle {
    
    if (self.isClipFacingScreen) {
        angle = @((angle.integerValue + 180)%360);
    }
    
    for (id<VaavudElectronicWindDelegate>delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(newWindAngleLocal:)]) {
            [delegate newWindAngleLocal:angle];
        }
    }
    
    if (self.currentHeading) {
        float windDirection = self.currentHeading.floatValue + angle.floatValue;
        
        if (windDirection > 360) {
            windDirection = windDirection - 360;
        }
        
        [self newWindDirection:@(windDirection)];
    }
}

- (void)newTickDetectionErrorCount:(NSNumber *)tickDetectionErrorCount {
    for (id<VaavudElectronicAnalysisDelegate>delegate in self.VaaElecAnalysisDelegates) {
        if ([delegate respondsToSelector:@selector(newTickDetectionErrorCount:)]) {
            [delegate newTickDetectionErrorCount:tickDetectionErrorCount];
        }
    }
}

- (void)newVelocityProfileError:(NSNumber *)profileError {
    for (id<VaavudElectronicAnalysisDelegate>delegate in self.VaaElecAnalysisDelegates) {
        if ([delegate respondsToSelector:@selector(newVelocityProfileError:)]) {
            [delegate newVelocityProfileError:profileError];
        }
    }
}

- (void)newAngularVelocities:(NSArray *)angularVelocities {
    for (id<VaavudElectronicAnalysisDelegate>delegate in self.VaaElecAnalysisDelegates) {
        if ([delegate respondsToSelector:@selector(newAngularVelocities:)]) {
            [delegate newAngularVelocities:angularVelocities];
        }
    }
}

- (void)newMaxAmplitude:(NSNumber *)amplitude {
    for (id<VaavudElectronicAnalysisDelegate>delegate in self.VaaElecAnalysisDelegates) {
        if ([delegate respondsToSelector:@selector(newMaxAmplitude:)]){
            [delegate newMaxAmplitude:amplitude];
        }
    }
}

- (void)sleipnirAvailabliltyDidChange:(BOOL)available {
    for (id<VaavudElectronicWindDelegate>delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(sleipnirAvailabliltyChanged:)]) {
            [delegate sleipnirAvailabliltyChanged:available];
        }
    }
}


- (void)calibrationPercentageComplete:(NSNumber *)percentage {
    for (id<VaavudElectronicWindDelegate>delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(calibrationPercentageComplete:)]) {
            [delegate calibrationPercentageComplete:percentage];
        }
    }
}

/* start the audio input/output and starts sending data */
- (void)start {
    [self.audioIO start];
    
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
        if (LOG) NSLog(@"There is no heading avaliable");
//        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Trying to start heading. Heading is not available" userInfo:nil];
    }
}

/* start the audio input/output and starts sending data */
- (void)stop {
    [self.audioIO stop];
    [self.locationManager stopUpdatingHeading];
}

//
- (void)adjustVolume:(float)adjustment {
    [self.audioIO adjustVolumeLevelAmount:adjustment];
}

- (NSNumber *)frequencyToWindspeed:(NSNumber *)frequency {
    return (frequency.floatValue > 0.0) ? @(frequency.floatValue*0.325 + 0.2): @(0.0);
}

// start calibration mode
- (void)startCalibration {
    [self.tickProcessor startCalibration];
}

// end calibbration mode
-(void)endCalibration {
    [self.tickProcessor endCalibration];
}

- (void)resetCalibration {
    [self.tickProcessor resetCalibration];
}

- (void)processBuffer:(VECircularBuffer *)circBuffer withDefaultBufferLengthInFrames:(UInt32)bufferLengthInFrames {
    [self.rawProcessor checkAndProcess:circBuffer withDefaultBufferLengthInFrames:bufferLengthInFrames];
}

- (void)processFloatBuffer:(float *)buffer withBufferLengthInFrames:(UInt32)bufferLengthInFrames {
    [self.microphoneOutputDeletage updateBuffer:buffer withBufferSize:bufferLengthInFrames];
}

- (void)algorithmAudioActive:(BOOL)active {
    if (active) {
        for (id<VaavudElectronicWindDelegate>delegate in self.VaaElecWindDelegates) {
            if ([delegate respondsToSelector:@selector(sleipnirStartedMeasuring)]) {
                [delegate sleipnirStartedMeasuring];
            }
        }
    }
    else {
        for (id<VaavudElectronicWindDelegate>delegate in self.VaaElecWindDelegates) {
            if ([delegate respondsToSelector:@selector(sleipnirStoppedMeasuring)]) {
                [delegate sleipnirStoppedMeasuring];
            }
        }

    }
}

- (void) interfaceOrientationChanged {
    self.orientation = [[UIApplication sharedApplication] statusBarOrientation];
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
    
    self.currentHeading = [NSNumber numberWithDouble: heading];
    
    for (id<VaavudElectronicWindDelegate>delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(newHeading:)]) {
            [delegate newHeading:self.currentHeading];
        }
    }

}

- (void)isClipFacingScreen:(BOOL)isFacingScreen {
    self.isClipFacingScreen = isFacingScreen;
}

@end
