//
//  BLEHandler.h
//  BLEManager
//
//  Created by Kenji on 1/3/15.
//  Copyright (c) 2015 Kenji. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreLocation/CoreLocation.h>

@interface BLEHandler : NSObject<CBCentralManagerDelegate, CLLocationManagerDelegate>

@property (nonatomic, weak) id tweak;

@end
