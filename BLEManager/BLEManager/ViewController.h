//
//  ViewController.h
//  BLEManager
//
//  Created by Kenji on 28/2/15.
//  Copyright (c) 2015 Kenji. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController<UITextFieldDelegate>

@property (nonatomic, weak) IBOutlet UILabel *lblBatteryLevel;
@property (nonatomic, weak) IBOutlet UILabel *lblConfigResult;
@property (nonatomic, weak) IBOutlet UITextField *tfInterval;
@property (nonatomic, weak) IBOutlet UITextField *tfDuty;
@property (nonatomic, weak) IBOutlet UITextField *tfBatteryStop;
@property (nonatomic, weak) IBOutlet UIButton *btnStartStop;

@end

