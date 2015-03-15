//
//  VaavudElectronicSDK+Analysis.m
//  VaavudElectronicSDK
//
//  Created by Andreas Okholm on 02/09/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import "VEVaavudElectronicSDK.m"

@implementation VEVaavudElectronicSDK (Analysis)

- (id<VaavudElectronicMicrophoneOutputDelegate>)microphoneOutputDeletage {
    return self.microphoneOutputDeletage;
}

- (void)setMicrophoneOutputDeletage:(id<VaavudElectronicMicrophoneOutputDelegate>)microphoneOutputDeletage {
    self.microphoneOutputDeletage = microphoneOutputDeletage;
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

- (void)setMicrophoneFloatRawListener:(id <VaavudElectronicMicrophoneOutputDelegate>)microphoneOutputDeletage{
    self.audioManager.microphoneOutputDeletage = microphoneOutputDeletage;
}


//- (void) setAudioPlot:(EZAudioPlotGL *) audioPlot {
//    
//    if (self.audioManager) {
////        self.audioManager.audioPlot = audioPlot;
////        self.audioManager.audioProcessor.audioPlot = audioPlot;
//    }
//}


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
    return [VEDirectionDetectionAlgo getFitCurve];
}

// returns the EdgeAngles for the samples
- (int *) getEdgeAngles {
    return [self.audioManager.soundProcessor.dirDetectionAlgo getEdgeAngles];
}

- (void) generateSummaryFile {
    [self.summeryGenerator generateFile];
}

- (NSNumber*) getHeading {
    return [self.locationManager getHeading];
}

- (NSString*) soundOutputDescription {
    return [self.audioManager soundOutputDescription];
}

- (NSString*) soundInputDescription {
    return [self.audioManager soundInputDescription];
}

@end
