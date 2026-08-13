ARCHS = arm64
TARGET = iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME = rootless
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = ShadowIPCCapture
ShadowIPCCapture_FILES = Tweak.xm
ShadowIPCCapture_FRAMEWORKS = Foundation
ShadowIPCCapture_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/tweak.mk
