//
//  BLEHandler.m
//  BLEManager
//
//  Created by Kenji on 1/3/15.
//  Copyright (c) 2015 Kenji. All rights reserved.
//

#import "BLEHandler.h"

@interface BLEHandler() {
    
    BOOL _isScanning;
    CBCentralManager *_centralManager;
    
    CLLocationManager *_locManager;
    CLBeaconRegion *_locRegion;
}

@property (strong) CBPeripheral     *connectingPeripheral;

@end

@implementation BLEHandler

- (id)init {
    self = [super init];
    if (self) {
//        dispatch_queue_t centralQueue = dispatch_queue_create("com.yo.mycentral", DISPATCH_QUEUE_SERIAL);
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        
//        _locManager = [[CLLocationManager alloc] init];
//        _locManager.delegate = self;
//        NSUUID *proximityUUID = [[NSUUID alloc] initWithUUIDString:@"B9407F30-F5F8-466E-AFF9-25556B57FE6D"];
//        _locRegion = [[CLBeaconRegion alloc] initWithProximityUUID:proximityUUID identifier:@"Estimote Region"];
//        [_locManager startMonitoringForRegion:_locRegion];
        
        [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(scheduleScan) userInfo:nil repeats:YES];
    }
    return self;
}

- (void)scheduleScan {
    NSLog(@"BLESCAN: scheduleScan");
    _isScanning = !_isScanning;
    if (_isScanning) {
        [_centralManager stopScan];
    }
    else {
        [_centralManager scanForPeripheralsWithServices:nil options:nil];
    }
}

#pragma mark - Bluetooth Manager

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
//        NSDictionary *options = @{CBCentralManagerScanOptionAllowDuplicatesKey:@(NO)};
//        NSUUID *proximityUUID = [[NSUUID alloc] initWithUUIDString:@"B9407F30-F5F8-466E-AFF9-25556B57FE6D"];
//        NSArray *services = @[[CBUUID UUIDWithString:@"180A"]];
//        [_centralManager scanForPeripheralsWithServices:nil options:nil];
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
        NSLog(@"BLESCAN: discover: %@", localName);
//        if (self.tweak != nil && [self.tweak respondsToSelector:@selector(beaconDiscover:)]) {
//            [self.tweak performSelector:@selector(beaconDiscover:) withObject:nil];
//        }
        NSLog(@"BLESCAN: found a bluetooth device name: %@", localName);
        if ([localName isEqualToString:@"estimote"]) {
//            NSTimeInterval timestamp = [[NSDate date] timeIntervalSinceDate:_timeScan];
            NSLog(@"DeviceId: %@ - RSSI: %f", [peripheral.identifier UUIDString], [RSSI floatValue]);
        }
    } else {
//        NSLog(@"BLESCAN: found a bluetooth device name: UNKNOWN");
    }
}

// called when have successfully connected to the BLE peripheral
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
//    NSLog(@"BLESCAN: connected to device");
}

#pragma mark - Location

- (void) locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region
{
    [_locManager requestStateForRegion:_locRegion];
}

- (void) locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region
{
    switch (state) {
        case CLRegionStateInside:
            [_locManager startRangingBeaconsInRegion:_locRegion];
            
            break;
        case CLRegionStateOutside:
        case CLRegionStateUnknown:
        default:
            // stop ranging beacons, etc
            NSLog(@"Region unknown");
    }
}

- (void) locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
    if ([beacons count] > 0) {
        // Handle your found beacons here
    }
}

@end
