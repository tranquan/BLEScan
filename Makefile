export ARCHS = armv7 arm64
export TARGET = iphone:latest:7.0

include theos/makefiles/common.mk

TWEAK_NAME = blescan
blescan_FILES = Tweak.xm BLEHandler.m
blescan_FRAMEWORKS = UIKit Foundation CoreFoundation CFNetwork SystemConfiguration MobileCoreServices CoreBluetooth
blescan_PRIVATE_FRAMEWORKS = AppSupport
blescan_LDFLAGS = -lz
blescan_LIBRARIES = rocketbootstrap

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
