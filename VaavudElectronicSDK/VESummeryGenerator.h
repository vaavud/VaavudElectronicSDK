//
//  SummeryGenerator.h
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 24/07/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VEVolumeReponse.h"

@interface VESummeryGenerator : NSObject <VaavudElectronicWindDelegate, VaavudElectronicAnalysisDelegate>


// Starts the recieving updates
- (void) startRecording;

// Ends the recieving updates
- (void) endRecording;

// generated the file
- (void) generateFile;

// returns the local path of the summeryfile
- (NSURL*) recordingPath;

// return the local parth of the summeryfile for the angular velocites
- (NSURL*) summeryAngularVelocitiesPath;

- (NSURL*) summaryVolumePath;

// log relationship between Volume and other parameters
- (void) volumeResponse:(VEVolumeReponse *) response;

@end
