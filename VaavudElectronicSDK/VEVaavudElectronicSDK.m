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
#import "VELocationManager.h"

@interface VEVaavudElectronicSDK() <VEAudioProcessingDelegate, DirectionDetectionDelegate, VEAudioIODelegate, locationManagerDelegate>

@property (strong, atomic) NSMutableArray *VaaElecWindDelegates;
@property (strong, atomic) NSMutableArray *VaaElecAnalysisDelegates;
@property (strong, nonatomic) VEAudioIO *audioIO;
@property (strong, nonatomic) VEAudioProcessingRaw *rawProcessor;
@property (strong, nonatomic) VEAudioProcessingTick *tickProcessor;
@property (strong, nonatomic) VESummeryGenerator *summeryGenerator;
@property (strong, nonatomic) VELocationManager *locationManager;
@property (strong, atomic) NSNumber *currentHeading;

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
    self.locationManager = [[VELocationManager alloc] initWithDelegate:self];
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

- (void)newHeading:(NSNumber *)heading {
    self.currentHeading = heading;
    
    for (id<VaavudElectronicWindDelegate>delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(newHeading:)]) {
            [delegate newHeading:heading];
        }
    }
}

- (void)newWindAngleLocal:(NSNumber *)angle {
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
    
    if ([self.locationManager isHeadingAvailable]) {
        [self.locationManager start];
    } else {
        // Do nothing - heading will not be updated
        if (LOG) NSLog(@"There is no heading avaliable");
    }
}

/* start the audio input/output and starts sending data */
- (void)stop {
    [self.audioIO stop];
    [self.locationManager stop];
}

//
- (void)adjustVolume:(float)adjustment {
    [self.audioIO adjustVolumeLevelAmount:adjustment];
}

- (NSNumber *)frequencyToWindspeed:(NSNumber *)frequency {
    return @(frequency.floatValue*0.325 + 0.2);
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

@end
