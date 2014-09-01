//
//  SummeryGenerator.m
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 24/07/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import "SummeryGenerator.h"
#import "VaavudElectronicSDK.h"

@interface SummeryGenerator()
@property (nonatomic, strong) NSNumber *speed;
@property (nonatomic, strong) NSNumber *angle;
@property (nonatomic, strong) NSNumber *heading;
@property (nonatomic, strong) NSArray *anglularVelocties;
@property (nonatomic, weak) VaavudElectronic *vaavudElectronic;


@end

@implementation SummeryGenerator


- (id) init {
    self = [super init];
    if (self) {
    }
    
    return self;
}

- (void) newSpeed: (NSNumber*) speed {
    self.speed = speed;
}
- (void) newAngularVelocities: (NSArray*) angularVelocities {
    self.anglularVelocties = angularVelocities;
}

- (void) newWindAngleLocal:(NSNumber*) angle {
    self.angle = angle;
}

- (void) newHeading: (NSNumber*) heading {
    self.heading = heading;
}

- (NSURL*) recordingPath {
    return [self recordingFilePathURL];
}

- (NSURL*) summeryAngularVelocitiesPath {
    return [self recordingAngularVelocitiesFilePathURL];
}



// Starts the recieving updates
- (void) startRecording {
    if (!self.vaavudElectronic) {
        self.vaavudElectronic = [VaavudElectronic sharedVaavudElec];
    }
    
    [self.vaavudElectronic addListener:self];
    [self.vaavudElectronic addAnalysisListener:self];
    
    // ask for heading
    self.heading = [self.vaavudElectronic getHeading];
    
}

// Ends the recieving updates
- (void) endRecording {
    
    if (!self.vaavudElectronic) {
        self.vaavudElectronic = [VaavudElectronic sharedVaavudElec];
    }
    
    [self.vaavudElectronic removeListener:self];
    [self.vaavudElectronic removeAnalysisListener:self];
}

// generated the file
- (void) generateFile {
    [self generateStandardSummeryFile];
    [self generateAngularVelocitySummeryFile];
}


- (void) generateStandardSummeryFile {
    NSDateFormatter *formatter;
    NSString        *dateString;
    NSString        *timeString;
    
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy'-'MM'-'dd"];
    dateString = [formatter stringFromDate:[NSDate date]];
    [formatter setDateFormat:@"HH':'mm':'ss"];
    timeString = [formatter stringFromDate:[NSDate date]];
    
    
    
    
    NSMutableArray *headerrow = [[NSMutableArray alloc] initWithCapacity:30];
    
    [headerrow addObject: @"date"];
    [headerrow addObject: @"time"];
    [headerrow addObject: @"frequency"];
    [headerrow addObject: @"localHeading"];
    [headerrow addObject: @"heading"];
    
    
    NSMutableArray *valuerow = [[NSMutableArray alloc] initWithCapacity:30];
    
    [valuerow addObject: dateString];
    [valuerow addObject: timeString];
    if (self.speed) {
        [valuerow addObject: self.speed.stringValue];
    } else {
        [valuerow addObject: @"-"];
    }
    
    if (self.angle) {
        [valuerow addObject: self.angle.stringValue];
    } else {
        [valuerow addObject: @"-"];
    }
    
    if (self.heading) {
        [valuerow addObject: self.heading.stringValue];
    } else {
        [valuerow addObject: @"-"];
    }
    
    
    //NSArray *myStrings = [[NSArray alloc] initWithObjects:first, second, third, fourth, fifth, nil];
    NSString *headerRowString = [headerrow componentsJoinedByString:@","];
    NSString *valueRowString = [valuerow componentsJoinedByString:@","];
    
    
    NSString *content = [NSString stringWithFormat: @"%@\n%@", headerRowString, valueRowString ];
    //save content to the documents directory
    [content writeToFile:[[self recordingFilePathURL] relativePath]
              atomically:NO
                encoding:NSStringEncodingConversionAllowLossy
                   error:nil];
}

- (void) generateAngularVelocitySummeryFile {
    
    NSMutableArray *rowsStrings = [[NSMutableArray alloc] initWithCapacity:30];
    
    NSMutableArray *headerrow = [[NSMutableArray alloc] initWithCapacity:2];
    
    [headerrow addObject: @"edgeAngle"];
    [headerrow addObject: @"relativeSpeed"];
    
    
    [rowsStrings addObject: [headerrow componentsJoinedByString:@","]];
    
    int* edgeAngles = [self.vaavudElectronic getEdgeAngles];
    
    if (self.anglularVelocties) {
        for (int i = 0; i < self.anglularVelocties.count; i++) {
            NSMutableArray *row = [[NSMutableArray alloc] initWithCapacity:2];
            [row addObject: [NSString stringWithFormat:@"%i", edgeAngles[i]]];
            [row addObject: [(NSNumber *)[self.anglularVelocties objectAtIndex:i] stringValue]];
            
            [rowsStrings addObject: [row componentsJoinedByString:@","]];
        }
    }
    
    NSString *content = [rowsStrings componentsJoinedByString: @"\n"];
    //save content to the documents directory
    [content writeToFile:[[self recordingAngularVelocitiesFilePathURL] relativePath]
              atomically:NO
                encoding:NSStringEncodingConversionAllowLossy
                   error:nil];
}


-(NSString*)applicationDocumentsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}

-(NSURL*)recordingFilePathURL {
    return [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@",
                                   [self applicationDocumentsDirectory],
                                   @"summeryTextFile.txt"]];
}

-(NSURL*)recordingAngularVelocitiesFilePathURL {
    return [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@",
                                   [self applicationDocumentsDirectory],
                                   @"summeryAngularVelocitiesTextFile.txt"]];
}



@end
