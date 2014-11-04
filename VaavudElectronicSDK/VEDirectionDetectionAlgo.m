//
//  DirectionDetectionAlgo.m
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 11/06/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import "VEDirectionDetectionAlgo.h"
//#define TEETH_PR_REV 10
#define TEETH_PR_REV 15
#define SAMPLE_BUFFER_SIZE 40
#define UPDATE_INTERVAL 0.2 // 5 times a second
#define ANGLE_CORRRECTION_COEFFICIENT 200 // originally 400 (but since actual velocity difference is about double...
#define ANGLE_DIFF 1
#define SMOOTHING_TIME_CONSTANT 3
#define SAMPLE_FREQUENCY 44100


@interface VEDirectionDetectionAlgo() {
    
    unsigned int totalTickCounter;
    unsigned int teethIndex;
    unsigned int tickCounterSinceStart;
    unsigned int teethProcessIndex;
    unsigned int tickBufferCounter;
    unsigned int lastTickBufferCounter;
    unsigned int startCounter;
    
    int tickLengthBuffer[TEETH_PR_REV];
    int tickLengthOneRotation;
    float expTickLengthRelativePrTeeth[TEETH_PR_REV];
    
    double nextRefreshTime;
    BOOL startLocated;
    int lastTickLength;
    float lastTickLengthCompensated;
    int tickEdgeAngle[TEETH_PR_REV]; // add one point in ether end
    int angleEstimator;
    
    int iteratorAngleCounter;
}

@property (strong, nonatomic) id<DirectionDetectionDelegate> dirDelegate;

@end


@implementation VEDirectionDetectionAlgo


float compensation[TEETH_PR_REV] = {1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,0.774193548387097};

//float compensation2[TEETH_PR_REV] = {1.36642200028858,1.14663273821641,-2.17037166831898,-1.25544425914286,-3.09283096100997,1.03853721398508,1.00103346210481,5.38022993669676,-2.62548084741271,1.81677551601541,-3.58838920481080,1.02778809390994,-1.05007481464095,1.76916037125822,-0.763987577138973};
//
//float compensation3[TEETH_PR_REV] = {0.482503210666667,0.257373151333333,0.318363569333333,0.383400920666667,0.469710791333333,0.653712393333333,0.0889313200000000,0.322430538000000,-0.0822921500000000,-0.624701627333333,-0.254397380000000,-0.132323110000000,-0.451682820000000,-0.298732492666667,-0.227766400000000};


//float compensationT1[TEETH_PR_REV] = {0.5673,0.3535,0.2140,-0.4933,-0.9837,-0.9791,-0.3582,-0.0840,0.5141,1.1365,1.1198,-0.1993,-0.0819,-0.0614,-0.6642};

//float compensationT1[TEETH_PR_REV] = {0.255313870261152,-1.06321284790957,-1.85809500396847,-0.485670500175613,0.304926712381872,0.731881867917250,1.45702351021075,1.30215137451077,1.21273480907476,0.686947775212225,0.0957051710857151,-0.902816536905571,-0.308586035140004,-0.288909983469392,-1.13939418308586};
//float compentationT1Ispo[TEETH_PR_REV] = {0.326978570833333,-0.299902298333333,-0.676498258333333,-1.62413215833333,-1.62867459833333,-1.56009190000000,-0.425381556666667,0.630586347500000,0.639615490000000,0.855704600000000,0.754921124166667,0.123426450000000,0.943220616666667,1.34049741666667,0.454642833333333};
//
//float compensationS12[TEETH_PR_REV] = {2.45987670000000,0.800626565000000,0.588490516666667,-0.935374225000000,-0.560158465833333,-0.328313783333333,0.122647412500000,0.264504658333333,-0.127888691666667,-0.258119426666667,-0.158305491666667,-1.92416610000000,0.0561986100000000,-0.175370266666667,0.132928903250000};

float fitcurve[360] = {0.492458649,0.475097354,0.457163957,0.43815945,0.417886639,0.396242588,0.373193991,0.348732732,0.322879916,0.295672578,0.267183381,0.237489337,0.206641721,0.174677409,0.141600479,0.107406628,0.07209709,0.035688557,-0.001736149,-0.040075612,-0.07923396,-0.119129452,-0.159740474,-0.201061524,-0.243077494,-0.285760295,-0.329033628,-0.372803527,-0.416960496,-0.461402046,-0.506079352,-0.550959589,-0.596012058,-0.641196554,-0.686428389,-0.7316121,-0.776658427,-0.821486639,-0.86604414,-0.910288407,-0.954188159,-0.997700711,-1.04073065,-1.083175145,-1.12494851,-1.16598175,-1.206248783,-1.245730511,-1.284401833,-1.322222309,-1.35911024,-1.394980303,-1.429757641,-1.463384106,-1.495839109,-1.527106984,-1.557169943,-1.585997072,-1.613529906,-1.639696711,-1.664406959,-1.687601625,-1.709282576,-1.729457027,-1.74813003,-1.765282558,-1.780859427,-1.794803517,-1.807059467,-1.817581803,-1.826338197,-1.833321748,-1.838553517,-1.84204704,-1.843804633,-1.843792211,-1.841944468,-1.838249925,-1.832745295,-1.825473679,-1.816480633,-1.80579389,-1.793427007,-1.779377851,-1.763635502,-1.746202119,-1.727092459,-1.706365053,-1.68409811,-1.660337682,-1.635109964,-1.608412061,-1.580235053,-1.550616518,-1.519614761,-1.487298201,-1.453736585,-1.418986229,-1.383093725,-1.346079822,-1.307958645,-1.268751389,-1.228494188,-1.187278554,-1.145207708,-1.102372253,-1.058842387,-1.014624021,-0.969715571,-0.924141562,-0.877944757,-0.831209266,-0.78402377,-0.736464629,-0.688598276,-0.640468694,-0.592115358,-0.543576794,-0.494899106,-0.44614985,-0.397404684,-0.348751134,-0.300263472,-0.251976054,-0.203912713,-0.156086855,-0.10852055,-0.061262099,-0.014363334,0.032125377,0.078156936,0.123691932,0.168700214,0.213172016,0.257094806,0.300440905,0.343184169,0.385308604,0.426806622,0.467688543,0.507964995,0.547639562,0.58670484,0.625126162,0.662869708,0.699917607,0.73625826,0.771890291,0.806812245,0.841016494,0.874493663,0.907232597,0.939221704,0.970449152,1.000900762,1.030553985,1.059385444,1.087375959,1.114505087,1.140742981,1.166060005,1.190438161,1.213862209,1.236314756,1.257776959,1.278225832,1.297633722,1.315954517,1.333135258,1.349119955,1.363855799,1.377318038,1.389494105,1.400378159,1.409951801,1.418076094,1.424530067,1.428874321,1.430639695,1.430122786,1.428011813,1.424680913,1.420303899,1.414930331,1.408532526,1.401097839,1.392624121,1.383096477,1.37249209,1.360817791,1.348104446,1.334379409,1.319665819,1.303975728,1.287311211,1.269681735,1.251104507,1.231593603,1.211159378,1.189813449,1.167569322,1.144447977,1.120479517,1.095694423,1.07012312,1.043804911,1.016791552,0.989133975,0.960880318,0.932066647,0.902710394,0.872830775,0.842452803,0.811610204,0.780351071,0.748729377,0.716807246,0.684646888,0.652308948,0.619847393,0.587303161,0.554717634,0.522136376,0.489608502,0.457189654,0.42493216,0.392879086,0.361074674,0.329568768,0.298422805,0.267723596,0.237553106,0.207972891,0.179032244,0.150757817,0.123176972,0.096327221,0.07024757,0.044976913,0.020561135,-0.002936205,-0.025457777,-0.046969061,-0.067447519,-0.086892,-0.105291043,-0.122598499,-0.138774737,-0.15381041,-0.167694295,-0.180398536,-0.191902979,-0.202213255,-0.211335348,-0.219266207,-0.225994202,-0.231489991,-0.235734227,-0.238738505,-0.240530984,-0.241168554,-0.240696271,-0.239120849,-0.236449199,-0.232701902,-0.227904392,-0.222088868,-0.215295326,-0.207579507,-0.198992345,-0.189568766,-0.179341391,-0.168342673,-0.156609304,-0.144187581,-0.131137561,-0.117546956,-0.103496067,-0.089040512,-0.074222947,-0.059064807,-0.043593933,-0.027858432,-0.011911511,0.004188358,0.020386066,0.036635476,0.05290363,0.069183898,0.085468723,0.101740721,0.117966516,0.134080232,0.15002522,0.165775284,0.18132632,0.196714689,0.211966194,0.227069861,0.241999243,0.25670392,0.271133347,0.285244656,0.299017463,0.312482338,0.325666375,0.338570125,0.351176947,0.363437404,0.375304993,0.386753264,0.397767313,0.40835403,0.418526516,0.428305101,0.437708505,0.446747839,0.455425806,0.463725206,0.471637854,0.479191402,0.486426988,0.493406718,0.500187139,0.506796072,0.513247318,0.519527751,0.525622405,0.531527514,0.537247267,0.542804947,0.548221221,0.553493734,0.558608105,0.563524665,0.568203411,0.572624306,0.576775653,0.580660011,0.584271312,0.587555089,0.590442236,0.592853185,0.594707773,0.595934991,0.596475777,0.596313552,0.595435733,0.593792844,0.591320567,0.587934721,0.58354927,0.578099024,0.571531296,0.563824527,0.554976375,0.545033796,0.53411216,0.522618315,0.51106101};

#pragma mark - Initialization
-(id)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"-init is not a valid initializer for the class DirectionDetectionAlgo"
                                 userInfo:nil];
    return nil;
}

- (id) initWithDelegate:(id<DirectionDetectionDelegate>)delegate {
    
    
    self = [super init];
    self.dirDelegate = delegate;
    nextRefreshTime = CACurrentMediaTime();
    startLocated = false;
    
    for (int i = 0; i < TEETH_PR_REV; i++) {
//        compensation[i] = compensation[i]*(compensation2[i]/100+1)*(compensation3[i]/100+1);
//        compensation[i] = compensation[i]*(-compentationT1Ispo[i]/100+1);
    }
    
    
    float stdTickSize = 23.5;
    
    tickEdgeAngle[0] = 0;
    for (int i = 1; i < TEETH_PR_REV-1; i++) {
        tickEdgeAngle[i] = (int) (stdTickSize*i); // shift array one to the right
    }
    
    tickEdgeAngle[TEETH_PR_REV-1] = (int) (360-stdTickSize);
    
    for (int i = 0 ; i < TEETH_PR_REV; i++) {
        NSLog(@"angle:%d", tickEdgeAngle[i]);
    }
    
    
    
    
    return self;
    
    
}


- (void) newTick:(int)tickLength {
    
    // first try to locate the starting position (large tick)
    if (!startLocated) {
        [self locateStart:tickLength];
        lastTickLength = tickLength;
        return;
    }
    
    // check if new tick value is within 20% of expected value
    
    float tickLengthCompensated = tickLength * compensation[teethIndex];
    
    if (tickLengthCompensated > 0.8 * lastTickLengthCompensated && tickLengthCompensated < 1.2 * lastTickLengthCompensated) {
        
        [self processValidTick:tickLength];
        
    } else {
        
        NSLog(@"Out of ratio: %f", tickLengthCompensated / ((float) lastTickLengthCompensated));
        
        // reset buffers
        for (int i = 0; i < TEETH_PR_REV; i++) {
            tickLengthBuffer[i] = 0;
        }
        tickLengthOneRotation = 0;
        tickCounterSinceStart = 0;
        startLocated = false;
    }
    
    lastTickLengthCompensated = tickLengthCompensated;
    
}



- (void) processValidTick:(int)tickLength {
    
    tickCounterSinceStart ++;
    
    // update tickLenghtOneRotation
    
    // Moving Avg subtract
    tickLengthOneRotation -= tickLengthBuffer[teethIndex];
    
    // Moving avg Update buffer value
    tickLengthBuffer[teethIndex] = tickLength;
    
    // Moving Avg update SUM
    tickLengthOneRotation += tickLengthBuffer[teethIndex];
    
    if (tickCounterSinceStart > TEETH_PR_REV) {
        // calculate relative tick length
        float tickLengthRelative = tickLengthBuffer[teethProcessIndex] * TEETH_PR_REV / (float) tickLengthOneRotation;
        
        float a_smoothingFactor = 3 *  tickLengthBuffer[teethProcessIndex] * TEETH_PR_REV / (float) ( SMOOTHING_TIME_CONSTANT * SAMPLE_FREQUENCY);
        
        expTickLengthRelativePrTeeth[teethProcessIndex] = a_smoothingFactor * tickLengthRelative + (1 - a_smoothingFactor) * expTickLengthRelativePrTeeth[teethProcessIndex];
        
//        if (teethIndex == 0)
//            NSLog(@"expFilterTeeth0: %f, one rotation %i", expTickLengthRelativePrTeeth[teethProcessIndex], tickLengthOneRotation);
        
        // update results
        if (CACurrentMediaTime() > nextRefreshTime) {
            [self updateUI];
            [self updateNextRefreshTime];
        }
        
    }
    
    
    teethIndex++;
    if (teethIndex == TEETH_PR_REV) {
        teethIndex = 0;
    }
    teethProcessIndex++;
    if (teethProcessIndex == TEETH_PR_REV) {
        teethProcessIndex = 0;
    }
    
    
}




- (void) locateStart:(int)samples{
    
    NSLog(@"Trying to locate start: Ratio: %f, StartCounter: %d", samples / ((float) lastTickLength), startCounter);
    
    if (samples > 1.2 * lastTickLength && samples < 1.4 * lastTickLength) {
        
        if (startCounter == 2* TEETH_PR_REV) {
            startLocated = true;
            lastTickLengthCompensated = samples * compensation[TEETH_PR_REV-1];
            NSLog(@"StartLocated: Ratio: %f, StartCounter: %d", samples / ((float) lastTickLength), startCounter);
            startCounter = 0;
            teethIndex = 0;
            teethProcessIndex = 2; //asdasd
        }
        
        if (startCounter % TEETH_PR_REV != 0 || startCounter > 2 * TEETH_PR_REV) {
            startCounter = 0;
        }
        
    }
    
    startCounter++;
    
}


- (void) updateNextRefreshTime {
    if (nextRefreshTime - UPDATE_INTERVAL < CACurrentMediaTime()) {
        nextRefreshTime = CACurrentMediaTime() + UPDATE_INTERVAL;
    }
    else {
        nextRefreshTime += UPDATE_INTERVAL;
    }
}





- (void) updateUI {
    
    float tickLengthRelativePrTeethCompensated[TEETH_PR_REV];
    
    // wrap tickLengthRelativePrTeethCompensated in Array
    NSMutableArray *angularVelocities = [[NSMutableArray alloc] initWithCapacity:TEETH_PR_REV];
    
    for (int i = 0; i < TEETH_PR_REV; i++) {
        tickLengthRelativePrTeethCompensated[i] = (expTickLengthRelativePrTeeth[i] * compensation[i] -1) * (-100); // - compensationS12[i]; // - compentationT1Ispo[i];
        [angularVelocities addObject: [NSNumber numberWithFloat: tickLengthRelativePrTeethCompensated[i]]];
    }
    
    // Calculate velocity for last revolution

    float windSpeed = 44100 / ((float)tickLengthOneRotation);
    
    [self iterateAngle: (float *) tickLengthRelativePrTeethCompensated];
    
    
    // See the Thread Safety warning above, but in a nutshell these callbacks happen on a separate audio thread. We wrap any UI updating in a GCD block on the main thread to avoid blocking that audio flow.
    dispatch_async(dispatch_get_main_queue(),^{
        [self.dirDelegate newWindAngleLocal:[NSNumber numberWithFloat:angleEstimator]];
        [self.dirDelegate newAngularVelocities: angularVelocities];
        [self.dirDelegate newSpeed: [NSNumber numberWithFloat:windSpeed]];
    });
    
}


- (void) iterateAngle: (float *) mvgRelativeSpeedPercent {
    
       // SMALL NOTICE (ANGLES IN USE ARE EDGE ANGLES, MIGHT BE BETTER TO CALCULATE EXCATE ANGLES!)
    
    if (iteratorAngleCounter == 5) {
        [self checkOppositeAngle: mvgRelativeSpeedPercent];
        iteratorAngleCounter = 0;
    }
    
    int angleLow = (angleEstimator - ANGLE_DIFF);
    int angleHigh = (angleEstimator + ANGLE_DIFF);
    
    if (angleLow < 0)
        angleLow += 360;
    
    if (angleHigh > 360)
        angleHigh -= 360;
    
    float angleLowSum = 0.0;
    float angleHighSum = 0.0;
    
    for (int i = 0; i < TEETH_PR_REV; i++) {  //NOW uses all points //starts at 1 and ends before last tick, to avoid errors based on these two.
        
        int signalExpectedIndexLow = tickEdgeAngle[i] - angleLow;
        if (signalExpectedIndexLow < 0)
            signalExpectedIndexLow += 360;
        
        int signalExpectedIndexHigh = tickEdgeAngle[i] - angleHigh;
        if (signalExpectedIndexHigh < 0)
            signalExpectedIndexHigh += 360;
        
        angleLowSum += powf(fitcurve[signalExpectedIndexLow]-mvgRelativeSpeedPercent[i], 2.0);
        angleHighSum += powf(fitcurve[signalExpectedIndexHigh]-mvgRelativeSpeedPercent[i], 2.0);
    }
        
    float angleHLDiff = (angleLowSum - angleHighSum)/ (float) TEETH_PR_REV;
    angleEstimator += angleHLDiff * (ANGLE_CORRRECTION_COEFFICIENT);
    
    if (angleEstimator < 0)
        angleEstimator += 360;
    
    if (angleEstimator > 360)
        angleEstimator -= 360;
    
    iteratorAngleCounter++;
    
}


- (void) checkOppositeAngle: (float *) mvgRelativeSpeedPercent {
    
    // SMALL NOTICE (ANGLES IN USE ARE EDGE ANGLES, MIGHT BE BETTER TO CALCULATE EXCATE ANGLES!)
    
    int angleLow = (angleEstimator);
    int angleHigh = (angleEstimator + 180);
    
    if (angleLow < 0)
        angleLow += 360;
    
    if (angleHigh > 360)
        angleHigh -= 360;
    
    float angleLowSum = 0.0;
    float angleHighSum = 0.0;
    
    for (int i = 0; i < TEETH_PR_REV; i++) {
    //for (int i = 0; i < TEETH_PR_REV; i++) {
        
        int signalExpectedIndexLow = tickEdgeAngle[i] - angleLow;
        if (signalExpectedIndexLow < 0)
            signalExpectedIndexLow += 360;
        
        int signalExpectedIndexHigh = tickEdgeAngle[i] - angleHigh;
        if (signalExpectedIndexHigh < 0)
            signalExpectedIndexHigh += 360;
        
        angleLowSum += powf(fitcurve[signalExpectedIndexLow]-mvgRelativeSpeedPercent[i], 2.0);
        angleHighSum += powf(fitcurve[signalExpectedIndexHigh]-mvgRelativeSpeedPercent[i], 2.0);
    }

    if (angleLowSum > angleHighSum) {
        angleEstimator += 180;
    }
    
    if (angleEstimator > 360)
        angleEstimator -= 360;
    
}



//- (float) correctAngle:(float) angle {
//    if (angle < 0) {
//        angle += 360;
//    }
//    else if (angle > 360) {
//        angle -= 360;
//    }
//    return angle;
//}

+ (float *) getFitCurve {
    return fitcurve;
}

- (int *) getEdgeAngles {
    return tickEdgeAngle;
}

@end
