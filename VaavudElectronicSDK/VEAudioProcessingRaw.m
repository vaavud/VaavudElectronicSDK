//
//  soundProcessing.m
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 09/06/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import "VEAudioProcessingRaw.h"
#import "VEAudioProcessingTick.h"

#define CALIBRATE_AUDIO_EVERY_X_BUFFER 20
#define EXECUTION_METRIX_EVERY 200

@interface VEAudioProcessingRaw() {
    int mvgAvg[3];
    int mvgAvgSum;
    int bufferIndex;
    int bufferIndexLast;
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
    
    float executionTimes[EXECUTION_METRIX_EVERY];
    int calculationCounter;
}

@property (strong, nonatomic) id<VEAudioProcessingDelegate> delegate;
@property (nonatomic) dispatch_queue_t dispatchQueue;

@end

@implementation VEAudioProcessingRaw


#pragma mark - Initialization
- (id)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"-init is not a valid initializer for the class SoundProcessingAlgo"
                                 userInfo:nil];
    return nil;
}

- (id)initWithDelegate:(id<VEAudioProcessingDelegate, DirectionDetectionDelegate>)delegate {
    self = [super init];
    
    counter = 0;
    bufferIndex = 0;
    bufferIndexLast = 2;
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
    
    self.delegate = delegate;
    
    self.dispatchQueue = (dispatch_queue_create("com.vaavud.processTickQueue", DISPATCH_QUEUE_SERIAL));
    dispatch_set_target_queue(self.dispatchQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    return self;
}

- (void)resetStateMachine {
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

- (void)checkAndProcess:(VECircularBuffer *)circBuffer withDefaultBufferLengthInFrames:(UInt32)bufferLengthInFrames {
    dispatch_async(self.dispatchQueue, ^(void){
        [self processBuffer:circBuffer withDefaultBufferLengthInFrames:bufferLengthInFrames];
        if (circBuffer->fillCount > bufferLengthInFrames*sizeof(SInt16)) {
            [self checkAndProcess:circBuffer withDefaultBufferLengthInFrames:bufferLengthInFrames];
        }
    });
}


- (void)processBuffer:(VECircularBuffer *)circBuffer withDefaultBufferLengthInFrames:(UInt32)bufferLengthInFrames {
    
    NSDate *methodStart;
    if (LOG_PERFORMANCE) {
        methodStart = [NSDate date];
    }

    // keep for now to comsume bytes
    int32_t availableBytes;
    SInt16 *circBufferTail = VECircularBufferTail(circBuffer, &availableBytes);
    UInt32 sampleSize = sizeof(SInt16);
    
    if (circBufferTail != NULL && circBuffer->fillCount >= bufferLengthInFrames*sampleSize) {
        UInt32 size = MIN(bufferLengthInFrames*sampleSize, availableBytes);
        UInt32 frames = size/sampleSize;
        
        [self newSoundData:circBufferTail bufferLength:frames];
        
        VECircularBufferConsume(circBuffer, size);
        if( circBuffer->fillCount > 0) {
            if (LOG_PERFORMANCE) NSLog(@"[VESDK] circBuffer fillCount %i", circBuffer->fillCount);
        }
    } else {
        if (LOG_PERFORMANCE) NSLog(@"[VESDK] Buffer is Null or not filled. Nsamples: %lu", availableBytes/sampleSize);
    }
    
    if (LOG_PERFORMANCE) {
        NSDate *methodFinish = [NSDate date];
        NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:methodStart]*1000; //ms
        if (executionTime > 10) {
            NSLog(@"[VESDK] ExecutionTime = %f ms", executionTime);
        }
        
        executionTimes[calculationCounter] = executionTime;
        calculationCounter++;
        if (calculationCounter == EXECUTION_METRIX_EVERY) {
            float sum = 0;
            for (int i = 0; i < EXECUTION_METRIX_EVERY; i++) {
                sum += executionTimes[i];
            }
            NSLog(@"[VESDK] Average executionTime: %f ms", sum/(float)EXECUTION_METRIX_EVERY);
            calculationCounter = 0;
        }
    }
}


- (void)newSoundData:(SInt16 *)data bufferLength:(UInt32)bufferLength {
    // used for stats & volume calibration
    int lDiffMax = 0;
    int lDiffMin = 6*INT16_MAX;
    long lDiffSum = 0;
    
    int avgMax = INT16_MIN;
    int avgMin = INT16_MAX;
    
    for (int i = 0; i < bufferLength; i++) {
        // Moving Avg subtract
        mvgAvgSum -= mvgAvg[bufferIndex];
        // Moving Diff subtrack
        mvgDiffSum -= mvgDiff[bufferIndex];
        
        
        // Moving Diff Update buffer value
        mvgDiff[bufferIndex] = abs(data[i]- mvgAvg[bufferIndexLast]); // ! need to use old mvgAvgValue so place before mvgAvg update
        // Moving avg Update buffer value
        mvgAvg[bufferIndex] = data[i];
        
        
        // Moving Avg update SUM
        mvgAvgSum += mvgAvg[bufferIndex];
        mvgDiffSum += mvgDiff[bufferIndex];
        
        bufferIndex += 1;
        if (bufferIndex == 3) {bufferIndex -= 3;}
        bufferIndexLast += 1;
        if (bufferIndexLast == 3) {bufferIndexLast -=3;}
            
            
        if ([self detectTick:(int)(counter - lastTick)]) {
            lastMvgMax = mvgMax;
            lastMvgMin = mvgMin;
            lastDiffMax = diffMax;
            lastDiffMin = diffMin;
            lastMvgGapMax = mvgGapMax;
            
            mvgMax = 0;
            mvgMin = 0;
            diffMax = 0;
            diffMin = 6*INT16_MAX;
            
            mvgState = 0;
            diffState = 0;
            
            longTick = [self.processorTick newTick:(int)(counter - lastTick)];
            lastTick = counter;
        }
        
        counter++;
        
        // stats
        if (calibrationCounter == CALIBRATE_AUDIO_EVERY_X_BUFFER) {
            lDiffMax = MAX(lDiffMax, mvgDiffSum);

            if (mvgAvgSum < 0) {
                lDiffMin = MIN(lDiffMin, mvgDiffSum);
            }
            
            avgMax = MAX(avgMax, mvgAvgSum);
            avgMin = MIN(avgMin, mvgAvgSum);
            
            lDiffSum += mvgDiffSum;
        }
    }
    
    if (calibrationCounter == CALIBRATE_AUDIO_EVERY_X_BUFFER && bufferLength > 0) {
        [self adjustVolumeDiffMax:lDiffMax diffMin:lDiffMin avgDiff:(int)(lDiffSum/bufferLength) avgMax:avgMax avgMin:avgMin];
        calibrationCounter= 0;
        // See the Thread Safety warning above, but in a nutshell these callbacks happen on a separate audio thread. We wrap any UI updating in a GCD block on the main thread to avoid blocking that audio flow.
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate newMaxAmplitude: [NSNumber numberWithInt:lDiffMax]];
        });
    }
    calibrationCounter++;
}

-(void)adjustVolumeDiffMax:(int)ldiffMax diffMin:(int)ldiffMin avgDiff:(int)avgDiff avgMax:(int)avgMax avgMin:(int)avgMin {
    BOOL rotating = avgMax > 66000 && avgMin < -66000;
    BOOL stationary = avgMax < 130 && avgMin > -130;
    
    if ((stationary && avgDiff < 660) || (rotating && ldiffMax < 66000)) {
        [self.delegate adjustVolume:0.01];
        if (LOG_VOLUME) NSLog(@"[VESDK] Volume +: %f, max: %i, min: %i, avg: %i, avgMax: %i, avgMin: %i", 0.01, ldiffMax, ldiffMin, avgDiff, avgMax, avgMin);
    }
    else if (ldiffMax > 125000 || (rotating && ldiffMin > 1650)) { // ldiffMax > 2700
        [self.delegate adjustVolume:-0.01];
        if (LOG_VOLUME) NSLog(@"[VESDK] Volume -: %f, max: %i, min: %i, avg: %i, avgMax: %i, avgMin: %i", 0.01, ldiffMax, ldiffMin, avgDiff, avgMax, avgMin);
    }
}

- (BOOL)detectTick:(int)sampleSinceTick {
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
                if (mvgAvgSum < 0.5*lastMvgMin && mvgAvgSum < -40000) {
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
            if (mvgMin > mvgAvgSum) {
                mvgMin = mvgAvgSum;
            }
            if (mvgDiffSum > 0.3*lastDiffMax) {
                diffState = 1;
            }
            break;
            
        case 1:
            if (mvgMin > mvgAvgSum) {
                mvgMin = mvgAvgSum;
            }
            if (mvgAvgSum > 0) {
                diffState = 2;
            }
            
            break;
        case 2:
            if (mvgDiffSum < 0.30*lastDiffMax) {
                diffState = 3;
                if (longTick) {
                    gapBlock = sampleSinceTick*2.9;
                } else {
                    gapBlock = sampleSinceTick*2.3;
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

            if (((mvgAvgSum < mvgGapMax - mvgDropHalf) && (mvgDiffSum > diffRiseThreshold1)) || mvgDiffSum > 0.75*lastDiffMax) {
                return  true;
            }

            break;
        default:
            break;
    }
    
    if (mvgMax < mvgAvgSum) {
        mvgMax = mvgAvgSum;
    }

    if (diffMax < mvgDiffSum) {
        diffMax = mvgDiffSum;
    }

    if (diffMin > mvgDiffSum) {
        diffMin = mvgDiffSum;
    }
    
    if (sampleSinceTick == 6000) {
        [self resetStateMachine];
    }
    
    return false;
}

@end
