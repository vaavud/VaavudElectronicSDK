//
//  VaavudElectronicSDK.h
//  VaavudElectronicSDK
//
//  Created by Andreas Okholm on 31/08/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VaavudElectronicSDK.h"
#import "EZAudio.h"


@protocol VaavudElectronicWindDelegate <NSObject>

@optional
- (void) newSpeed: (NSNumber*) speed;
- (void) newWindDirection: (NSNumber*) windDirection;

- (void) vaavudPlugedIn;
- (void) vaavudWasUnpluged;
- (void) vaavudStartedMeasureing;
- (void) vaavudStopMeasureing;
- (void) notVaavudPlugedIn;

@end


@protocol VaavudElectronicAnalysisDelegate <NSObject>

@optional
- (void) newAngularVelocities: (NSArray*) angularVelocities;
- (void) newWindAngleLocal:(NSNumber*) angle;
- (void) newHeading: (NSNumber*) heading;
- (void) newMaxAmplitude: (NSNumber*) amplitude;
@end

typedef NS_ENUM(NSUInteger, VaavudElectronicConnectionStatus) {
    VaavudElectronicConnectionStatusUnchecked,
    VaavudElectronicConnectionStatusConnected,
    VaavudElectronicConnectionStatusNotConnected
};

@interface VaavudElectronicSDK : NSObject

+ (VaavudElectronicSDK *) sharedVaavudElectronic;

/* What is the current Vaavud Electronic connection status ? Initialize class as soon as possible to start detection*/
- (VaavudElectronicConnectionStatus) isVaavudElectronicConnected;

/* add listener of heading, windspeed and device information */
- (void) addListener:(id <VaavudElectronicWindDelegate>) delegate;

/* remove listener of heading, windspeed and device information */
- (void) removeListener:(id <VaavudElectronicWindDelegate>) delegate;

/* add listener of analysis information */
- (void) addAnalysisListener:(id <VaavudElectronicAnalysisDelegate>) delegate;

/* remove listener of analysis information */
- (void) removeAnalysisListener:(id <VaavudElectronicAnalysisDelegate>) delegate;

/* start the audio input/output (and location,heading) and starts sending data */
// If Vaavud Electronic is not inserted nothing will happen.
- (void) start;

/* stop the audio input/output  (and location,heading) and stop sending data */
- (void) stop;

// returnt the volume to initial state - to be used when the app closes
- (void) returnVolumeToInitialState;

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
- (void) generateSummeryFile;

// returns the fitcurve used in direction algorithm
- (float *) getFitCurve;

// returns the EdgeAngles for the samples
- (int *) getEdgeAngles;

// return the current heading of device (if avilale)
- (NSNumber*) getHeading;


@end