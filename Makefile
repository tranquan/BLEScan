export ARCHS = armv7 armv7s arm64
export TARGET = iphone:latest:7.0

include theos/makefiles/common.mk

TWEAK_NAME = blescan
blescan_FILES = Tweak.xm
blescan_FRAMEWORKS = UIKit Foundation CoreFoundation CFNetwork SystemConfiguration MobileCoreServices CoreBluetooth
blescan_PRIVATE_FRAMEWORKS = AppSupport
blescan_LDFLAGS = -lz

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
