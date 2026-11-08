include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = AppVolumePrefs

AppVolumePrefs_FILES = AVRootListController.m AVSliderCell.m ../AppVolumeManager.m
AppVolumePrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -I..
AppVolumePrefs_FRAMEWORKS = UIKit Foundation CoreGraphics
AppVolumePrefs_PRIVATE_FRAMEWORKS = Preferences
AppVolumePrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
