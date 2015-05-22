//
//  VaavudElectronicSDK+Analysis.h
//  VaavudElectronicSDK
//
//  Created by Andreas Okholm on 02/09/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//


@protocol VaavudElectronicAnalysisDelegate <NSObject>

@optional
- (void)newAngularVelocities: (NSArray*) angularVelocities;
- (void)newTickDetectionErrorCount: (NSNumber *) tickDetectionErrorCount;
- (void)newVelocityProfileError: (NSNumber *) profileError;
- (void)newMaxAmplitude: (NSNumber*) amplitude;
@end

@protocol VaavudElectronicMicrophoneOutputDelegate <NSObject>

-(void)updateBuffer:(float *)buffer withBufferSize:(UInt32)bufferSize;

@end

@interface VEVaavudElectronicSDK (Analysis)

/* add listener of analysis information */
- (void)addAnalysisListener:(id <VaavudElectronicAnalysisDelegate>)delegate;

/* remove listener of analysis information */
- (void)removeAnalysisListener:(id <VaavudElectronicAnalysisDelegate>)delegate;

// set
- (void)setMicrophoneFloatRawListener:(id <VaavudElectronicMicrophoneOutputDelegate>)microphoneOutputDeletage;

// Starts the internal soundfile recorder
- (void)startRecording;

// Ends the internal soundfile recorder
- (void)endRecording;

// returns true if recording is active
- (BOOL)isRecording;

// returns the local path of the recording
- (NSURL *)recordingPath;

// returns the local path of the recording
- (NSURL *)summeryPath;

// returns the local path of the recording
- (NSURL *)summeryAngularVelocitiesPath;

// returns the local path of the recording
- (NSURL *)summaryVolumePath;

// generate summaryFile
- (void)generateSummaryFile;

// returns the fitcurve used in direction algorithm
- (float *)getFitCurve;

// returns the EdgeAngles for the samples
- (int *)getEdgeAngles;

// array of length 15
- (NSArray *)getEncoderCoefficients;

// sound output volume
- (float)getVolume;

// set the sound output volume
- (void)setVolume:(float)volume;

// return the current heading of device (if avilale)
- (NSNumber *)getHeading;

// return the sound output description as NSString
- (NSString *)soundOutputDescription;

// return the sound input descriotion as NSString
- (NSString *)soundInputDescription;

@end
