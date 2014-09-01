//
//  soundProcessing.m
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 09/06/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import "SoundProcessingAlgo.h"
#import "VaavudElectronicSDK.h"

@interface SoundProcessingAlgo() {
    int mvgAvg[3];
    int mvgAvgSum;
    int mvgDiff[3];
    int mvgDiffSum;
    int lastValue;
    unsigned long counter;
    unsigned long lastTick;
    short mvgState;
    short diffState;
    int diffSumRiseThreshold;
}

@property (strong, nonatomic) id<SoundProcessingDelegate, DirectionDetectionDelegate> windDelegate;

@end

@implementation SoundProcessingAlgo


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
    
    diffSumRiseThreshold = 800; // STARTING VALUE
    
    self.dirDetectionAlgo = [[DirectionDetectionAlgo alloc] initWithDelegate:delegate];
    
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
            
            NSLog(@"Tick %lu", counter - lastTick);
            
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
    
    // NOTE ALL COMPARISON VALUES IS TIMED BY 3
    switch (mvgState) {
        case 0:
            if (sampleSinceTick < 90) {
                if (mvgAvgSum < -800 && mvgDiffSum > 200) {
                    mvgState = 1;
                    diffState = 1;
                    return true;
                }
            } else {
                mvgState = -1;
            }
            break;
        case 1:
            if (sampleSinceTick < 70) {
                if (mvgAvgSum > 800) {
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
            if (mvgDiffSum > diffSumRiseThreshold) { // outside 800
                mvgState = 1;
                diffState = 1;
                return  true;
            }
            break;
        case 1:
            if (mvgDiffSum > 1500) {
                diffState = 2;
            }
            break;
        case 2:
            if (mvgDiffSum < 500 && mvgAvgSum < 0) { // outside 500
                diffState = 0;
                diffSumRiseThreshold = mvgDiffSum * 1.4 + 100;
            }
        default:
            break;
    }
    
    return false;
    
}



@end
