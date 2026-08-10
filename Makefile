TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES := Facebook

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FBAMARYT

FBAMARYT_FILES = Tweak.m
FBAMARYT_CFLAGS = -fobjc-arc
FBAMARYT_FRAMEWORKS = UIKit Security Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
