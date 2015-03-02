//
//  ViewController.m
//  BLEManager
//
//  Created by Kenji on 28/2/15.
//  Copyright (c) 2015 Kenji. All rights reserved.
//

#import "ViewController.h"
#import <AppSupport/CPDistributedMessagingCenter.h>
#import <objc/runtime.h>
#import "rocketbootstrap.h"

@interface ViewController () {
    int _isRunning;
    float _interval;
    float _duty;
    float _dutyTime;
    float _sleepTime;
    NSTimer *_updateTimer;
    CPDistributedMessagingCenter *_messagingCenter;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _interval = 0;
    _duty = 0;
    _dutyTime = 0;
    _sleepTime = 0;
    _messagingCenter = [objc_getClass("CPDistributedMessagingCenter") centerNamed:@"com.kenji.blescan.notif"];
    if (_messagingCenter) {
        rocketbootstrap_distributedmessagingcenter_apply(_messagingCenter);
    }
    
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    [self.view addGestureRecognizer:tapGesture];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // update battery state
    _updateTimer = [NSTimer timerWithTimeInterval:2 target:self selector:@selector(updateBatteryLevel:) userInfo:nil repeats:YES];
    [_updateTimer fire];
    
    // update scanning state
    if (_messagingCenter) {
        NSDictionary *info = [_messagingCenter sendMessageAndReceiveReplyName:@"get_state" userInfo:nil];
        if (info && [info isKindOfClass:[NSDictionary class]]) {
            
            _isRunning = [[info objectForKey:@"is_running"] intValue];
            if (_isRunning == 1) {
                [self.btnStartStop setTitle:@"Stop" forState:UIControlStateNormal];
            } else {
                [self.btnStartStop setTitle:@"Start" forState:UIControlStateNormal];
            }
            
            _dutyTime = [[info objectForKey:@"duty_time"] floatValue];
            _sleepTime = [[info objectForKey:@"sleep_time"] floatValue];
            self.lblConfigResult.text = [NSString stringWithFormat:@"Config: scan %.2f s, sleep %.2f s", _dutyTime, _sleepTime];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [_updateTimer invalidate];
    _updateTimer = nil;
    [super viewWillDisappear:animated];
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

- (void)updateBatteryLevel:(id)sender {
    float battery = [[UIDevice currentDevice] batteryLevel] * 100;
    if (battery < 0) {
        self.lblBatteryLevel.text = [NSString stringWithFormat:@"Battery Level: unknown"];
    } else {
        self.lblBatteryLevel.text = [NSString stringWithFormat:@"Battery Level: %.2f%%", battery];
    }
}

- (IBAction)btnStartStopTapped:(id)sender {
    
    if (_isRunning == 0) {
        _isRunning = 1;
        _interval = [self.tfInterval.text floatValue];
        _duty = [self.tfDuty.text floatValue];
        _dutyTime = (_duty / 100.0) * _interval;
        _sleepTime = _interval - _dutyTime;
        
        if (_dutyTime <= 0 || _sleepTime <= 0) {
            [[[UIAlertView alloc] initWithTitle:@"Alert" message:@"Cannot start scan with this config\nScan time must be >= 0" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            return;
        }
        
        [self.tfInterval resignFirstResponder];
        [self.tfDuty resignFirstResponder];
        
        [self sendToBackgroundMessage:@"start_scan" withUserInfo:@{@"duty_time" : @(_dutyTime),
                                                                   @"sleep_time" : @(_sleepTime)}];
        [self.btnStartStop setTitle:@"Stop" forState:UIControlStateNormal];
    } else {
        _isRunning = 0;
        [self sendToBackgroundMessage:@"stop_scan" withUserInfo:nil];
        [self.btnStartStop setTitle:@"Start" forState:UIControlStateNormal];
    }
}

- (void)sendToBackgroundMessage:(NSString *)name withUserInfo:(NSDictionary *)userInfo {
    if (_messagingCenter) {
        [_messagingCenter sendMessageName:name userInfo:userInfo];
    }
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
    _dutyTime = (_duty / 100.0) * _interval;
    _sleepTime = _interval - _dutyTime;
    self.lblConfigResult.text = [NSString stringWithFormat:@"Config: scan %.2f s, sleep %.2f s", _dutyTime, _sleepTime];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if ([string hasSuffix:@"\n"]) {
        if (textField == self.tfInterval) {
            [self.tfDuty becomeFirstResponder];
        } else {
            [textField resignFirstResponder];
        }
        return NO;
    }
    return YES;
}

@end
