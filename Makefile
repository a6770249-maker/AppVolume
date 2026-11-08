export TARGET = iphone:clang:latest:15.0
export ARCHS = arm64 arm64e
export THEOS_PACKAGE_SCHEME = rootless

TWEAK_NAME = AppVolume
AppVolume_FILES = AppVolumeTweak.xm AppVolumeManager.m
AppVolume_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -I$(THEOS_PROJECT_DIR)
AppVolume_FRAMEWORKS = UIKit Foundation AVFoundation AudioToolbox

SUBPROJECTS += preferences

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 Preferences 2>/dev/null || true"
