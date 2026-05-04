TARGET := iphone:clang:latest:14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = XXTWakeHelper
XXTWakeHelper_FILES = Sources/main.m Sources/AppDelegate.m
XXTWakeHelper_FRAMEWORKS = UIKit Foundation
XXTWakeHelper_CFLAGS = -fobjc-arc
XXTWakeHelper_CODESIGN_FLAGS = -Sentitlements.plist
XXTWakeHelper_INSTALL_PATH = /Applications

include $(THEOS_MAKE_PATH)/application.mk
