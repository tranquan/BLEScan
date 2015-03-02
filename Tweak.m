#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBUIController.h>
#import <SpringBoard/SBAwayController.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBSoundPreferences.h>
#import <SpringBoard/SBUIController.h>
#import <SpringBoard/SBDisplayStack.h>
#import <SpringBoard/SBDisplay.h>
#import <SpringBoard/SBAlert.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBIconList.h>

#import <Availability.h>
#import <CoreBluetooth/CoreBluetooth.h>

#include <dlfcn.h>
#include <objc/runtime.h>

#import "BLEHandler.h"

// prototype rocketboostrap
typedef void (*rocketbootstrap_distributedmessagingcenter_apply)(id messaging_center);

// ========================================
// DEFINES
// ========================================

// device utils
#define IS_IPHONE5 					(([[UIScreen mainScreen] bounds].size.height-568)?NO:YES)
#define IS_OS_5_OR_LATER    ([[[UIDevice currentDevice] systemVersion] floatValue] >= 5.0)
#define IS_OS_6_OR_LATER    ([[[UIDevice currentDevice] systemVersion] floatValue] >= 6.0)
#define IS_OS_7_OR_LATER    ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0)
#define IS_OS_8_OR_LATER    ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)

// turn this off on release
// on build release: comment define SAMAEL_DEBUG for not write log
#define BLESCAN_DEBUG
#ifdef BLESCAN_DEBUG
#   define DLog(fmt, ...) NSLog((@"BLESCAN: %s " fmt), __PRETTY_FUNCTION__, ##__VA_ARGS__)
#else
#   define DLog(...)
#endif

// thermal color for ipromise status for iOS7
// 0: transparent
// 1: yellow	- ipromise OK
// 2: orange	- iPromise already run, but account not connected
// 3: red			- iPromise not run
//
static int BLESCAN_THERMAL_COLOR 				= 0;
static int BLESCAN_THERMAL_TRANSPARENT 	= 0;
static int BLESCAN_THERMAL_YELLOW 			= 1;
static int BLESCAN_THERMAL_ORANGE 			= 2;
static int BLESCAN_THERMAL_RED 					= 3;

// CBCentralManager
static CBCentralManager *CentralManager;
static BLEHandler *CentralHandler;
static NSDateFormatter *DateFormatter;

// globals vars
float _interval;
float _dutyPercent;
float _dutyTime;
float _sleepTime;
float _batteryDropToStop;
float _batteryAtStart;
float _currBatteryLevel;
float _prevBatteryLevel;

int _isRunning;
int _startPendings;
int _stopPendings;

NSDate *_startTime;
NSDate *_stopTime;
NSString *_logFilePath;

// ========================================
// SPRINGBOARD
// ========================================

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application
{
	DLog(@"register messaging center: com.kenji.blescan.notif");

	[self myChangeThermalColor:BLESCAN_THERMAL_RED];
	if (DateFormatter == nil) {
		DateFormatter = [[NSDateFormatter alloc] init];
		[DateFormatter setDateFormat:@"dd/MM/yyyy-hh:mm:ss"];
	}

	// dynamic load lib rocket boostrap if founded
  id messagingCenter = [objc_getClass("CPDistributedMessagingCenter") centerNamed:@"com.kenji.blescan.notif"];
  if (IS_OS_7_OR_LATER) {
    void *lib = dlopen("/usr/lib/librocketbootstrap.dylib", RTLD_LAZY);
    if (lib != NULL) {
      rocketbootstrap_distributedmessagingcenter_apply p_rocketbootstrap_distributedmessagingcenter_apply = 
      (rocketbootstrap_distributedmessagingcenter_apply)dlsym(lib, "rocketbootstrap_distributedmessagingcenter_apply");
      p_rocketbootstrap_distributedmessagingcenter_apply(messagingCenter);
    }
    dlclose(lib);
  }
  [messagingCenter runServerOnCurrentThread];
  [messagingCenter registerForMessageName:@"start_scan" target:self selector:@selector(handleMessageName:withUserInfo:)];
  [messagingCenter registerForMessageName:@"stop_scan" target:self selector:@selector(handleMessageName:withUserInfo:)];
  [messagingCenter registerForMessageName:@"get_state" target:self selector:@selector(handleMessageNameAndReply:withUserInfo:)];

  if (CentralHandler == nil) {
  	CentralHandler = [[BLEHandler alloc] init];
  }

	if (CentralManager == nil) {
		CentralManager = [[CBCentralManager alloc] initWithDelegate:CentralHandler queue:nil];
	}

  %orig;
}

%new
- (void)handleMessageName:(NSString *)name withUserInfo:(NSDictionary *)userInfo {
	@autoreleasepool {

		if ([name isEqualToString:@"start_scan"]) {
			
			_isRunning = 1;
			_interval = [[userInfo objectForKey:@"interval"] floatValue];
			_dutyPercent = [[userInfo objectForKey:@"duty_percent"] floatValue];
			_batteryDropToStop = [[userInfo objectForKey:@"battery_stop"] floatValue];
			_dutyTime = [[userInfo objectForKey:@"duty_time"] floatValue];
			_sleepTime = [[userInfo objectForKey:@"sleep_time"] floatValue];
			[_startTime release];
			_startTime = [[NSDate date] retain];

			CGFloat battery = [[UIDevice currentDevice] batteryLevel] * 100;
			_batteryAtStart = battery;
			_currBatteryLevel = battery;
			_prevBatteryLevel = battery + 1.0;

			[self myChangeThermalColor:BLESCAN_THERMAL_ORANGE];
			[self myOpenLogFile];
			[self myBLEStartScan];

			return;
		}

		if ([name isEqualToString:@"stop_scan"]) {

			_isRunning = 0;
			[_stopTime release];
			_stopTime = [[NSDate date] retain];

			[self myChangeThermalColor:BLESCAN_THERMAL_RED];
			[self myCloseLogFile];
			[CentralManager stopScan]; 
			
			return;
		}
	}
}

%new
- (NSDictionary *)handleMessageNameAndReply:(NSString *)name withUserInfo:(NSDictionary *)userInfo {
	@autoreleasepool {
		if ([name isEqualToString:@"get_state"]) {
			NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithFloat:_dutyTime], @"duty_time",
				[NSNumber numberWithFloat:_sleepTime], @"sleep_time",
				[NSNumber numberWithFloat:_batteryDropToStop], @"battery_stop",
        [NSNumber numberWithInt:_isRunning], @"is_running", nil];
			[info retain];
			return info;
		}
		return nil;
	}
}

%new 
- (void)myBLEStartScan {
	
	if (_startPendings > 0) {
		_startPendings--;
	}
	if (_isRunning == 0) {
		return;
	}

	@autoreleasepool {

		NSString *curtime = [DateFormatter stringFromDate:[NSDate date]];
		CGFloat battery = [[UIDevice currentDevice] batteryLevel] * 100;

		// check if battery drop enough to stop
		if (fabs(_batteryAtStart - battery) >= _batteryDropToStop) {
			_isRunning = 0;
			[_stopTime release];
			_stopTime = [[NSDate date] retain];

			[self myChangeThermalColor:BLESCAN_THERMAL_RED];
			[self myCloseLogFile];
			[CentralManager stopScan]; 
			return;
		}

		// log scan time
		_currBatteryLevel = battery;
		if (fabsf(_prevBatteryLevel - _currBatteryLevel) >= 1.0) {
			_prevBatteryLevel = _currBatteryLevel;
			NSString *logText = [NSString stringWithFormat:@"%@, %.2f\n", curtime, _currBatteryLevel];
			[self myWriteLogToFile:logText];
		}

		// update UI 
		DLog(@"start bluetooth scan at time: %@ with battery level: %f", curtime, battery);
		if (_dutyTime > 1.0 && _sleepTime > 1.0) {
			[self myChangeThermalColor:BLESCAN_THERMAL_YELLOW];
		}

		// do scan
		[CentralManager scanForPeripheralsWithServices:nil options:nil];

		// pending stop
		if (_stopPendings == 0) {
			_stopPendings++;
			[self performSelector:@selector(myBLEStopScan) withObject:nil afterDelay:_dutyTime]; 
		}
  }
}

%new 
- (void)myBLEStopScan {
	
	if (_stopPendings > 0) {
		_stopPendings--;
	}
	if (_isRunning == 0) {
		return;
	}

	@autoreleasepool {

  	DLog(@"stop bluetooth scan");
  	if (_dutyTime > 1.0 && _sleepTime > 1.0) {
			[self myChangeThermalColor:BLESCAN_THERMAL_ORANGE];
		}
		[CentralManager stopScan]; 

		if (_startPendings == 0) {
			_startPendings++;
 			[self performSelector:@selector(myBLEStartScan) withObject:nil afterDelay:_sleepTime]; 
 		}
  }
}

%new 
- (void)myOpenLogFile {
	@autoreleasepool {

		BOOL isDir = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:@"/tmp/blescan" isDirectory:&isDir];
    if (exists == NO || (exists == YES && isDir == NO)) {
        [[NSFileManager defaultManager] createDirectoryAtPath:@"/tmp/blescan" 
        	withIntermediateDirectories:NO attributes:nil error:nil];
    }
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setDateFormat:@"dd-MM-yyyy.hh-mm-ss"];
    [_logFilePath release];
    _logFilePath = [NSString stringWithFormat:@"/tmp/blescan/%@", [formatter stringFromDate:[NSDate date]]];
    [_logFilePath retain];

    NSString *curtime = [DateFormatter stringFromDate:[NSDate date]];
    NSString *content = [NSString stringWithFormat:@"start log at %@ ----\nbattery: %.2f battery stop: %.2f\ninterval: %.2f s duty_percent: %.2f %%\nscan_time: %.2f s sleep_time: %.2f s\n-----\n", curtime, _batteryAtStart, _batteryDropToStop, _interval, _dutyPercent, _dutyTime, _sleepTime];
    if ([[NSFileManager defaultManager] fileExistsAtPath:_logFilePath] == NO) {
        [[NSFileManager defaultManager] createFileAtPath:_logFilePath contents:
        	[content dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
    }
	}
}

%new 
- (void)myWriteLogToFile:(NSString *)logText {
	@autoreleasepool {
    NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:_logFilePath];
    if (file) {
    	[file seekToEndOfFile];
    	[file writeData:[logText dataUsingEncoding:NSUTF8StringEncoding]];
    	[file closeFile];
  	}
	}
}

%new 
- (void)myCloseLogFile {
	@autoreleasepool {
		NSFileHandle *file = [NSFileHandle fileHandleForUpdatingAtPath:_logFilePath];
		if (file) {
			NSString *curtime = [DateFormatter stringFromDate:[NSDate date]];
			CGFloat battery = [[UIDevice currentDevice] batteryLevel] * 100;
			NSString *content = [NSString stringWithFormat:@"end log at %@ -----\nbatter: %.2f\n", curtime, battery];
    	[file seekToEndOfFile];
    	[file writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
    	[file closeFile];
  	}
	}
}

%new
- (void)myChangeThermalColor:(int)thermalColor {
	BLESCAN_THERMAL_COLOR = thermalColor;
	[[%c(SBStatusBarStateAggregator) sharedInstance] _updateThermalColorItem];
}

%end

// ----- thermal color for ipromise status -----

%hook SBStatusBarStateAggregator

+ (int)_thermalColorForLevel:(int)arg1
{
  return BLESCAN_THERMAL_COLOR;
}

%end
