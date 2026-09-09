TARGET := iphone:clang:latest:14.0
ARCHS = arm64
include $(THEOS)/makefiles/common.mk
APPLICATION_NAME = DID603Diagnostic
DID603Diagnostic_FILES = Sources/main.m
DID603Diagnostic_FRAMEWORKS = UIKit Foundation Security
DID603Diagnostic_CFLAGS = -fobjc-arc
DID603Diagnostic_CODESIGN_FLAGS = -SEntitlements.plist
DID603Diagnostic_INSTALL_PATH = /Applications
include $(THEOS_MAKE_PATH)/application.mk
