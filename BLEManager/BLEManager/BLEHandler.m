//
//  BLEHandler.m
//  BLEManager
//
//  Created by Kenji on 1/3/15.
//  Copyright (c) 2015 Kenji. All rights reserved.
//

#import "BLEHandler.h"

@implementation BLEHandler

// 1. called whenever the device state changes
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    // Determine the state of the peripheral
    if ([central state] == CBCentralManagerStatePoweredOff) {
        // all peripheral objects that have been obtained from the central
        // become invalid and must be re-discover
        NSLog(@"BLESCAN: CoreBluetooth BLE hardware is powered off");
    }
    else if ([central state] == CBCentralManagerStatePoweredOn) {
        NSLog(@"BLESCAN: CoreBluetooth BLE hardware is powered on and ready");
    }
    else if ([central state] == CBCentralManagerStateUnauthorized) {
        NSLog(@"BLESCAN: CoreBluetooth BLE state is unauthorized");
    }
    else if ([central state] == CBCentralManagerStateUnknown) {
        NSLog(@"BLESCAN: CoreBluetooth BLE state is unknown");
    }
    else if ([central state] == CBCentralManagerStateUnsupported) {
        NSLog(@"BLESCAN: CoreBluetooth BLE hardware is unsupported on this platform");
    }
}

// 2. called with the CBPeripheral class as uts main input paramenter.
// this contains most of the information there is know about a BLE peripheral
// RSSI stands for Received Signal Strength Indicator
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    NSString *localName = [advertisementData objectForKey:CBAdvertisementDataLocalNameKey];
    if ([localName length] > 0) {
        NSLog(@"BLESCAN: found a bluetooth device name: %@", localName);
    } else {
        NSLog(@"BLESCAN: found a bluetooth device name: UNKNOWN");
    }
}

// called when have successfully connected to the BLE peripheral
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"BLESCAN: connected to device");
}

@end
