//
//  soundProcessing.m
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 09/06/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import "VESoundProcessingAlgo.h"

@interface VESoundProcessingAlgo() {
    int mvgAvg[3];
    int mvgAvgSum;
    int mvgDiff[3];
    int mvgDiffSum;
    int lastValue;
    int gapBlock;
    int mvgDiffUp;
    unsigned long counter;
    unsigned long lastTick;
    short mvgState;
    short diffState;
    int diffSumRiseThreshold;
    
    int mvgMax, mvgMin, lastMvgMax, lastMvgMin, diffMax, diffMin, lastDiffMax, lastDiffMin, diffGap, mvgGapMax, lastMvgGapMax, mvgDropHalf, diffRiseThreshold1;
}

@property (strong, nonatomic) id<SoundProcessingDelegate, DirectionDetectionDelegate> windDelegate;

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
    lastValue = 0;
    
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
    
    
    
    self.dirDetectionAlgo = [[VEDirectionDetectionAlgo alloc] initWithDelegate:delegate];
    
    self.windDelegate = delegate;
    
    return self;
}



- (void) newSoundData:(int *)data bufferLength:(UInt32) bufferLength {
   
    
    int maxDiff = 0;
    
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
        
        
        if (maxDiff < mvgDiffSum) {
            maxDiff = mvgDiffSum;
        }
        
        
        if ([self detectTick: (int) (counter - lastTick)]) {
            
            
            mvgState = 0;
            diffState = 0;
            
            lastMvgMax = mvgMax;
            lastMvgMin = mvgMin;
            lastDiffMax = diffMax;
            lastDiffMin = diffMin;
            lastMvgGapMax = mvgGapMax;
            
            mvgMax = 0;
            mvgMin = 0;

            
            
            [self.dirDetectionAlgo newTick: (int) (counter - lastTick)];
            
//            NSLog(@"Tick %lu", counter - lastTick);
            
            lastTick = counter;
        }
        
        counter++;
        
        
        
        
        
    }
    
    // See the Thread Safety warning above, but in a nutshell these callbacks happen on a separate audio thread. We wrap any UI updating in a GCD block on the main thread to avoid blocking that audio flow.
    dispatch_async(dispatch_get_main_queue(),^{
        [self.windDelegate newMaxAmplitude: [NSNumber numberWithInt:maxDiff]];
    });

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
            if (mvgAvgSum<mvgMin)
                mvgMin=mvgAvgSum;
            if (mvgDiffSum > 0.3*lastDiffMax) {
                diffState = 1;
            }
            break;
            
        case 1:
            if (mvgAvgSum<mvgMin)
                mvgMin=mvgAvgSum;
            if (mvgAvgSum > 0) {
                diffState = 2;
            }
            
            break;
        case 2:
            if (mvgDiffSum < 0.35*lastDiffMax) {
                diffState = 3;
                gapBlock = sampleSinceTick * 2.5;
            }
            break;
        case 3:
            if (sampleSinceTick > gapBlock) {
                diffState = 4;
                diffGap = mvgDiffSum;
                mvgGapMax = mvgAvgSum;
                diffRiseThreshold1 = diffGap + 0.1 * (lastDiffMax - diffGap);
                mvgDropHalf =  (lastMvgGapMax - mvgMin)/2 ;
                
            }
            break;
        case 4:
            if (mvgAvgSum > mvgGapMax)
                mvgGapMax = mvgAvgSum;
            
//            if (mvgDiffSum > 0.3*lastDiffMax && mvgAvgSum < 0.2*lastMvgMin) { // diff was 1200
            if ( (mvgAvgSum < mvgGapMax - mvgDropHalf && ( mvgDiffSum > diffRiseThreshold1 ))  || mvgDiffSum > 0.5*lastDiffMax ) {
                return  true;
            }

            break;
        default:
            break;
    }
    
    if (mvgAvgSum > mvgMax)
        mvgMax=mvgAvgSum;
    
    if (mvgDiffSum> diffMax)
        diffMax = mvgDiffSum;
    
    if (mvgDiffSum<diffMin)
        diffMin = mvgDiffSum;
    
    
    return false;
    
}



@end
