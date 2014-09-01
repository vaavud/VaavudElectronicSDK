//
//  VaavudElectronicSDK.m
//  VaavudElectronicSDK
//
//  Created by Andreas Okholm on 31/08/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import "VaavudElectronicSDK.h"
#import "AudioManager.h"
#import "DirectionDetectionAlgo.h"
#import "SummeryGenerator.h"
#import "LocationManager.h"
#import "AudioVaavudElectronicDetection.h"

@interface VaavudElectronicSDK() <SoundProcessingDelegate, DirectionDetectionDelegate, AudioManagerDelegate, locationManagerDelegate, AudioVaavudElectronicDetectionDelegate>

@property (strong, atomic) NSMutableArray *VaaElecWindDelegates;
@property (strong, atomic) NSMutableArray *VaaElecAnalysisDelegates;
@property (strong, nonatomic) AudioManager *audioManager;
@property (strong, nonatomic) SummeryGenerator *summeryGenerator;
@property (strong, nonatomic) LocationManager *locationManager;
@property (strong, nonatomic) AudioVaavudElectronicDetection *AVElectronicDetection;
@property (strong, nonatomic) NSNumber* currentHeading;

@end

@implementation VaavudElectronicSDK

// initialize sharedObject as nil (first call only)
static VaavudElectronicSDK *sharedInstance = nil;

+ (VaavudElectronicSDK *) sharedVaavudElectronic {
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
    self.audioManager = [[AudioManager alloc] initWithDelegate:self];
    self.summeryGenerator = [[SummeryGenerator alloc] init];
    self.locationManager = [[LocationManager alloc] initWithDelegate:self];
    self.AVElectronicDetection = [[AudioVaavudElectronicDetection alloc] initWithDelegate:self];
}

+ (id) allocWithZone:(NSZone *)zone {
    //If coder misunderstands this is a singleton, behave properly with
    // ref count +1 on alloc anyway, and still return singleton!
    return [VaavudElectronicSDK sharedVaavudElectronic];
}


- (VaavudElectronicConnectionStatus) isVaavudElectronicConnected {
    return self.AVElectronicDetection.vaavudElectronicConnectionStatus;
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


/* add listener of heading and windspeed information */
- (void) addAnalysisListener:(id <VaavudElectronicAnalysisDelegate>) delegate {
    
    NSArray *array = [self.VaaElecAnalysisDelegates copy];
    
    if ([array containsObject:delegate]) {
        // do nothing
        NSLog(@"trying to add delegate twice");
    } else {
        [self.VaaElecAnalysisDelegates addObject:delegate];
    }
}


/* remove listener of heading and windspeed information */
- (void) removeAnalysisListener:(id <VaavudElectronicAnalysisDelegate>) delegate {
    NSArray *array = [self.VaaElecAnalysisDelegates copy];
    if ([array containsObject:delegate]) {
        // do nothing
        [self.VaaElecAnalysisDelegates removeObject:delegate];
    } else {
        NSLog(@"trying to remove delegate, which does not excists");
    }
}




- (void) newSpeed: (NSNumber*) speed {
    for (id<VaavudElectronicWindDelegate> delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(newSpeed:)]) {
            [delegate newSpeed: speed];
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
    
    for (id<VaavudElectronicAnalysisDelegate> delegate in self.VaaElecAnalysisDelegates) {
        if ([delegate respondsToSelector:@selector(newHeading:)]) {
            [delegate newHeading: heading];
        }
    }
}

- (void) newWindAngleLocal:(NSNumber*) angle {
    for (id<VaavudElectronicAnalysisDelegate> delegate in self.VaaElecAnalysisDelegates) {
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




- (void) vaavudPlugedIn {
    
    [self.audioManager vaavudPlugedIn];
    
    
    for (id<VaavudElectronicWindDelegate> delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(vaavudPlugedIn)]) {
            [delegate vaavudPlugedIn];
        }
    }
}
- (void) vaavudWasUnpluged {
    
    [self.audioManager vaavudWasUnpluged];
    
    for (id<VaavudElectronicWindDelegate> delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(vaavudWasUnpluged)]) {
            [delegate vaavudWasUnpluged];
        }
    }
}

- (void) notVaavudPlugedIn {
    for (id<VaavudElectronicWindDelegate> delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(notVaavudPlugedIn)]) {
            [delegate notVaavudPlugedIn];
        }
    }
}


- (void) vaavudStartedMeasureing {
    for (id<VaavudElectronicWindDelegate> delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(vaavudStartedMeasureing)]) {
            [delegate vaavudStartedMeasureing];
        }
    }
}

- (void) vaavudStopMeasureing {
    for (id<VaavudElectronicWindDelegate> delegate in self.VaaElecWindDelegates) {
        if ([delegate respondsToSelector:@selector(vaavudStopMeasureing)]) {
            [delegate vaavudStopMeasureing];
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

- (void) setAudioPlot:(EZAudioPlotGL *) audioPlot {
    if (self.audioManager) {
        self.audioManager.audioPlot = audioPlot;
    }
}


// Starts the internal soundfile recorder
- (void) startRecording {
    [self.audioManager startRecording];
    [self.summeryGenerator startRecording];
}

// Ends the internal soundfile recorder
- (void) endRecording {
    [self.audioManager endRecording];
    [self.summeryGenerator endRecording];
}

// returns true if recording is active
- (BOOL) isRecording {
    return [self.audioManager isRecording];
}

// returns the local path of the recording
- (NSURL*) recordingPath {
    return [self.audioManager recordingPath];
}

// returns the local path of the summeryfile
- (NSURL*) summeryPath {
    return [self.summeryGenerator recordingPath];
}

- (NSURL*) summeryAngularVelocitiesPath {
    return [self.summeryGenerator summeryAngularVelocitiesPath];
}

// returns the fitcurve used in the directionAlgorithm
- (float *) getFitCurve {
    return [DirectionDetectionAlgo getFitCurve];
}

// returns the EdgeAngles for the samples
- (int *) getEdgeAngles {
    return [self.audioManager.soundProcessor.dirDetectionAlgo getEdgeAngles];
}

- (void) generateSummeryFile {
    [self.summeryGenerator generateFile];
}

- (NSNumber*) getHeading {
    return [self.locationManager getHeading];
}


@end
