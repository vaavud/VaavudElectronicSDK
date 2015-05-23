//
//  VEVolumeReponse.h
//  VaavudElectronicSDK
//
//  Created by Andreas Okholm on 17/05/15.
//  Copyright (c) 2015 Vaavud. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VEVolumeReponse : NSObject
@property float volume;
@property int diffMax;
@property int diffMin;
@property int diffAvg;
@property int mvgMax;
@property int mvgMin;
@property int mvgAvg;
@property int diff10;
@property int diff20;
@property int diff30;
@property int diff40;
@property int diff50;
@property int diff60;
@property int diff70;
@property int diff80;
@property int diff90;
@property int ticks;
@end
