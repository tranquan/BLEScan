//
//  BLEScanVC.m
//  BLEManager
//
//  Created by Kenji on 21/4/15.
//  Copyright (c) 2015 Kenji. All rights reserved.
//
//  This ViewController is for run scan as a foreground app, BackgroundManager Tweak required

#import "BLEScanVC.h"
#import <CoreBluetooth/CoreBluetooth.h>

//#define DEBUG_MODE

#ifdef DEBUG_MODE
#   define DLog(fmt, ...) NSLog((@"%s", fmt), __PRETTY_FUNCTION__, ##__VA_ARGS__)
#else
#   define DLog(...)
#endif

static NSDateFormatter *DateFormatter;

@interface BLEScanVC () <UITextFieldDelegate, CBCentralManagerDelegate> {
    
    int _isRunning;
    float _interval;
    float _duty;
    float _dutyTime;
    float _sleepTime;
    BOOL _isScanAllInterval;        // YES: don't idle, scan whole time. NO: scan & idle
    BOOL _isScanBeaconsMode;        // YES: scan for detect beacons, not log battery. NO: scan & log battery changes
    BOOL _isScanDuplicateBeacons;   // YES: log for duplicate beacons. NO: not allow duplicate until scan complete
    
    float _batteryDropToStop;
    float _batteryAtStart;
    float _currBatteryLevel;
    float _prevBatteryLevel;
    
    int _startPendings;
    int _stopPendings;
    
    NSDate *_startTime;
    NSDate *_stopTime;
    NSString *_logFilePath;
    
    NSTimer *_updateTimer;
    NSDate *_timeScan;
    
    NSMutableDictionary *_beaconsCached;
}

@property (nonatomic, strong) CBCentralManager *bleManager;

@end

@implementation BLEScanVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _interval = 0;
    _duty = 0;
    _dutyTime = 0;
    _sleepTime = 0;
    _beaconsCached = [[NSMutableDictionary alloc] init];
    
    if (DateFormatter == nil) {
        DateFormatter = [[NSDateFormatter alloc] init];
        [DateFormatter setDateFormat:@"dd/MM/yyyy-HH:mm:ss"];
    }
    
    dispatch_queue_t queue = dispatch_queue_create("com.kenji.blescan", NULL);
    self.bleManager = [[CBCentralManager alloc] initWithDelegate:self queue:queue];
    
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    [self.view addGestureRecognizer:tapGesture];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self updateSwitchesUI];
    
    // update battery level
    float battery = [[UIDevice currentDevice] batteryLevel] * 100;
    if (battery < 0) {
        self.lblBatteryLevel.text = [NSString stringWithFormat:@"Battery Level: unknown"];
    } else {
        self.lblBatteryLevel.text = [NSString stringWithFormat:@"Battery Level: %.2f%%", battery];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)handleTapGesture:(UITapGestureRecognizer *)gesture {
    if (self.tfInterval.isFirstResponder) {
        [self.tfInterval resignFirstResponder];
    }
    if (self.tfDuty.isFirstResponder) {
        [self.tfDuty resignFirstResponder];
    }
}

#pragma mark - Actions

- (IBAction)btnStartStopTapped:(id)sender {
    
    if (_isRunning == 0) {
        _isRunning = 1;
        _startTime = [NSDate date];
        
        _interval = [self.tfInterval.text floatValue];
        _duty = [self.tfDuty.text floatValue];
        _batteryDropToStop = [self.tfBatteryStop.text floatValue];
        _dutyTime = (_duty / 100.0) * _interval;
        _sleepTime = _interval - _dutyTime;
        
        _isScanAllInterval = self.switchScanWholeInterval.isOn;
        _isScanBeaconsMode = self.switchScanBeaconsMode.isOn;
        _isScanDuplicateBeacons = self.switchScanDuplicateBeacons.isOn;
        
        if (_dutyTime <= 0 || _sleepTime <= 0) {
            [[[UIAlertView alloc] initWithTitle:@"Alert" message:@"Cannot start scan with this config\nScan time must be >= 0" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            return;
        }
        
        [self.tfInterval resignFirstResponder];
        [self.tfDuty resignFirstResponder];
        [self.tfBatteryStop resignFirstResponder];
        
        CGFloat battery = [[UIDevice currentDevice] batteryLevel] * 100;
        _batteryAtStart = battery;
        _currBatteryLevel = battery;
        _prevBatteryLevel = battery + 1.0;
        
        [self myOpenLogFile];
        [self myBLEStartScan];
        
        [self.lblScanStatus setText:@"scanning..."];
        [self.btnStartStop setTitle:@"Stop" forState:UIControlStateNormal];
        
        // monitor battery drop to stop scaning process
        [self performSelector:@selector(myBatteryMonitor) withObject:nil afterDelay:1];
    }
    else {
        _isRunning = 0;
        _stopTime = [NSDate date];
        
        [self.tfInterval resignFirstResponder];
        [self.tfDuty resignFirstResponder];
        [self.tfBatteryStop resignFirstResponder];
        
        [self myCloseLogFile];
        [self myBLEStopScan];
        
        [self.lblScanStatus setText:@"stop"];
        [self.btnStartStop setTitle:@"Start" forState:UIControlStateNormal];
    }
}

- (IBAction)switchingScanWholeInterval:(id)sender {
    [self updateSwitchesUI];
}

- (IBAction)switchingScanBeaconsMode:(id)sender {
    [self updateSwitchesUI];
}

- (IBAction)switchingScanDuplicateBeacons:(id)sender {
    [self updateSwitchesUI];
}

- (void)updateSwitchesUI {
    _isScanAllInterval = self.switchScanWholeInterval.isOn;
    self.lblScanWholeInterval.text = _isScanAllInterval ? @"Scan 100% Interval" : @"Scan & Idle";
    _isScanBeaconsMode = self.switchScanBeaconsMode.isOn;
    self.lblScanBeaconsMode.text = _isScanBeaconsMode ? @"Scan & Logging Beacons" : @"Scan & log Battery";
    _isScanDuplicateBeacons = self.switchScanDuplicateBeacons.isOn;
    self.lblScanDuplicateBeacons.text = _isScanDuplicateBeacons ? @"Scan Duplicate Beacons" : @"Scan Each Beacon Once";
}

#pragma mark - Helpers

- (void)myBLEStartScan {
    
    if (_startPendings > 0) {
        _startPendings--;
    }
    if (_isRunning == 0) {
        return;
    }
    
    NSString *curtime = [DateFormatter stringFromDate:[NSDate date]];
    CGFloat battery = [[UIDevice currentDevice] batteryLevel] * 100;
    
    // log scan time
    if (_isScanBeaconsMode == false) {
        _currBatteryLevel = battery;
        if (fabsf(_prevBatteryLevel - _currBatteryLevel) >= 1.0) {
            _prevBatteryLevel = _currBatteryLevel;
            NSString *logText = [NSString stringWithFormat:@"%@, %.2f\n", curtime, _currBatteryLevel];
            [self myWriteLogToFile:logText];
        }
    }
    
    // do scan
    DLog(@"start bluetooth scan at time: %@ with battery level: %f", curtime, battery);
    if (_dutyTime > 1.0 && _sleepTime > 1.0) {
        [self.lblScanStatus setText:@"scanning..."];
    }
    _timeScan = [NSDate date];
    if (_isScanDuplicateBeacons) {
        NSDictionary *options = @{CBCentralManagerScanOptionAllowDuplicatesKey : @(YES)};
        [self.bleManager scanForPeripheralsWithServices:nil options:options];
    } else {
        [self.bleManager scanForPeripheralsWithServices:nil options:nil];
    }
    
    // pending stop if needed in idle mode
    if (_isScanAllInterval == false) {
        if (_stopPendings == 0) {
            _stopPendings++;
            [self performSelector:@selector(myBLEStopScan) withObject:nil afterDelay:_dutyTime];
        }
    }
}

- (void)myBLEStopScan {
    
    if (_stopPendings > 0) {
        _stopPendings--;
    }
    if (_isRunning == 0) {
        return;
    }
    
    // stop scan
    DLog(@"stop bluetooth scan");
    if (_dutyTime > 1.0 && _sleepTime > 1.0) {
        [self.lblScanStatus setText:@"idle..."];
    }
    [self.bleManager stopScan];
    
    // pending start again
    if (_startPendings == 0) {
        _startPendings++;
        [self performSelector:@selector(myBLEStartScan) withObject:nil afterDelay:_sleepTime];
    }
}

- (void)myBatteryMonitor {
    if (_isRunning == 0) return;
    CGFloat battery = [[UIDevice currentDevice] batteryLevel] * 100;
    if (_isScanBeaconsMode == false) {
        if (fabs(_batteryAtStart - battery) >= _batteryDropToStop) {
            _isRunning = 0;
            _stopTime = [NSDate date];
            [self.lblScanStatus setText:@"stop"];
            [self myCloseLogFile];
            [self.bleManager stopScan];
            return;
        }
    }
    [self performSelector:@selector(myBatteryMonitor) withObject:nil afterDelay:1];
}

- (void)myOpenLogFile {
    BOOL isDir = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:@"/tmp/blescan" isDirectory:&isDir];
    if (exists == NO || (exists == YES && isDir == NO)) {
        [[NSFileManager defaultManager] createDirectoryAtPath:@"/tmp/blescan"
                                  withIntermediateDirectories:NO attributes:nil error:nil];
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"dd-MM-yyyy.HH-mm-ss"];
    _logFilePath = [NSString stringWithFormat:@"/tmp/blescan/%@.%d.%d.%d", [formatter stringFromDate:[NSDate date]], (int)(_interval*1000), (int)(_dutyTime*1000), (int)(_sleepTime*1000)];
    
    NSString *content = @"";
    if (_isScanBeaconsMode) {
        content = @"";
    } else {
        NSString *curtime = [DateFormatter stringFromDate:[NSDate date]];
        content = [NSString stringWithFormat:@"start log at %@ ----\nbattery: %.2f battery stop: %.2f\ninterval: %.2f s duty_percent: %.2f %%\nscan_time: %.2f s sleep_time: %.2f s\n-----\n\n", curtime, _batteryAtStart, _batteryDropToStop, _interval, _duty, _dutyTime, _sleepTime];
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:_logFilePath] == NO) {
        [[NSFileManager defaultManager] createFileAtPath:_logFilePath contents:
         [content dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
    }
}

- (void)myWriteLogToFile:(NSString *)logText {
    NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:_logFilePath];
    if (file) {
        [file seekToEndOfFile];
        [file writeData:[logText dataUsingEncoding:NSUTF8StringEncoding]];
        [file closeFile];
    }
}

- (void)myCloseLogFile {
    NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:_logFilePath];
    if (file) {
        NSString *content = @"";
        if (_isScanBeaconsMode) {
            content = @"";
        } else {
            _stopTime = [NSDate date];
            NSString *curtime = [DateFormatter stringFromDate:_stopTime];
            float durations = (float)([_stopTime timeIntervalSince1970] - [_startTime timeIntervalSince1970]);
            CGFloat battery = [[UIDevice currentDevice] batteryLevel] * 100;
            content = [NSString stringWithFormat:@"\nend log at %@ -----\nbattery: %.2f durations: %.2f s\n", curtime, battery, durations];
        }
        [file seekToEndOfFile];
        [file writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
        [file closeFile];
    }
}

#pragma mark - CBCentralManager Delegate

// 1. called whenever the device state changes
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    // Determine the state of the peripheral
    if ([central state] == CBCentralManagerStatePoweredOff) {
        // all peripheral objects that have been obtained from the central
        // become invalid and must be re-discover
        DLog(@"BLESCAN: CoreBluetooth BLE hardware is powered off");
    }
    else if ([central state] == CBCentralManagerStatePoweredOn) {
        DLog(@"BLESCAN: CoreBluetooth BLE hardware is powered on and ready");
    }
    else if ([central state] == CBCentralManagerStateUnauthorized) {
        DLog(@"BLESCAN: CoreBluetooth BLE state is unauthorized");
    }
    else if ([central state] == CBCentralManagerStateUnknown) {
        DLog(@"BLESCAN: CoreBluetooth BLE state is unknown");
    }
    else if ([central state] == CBCentralManagerStateUnsupported) {
        DLog(@"BLESCAN: CoreBluetooth BLE hardware is unsupported on this platform");
    }
}

// 2. called with the CBPeripheral class as uts main input paramenter.
// this contains most of the information there is know about a BLE peripheral
// RSSI stands for Received Signal Strength Indicator
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    
    // no need to log beacons in battery mode
    if (_isScanBeaconsMode == false) {
        return;
    }
    
    // log beacons
    NSString *localName = [advertisementData objectForKey:CBAdvertisementDataLocalNameKey];
    if ([localName length] > 0) {
        // only track estimote
        if ([localName isEqualToString:@"estimote"]) {
            NSString *beaconIden = [peripheral.identifier UUIDString];
            NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
            NSTimeInterval lastTimeStamp = [[_beaconsCached objectForKey:beaconIden] doubleValue];
            if (timestamp - lastTimeStamp >= 0.1) {
                [_beaconsCached setObject:[NSNumber numberWithDouble:timestamp] forKey:beaconIden];
                DLog(@"DeviceId: %@ - RSSI: %f - timestamp: %lf", [peripheral.identifier UUIDString], [RSSI floatValue], timestamp * 1000);
                NSString *logText = [NSString stringWithFormat:@"%@,%f,%lf\n", beaconIden, [RSSI floatValue], timestamp * 1000];
                [self myWriteLogToFile:logText];
            }
        }
    }
    else {
        // found unknow device
    }
}

// called when have successfully connected to the BLE peripheral
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    DLog(@"BLESCAN: connected to device");
}


#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField == self.tfInterval) {
        _interval = [self.tfInterval.text floatValue];
    }
    if (textField == self.tfDuty) {
        _duty = [self.tfDuty.text floatValue];
    }
    if (textField == self.tfBatteryStop) {
        _batteryDropToStop = [self.tfBatteryStop.text floatValue];
    }
    _dutyTime = (_duty / 100.0) * _interval;
    _sleepTime = _interval - _dutyTime;
    self.lblConfigResult.text = [NSString stringWithFormat:@"Config: scan %.2f s, sleep %.2f s \nbattery stop: %.2f %%", _dutyTime, _sleepTime, _batteryDropToStop];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if ([string hasSuffix:@"\n"]) {
        if (textField == self.tfInterval) {
            [self.tfDuty becomeFirstResponder];
        } else if (textField == self.tfDuty) {
            [self.tfBatteryStop becomeFirstResponder];
        }
        else {
            [self.tfBatteryStop resignFirstResponder];
        }
        return NO;
    }
    return YES;
}

@end
