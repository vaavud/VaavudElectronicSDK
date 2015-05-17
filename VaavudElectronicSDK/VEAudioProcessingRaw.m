//
//  soundProcessing.m
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 09/06/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import "VEAudioProcessingRaw.h"
#import "VEAudioProcessingTick.h"

static const int EXECUTE_METRICS_EVERY = 200;
static const int VOLUME_ADJUST_THRESHOLD = 6;
static const float alpha = 0.05;

@interface VEAudioProcessingRaw() {
    int mvgAvg[3];
    int mvgAvgSum;
    int bufferIndex;
    int bufferIndexLast;
    int mvgDiff[3];
    int mvgDiffSum;
    int diffArray[64];
    float diff40lowpass;
    
    int gapBlock;
    unsigned long counter;
    unsigned long lastTick;
    short mvgState;
    short diffState;
    int diffSumRiseThreshold;
    
    int mvgMax, mvgMin, lastMvgMax, lastMvgMin, diffMax, diffMin, lastDiffMax, lastDiffMin, diffGap, mvgGapMax, lastMvgGapMax, mvgDropHalf, diffRiseThreshold1;
    bool mvgDropHalfRefresh, longTick;
    
    int volumeAdjustCounter;
    float executionTimes[EXECUTE_METRICS_EVERY];
    int calculationCounter;
}

@property (strong, nonatomic) id<VEAudioProcessingRawDelegate> delegate;
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

- (id)initWithDelegate:(id<VEAudioProcessingRawDelegate>)delegate {
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
    
    lastMvgMax = 16350;
    lastMvgMin = -16350;
    lastDiffMax = 32700;
    lastDiffMin = 0;
    lastMvgGapMax = 0;
    
    diff40lowpass = 2000;
    
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
    
    lastMvgMax = 16350;
    lastMvgMin = -16350;
    lastDiffMax = 32700;
    lastDiffMin = 0;
    lastMvgGapMax = 0;
    diff40lowpass = 2000;
    
    mvgDropHalfRefresh = YES;
}

- (void)checkAndProcess:(VECircularBuffer *)circBuffer withDefaultBufferLengthInFrames:(UInt32)bufferLengthInFrames {
        dispatch_async(self.dispatchQueue, ^(void){
            [self processBuffer:circBuffer withDefaultBufferLengthInFrames:bufferLengthInFrames];
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
//        if( circBuffer->fillCount > bufferLengthInFrames*10) {
//            if (LOG_PERFORMANCE) NSLog(@"[VESDK] circBuffer fillCount %i", circBuffer->fillCount);
//        }
    } else {
        if (LOG_PERFORMANCE) NSLog(@"[VESDK] Buffer is Null or not filled. Nsamples: %lu",(unsigned long) availableBytes/sampleSize);
    }
    
    if (LOG_PERFORMANCE) {
        NSDate *methodFinish = [NSDate date];
        NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:methodStart]*1000; //ms
        if (executionTime > 100) {
            NSLog(@"[VESDK] ExecutionTime = %f ms", executionTime);
        }
        
        executionTimes[calculationCounter] = executionTime;
        calculationCounter++;
        if (calculationCounter == EXECUTE_METRICS_EVERY) {
            float sum = 0;
            for (int i = 0; i < EXECUTE_METRICS_EVERY; i++) {
                sum += executionTimes[i];
            }
            NSLog(@"[VESDK] Average executionTime: %f ms", sum/(float) EXECUTE_METRICS_EVERY);
            calculationCounter = 0;
            if (LOG_PERFORMANCE) NSLog(@"[VESDK] CircBuffer fillCount %i", circBuffer->fillCount);
        }
    }
}


- (void)newSoundData:(SInt16 *)data bufferLength:(UInt32)bufferLength {
    // used for stats & volume calibration
    int mvgMaxVol = 0;
    int mvgMinVol = 0;
    int diffMaxVol = 0;
    int diffMinVol = 6*INT16_MAX;
    long mvgAvgVol = 0;
    long diffAvgVol = 0;
    
    int diffArrayStoreEvery = bufferLength/64;
    int diffArrayCounter = 0;
    
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
        
        // update volume values
        mvgMaxVol = MAX(mvgMaxVol, mvgAvgSum);
        mvgMinVol = MIN(mvgMinVol, mvgAvgSum);
        diffMaxVol = MAX(diffMaxVol, mvgDiffSum);
        diffMinVol = MIN(diffMinVol, mvgDiffSum);
        mvgAvgVol += mvgAvgSum;
        diffAvgVol += mvgDiffSum;
        if(counter%diffArrayStoreEvery == 0) {
            diffArray[diffArrayCounter] = mvgDiffSum;
            diffArrayCounter++;
        }
        counter++;
    }
    
    VEVolumeReponse *volRepsonse = [[VEVolumeReponse alloc] init];
    volRepsonse.volume = [MPMusicPlayerController applicationMusicPlayer].volume;
    volRepsonse.diffMax = diffMaxVol;
    volRepsonse.diffMin = diffMinVol;
    volRepsonse.mvgMax = mvgMaxVol;
    volRepsonse.mvgMin = mvgMinVol;
    volRepsonse.diffAvg = (int) diffAvgVol/bufferLength;
    volRepsonse.mvgAvg = (int) mvgAvgVol/bufferLength;
    
    [self sortArray:diffArray ofSize:sizeof(diffArray) / sizeof(*diffArray)];
    volRepsonse.diff10 = diffArray[6];
    volRepsonse.diff20 = diffArray[12];
    volRepsonse.diff30 = diffArray[19];
    volRepsonse.diff40 = diffArray[25];
    volRepsonse.diff50 = diffArray[32];
    volRepsonse.diff60 = diffArray[38];
    volRepsonse.diff70 = diffArray[44];
    volRepsonse.diff80 = diffArray[51];
    volRepsonse.diff90 = diffArray[57];
    
    diff40lowpass = diff40lowpass*alpha +volRepsonse.diff40*(1-alpha);
    
    [self.delegate volumeResponse:volRepsonse];
    
    
    if (diff40lowpass > 4000 && volumeAdjustCounter > VOLUME_ADJUST_THRESHOLD) {
        float adjustment = -0.01;
        if (diff40lowpass > 20000) {
            adjustment = -0.05;
        }
        
        if (LOG_VOLUME) NSLog(@"[VESDK] diff40lowpass: %f Adjustment: %f", diff40lowpass, adjustment);
        [self.delegate adjustVolume:adjustment];
        volumeAdjustCounter = 0;
    }
    
    if (diff40lowpass < 1000 && volumeAdjustCounter > VOLUME_ADJUST_THRESHOLD) {
        float adjustment = +0.01;
        if (LOG_VOLUME) NSLog(@"[VESDK] diff40lowpass: %f  Adjustment: %f", diff40lowpass, adjustment);
        [self.delegate adjustVolume:adjustment];
        volumeAdjustCounter = 0;
    }
    volumeAdjustCounter++;

    
    dispatch_async(dispatch_get_main_queue(),^{
        [self.delegate newMaxAmplitude:@(diffMax)];
    });
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
    
    if (sampleSinceTick == 8800) {
        lastTick = counter; // reset tick counter
        [self resetStateMachine];
        [self.processorTick newTickReset];
    }
    
    return false;
}

int compare(const void *first, const void *second)
{
    return *(const int *)first - *(const int *)second;
}

- (void)sortArray:(int *)array ofSize:(size_t)sz
{
    qsort(array, sz, sizeof(*array), compare);
}

@end
