//
//  VaavudElectronicSDK+Analysis.m
//  VaavudElectronicSDK
//
//  Created by Andreas Okholm on 02/09/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import "VEVaavudElectronicSDK.m"

@implementation VEVaavudElectronicSDK (Analysis)

- (void)setMicrophoneFloatRawListener:(id <VaavudElectronicMicrophoneOutputDelegate>)microphoneOutputDeletage{
    self.audioIO.microphoneOutputDeletage = microphoneOutputDeletage;
}


/* add listener of heading and windspeed information */
- (void) addAnalysisListener:(id <VaavudElectronicAnalysisDelegate>) delegate {
    
    NSArray *array = [self.VaaElecAnalysisDelegates copy];
    
    if ([array containsObject:delegate]) {
        // do nothing
        NSLog(@"[SDK] trying to add delegate twice");
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
        NSLog(@"[SDK] trying to remove delegate, which does not excists");
    }
}


// Starts the internal soundfile recorder
- (void) startRecording {
    [self.audioIO startRecording];
    [self.summeryGenerator startRecording];
}

// Ends the internal soundfile recorder
- (void) endRecording {
    [self.audioIO endRecording];
    [self.summeryGenerator endRecording];
}

// returns true if recording is active
- (BOOL) isRecording {
    return [self.audioIO isRecording];
}

// returns the local path of the recording
- (NSURL*) recordingPath {
    return [self.audioIO recordingPath];
}

// returns the local path of the summeryfile
- (NSURL*) summeryPath {
    return [self.summeryGenerator recordingPath];
}

- (NSURL*) summeryAngularVelocitiesPath {
    return [self.summeryGenerator summeryAngularVelocitiesPath];
}

- (NSURL*) summaryVolumePath {
    return [self.summeryGenerator summaryVolumePath];
}

// returns the fitcurve used in the directionAlgorithm
- (float *) getFitCurve {
    return [VEAudioProcessingTick getFitCurve];
}

// returns the EdgeAngles for the samples
- (int *) getEdgeAngles {
    return [self.tickProcessor getEdgeAngles];
}

- (NSArray *) getEncoderCoefficients {
    return [self.tickProcessor getEncoderCoefficients];
}

- (float) getVolume {
    return self.audioIO.volume;
}

- (void)setVolume:(float)volume {
    self.audioIO.volume = volume;
}

- (void) generateSummaryFile {
    [self.summeryGenerator generateFile];
}

- (NSNumber*) getHeading {
    return self.currentHeading;
}

- (NSString*) soundOutputDescription {
    return [self.audioIO soundOutputDescription];
}

- (NSString*) soundInputDescription {
    return [self.audioIO soundInputDescription];
}

@end
