TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES := Facebook

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FBLoginFix

FBLoginFix_FILES = Tweak.x
FBLoginFix_CFLAGS = -fobjc-arc
FBLoginFix_FRAMEWORKS = Security Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
