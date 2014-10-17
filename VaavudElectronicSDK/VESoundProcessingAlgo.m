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
    mvgDiffUp = 200;
    
    diffSumRiseThreshold = 800; // STARTING VALUE
    
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
        
        
//        if (counter > 80000 && counter < 80010 ) {
//            NSLog(@"counter: %lu, bufferIndex: %d, data[i]: %d", counter, bufferIndex, data[i]);
//            NSLog(@"mvgAvg: %d, %d, %d", mvgAvg[0], mvgAvg[1], mvgAvg[2]);
//            NSLog(@"mvgDiff: %d, %d, %d", mvgDiff[0], mvgDiff[1], mvgDiff[2]);
//            NSLog(@"mvgAvgSum: %d", mvgAvgSum);
//            NSLog(@"mvgDiffSum: %d", mvgDiffSum);
//            
//        }
        
        
        if (maxDiff < mvgDiffSum) {
            maxDiff = mvgDiffSum;
        }
        
        
        if ([self detectTick: (int) (counter - lastTick)]) {
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

//    NSLog(@"counter: %lu", counter);
//    NSLog(@"mvgAvgSum: %d", mvgAvgSum);
//    NSLog(@"mvgDiffSum: %d", mvgDiffSum);
    

}


- (BOOL) detectTick:(int) sampleSinceTick {
    
    switch (mvgState) {
        case 0:
            if (sampleSinceTick < 70) {
                if (mvgAvgSum < -810 && mvgDiffSum > 510) {
                    mvgState = 1;
                    diffState = 1;
                    return true;
                }
            } else {
                mvgState = -1;
            }
            break;
        case 1:
            if (sampleSinceTick < 60) {
                if (mvgAvgSum > 810) {
                    mvgState = 0;
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
            if (sampleSinceTick < 100) { // was 170
                if (mvgAvgSum < -1800) {
                    mvgState = 1;
                    diffState = 1;
                    return  true;
                }
            } else {
                if (mvgDiffSum > 180 && mvgAvgSum < -600) { // diff was 1200
                    mvgState = 1;
                    diffState = 1;
                    return  true;
                }
            }
            break;
        case 1:
            if (mvgDiffSum > 1500) {
                diffState = 2;
            }
            break;
            
        case 2:
            if (mvgAvgSum > 0) {
                diffState = 3;
            }
            
            break;
        case 3:
            if (mvgDiffSum < 1050) {
                diffState = 4;
                gapBlock = sampleSinceTick * 2.5;
            }
        
        case 4:
            if (sampleSinceTick > gapBlock) {
                diffState = 0;
//                mvgDiffUp = (int) mvgDiffSum * 1.7;
//                if (mvgDiffUp > 1200)
//                    mvgDiffUp = 1200;
                
            }
            break;
        default:
            break;
    }
    
    return false;
    
}



@end
