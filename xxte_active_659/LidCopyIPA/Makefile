TARGET := iphone:clang:latest:14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = LidCopy
LidCopy_FILES = main.m
LidCopy_FRAMEWORKS = UIKit Foundation
LidCopy_CFLAGS = -fobjc-arc
LidCopy_CODESIGN_FLAGS = -SEntitlements.plist
LidCopy_INSTALL_PATH = /Applications

include $(THEOS_MAKE_PATH)/application.mk
