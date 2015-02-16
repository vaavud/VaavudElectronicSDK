//
//  soundProcessing.m
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 09/06/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import "VESoundProcessingAlgo.h"
#import "VEDirectionDetectionAlgo.h"

@interface VESoundProcessingAlgo() {
    int mvgAvg[3];
    int mvgAvgSum;
    int mvgDiff[3];
    int mvgDiffSum;
    int gapBlock;
    unsigned long counter;
    unsigned long lastTick;
    short mvgState;
    short diffState;
    int diffSumRiseThreshold;
    
    int mvgMax, mvgMin, lastMvgMax, lastMvgMin, diffMax, diffMin, lastDiffMax, lastDiffMin, diffGap, mvgGapMax, lastMvgGapMax, mvgDropHalf, diffRiseThreshold1;
    bool mvgDropHalfRefresh, longTick;
    
    int calibrationCounter;
    float volume;
}

@property (strong, nonatomic) id<SoundProcessingDelegate, DirectionDetectionDelegate> delegate;
@property (strong, nonatomic) MPMusicPlayerController *musicPlayer;


@end

@implementation VESoundProcessingAlgo


#pragma mark - Initialization
-(id)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"-init is not a valid initializer for the class SoundProcessingAlgo"
                                 userInfo:nil];
    return nil;
}

- (id)initWithDelegate:(id<SoundProcessingDelegate, DirectionDetectionDelegate>)delegate {
    
    self = [super init];
    
    counter = 0;
    mvgAvgSum = 0;
    mvgDiffSum = 0;
    
    mvgState = 0;
    diffState = 0;
    gapBlock = 0;

    mvgMax = 0;
    mvgMin = 0;
    diffMax = 0;
    diffMin = 0;
    
    lastMvgMax = 500;
    lastMvgMin = -500;
    lastDiffMax = 1000;
    lastDiffMin = 0;
    lastMvgGapMax = 0;
    
    mvgDropHalf = 0;
    mvgDropHalfRefresh = YES;
    
    self.dirDetectionAlgo = [[VEDirectionDetectionAlgo alloc] initWithDelegate:delegate];
    self.delegate = delegate;
    
    self.musicPlayer = [MPMusicPlayerController applicationMusicPlayer];
   
    volume = [[NSUserDefaults standardUserDefaults] floatForKey:@"VOLUME"];
    
    if (volume == 0) {
        volume = 1.0;
    }
    self.musicPlayer.volume = volume;
    
    return self;
}

- (void) resetStateMachine {
    mvgState = 0;
    diffState = 0;
    gapBlock = 0;
    
    mvgMax = 0;
    mvgMin = 0;
    diffMax = 0;
    diffMin = 0;
    
    lastMvgMax = 500;
    lastMvgMin = -500;
    lastDiffMax = 1000;
    lastDiffMin = 0;
    lastMvgGapMax = 0;
    mvgDropHalfRefresh = YES;
}

- (void) newSoundData:(int *)data bufferLength:(UInt32) bufferLength {
   
    // used for stats & volume calibration
    int lDiffMax = 0;
    int lDiffMin = 10000;
    long lDiffSum = 0;
    
    int avgMax = -10000;
    int avgMin = 10000;
    
    for (int i = 0; i < bufferLength; i++) {
        
        int bufferIndex = counter%3;
        int bufferIndexLast = (counter-1)%3;
        
        // Moving Avg subtract
        mvgAvgSum -= mvgAvg[bufferIndex];
        // Moving Diff subtrack
        mvgDiffSum -= mvgDiff[bufferIndex];
        
        
        // Moving Diff Update buffer value
        mvgDiff[bufferIndex] = abs( data[i]- mvgAvg[bufferIndexLast]); // ! need to use old mvgAvgValue so place before mvgAvg update
        // Moving avg Update buffer value
        mvgAvg[bufferIndex] = data[i];
        
        
        // Moving Avg update SUM
        mvgAvgSum += mvgAvg[bufferIndex];
        mvgDiffSum += mvgDiff[bufferIndex];
        

        if ([self detectTick: (int) (counter - lastTick)]) {
            
            lastMvgMax = mvgMax;
            lastMvgMin = mvgMin;
            lastDiffMax = diffMax;
            lastDiffMin = diffMin;
            lastMvgGapMax = mvgGapMax;
            
            mvgMax = 0;
            mvgMin = 0;
            diffMax = 0;
            diffMin = 1000;
            
            mvgState = 0;
            diffState = 0;
            
            longTick = [self.dirDetectionAlgo newTick: (int) (counter - lastTick)];
            lastTick = counter;
            
        }
        
        counter++;
        
        // stats
        if (calibrationCounter == 0) {
            if (lDiffMax < mvgDiffSum){
                lDiffMax = mvgDiffSum;
            }
            
            if (lDiffMin > mvgDiffSum){
                lDiffMin = mvgDiffSum;
            }
            
            if (avgMax < mvgAvgSum){
                avgMax = mvgAvgSum;
            }
            
            if (avgMin > mvgAvgSum){
                avgMin = mvgAvgSum;
            }
            
            lDiffSum += mvgDiffSum;
        }
    }
    
    if (calibrationCounter == 0) {
        [self adjustVolumediffMax:lDiffMax anddiffMin:lDiffMin andAvgDiff:lDiffSum/bufferLength andAvgMax:avgMax andAvgMin:avgMin];
        calibrationCounter-= 20; // Calibrate every X buffer
    }
    calibrationCounter++;
    
    
    // See the Thread Safety warning above, but in a nutshell these callbacks happen on a separate audio thread. We wrap any UI updating in a GCD block on the main thread to avoid blocking that audio flow.
    dispatch_async(dispatch_get_main_queue(),^{
        [self.delegate newMaxAmplitude: [NSNumber numberWithInt:lDiffMax]];
    });

}

-(void) adjustVolumediffMax:(int)ldiffMax anddiffMin:(int)ldiffMin andAvgDiff:(int)avgDiff andAvgMax:(int)avgMax andAvgMin:(int)avgMin{
    
    if (avgDiff < 25 && avgMax < 2 && avgMin > -2) {
        volume += 0.01;
        self.musicPlayer.volume = volume;
        [[NSUserDefaults standardUserDefaults] setFloat:volume forKey:@"VOLUME"];
        NSLog(@"[VESDK] Volume: %f, max: %i, min: %i, avg: %i, avgMax: %i, avgMin: %i", volume, ldiffMax, ldiffMin, avgDiff, avgMax, avgMin);
    }
    
    if (ldiffMax > 3750 || (ldiffMax > 2700 && (avgMax > 2000 && avgMin < -2000))) {
        volume -= 0.01;
        self.musicPlayer.volume = volume;
        [[NSUserDefaults standardUserDefaults] setFloat:volume forKey:@"VOLUME"];
        NSLog(@"[VESDK] Volume: %f, max: %i, min: %i, avg: %i, avgMax: %i, avgMin: %i", volume, ldiffMax, ldiffMin, avgDiff, avgMax, avgMin);
    }
}
            

- (BOOL) detectTick:(int) sampleSinceTick {
    
    switch (mvgState) {
        case 0:
            if (sampleSinceTick < 60) {
                if (mvgAvgSum > 0.5*lastMvgMax) {
                    mvgState = 1;
                }
            } else {
                mvgState = -1;
            }
            break;
        case 1:
            if (sampleSinceTick < 90) {
                if (mvgAvgSum < 0.5*lastMvgMin) {
                    return true;
                }
            } else {
                mvgState = -1;
            }
            break;
        default:
            break;
    }
    
    
    switch (diffState) {
        case 0:
            if (mvgAvgSum<mvgMin) {
                mvgMin=mvgAvgSum;
            }
            if (mvgDiffSum > 0.3*lastDiffMax) {
                diffState = 1;
            }
            break;
            
        case 1:
            if (mvgAvgSum<mvgMin) {
                mvgMin=mvgAvgSum;
            }
            if (mvgAvgSum > 0) {
                diffState = 2;
            }
            
            break;
        case 2:
            if (mvgDiffSum < 0.30*lastDiffMax) {
                diffState = 3;
                if (longTick) {
                    gapBlock = sampleSinceTick * 2.9;
                } else {
                    gapBlock = sampleSinceTick * 2.3;
                }
                
                if (gapBlock > 5000) {
                    gapBlock = 5000;
                }
            }
            break;
        case 3:
            if (sampleSinceTick > gapBlock) {
                diffState = 4;
                
                diffGap = mvgDiffSum;
                mvgGapMax = mvgAvgSum;
                
                diffRiseThreshold1 = diffGap + 0.1 * (lastDiffMax - diffGap);
                
                int newMvgDropHalf = ( lastMvgGapMax - mvgMin)/2;
                if (newMvgDropHalf  < mvgDropHalf*1.25 || mvgDropHalfRefresh) {
                    mvgDropHalf = newMvgDropHalf;
                    mvgDropHalfRefresh = NO;
                }
                else {
                    mvgDropHalfRefresh = YES;
                }
            
                
            }
            break;
        case 4:
            if (mvgAvgSum > mvgGapMax) {
                mvgGapMax = mvgAvgSum;
            }

            if ( ((mvgAvgSum < mvgGapMax - mvgDropHalf) && ( mvgDiffSum > diffRiseThreshold1 ))  || mvgDiffSum > 0.75*lastDiffMax ) {
                return  true;
            }

            break;
        default:
            break;
    }
    
    if (mvgAvgSum > mvgMax) {
        mvgMax=mvgAvgSum;
    }
    
    if (mvgDiffSum> diffMax) {
        diffMax = mvgDiffSum;
    }

    if (mvgDiffSum<diffMin) {
        diffMin = mvgDiffSum;
    }
    
    if (sampleSinceTick == 6000) {
        [self resetStateMachine];
    }
    
    return false;
    
}

@end
