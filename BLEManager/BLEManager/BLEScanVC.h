//
//  BLEScanVC.h
//  BLEManager
//
//  Created by Kenji on 21/4/15.
//  Copyright (c) 2015 Kenji. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BLEScanVC : UIViewController

@property (nonatomic, weak) IBOutlet UILabel *lblScanStatus;
@property (nonatomic, weak) IBOutlet UILabel *lblBatteryLevel;
@property (nonatomic, weak) IBOutlet UILabel *lblConfigResult;
@property (nonatomic, weak) IBOutlet UITextField *tfInterval;
@property (nonatomic, weak) IBOutlet UITextField *tfDuty;
@property (nonatomic, weak) IBOutlet UITextField *tfBatteryStop;
@property (nonatomic, weak) IBOutlet UIButton *btnStartStop;
@property (nonatomic, weak) IBOutlet UILabel *lblScanWholeInterval;
@property (nonatomic, weak) IBOutlet UILabel *lblScanBeaconsMode;
@property (nonatomic, weak) IBOutlet UILabel *lblScanDuplicateBeacons;
@property (nonatomic, weak) IBOutlet UISwitch *switchScanWholeInterval;
@property (nonatomic, weak) IBOutlet UISwitch *switchScanBeaconsMode;
@property (nonatomic, weak) IBOutlet UISwitch *switchScanDuplicateBeacons;

@end
