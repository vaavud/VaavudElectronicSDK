//
//  VaavudElectronicSDK.m
//  VaavudElectronicSDK
//
//  Created by Andreas Okholm on 31/08/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import "VEAudioManager.h"
#import "VEDirectionDetectionAlgo.h"
#import "VESummeryGenerator.h"
#import "VELocationManager.h"
#import "VEAudioVaavudElectronicDetection.h"

@interface VEVaavudElectronicSDK() <SoundProcessingDelegate, DirectionDetectionDelegate, AudioManagerDelegate, locationManagerDelegate, AudioVaavudElectronicDetectionDelegate>

@property (strong, atomic) NSMutableArray *VaaElecWindDelegates;
@property (strong, atomic) NSMutableArray *VaaElecAnalysisDelegates;
@property (strong, nonatomic) VEAudioManager *audioManager;
@property (strong, nonatomic) VESummeryGenerator *summeryGenerator;
@property (strong, nonatomic) VELocationManager *locationManager;
@property (strong, nonatomic) VEAudioVaavudElectronicDetection *AVElectronicDetection;
@property (strong, atomic) NSNumber* currentHeading;

@end

@implementation VEVaavudElectronicSDK

// initialize sharedObject as nil (first call only)
static VEVaavudElectronicSDK *sharedInstance = nil;

+ (VEVaavudElectronicSDK *) sharedVaavudElectronic {
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

- (void) initSingleton {
    self.VaaElecWindDelegates = [[NSMutableArray alloc] initWithCapacity:3];
    self.VaaElecAnalysisDelegates = [[NSMutableArray alloc] initWithCapacity:3];
    self.audioManager = [[VEAudioManager alloc] initWithDelegate:self];
    self.summeryGenerator = [[VESummeryGenerator alloc] init];
    self.locationManager = [[VELocationManager alloc] initWithDelegate:self];
    self.AVElectronicDetection = [[VEAudioVaavudElectronicDetection alloc] initWithDelegate:self];
}

+ (id) allocWithZone:(NSZone *)zone {
    //If coder misunderstands this is a singleton, behave properly with
    // ref count +1 on alloc anyway, and still return singleton!
    return [VEVaavudElectronicSDK sharedVaavudElectronic];
}


- (BOOL) sleipnirAvailable {
    return self.AVElectronicDetection.sleipnirAvailable;
}



/* add listener of heading and windspeed information */
- (void) addListener:(id <VaavudElectronicWindDelegate>) delegate {
    
    NSArray *array = [self.VaaElecWindDelegates copy];
    
    if ([array containsObject:delegate]) {
        // do nothing
        NSLog(@"trying to add delegate twice");
    } else {
        [self.VaaElecWindDelegates addObject:delegate];
    }
}


/* remove listener of heading and windspeed information */
- (void) removeListener:(id <VaavudElectronicWindDelegate>) delegate {
    NSArray *array = [self.VaaElecWindDelegates copy];
    if ([array containsObject:delegate]) {
        // do nothing
        [self.VaaElecWindDelegates removeObject:delegate];
    } else {
        NSLog(@"trying to remove delegate, which does not excists");
    }
}



- (void) newSpeed: (NSNumber*) speed {
    
    // REFACTOR with better naming / logic
    NSNumber *windspeed = [self frequencyToWindspeed: speed];
    
    for (id<VaavudElectronicWindDelegate> delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(newSpeed:)]) {
            [delegate newSpeed: windspeed];
        }
    }
}


- (void) newWindDirection: (NSNumber*) speed {
    for (id<VaavudElectronicWindDelegate> delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(newWindDirection:)]) {
            [delegate newWindDirection: speed];
        }
    }
}

- (void) newHeading:(NSNumber *)heading {
    
    self.currentHeading = heading;
    
    for (id<VaavudElectronicWindDelegate> delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(newHeading:)]) {
            [delegate newHeading: heading];
        }
    }
}

- (void) newWindAngleLocal:(NSNumber*) angle {
    for (id<VaavudElectronicWindDelegate> delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(newWindAngleLocal:)]) {
            [delegate newWindAngleLocal: angle];
        }
    }
    
    if (self.currentHeading) {
        float windDirection = self.currentHeading.floatValue + angle.floatValue;
        
        if (windDirection > 360) {
            windDirection = windDirection - 360;
        }
        
        [self newWindDirection: [NSNumber numberWithFloat: windDirection]];
        
    }
    
}

- (void) newTickDetectionErrorCount: (NSNumber *) tickDetectionErrorCount {
    for (id<VaavudElectronicAnalysisDelegate> delegate in self.VaaElecAnalysisDelegates) {
        if ([delegate respondsToSelector:@selector(newTickDetectionErrorCount:)]) {
            [delegate newTickDetectionErrorCount:tickDetectionErrorCount];
        }
    }
}

- (void) newVelocityProfileError: (NSNumber *) profileError {
    for (id<VaavudElectronicAnalysisDelegate> delegate in self.VaaElecAnalysisDelegates) {
        if ([delegate respondsToSelector:@selector(newVelocityProfileError:)]) {
            [delegate newVelocityProfileError:profileError];
        }
    }
}

- (void) newAngularVelocities: (NSArray*) angularVelocities {
    for (id<VaavudElectronicAnalysisDelegate> delegate in self.VaaElecAnalysisDelegates) {
        if ([delegate respondsToSelector:@selector(newAngularVelocities:)]) {
            [delegate newAngularVelocities:angularVelocities];
        }
    }
}

- (void) newMaxAmplitude: (NSNumber*) amplitude {
    for (id<VaavudElectronicAnalysisDelegate> delegate in self.VaaElecAnalysisDelegates) {
        if ([delegate respondsToSelector:@selector(newMaxAmplitude:)]){
            [delegate newMaxAmplitude: amplitude];
        }
    }
}


- (void) sleipnirAvailabliltyChanged: (BOOL) available {
    
    [self.audioManager sleipnirAvailabliltyChanged: available];
    
    for (id<VaavudElectronicWindDelegate> delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(sleipnirAvailabliltyChanged:)]) {
            [delegate sleipnirAvailabliltyChanged: available];
        }
    }
}

- (void) deviceConnectedTypeSleipnir: (BOOL) sleipnir {
    for (id<VaavudElectronicWindDelegate> delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(deviceConnectedTypeSleipnir:)]) {
            [delegate deviceConnectedTypeSleipnir: sleipnir];
        }
    }
}

- (void) deviceDisconnectedTypeSleipnir: (BOOL) sleipnir {
    for (id<VaavudElectronicWindDelegate> delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(deviceDisconnectedTypeSleipnir:)]) {
            [delegate deviceDisconnectedTypeSleipnir: sleipnir];
        }
    }
}

- (void) deviceConnectedChecking {
    
    for (id<VaavudElectronicWindDelegate> delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(deviceConnectedChecking)]) {
            [delegate deviceConnectedChecking];
        }
    }
}


- (void) vaavudStartedMeasuring {
    for (id<VaavudElectronicWindDelegate> delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(sleipnirStartedMeasuring)]) {
            [delegate sleipnirStartedMeasuring];
        }
    }
}

- (void) vaavudStopMeasuring {
    for (id<VaavudElectronicWindDelegate> delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(sleipnirStoppedMeasuring)]) {
            [delegate sleipnirStoppedMeasuring];
        }
    }
}


- (void) newRecordingReadyToUpload {
    for (id<VaavudElectronicAnalysisDelegate> delegate in self.VaaElecAnalysisDelegates) {
        if ([delegate respondsToSelector:@selector(newRecordingReadyToUpload)]){
            [delegate newRecordingReadyToUpload];
        }
    }
}

- (void) calibrationPercentageComplete: (NSNumber*) percentage {
    for (id<VaavudElectronicWindDelegate> delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(calibrationPercentageComplete:)]) {
            [delegate calibrationPercentageComplete: percentage];
        }
    }
}




/* start the audio input/output and starts sending data */
- (void) start {
    [self.audioManager start];
    
    if ([self.locationManager isHeadingAvailable]) {
        [self.locationManager start];
    } else {
        // Do nothing - heading will not be updated
    }
    
}

/* start the audio input/output and starts sending data */
- (void) stop {
    [self.audioManager stop];
    [self.locationManager stop];
}

- (void) returnVolumeToInitialState {
    [self.audioManager returnVolumeToInitialState];
}


- (NSNumber*) frequencyToWindspeed: (NSNumber *) frequency{
    return [NSNumber numberWithFloat: frequency.floatValue * 0.325+0.2];
}


// start calibration mode
-(void) startCalibration {
    [self.audioManager.soundProcessor.dirDetectionAlgo startCalibration];
}

// end calibbration mode
-(void) endCalibration {
    [self.audioManager.soundProcessor.dirDetectionAlgo endCalibration];
}


@end
