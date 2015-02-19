//
//  VaavudElectronicSDK+Analysis.h
//  VaavudElectronicSDK
//
//  Created by Andreas Okholm on 02/09/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//


@protocol VaavudElectronicAnalysisDelegate <NSObject>

@optional
- (void) newAngularVelocities: (NSArray*) angularVelocities;
- (void) newTickDetectionErrorCount: (NSNumber *) tickDetectionErrorCount;
- (void) newVelocityProfileError: (NSNumber *) profileError;
- (void) newMaxAmplitude: (NSNumber*) amplitude;
- (void) newRecordingReadyToUpload;
@end



@interface VEVaavudElectronicSDK (Analysis)

/* add listener of analysis information */
- (void) addAnalysisListener:(id <VaavudElectronicAnalysisDelegate>) delegate;

/* remove listener of analysis information */
- (void) removeAnalysisListener:(id <VaavudElectronicAnalysisDelegate>) delegate;

// sets the audioPlot to which buffered raw audio values is send for plotting
- (void) setAudioPlot:(EZAudioPlotGL *) audioPlot;

// Starts the internal soundfile recorder
- (void) startRecording;

// Ends the internal soundfile recorder
- (void) endRecording;

// returns true if recording is active
- (BOOL) isRecording;

// returns the local path of the recording
- (NSURL*) recordingPath;

// returns the local path of the recording
- (NSURL*) summeryPath;

// returns the local path of the recording
- (NSURL*) summeryAngularVelocitiesPath;

// generate summeryFile
- (void) generateSummaryFile;

// returns the fitcurve used in direction algorithm
- (float *) getFitCurve;

// returns the EdgeAngles for the samples
- (int *) getEdgeAngles;

// return the current heading of device (if avilale)
- (NSNumber*) getHeading;

// return the sound output description as NSString
- (NSString*) soundOutputDescription;

// return the sound input descriotion as NSString
- (NSString*) soundInputDescription;


@end
