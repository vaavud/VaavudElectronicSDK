//
//  DirectionDetectionAlgo.m
//  VaavudElectronicsTest
//
//  Created by Andreas Okholm on 11/06/14.
//  Copyright (c) 2014 Vaavud. All rights reserved.
//

#import "VEDirectionDetectionAlgo.h"
#define TEETH_PR_REV 15
#define SAMPLE_BUFFER_SIZE 40
#define UPDATE_INTERVAL 0.2 // 5 times a second
#define ANGLE_CORRRECTION_COEFFICIENT 100 // originally 400 (but since actual velocity difference is about double...
#define ANGLE_DIFF 1
#define SMOOTHING_TIME_CONSTANT 4
#define SMOOTHING_TIME_CONSTANT_CALIBRATION 12
#define SAMPLE_FREQUENCY 44100
#define REQUIRED_CALIBRATION_TICKS 1500


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
    int tickLengthOneRotationLast;
    float expTickLengthRelativePrTeeth[TEETH_PR_REV];
    
    double nextRefreshTime;
    
    BOOL startLocated;
    BOOL initializeExponentialFilter;
    int lastTickLength;
    float lastTickLengthCompensated;
    int tickEdgeAngle[TEETH_PR_REV]; // add one point in ether end
    float angleEstimator;
    
    int iteratorAngleCounter;
    
    BOOL calibrationMode;
    int calibrationTickSlowdownCounter;
    int calibrationTickCounter;
    int tickDetectionErrorCount;
}

@property (strong, nonatomic) id<DirectionDetectionDelegate> dirDelegate;

@end


@implementation VEDirectionDetectionAlgo


float compensation[TEETH_PR_REV] = {1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,1.02127659574468,0.774193548387097};

float fitcurve[360]  = {1.93055056304272,1.92754159835895,1.92282438491601,1.91642240663535,1.90836180821769,1.89867136590046,1.88738243346175,1.87452883370120,1.86014676759279,1.84427478518094,1.82695377850290,1.80822697586826,1.78813992874676,1.76674047747091,1.74407866757061,1.72020656030400,1.69517800715690,1.66904843699963,1.64187464950645,1.61371462647876,1.58462740924956,1.55467305246007,1.52391260026944,1.49240801962532,1.46022202221808,1.42741784194637,1.39405900931661,1.36020913199620,1.32593169153717,1.29128981914961,1.25634600129292,1.22116175831135,1.18579734303049,1.15031150113437,1.11476127584804,1.07920182312177,1.04368623722990,1.00826539680125,0.972987817770956,0.937899532389511,0.903043996582429,0.868462039649354,0.834191843341422,0.800268955749256,0.766726343538812,0.733594507605786,0.700901592353379,0.668673415622578,0.636933467547068,0.605702923030820,0.575000695079098,0.544843511789263,0.515245997694165,0.486220761974393,0.457778504155552,0.429928136760471,0.402676934592876,0.376030705291920,0.349993988555626,0.324570272343151,0.299762224554410,0.275571929569200,0.252001097395764,0.229051207572156,0.206723638918024,0.185019804046930,0.163941295536526,0.143490058746097,0.123668551764306,0.104479853075893,0.0859277278556616,0.0680166393704737,0.0507517558714560,0.0341389996545297,0.0181851042532520,0.00289764968455452,-0.0117149087765697,-0.0256432058939759,-0.0388769297985376,-0.0514047989025574,-0.0632145881998666,-0.0742932098523405,-0.0846268105605133,-0.0942008705954160,-0.103000306115350,-0.111009589516615,-0.118212913029394,-0.124594370818823,-0.130138144991804,-0.134828678151935,-0.138650863623146,-0.141589940836392,-0.143631982613669,-0.144763880519847,-0.144973663286989,-0.144250763791977,-0.142586242357516,-0.139972901415060,-0.136405374393993,-0.131880243512971,-0.126396155480609,-0.119953903391895,-0.112556485929105,-0.104209142607944,-0.0949193873907413,-0.0846970613071941,-0.0735543869171775,-0.0615060081531991,-0.0485690247473594,-0.0347630384066071,-0.0201102291169421,-0.00463544268113327,0.0116337222903312,0.0286668458970663,0.0464306654552773,0.0648890733800766,0.0840031184656525,0.103731019912623,0.124028212339776,0.144847424043910,0.166138809986866,0.187850105743243,0.209926771139125,0.232312099871980,0.254947302034379,0.277771580177066,0.300722214300621,0.323734675998779,0.346742778934413,0.369678866423019,0.392474005660318,0.415058168415599,0.437360424725763,0.459309184877691,0.480832480534593,0.501858298006565,0.522314926262134,0.542131291505136,0.561237285624209,0.579564080503314,0.597044401632675,0.613612772959745,0.629205754062743,0.643762145476949,0.657223114636108,0.669532313041451,0.680636049606467,0.690483471159853,0.699026703209735,0.706220954402490,0.712024568042803,0.716399053179197,0.719309119720656,0.720722727690873,0.720611146548223,0.718949016219273,0.715714393715594,0.710888767907992,0.704457075805069,0.696407729977473,0.686732645873142,0.675427261400450,0.662490538243213,0.647924923861272,0.631736296292326,0.613933903685354,0.594530298066370,0.573541258916757,0.550985712714184,0.526885650621979,0.501266033241476,0.474154669767433,0.445582087732282,0.415581407568944,0.384188230396930,0.351440532507190,0.317378563602313,0.282044739176431,0.245483514902245,0.207741270922022,0.168866239711485,0.128908451253386,0.0879196798867660,0.0459533973687714,0.00306473704801602,-0.0406895385539698,-0.0852510874443092,-0.130560085653262,-0.176555352635537,-0.223174483926726,-0.270354003694408,-0.318029564779040,-0.366136150084997,-0.414608230085121,-0.463379905156156,-0.512385053863697,-0.561557494697062,-0.610831175836623,-0.660140375852816,-0.709419902462159,-0.758605275138057,-0.807632877266797,-0.856440096451739,-0.904965450293262,-0.953148676657088,-1.00093081662756,-1.04825431459765,-1.09506313749468,-1.14130292468632,-1.18692112548173,-1.23186707424668,-1.27609204040434,-1.31954926810789,-1.36219398618314,-1.40398339226546,-1.44487663036859,-1.48483477692865,-1.52382083785846,-1.56179973308302,-1.59873829611478,-1.63460528731700,-1.66937141578467,-1.70300935345337,-1.73549372023954,-1.76680103882706,-1.79690964091476,-1.82579956937042,-1.85345251794598,-1.87985178650518,-1.90498224798798,-1.92883034611430,-1.95138411094696,-1.97263317597833,-1.99256875417214,-2.01118351063343,-2.02847142222021,-2.04442770651076,-2.05904876934359,-2.07233212953319,-2.08427634067406,-2.09488092934612,-2.10414633918689,-2.11207385653047,-2.11866550063715,-2.12392392855818,-2.12785235294625,-2.13045446941802,-2.13173440166218,-2.13169662774024,-2.13034586385060,-2.12768694358104,-2.12372472526967,-2.11846404796602,-2.11190978398746,-2.10406693046473,-2.09494070314769,-2.08453657856423,-2.07286020228535,-2.05991724573168,-2.04571329439890,-2.03025381011404,-2.01354409660671,-1.99558925551097,-1.97639417257405,-1.95596358148356,-1.93430215219623,-1.91141456498716,-1.88730558353145,-1.86198014106267,-1.83544343461144,-1.80770102675171,-1.77875894897603,-1.74862377338231,-1.71730261999106,-1.68480317756577,-1.65113374186939,-1.61630326967538,-1.58032147957387,-1.54319899451728,-1.50494750075179,-1.46557986180280,-1.42511011063198,-1.38355342912957,-1.34092621637585,-1.29724617853082,-1.25253238496823,-1.20680533995027,-1.16008712948684,-1.11240159666417,-1.06377448238627,-1.01423346987064,-0.963808178076644,-0.912530147553338,-0.860432823915887,-0.807551534849895,-0.753923437647436,-0.699587397418073,-0.644583841616784,-0.588954623685606,-0.532742913754490,-0.475993148906732,-0.418751007243797,-0.361063391962615,-0.302978414524606,-0.244545320336948,-0.185814388853583,-0.126836850407010,-0.0676648561212342,-0.00835148845376236,0.0510492170666441,0.110482255689112,0.169891654855290,0.229220498160153,0.288410989747835,0.347404532745552,0.406141804216642,0.464562841859978,0.522607165069588,0.580213909827325,0.637321971379807,0.693870171239719,0.749797447763799,0.805043053132515,0.859546740347051,0.913248923637761,0.966090812760156,1.01801450649125,1.06896306768950,1.11888059184822,1.16771228860579,1.21540460253994,1.26190534933332,1.30716384843168,1.35113103633228,1.39375955096661,1.43500380728303,1.47482010511715,1.51316681498404,1.55000456748550,1.58529639518708,1.61900783540342,1.65110697646223,1.68156447603108,1.71035356279630,1.73745001850842,1.76283212588682,1.78648061977600,1.80837868058991,1.82851194497160,1.84686852509262,1.86343902222370,1.87821647622575,1.89119628770111,1.90237616864563,1.91175616824101,1.91933872768542,1.92512873506254,1.92913358874019,1.93136328313521,1.93183048501708};


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
    initializeExponentialFilter = true;
    
    calibrationMode = false;
    
    
    float stdTickSize = 23.5;
    
    tickEdgeAngle[0] = 0;
    for (int i = 1; i < TEETH_PR_REV-1; i++) {
        tickEdgeAngle[i] = (int) (stdTickSize*i); // shift array one to the right
    }
    
    tickEdgeAngle[TEETH_PR_REV-1] = (int) (360-stdTickSize);
    
   
    return self;
}


- (BOOL) newTick:(int)tickLength {
    
//    NSLog(@"tick Length: %i", tickLength);
    
    // first try to locate the starting position (large tick)
    if (!startLocated) {
        [self locateStart:tickLength];
        lastTickLength = tickLength;
        return NO;
    }
    
    // check if new tick value is within 20% of expected value
    
    float tickLengthCompensated = tickLength * compensation[teethIndex];
    
    if (tickLengthCompensated > 0.8 * lastTickLengthCompensated && tickLengthCompensated < 1.2 * lastTickLengthCompensated) {
        
        [self processValidTick:tickLength];
        
    } else {
        
        NSLog(@"Out of ratio: %f, teeth: %03d, ticks: %03d, tickLength: %03d", tickLengthCompensated / ((float) lastTickLengthCompensated), teethIndex, tickCounterSinceStart, tickLength);
        [self resetDirectionAlgorithm];
        
        tickDetectionErrorCount++;
        dispatch_async(dispatch_get_main_queue(),^{
            [self.dirDelegate newTickDetectionErrorCount:[NSNumber numberWithInteger:tickDetectionErrorCount]];
        });
        
        
    }
    
    lastTickLengthCompensated = tickLengthCompensated;
    
    if (teethIndex == TEETH_PR_REV-1) {
        return YES;
    } else {
        return NO;
    }
    
}

- (void) resetDirectionAlgorithm {
    // reset buffers
    for (int i = 0; i < TEETH_PR_REV; i++) {
        tickLengthBuffer[i] = 0;
    }
    tickLengthOneRotation = 0;
    tickLengthOneRotationLast = 0;
    tickCounterSinceStart = 0;
    startLocated = false;
    initializeExponentialFilter = false;
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
    
    
    if (calibrationMode) {
        
        
        if (tickLengthOneRotation > tickLengthOneRotationLast) {
            calibrationTickSlowdownCounter++;
        } else {
            calibrationTickSlowdownCounter = 0;
        }
        
        if (calibrationTickSlowdownCounter > 200 && tickLengthOneRotation > 750 && initializeExponentialFilter) {
            [self initializeExponentialFilter];
            initializeExponentialFilter = false;
        }
        
        if (!(initializeExponentialFilter) && tickLengthOneRotation < 15000 && calibrationTickSlowdownCounter > 200 && tickLengthOneRotation > 750) {
            [self updateExponentialFilter];
            calibrationTickCounter++;
            
            if (calibrationTickCounter == REQUIRED_CALIBRATION_TICKS) {
                [self endCalibration];
                dispatch_async(dispatch_get_main_queue(),^{
                    [self.dirDelegate calibrationPercentageComplete: [NSNumber numberWithFloat: calibrationTickCounter / (float) REQUIRED_CALIBRATION_TICKS]];
                });
            }
            
            // update results
            if (CACurrentMediaTime() > nextRefreshTime) {
                [self updateUI];
                [self updateNextRefreshTime];
                
                dispatch_async(dispatch_get_main_queue(),^{
                    [self.dirDelegate calibrationPercentageComplete: [NSNumber numberWithFloat: calibrationTickCounter / (float) REQUIRED_CALIBRATION_TICKS]];
                });
            }

        }

    } else {
        
        // initialize coefficients  Stuff
        if (tickCounterSinceStart == TEETH_PR_REV && initializeExponentialFilter) {
            [self initializeExponentialFilter];
        }
        
        if (tickCounterSinceStart > TEETH_PR_REV) {
            
            [self updateExponentialFilter];
            
            // update results
            if (CACurrentMediaTime() > nextRefreshTime) {
                [self updateUI];
                [self updateNextRefreshTime];
            }
            
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
    
    tickLengthOneRotationLast = tickLengthOneRotation;
}

- (void) initializeExponentialFilter {
    for (int i=0; i< TEETH_PR_REV; i++) {
        expTickLengthRelativePrTeeth[i] = tickLengthBuffer[i] * TEETH_PR_REV / (float) tickLengthOneRotation;
    }
}

- (void) updateExponentialFilter {
    // calculate relative tick length
    float tickLengthRelative = tickLengthBuffer[teethProcessIndex] * TEETH_PR_REV / (float) tickLengthOneRotation;
    
    float a_smoothingFactor;
    if (calibrationMode) {
        a_smoothingFactor =  3 *  tickLengthBuffer[teethProcessIndex] * TEETH_PR_REV / (float) ( SMOOTHING_TIME_CONSTANT_CALIBRATION * SAMPLE_FREQUENCY);
    } else {
        a_smoothingFactor =  3 *  tickLengthBuffer[teethProcessIndex] * TEETH_PR_REV / (float) ( SMOOTHING_TIME_CONSTANT * SAMPLE_FREQUENCY);
    }
    
    
    expTickLengthRelativePrTeeth[teethProcessIndex] = a_smoothingFactor * tickLengthRelative + (1 - a_smoothingFactor) * expTickLengthRelativePrTeeth[teethProcessIndex];
}



- (void) locateStart:(int)samples{
    
//    NSLog(@"Trying to locate start: Ratio: %f, StartCounter: %d", samples / ((float) lastTickLength), startCounter);
    
    if (samples > 1.2 * lastTickLength && samples < 1.4 * lastTickLength) {
        
        if (startCounter == 2* TEETH_PR_REV) {
            startLocated = true;
            lastTickLengthCompensated = samples * compensation[TEETH_PR_REV-1];
            NSLog(@"Start: Ratio: %f", samples / ((float) lastTickLength));
            startCounter = 0;
            teethIndex = 0;
            teethProcessIndex = TEETH_PR_REV/2; // should be 7 for 15 teeth
        }
        
        if (startCounter % TEETH_PR_REV != 0) {
            startCounter = 0;
        }
        
    }
    
    if (startCounter > 2 * TEETH_PR_REV) {
        startCounter = 0;
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
    
    int angleLow = (int) lroundf(angleEstimator -0.5);
    int angleHigh = angleLow+1;
    
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
    
//    NSLog(@"AngleRMS(left): %f and diff: %f", angleLowSum, angleHLDiff*ANGLE_CORRRECTION_COEFFICIENT);
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



+ (float *) getFitCurve {
    return fitcurve;
}

- (int *) getEdgeAngles {
    return tickEdgeAngle;
}



// start calibration mode
-(void) startCalibration {
    calibrationMode = true;
    [self resetDirectionAlgorithm];
    calibrationTickCounter = 0;
    initializeExponentialFilter = true;
    
}

// end calibbration mode
-(void) endCalibration {
    calibrationMode = false;
    
    float compensationSum = 0;
    
    for (int i = 0; i < TEETH_PR_REV; i++) {
        compensationSum = compensationSum + 1/expTickLengthRelativePrTeeth[i];
    }
    
    float compensationAdjust = (compensationSum - TEETH_PR_REV) / TEETH_PR_REV;
    
    
    for (int i = 0; i < TEETH_PR_REV; i++) {
        compensation[i] = 1/expTickLengthRelativePrTeeth[i] - compensationAdjust;
    }
    
    [self resetDirectionAlgorithm];
    initializeExponentialFilter = true;
}

@end
