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

// bluetooth scan interval
static int BLESCAN_INTERVAL = 10;

// CBCentralManager
static CBCentralManager *centralManager;

// ========================================
// SPRINGBOARD
// ========================================

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application
{
	if (centralManager == nil) {
		centralManager = [[CBCentralManager alloc] initWithDelegate:nil queue:nil];
	}

	NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(myBluetoothScanThread) object:nil];
	[thread start];

  %orig;
}

// ----- main thread for doing bluetooth scan -----

%new
- (void)myBluetoothScanThread {

	static NSDateFormatter *formatter = nil;
	if (formatter == nil) {
		formatter = [[NSDateFormatter alloc] init];
		[formatter setDateFormat:@"dd/MM/yyyy hh:mm:ss"];
	}

	while (true) {
		NSString *curtime = [formatter stringFromDate:[NSDate date]];
		CGFloat battery = [[UIDevice currentDevice] batteryLevel] * 100;

		DLog(@"start bluetooth scan at time: %@ with battery level: %f", curtime, battery);
		[self myChangeThermalColor:BLESCAN_THERMAL_YELLOW];
		[centralManager scanForPeripheralsWithServices:nil options:nil];
		sleep(BLESCAN_INTERVAL);

		DLog(@"stop bluetooth scan");
		[self myChangeThermalColor:BLESCAN_THERMAL_ORANGE];
		[centralManager stopScan];
		sleep(BLESCAN_INTERVAL);
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
