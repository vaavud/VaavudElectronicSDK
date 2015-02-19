//
//  EZMicrophone+VESDK.h
//  VaavudElectronicSDK
//
//  Created by Andreas Okholm on 16/02/15.
//  Copyright (c) 2015 Vaavud. All rights reserved.
//

#import "EZMicrophone.h"

@interface EZMicrophone (VESDK)

-(void)_configureStreamFormatWithSampleRate:(Float64)sampleRate;

@end
