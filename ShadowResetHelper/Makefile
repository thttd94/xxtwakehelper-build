TARGET := iphone:clang:latest:14.0
ARCHS = arm64
include $(THEOS)/makefiles/common.mk
APPLICATION_NAME = ShadowResetHelper
ShadowResetHelper_FILES = Sources/main.m
ShadowResetHelper_FRAMEWORKS = UIKit Foundation
ShadowResetHelper_CFLAGS = -fobjc-arc
ShadowResetHelper_CODESIGN_FLAGS = -Sentitlements.plist
ShadowResetHelper_INSTALL_PATH = /Applications
include $(THEOS_MAKE_PATH)/application.mk
